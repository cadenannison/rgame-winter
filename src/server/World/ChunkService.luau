--!strict
-- Builds the seeded 8x8 world layout and streams chunk models in/out around players.
-- Layout is pure (shared/logic/WorldLayout); this file only touches Roblox instances.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldLayout = require(Shared:WaitForChild("logic"):WaitForChild("WorldLayout"))
local World = require(Shared:WaitForChild("logic"):WaitForChild("World"))
local BiomeLogic = require(Shared:WaitForChild("logic"):WaitForChild("BiomeLogic"))
local PerfBudget = require(Shared:WaitForChild("logic"):WaitForChild("PerfBudget"))
local FireTiers = require(Shared:WaitForChild("logic"):WaitForChild("FireTiers"))
local MassivePlacement = require(Shared:WaitForChild("logic"):WaitForChild("MassivePlacement"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local Server = ServerScriptService:WaitForChild("Server")
local DebugService = require(Server:WaitForChild("Debug"):WaitForChild("DebugService"))
local GatherService = require(Server:WaitForChild("Items"):WaitForChild("GatherService"))
local PoiService = require(script.Parent:WaitForChild("PoiService"))
local WorldArt = require(Server:WaitForChild("Art"):WaitForChild("WorldArt"))
local TerrainBuilder = require(script.Parent:WaitForChild("TerrainBuilder"))
local TreeBuilder = require(script.Parent:WaitForChild("TreeBuilder"))

local WORLD = Config.World
local SLOT_TAGS = WORLD.SlotTags
local ORE_TAG = Config.Biome.OreSlotTag
local GATHER = Config.Gather
local PERF = Config.Perf
local SLOT_SIZE = Vector3.new(2, 2, 2)
local TELEPORT_HEIGHT = 5
-- Block-out visuals for gatherable slots (Phase 4 replaces with art). Kind = ItemCatalog.Nodes key.
local NODE_SLOTS: { [string]: { kind: string, size: Vector3, color: Color3, material: Enum.Material } } =
	{
		[SLOT_TAGS.Tree] = {
			kind = "Tree",
			size = Vector3.new(2, 10, 2),
			color = Color3.fromRGB(96, 70, 48),
			material = Enum.Material.Wood,
		},
		[SLOT_TAGS.Rock] = {
			kind = "Rock",
			size = Vector3.new(4, 3, 4),
			color = Color3.fromRGB(128, 132, 140),
			material = Enum.Material.Slate,
		},
		[ORE_TAG] = {
			kind = "IronOre",
			size = Vector3.new(4, 3, 4),
			color = Color3.fromRGB(110, 92, 84),
			material = Enum.Material.Slate,
		},
	}
local CAMPFIRE_SIZE = Vector3.new(4, 1, 4)
local CAMPFIRE_COLOR = Color3.fromRGB(230, 120, 40)

local ChunkService = {}

local layout: WorldLayout.Layout? = nil
local folder: Folder? = nil
local loaded: { [number]: Model } = {}
local keep: { [number]: boolean } = {}
local accumulator = 0
local partCounts: { [number]: number } = {} -- BaseParts per loaded chunk (for the live part cap)
local totalParts = 0
local loadedCount = 0
local heartbeatConn: RBXScriptConnection? = nil
local unregisterDebug: (() -> ())? = nil
local campFolder: Folder? = nil
local campFire: BasePart? = nil
-- Live tree clearing around fires (Config.FireRules): one disc per lit-or-not fire, kept so a chunk that
-- (re)loads later also skips the trees inside it.
type ClearDisc = { x: number, z: number, radius: number }
local fireDiscs: { [Instance]: ClearDisc } = {}
local fireConns: { [Instance]: { RBXScriptConnection } } = {}
local fireAddedConn: RBXScriptConnection? = nil
local fallHandler: ((player: Player) -> ())? = nil
local fallen: { [Player]: boolean } = {}
-- Massive structure sites (seeded, fixed per layout) and per-chunk build counters: MassiveService rebuilds
-- a structure whenever one of its covering chunks was rebuilt (carved voids would be overwritten).
local sites: { MassivePlacement.Site } = {}
local generations: { [number]: number } = {}
local extraPartsProvider: (() -> number)? = nil

-- Node state kept outside chunk models so depleted nodes stay depleted across unload/reload
-- (docs/KNOWN_ISSUES fix). key = "<chunkIndex>:<tag>:<i>".
type Pending = {
	part: BasePart,
	kind: string,
	key: string,
	at: number,
	transparency: number,
	canCollide: boolean,
}
local nodeMemory: { [string]: BiomeLogic.NodeMemo } = {}
local pendingByChunk: { [number]: { Pending } } = {}
local connsByChunk: { [number]: { RBXScriptConnection } } = {}

local function trackNode(index: number, part: BasePart, key: string)
	local conns = connsByChunk[index]
	if conns == nil then
		conns = {}
		connsByChunk[index] = conns
	end
	table.insert(
		conns,
		part:GetAttributeChangedSignal(ItemCatalog.NodeDepletedAttribute):Connect(function()
			if part:GetAttribute(ItemCatalog.NodeDepletedAttribute) == true then
				nodeMemory[key] = { depletedAt = os.clock() }
			else
				nodeMemory[key] = nil
			end
		end)
	)
	table.insert(
		conns,
		part:GetAttributeChangedSignal(ItemCatalog.NodeHitsAttribute):Connect(function()
			if part:GetAttribute(ItemCatalog.NodeDepletedAttribute) == true then
				return
			end
			local hits = part:GetAttribute(ItemCatalog.NodeHitsAttribute)
			if type(hits) == "number" and hits < GATHER.HitsToDeplete then
				nodeMemory[key] = { hits = hits }
			else
				nodeMemory[key] = nil
			end
		end)
	)
end

-- Terrain top Y for the current layout (camp-aware); the base height before start().
local function groundY(x: number, z: number): number
	local l = layout
	if not l then
		return Config.Terrain.BaseHeight
	end
	return World.heightAt(l.seed, x, z, l.camp.position.x, l.camp.position.z)
end

-- Tree/rock/ore slots are visible gather nodes registered with GatherService (tier and respawn come
-- from Config via ItemCatalog.Nodes); other slots are invisible markers. key is nil for markers.
local function newSlot(
	parent: Instance,
	tag: string,
	pos: WorldLayout.Vec2,
	index: number,
	key: string,
	biome: string,
	rng: Random,
	prebuilt: Part? -- TreeBuilder trunk (already sized, placed and skinned); skips the block-out
)
	local node = NODE_SLOTS[tag]
	local size = if node then node.size else SLOT_SIZE
	local part = prebuilt or Instance.new("Part")
	if not prebuilt then
		part.Name = tag
		part.Size = size
		part.Position = Vector3.new(pos.x, groundY(pos.x, pos.z) + size.Y / 2, pos.z)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		if node then
			part.Color = node.color
			part.Material = node.material
		else
			part.Transparency = 1
		end
	end
	CollectionService:AddTag(part, tag)
	part.Parent = parent
	if not node then
		return
	end
	if not prebuilt then
		WorldArt.skinNode(part, node.kind, biome, parent, rng)
	end
	local state, remaining = BiomeLogic.nodeState(
		nodeMemory[key],
		os.clock(),
		GATHER.RespawnSeconds,
		GATHER.HitsToDeplete
	)
	if state == "depleted" then
		-- Still depleted from before the unload: hidden and unregistered until the timer runs out.
		local pending: Pending = {
			part = part,
			kind = node.kind,
			key = key,
			at = os.clock() + remaining,
			transparency = part.Transparency,
			canCollide = part.CanCollide,
		}
		part.Transparency = 1
		part:SetAttribute(ItemCatalog.NodeDepletedAttribute, true)
		local list = pendingByChunk[index]
		if list == nil then
			list = {}
			pendingByChunk[index] = list
		end
		table.insert(list, pending)
		return
	end
	if state == "full" then
		nodeMemory[key] = nil
	end
	GatherService.registerNode(part, node.kind)
	if state == "partial" then
		local memo = nodeMemory[key]
		if memo and memo.hits then
			part:SetAttribute(ItemCatalog.NodeHitsAttribute, memo.hits)
		end
	end
	trackNode(index, part, key)
end

-- Brings back nodes whose respawn time passed while their chunk was loaded.
local function releasePending()
	local now = os.clock()
	for index, list in pendingByChunk do
		for i = #list, 1, -1 do
			local p = list[i]
			if now >= p.at then
				table.remove(list, i)
				nodeMemory[p.key] = nil
				if p.part.Parent ~= nil then
					p.part.Transparency = p.transparency
					GatherService.registerNode(p.part, p.kind)
					trackNode(index, p.part, p.key)
				end
			end
		end
	end
end

local function inClearDisc(x: number, z: number): boolean
	for _, d in fireDiscs do
		local dx, dz = x - d.x, z - d.z
		if dx * dx + dz * dz <= d.radius * d.radius then
			return true
		end
	end
	return false
end

local function buildChunk(chunk: WorldLayout.Chunk, root: Folder, forced: boolean): number
	local model = Instance.new("Model")
	model.Name = `Chunk_{chunk.cx}_{chunk.cy}`
	model:SetAttribute("ChunkIndex", chunk.index)
	model:SetAttribute("Ring", chunk.ring)
	model:SetAttribute("Variant", chunk.variant)
	model:SetAttribute("Rotation", chunk.rotation)

	-- Ground is Roblox Terrain voxels (not parts): seeded block heights, flat around the camp.
	local l = layout
	if l then
		-- Queued and drained a few thousand blocks per tick (Config.Terrain.BuildBlocksPerTick); forced loads
		-- (spawn, teleport) finish at once so there is ground under the player.
		TerrainBuilder.queue(
			chunk.index,
			l.seed,
			chunk.center.x,
			chunk.center.z,
			l.camp.position.x,
			l.camp.position.z
		)
		if forced then
			TerrainBuilder.flush(chunk.index)
		end
	end
	local rng = WorldArt.chunkRandom(chunk.index)
	WorldArt.decorChunk(model, chunk.biome, chunk.center.x, chunk.center.z, rng, groundY)

	local function fill(tag: string, list: { WorldLayout.Vec2 })
		for i, p in list do
			if MassivePlacement.blocks(sites, p.x, p.z) then
				continue -- inside a massive structure footprint
			end
			newSlot(model, tag, p, chunk.index, `{chunk.index}:{tag}:{i}`, chunk.biome, rng)
		end
	end
	local l2 = layout
	if l2 then
		TreeBuilder.forEach(l2, chunk, function(i: number, pos: WorldLayout.Vec2, trunk: Part)
			if inClearDisc(pos.x, pos.z) then
				trunk:Destroy() -- a fire cleared this spot after an earlier load
				return
			end
			newSlot(
				model,
				SLOT_TAGS.Tree,
				pos,
				chunk.index,
				`{chunk.index}:{SLOT_TAGS.Tree}:{i}`,
				chunk.biome,
				rng,
				trunk
			)
		end, MassivePlacement.clears(sites, chunk, l2.chunkSize))
	else
		fill(SLOT_TAGS.Tree, chunk.trees)
	end
	fill(SLOT_TAGS.Rock, chunk.rocks)
	fill(ORE_TAG, chunk.ore)
	fill(SLOT_TAGS.Food, chunk.food)
	fill(SLOT_TAGS.SpawnZone, chunk.spawnZones)
	for _, poi in chunk.pois do
		PoiService.build(model, poi, chunk.index)
	end
	model:SetAttribute("Biome", chunk.biome)
	model:SetAttribute("VariantId", chunk.variantId)

	CollectionService:AddTag(model, WORLD.ChunkTag)
	model.Parent = root
	loaded[chunk.index] = model
	generations[chunk.index] = (generations[chunk.index] or 0) + 1
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	partCounts[chunk.index] = parts
	totalParts += parts
	loadedCount += 1
	return parts
end

local function unloadChunk(index: number)
	local model = loaded[index]
	loaded[index] = nil
	pendingByChunk[index] = nil
	local conns = connsByChunk[index]
	if conns then
		for _, c in conns do
			c:Disconnect()
		end
		connsByChunk[index] = nil
	end
	TerrainBuilder.cancel(index) -- stops a half-built chunk and clears what it filled
	if model then
		model:Destroy()
		totalParts -= partCounts[index] or 0
		partCounts[index] = nil
		loadedCount -= 1
	end
end

local function playerPositions(): { WorldLayout.Vec2 }
	local out: { WorldLayout.Vec2 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			table.insert(out, { x = hrp.Position.X, z = hrp.Position.Z })
		end
	end
	return out
end

-- budgeted = streaming tick: at most Perf.ChunkLoadBudgetPerFrame chunks / ChunkPartBudgetPerFrame parts
-- per tick, nearest first, and none past Perf.MaxLiveParts. Unloads run first to free headroom. Forced
-- loads (spawn, teleport) are not budgeted.
local function applyDiff(positions: { WorldLayout.Vec2 }, budgeted: boolean)
	local l, root = layout, folder
	if not l or not root then
		return
	end
	local toLoad, toUnload = WorldLayout.streamDiff(l, WORLD, positions, loaded :: any, keep)
	for _, index in toUnload do
		unloadChunk(index)
	end
	if not budgeted then
		for _, index in toLoad do
			buildChunk(l.chunks[index], root, true)
		end
		return
	end
	local function nearest(index: number): number
		local best = math.huge
		for _, pos in positions do
			best = math.min(best, WorldLayout.distanceToChunk(l, l.chunks[index], pos))
		end
		return best
	end
	table.sort(toLoad, function(a, b)
		return nearest(a) < nearest(b)
	end)
	local average = if loadedCount > 0
		then totalParts / loadedCount
		else PERF.ChunkPartBudgetPerFrame
	local extraProvider = extraPartsProvider
	local allowance = PerfBudget.chunkAllowance(
		PERF.ChunkLoadBudgetPerFrame,
		totalParts + (if extraProvider then extraProvider() else 0),
		PERF.MaxLiveParts,
		average
	)
	local builtParts = 0
	for _, index in PerfBudget.take(toLoad, allowance) do
		if builtParts >= PERF.ChunkPartBudgetPerFrame then
			break
		end
		builtParts += buildChunk(l.chunks[index], root, false)
	end
end

-- Terrain top Y at (x, z) for the current seed and camp (use this, not World.heightAt directly, so
-- the flat camp area matches what was built). Nil before start().
function ChunkService.heightAt(x: number, z: number): number?
	local l = layout
	if not l then
		return nil
	end
	return World.heightAt(l.seed, x, z, l.camp.position.x, l.camp.position.z)
end

-- Registers the single handler called once per player who falls below Terrain.KillHeight or off the world
-- edge (World.shouldKill). Integration wires it to the run-end/downed logic (the player is gone, not
-- revivable). Returns an unregister function.
function ChunkService.setFallHandler(handler: (player: Player) -> ()): () -> ()
	fallHandler = handler
	return function()
		if fallHandler == handler then
			fallHandler = nil
		end
	end
end

local function checkFalls()
	local handler = fallHandler
	for player in fallen do
		if player.Parent == nil then
			fallen[player] = nil
		end
	end
	for _, player in Players:GetPlayers() do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			local p = hrp.Position
			if World.shouldKill(p.X, p.Y, p.Z) then
				if not fallen[player] then
					fallen[player] = true
					if handler then
						task.spawn(handler, player)
					end
				end
			else
				fallen[player] = nil
			end
		end
	end
end

-- Server stats for tools/qa/perf.luau (Studio sampling): loaded chunks and tracked chunk parts.
function ChunkService.getStats(): { chunks: number, parts: number }
	return { chunks = loadedCount, parts = totalParts }
end

-- Synchronously make sure chunks around a world position exist (spawn, teleport).
function ChunkService.ensureLoadedAround(x: number, z: number)
	applyDiff({ { x = x, z = z } }, false)
end

function ChunkService.getCampPosition(): Vector3?
	local l = layout
	if not l then
		return nil
	end
	return Vector3.new(
		l.camp.position.x,
		groundY(l.camp.position.x, l.camp.position.z) + TELEPORT_HEIGHT,
		l.camp.position.z
	)
end

-- Ground-level spawn point beside the camp fire (inside its warm radius). Nil until start().
function ChunkService.getCampSpawnPosition(): Vector3?
	local l = layout
	if not l then
		return nil
	end
	local x, z = l.camp.position.x + WORLD.CampSpawnOffset, l.camp.position.z
	return Vector3.new(x, groundY(x, z), z)
end

-- The camp campfire (tagged Config.Fire.Tag; FireService registers it from the tag).
function ChunkService.getCampFire(): BasePart?
	return campFire
end

-- Massive structure sites for this layout (empty before start()). Read-only.
function ChunkService.getSites(): { MassivePlacement.Site }
	return sites
end

function ChunkService.isLoaded(index: number): boolean
	return loaded[index] :: Model? ~= nil
end

-- Loaded and its terrain fully built (no queued voxel work left).
function ChunkService.isTerrainReady(index: number): boolean
	return loaded[index] :: Model? ~= nil and not TerrainBuilder.isPending(index)
end

-- Counter that increases every time the chunk model (and its terrain) is built.
function ChunkService.generation(index: number): number
	return generations[index] or 0
end

-- Rebuilds one loaded chunk's terrain (clears the structure's carved voids/pad after a structure is
-- destroyed while neighbouring chunks stay loaded).
function ChunkService.refreshTerrain(index: number)
	local l = layout
	if not l or (loaded[index] :: Model?) == nil then
		return
	end
	local chunk = l.chunks[index]
	TerrainBuilder.cancel(index)
	TerrainBuilder.queue(
		index,
		l.seed,
		chunk.center.x,
		chunk.center.z,
		l.camp.position.x,
		l.camp.position.z
	)
end

-- Voxels are free but structure parts are not: MassiveService reports its live part estimate so chunk
-- streaming keeps the total under Perf.MaxLiveParts.
function ChunkService.setExtraPartsProvider(fn: (() -> number)?)
	extraPartsProvider = fn
end

function ChunkService.getSeed(): number?
	return if layout then layout.seed else nil
end

local function teleportRing(player: Player, arg: unknown)
	local l = layout
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not l or type(arg) ~= "number" or not (hrp and hrp:IsA("BasePart")) then
		return
	end
	-- Debug ring 1 = start forest, then outward; clamped to the outermost ring.
	local ring = math.min(WORLD.StartForestRing + (arg - 1), WorldLayout.maxRing(l.gridSize))
	local pos = WorldLayout.ringPosition(l, ring)
	ChunkService.ensureLoadedAround(pos.x, pos.z)
	hrp.CFrame = CFrame.new(pos.x, groundY(pos.x, pos.z) + TELEPORT_HEIGHT, pos.z)
end

-- Removes live trees (trunk + foliage; GatherService unregisters the node on Destroying) whose base is within
-- radius studs (XZ) of (x, z). Returns the count. Trees are found through the tree tag, not a Workspace scan.
function ChunkService.clearTreesAround(x: number, z: number, radius: number): number
	local removed = 0
	for _, tree in CollectionService:GetTagged(SLOT_TAGS.Tree) do
		if tree:IsA("BasePart") and tree:IsDescendantOf(Workspace) then
			local dx, dz = tree.Position.X - x, tree.Position.Z - z
			if dx * dx + dz * dz <= radius * radius then
				tree:Destroy()
				removed += 1
			end
		end
	end
	return removed
end

local function firePosition(fire: Instance): Vector3?
	if fire:IsA("BasePart") then
		return fire.Position
	elseif fire:IsA("Model") then
		return fire:GetPivot().Position
	end
	return nil
end

local function applyFireClear(fire: Instance)
	local pos = firePosition(fire)
	if not pos or not Config.FireRules.ClearLiveTrees then
		return
	end
	local radius = FireTiers.treeClearRadius(fire:GetAttribute(Config.Fire.TierAttribute))
	local disc = fireDiscs[fire]
	if disc and disc.radius >= radius and disc.x == pos.X and disc.z == pos.Z then
		return
	end
	fireDiscs[fire] = { x = pos.X, z = pos.Z, radius = radius }
	ChunkService.clearTreesAround(pos.X, pos.Z, radius)
end

local function watchFire(fire: Instance)
	if fireConns[fire] then
		return
	end
	local conns: { RBXScriptConnection } = {}
	fireConns[fire] = conns
	table.insert(
		conns,
		fire:GetAttributeChangedSignal(Config.Fire.TierAttribute):Connect(function()
			applyFireClear(fire) -- an upgrade widens the cleared disc
		end)
	)
	table.insert(
		conns,
		fire.Destroying:Once(function()
			for _, c in conns do
				c:Disconnect()
			end
			fireConns[fire] = nil
			fireDiscs[fire] = nil
		end)
	)
	-- Next frame: FireService sets Tier on the fire after tagging it.
	task.defer(function()
		if fire.Parent ~= nil then
			applyFireClear(fire)
		end
	end)
end

function ChunkService.start()
	if layout then
		return
	end
	local attr = Workspace:GetAttribute(WORLD.SeedAttribute)
	local seed = if type(attr) == "number"
		then attr
		elseif RunService:IsStudio() then WORLD.DefaultSeed
		else os.time()
	local l = WorldLayout.generate(seed, WORLD)
	layout = l
	sites = MassivePlacement.plan(l)
	Workspace:SetAttribute(WORLD.SeedAttribute, seed)
	PoiService.start(seed)

	local root = Instance.new("Folder")
	root.Name = WORLD.ChunkFolderName
	root.Parent = Workspace
	folder = root

	keep[l.camp.chunkIndex] = true
	Workspace:SetAttribute(
		WORLD.CampAttribute,
		Vector3.new(
			l.camp.position.x,
			groundY(l.camp.position.x, l.camp.position.z),
			l.camp.position.z
		)
	)
	ChunkService.ensureLoadedAround(l.camp.position.x, l.camp.position.z)

	-- Camp campfire: outside the chunk models so streaming never removes it.
	local camp = Instance.new("Folder")
	camp.Name = WORLD.CampFolderName
	local fire = Instance.new("Part")
	fire.Name = Config.Fire.Tag
	fire.Size = CAMPFIRE_SIZE
	fire.Position = Vector3.new(
		l.camp.position.x,
		groundY(l.camp.position.x, l.camp.position.z) + CAMPFIRE_SIZE.Y / 2,
		l.camp.position.z
	)
	fire.Anchored = true
	fire.Color = CAMPFIRE_COLOR
	fire.Material = Enum.Material.Neon
	CollectionService:AddTag(fire, Config.Fire.Tag)
	fire.Parent = camp
	camp.Parent = Workspace
	campFolder = camp
	campFire = fire

	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < WORLD.StreamInterval then
			return
		end
		accumulator = 0
		releasePending()
		checkFalls()
		local positions = playerPositions()
		if #positions > 0 then
			applyDiff(positions, true)
		end
	end)

	unregisterDebug = DebugService.register("teleportRing", teleportRing)

	-- Fires placed after a chunk loaded clear the trees around them (and keep them cleared on reload).
	fireAddedConn = CollectionService:GetInstanceAddedSignal(Config.Fire.Tag):Connect(watchFire)
	for _, existing in CollectionService:GetTagged(Config.Fire.Tag) do
		watchFire(existing)
	end
end

function ChunkService.stop()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	if unregisterDebug then
		unregisterDebug()
		unregisterDebug = nil
	end
	if fireAddedConn then
		fireAddedConn:Disconnect()
		fireAddedConn = nil
	end
	for _, conns in fireConns do
		for _, c in conns do
			c:Disconnect()
		end
	end
	table.clear(fireConns)
	table.clear(fireDiscs)
	for index in table.clone(loaded) do
		unloadChunk(index)
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	if campFolder then
		campFolder:Destroy()
		campFolder = nil
		campFire = nil
	end
	TerrainBuilder.stop()
	table.clear(fallen)
	table.clear(nodeMemory)
	table.clear(partCounts)
	totalParts, loadedCount = 0, 0
	table.clear(pendingByChunk)
	table.clear(generations)
	sites = {}
	extraPartsProvider = nil
	PoiService.stop()
	layout = nil
end

return ChunkService
