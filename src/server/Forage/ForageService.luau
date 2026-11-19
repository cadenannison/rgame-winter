--!strict
-- Forage round: hand-picked forage, tool-gated finite resource nodes and relic fragments near structures.
-- Placement is pure and seeded (shared/logic/ForagePlan); this adapter spawns placeholder Parts lazily around
-- players (one loop for all of them), pools them, keeps them off structure footprints and ungrounded sites,
-- and stays under Config.Forage.MaxLiveParts and Perf.MaxLiveParts. Picking goes through GatherService
-- (GatherRequest: type, range, Guard, tool tier, inventory room); this module only owns the lifecycle.
--  * forage: respawns when the day counter changes (dawn). * nodes and relics: finite per run (per seed).
-- Coin credit (CoinValues) accumulates per player; ForageService.takeCoinCredit(player) is claimed at run end.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DayClock = require(Shared.logic.DayClock)
local ForagePlan = require(Shared.logic.ForagePlan)
local PerfBudget = require(Shared.logic.PerfBudget)
local SiteGround = require(Shared.logic.SiteGround)
local GatherService = require(script.Parent.Parent.Items.GatherService)
local ChunkService = require(script.Parent.Parent.World.ChunkService)
local GroundProbe = require(script.Parent.Parent.World.GroundProbe)

local F = Config.Forage
local FOLDER_NAME = "Forage"
local DEBUG_RING_MIN, DEBUG_RING_MAX = 6, 14 -- studs from the player for debug spawns

type Live = { part: Part, entry: ForagePlan.Entry }

local ForageService = {}

local folder: Folder? = nil
local live: { [string]: Live } = {}
local liveCount = 0
local byPart: { [Instance]: string } = {}
local pool: { Part } = {}
local consumed: { [string]: boolean } = {} -- nodes and relics used up this run
local pickedToday: { [string]: boolean } = {} -- forage picked since the last dawn
local rejected: { [string]: boolean } = {} -- permanent placement failures (footprint, ground)
local relicCache: { [string]: { ForagePlan.Entry } } = {}
local coinCredit: { [Player]: number } = {}
local connections: { RBXScriptConnection } = {}
local currentSeed: number? = nil
local lastDay: number? = nil
local accumulator = 0
local debugCounter = 0
local started = false

local function material(name: string): Enum.Material
	return (Enum.Material :: any)[name] or Enum.Material.SmoothPlastic
end

local function colorOf(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Visual spec for an entry (placeholder look; sprites come in the art pass).
local function specOf(entry: ForagePlan.Entry): ({ number }, { number }, string)
	for _, k in F.Forage do
		if k.itemId == entry.kind then
			return k.color, k.size, k.material
		end
	end
	for _, k in F.Nodes do
		if k.itemId == entry.kind then
			return k.color, k.size, k.material
		end
	end
	local r = F.Relic
	return r.color, r.size, r.material
end

local function getFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	folder = created
	return created
end

local function release(key: string)
	local item = live[key]
	if not item then
		return
	end
	live[key] = nil
	liveCount -= 1
	byPart[item.part] = nil
	GatherService.unregisterNode(item.part)
	CollectionService:RemoveTag(item.part, F.NodeTag)
	item.part.Parent = nil
	if #pool < F.MaxLiveParts then
		table.insert(pool, item.part)
	else
		item.part:Destroy()
	end
end

local function playerRoots(): { Vector3 }
	local list: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			table.insert(list, root.Position)
		end
	end
	return list
end

local function budgetOk(): boolean
	if liveCount >= F.MaxLiveParts then
		return false
	end
	-- chunk parts + every extra reservation (massive structures + our own live parts)
	return PerfBudget.hasPartRoom(
		ChunkService.getStats().parts,
		ChunkService.getExtraParts(),
		Config.Perf.MaxLiveParts,
		F.PartHeadroom
	)
end

local function terrainReady(x: number, z: number): boolean
	local index = ChunkService.chunkIndexAt(x, z)
	return index ~= nil and ChunkService.isLoaded(index) and ChunkService.isTerrainReady(index)
end

local function heightFn(x: number, z: number): number
	return ChunkService.heightAt(x, z) or 0
end

-- Positions kept clear (placed structures, fires, chests, workbenches), gathered once per pass.
local function avoidPositions(): { Vector3 }
	local list: { Vector3 } = {}
	for _, tag in F.AvoidTags do
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsA("BasePart") then
				table.insert(list, inst.Position)
			elseif inst:IsA("Model") then
				table.insert(list, inst:GetPivot().Position)
			end
		end
	end
	return list
end

local function nearAvoid(x: number, z: number, avoid: { Vector3 }): boolean
	local r2 = F.AvoidRadius * F.AvoidRadius
	for _, p in avoid do
		local dx, dz = p.X - x, p.Z - z
		if dx * dx + dz * dz < r2 then
			return true
		end
	end
	return false
end

local function onUsedUp(player: Player, node: Instance, itemId: string, granted: number)
	local key = byPart[node]
	if not key then
		return
	end
	local item = live[key]
	if item then
		if item.entry.class == "forage" then
			pickedToday[key] = true
		else
			consumed[key] = true
		end
	end
	local value = F.CoinValues[itemId]
	if value and granted > 0 and player.Parent == Players then
		coinCredit[player] = (coinCredit[player] or 0) + value * granted
	end
	release(key)
end

-- Spawns one entry. Relics pass margin 0 and no avoid list (they sit just outside a site by design).
-- Returns "ok" | "wait" (try again later: terrain, budget) | "reject" (never place here).
local function spawn(
	entry: ForagePlan.Entry,
	sites: { ForagePlan.Site },
	avoid: { Vector3 }?,
	margin: number
): string
	if not terrainReady(entry.x, entry.z) then
		return "wait"
	end
	if not budgetOk() then
		return "wait"
	end
	if ForagePlan.insideSite(entry.x, entry.z, sites, margin) then
		return "reject"
	end
	if avoid and nearAvoid(entry.x, entry.z, avoid) then
		return "reject"
	end
	local plan = SiteGround.plan(heightFn, entry.x, entry.z, F.GroundHalfSize, F.GroundHalfSize)
	if not plan.ok then
		return "reject"
	end
	local color, size, matName = specOf(entry)
	local y = GroundProbe.groundY(entry.x, entry.z, plan.baseY)
	local part: Part = table.remove(pool) or Instance.new("Part")
	part.Name = entry.kind
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Size = Vector3.new(size[1], size[2], size[3])
	part.Color = colorOf(color)
	part.Material = material(matName)
	part.Transparency = 0
	part.Position = Vector3.new(entry.x, y + size[2] / 2 + F.GroundLift, entry.z)
	part:SetAttribute(F.KindAttribute, entry.class)
	part:SetAttribute(F.CountAttribute, entry.count)
	part.Parent = getFolder()
	if not GatherService.registerNode(part, entry.kind) then
		part.Parent = nil
		return "reject"
	end
	GatherService.setManaged(part, onUsedUp)
	CollectionService:AddTag(part, F.NodeTag)
	live[entry.key] = { part = part, entry = entry }
	liveCount += 1
	byPart[part] = entry.key
	return "ok"
end

local function relicsOf(site: ForagePlan.Site, seed: number): { ForagePlan.Entry }
	local cached = relicCache[site.key]
	if cached then
		return cached
	end
	local list = ForagePlan.relics(seed, site)
	relicCache[site.key] = list
	return list
end

local function resetRun()
	for key in live do
		release(key)
	end
	table.clear(consumed)
	table.clear(pickedToday)
	table.clear(rejected)
	table.clear(relicCache)
end

local function step()
	local seed = ChunkService.getSeed()
	if seed == nil then
		return
	end
	if seed ~= currentSeed then
		currentSeed = seed
		ChunkService.setExtraPartsProvider("forage", ForageService.liveCount) -- ChunkService.stop clears providers
		resetRun()
	end
	local day = Workspace:GetAttribute(Config.Time.DayAttribute)
	if DayClock.isNewDay(lastDay, day) then
		lastDay = day :: number
		table.clear(pickedToday) -- dawn: forage grows back
	end
	local roots = playerRoots()
	-- Release anything no player is near.
	local despawn2 = F.DespawnRadius * F.DespawnRadius
	for key, item in live do
		local p = item.part.Position
		local near = false
		for _, r in roots do
			local dx, dz = r.X - p.X, r.Z - p.Z
			if dx * dx + dz * dz <= despawn2 then
				near = true
				break
			end
		end
		if not near then
			release(key)
		end
	end
	if #roots == 0 then
		return
	end
	local rawSites = ChunkService.getSites()
	local sites: { ForagePlan.Site } = {}
	for _, s in rawSites do
		table.insert(sites, { key = s.key, x = s.x, z = s.z, radius = s.radius, ring = s.ring })
	end
	local avoid = avoidPositions()
	local spawned = 0
	local spawn2 = F.SpawnRadius * F.SpawnRadius
	local function consider(
		entry: ForagePlan.Entry,
		root: Vector3,
		others: { ForagePlan.Site },
		useAvoid: boolean,
		margin: number
	)
		if
			live[entry.key]
			or consumed[entry.key]
			or pickedToday[entry.key]
			or rejected[entry.key]
			or spawned >= F.MaxSpawnsPerPass
		then
			return
		end
		local dx, dz = entry.x - root.X, entry.z - root.Z
		if dx * dx + dz * dz > spawn2 then
			return
		end
		local result = spawn(entry, others, if useAvoid then avoid else nil, margin)
		if result == "ok" then
			spawned += 1
		elseif result == "reject" then
			rejected[entry.key] = true
		end
	end
	for _, root in roots do
		local cx0, cz0 = ForagePlan.cellOf(root.X, root.Z)
		local span = math.ceil(F.SpawnRadius / F.CellSize)
		for cx = cx0 - span, cx0 + span do
			for cz = cz0 - span, cz0 + span do
				for _, entry in ForagePlan.cell(seed, cx, cz) do
					consider(entry, root, sites, true, F.SiteMargin)
				end
			end
		end
		for _, site in sites do
			local reach = F.SpawnRadius + site.radius * F.Relic.RadiusMax
			local dx, dz = site.x - root.X, site.z - root.Z
			if dx * dx + dz * dz <= reach * reach then
				local others: { ForagePlan.Site } = {}
				for _, o in sites do
					if o.key ~= site.key then
						table.insert(others, o)
					end
				end
				for _, entry in relicsOf(site, seed) do
					consider(entry, root, others, false, 0)
				end
			end
		end
	end
end

-- Debug (orchestrator wires /debug forage): spawns one pickup of every forage kind, node kind and a relic in
-- a ring around the player, ignoring ring/chance/day state (still grounded, still outside footprints).
-- Returns how many were placed.
function ForageService.DebugSpawnNear(player: Player): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return 0
	end
	local origin = root.Position
	local kinds: { { kind: string, class: string, count: number } } = {}
	for _, k in F.Forage do
		table.insert(kinds, { kind = k.itemId, class = "forage", count = k.maxCount })
	end
	for _, k in F.Nodes do
		table.insert(kinds, { kind = k.itemId, class = "node", count = k.maxCount })
	end
	table.insert(kinds, { kind = F.Relic.itemId, class = "relic", count = F.Relic.maxCount })
	local sites: { ForagePlan.Site } = {}
	for _, s in ChunkService.getSites() do
		table.insert(sites, { key = s.key, x = s.x, z = s.z, radius = s.radius, ring = s.ring })
	end
	local avoid = avoidPositions()
	local placed = 0
	for i, k in kinds do
		local angle = (i / #kinds) * math.pi * 2
		local dist = DEBUG_RING_MIN + (DEBUG_RING_MAX - DEBUG_RING_MIN) * ((i % 3) / 2)
		debugCounter += 1
		local entry: ForagePlan.Entry = {
			key = `d:{debugCounter}`,
			class = k.class,
			kind = k.kind,
			x = origin.X + math.cos(angle) * dist,
			z = origin.Z + math.sin(angle) * dist,
			count = k.count,
		}
		if spawn(entry, sites, avoid, 0) == "ok" then
			placed += 1
		end
	end
	return placed
end

-- Coins earned from picked-up valuables (Config.Forage.CoinValues) since the last claim. Clears the credit.
-- Paid at run end: RunLifecycleService.settle claims it via RunPayout (forageCoins).
function ForageService.takeCoinCredit(player: Player): number
	local credit = coinCredit[player] or 0
	coinCredit[player] = nil
	return credit
end

function ForageService.getCoinCredit(player: Player): number
	return coinCredit[player] or 0
end

function ForageService.liveCount(): number
	return liveCount
end

function ForageService.start()
	if started or not F.Enabled then
		return
	end
	started = true
	ChunkService.setExtraPartsProvider("forage", ForageService.liveCount) -- chunk streaming counts our parts
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			-- deferred so RunLifecycle's own PlayerRemoving settle can still claim the credit
			task.defer(function()
				coinCredit[player] = nil
			end)
		end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator >= F.UpdateInterval then
				accumulator = 0
				local ok, err = pcall(function(): string?
					step()
					return nil
				end)
				if not ok then
					warn(`ForageService: {err}`)
				end
			end
		end)
	)
end

function ForageService.stop()
	ChunkService.setExtraPartsProvider("forage", nil)
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	resetRun()
	for _, part in pool do
		part:Destroy()
	end
	table.clear(pool)
	table.clear(coinCredit)
	if folder then
		folder:Destroy()
		folder = nil
	end
	currentSeed = nil
	lastDay = nil
	started = false
end

return ForageService
