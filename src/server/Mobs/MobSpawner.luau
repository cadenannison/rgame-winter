--!strict
-- Mob creation and natural spawning: ring-weighted species with per-species caps, dread weighting for
-- ambient mobs, herds / packs, structure-footprint and fire exclusion, grounded sites only (species),
-- and mob parts counted against the live part budget (Perf.MaxLiveParts stays 6000).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Biomes = require(Shared.data.Biomes)
local MobData = require(Shared.data.Mobs)
local CreatureRegistry = require(Shared.Creatures.Registry)
local MobDread = require(Shared.logic.MobDread)
local MobRules = require(Shared.logic.MobRules)
local MobScaling = require(Shared.logic.MobScaling)
local MobSpawnPick = require(Shared.logic.MobSpawnPick)
local MobSpecies = require(Shared.logic.MobSpecies)
local MobWildlife = require(Shared.logic.MobWildlife)
local Server = script.Parent.Parent
local MobKinds = require(script.Parent.MobKinds)
local MobRegistry = require(script.Parent.MobRegistry)
local MobWorld = require(script.Parent.MobWorld)
local Species = require(script.Parent.Species)
local Types = require(script.Parent.MobTypes)

type MobKind = Types.MobKind
type MobRow = Types.MobRow
type PlayerInfo = Types.PlayerInfo

local MOBS = Config.Mobs

export type CreateOpts = { health: number?, damage: number?, groupId: number? }

local MobSpawner = {}

local spawnBlocker: ((x: number, z: number) -> boolean)? = nil -- true = no natural spawn here (structure footprints)
local spawnBiasProvider: ((Vector3) -> number)? = nil -- hot springs attract mobs
local eventBudgetMultiplier = 1 -- EventService spawn modifier (blizzard / false night)
local nextGroupId = 0
local pending: { MobWildlife.Pending } = {} -- killed animals waiting for their replacement day
local rng = Random.new()
local chunkService: any = nil
local groundProbe: any = nil
local warned: { [string]: boolean } = {}

function MobSpawner.setSpawnBlocker(fn: ((x: number, z: number) -> boolean)?)
	spawnBlocker = fn
end

function MobSpawner.setSpawnBiasProvider(fn: ((Vector3) -> number)?)
	spawnBiasProvider = fn
end

function MobSpawner.setBudgetMultiplier(multiplier: number)
	if type(multiplier) == "number" and multiplier == multiplier then
		eventBudgetMultiplier = math.clamp(multiplier, 0, Config.Scaling.MaxSpawnMultiplier)
	end
end

function MobSpawner.getBudgetMultiplier(): number
	return eventBudgetMultiplier
end

function MobSpawner.newGroupId(): number
	nextGroupId += 1
	return nextGroupId
end

-- Mob creation ----------------------------------------------------------------------------------------

function MobSpawner.createMob(kind: MobKind, position: Vector3, opts: CreateOpts?): Model?
	local parent = MobWorld.getFolder()
	if not parent then
		return nil
	end
	local isBoss = kind.category == "miniboss" or kind.category == "boss"
	local ring = MobWorld.ringAt(position)
	local scaledHealth, scaledDamage = MobScaling.mobStats(
		kind.name,
		kind.stats.Health,
		kind.stats.Damage,
		MobWorld.getDay(),
		ring,
		MobWorld.getPartyCount()
	)
	local health = (opts and opts.health) or scaledHealth
	local damage = (opts and opts.damage) or scaledDamage

	local model = Instance.new("Model")
	model.Name = kind.name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = kind.size
	root.Color = kind.color
	root.Material = Enum.Material.SmoothPlastic
	root.CanCollide = true
	root.Anchored = false
	root.CFrame = CFrame.new(position + Vector3.new(0, kind.size.Y / 2 + MOBS.SpawnLift, 0))
	root.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = kind.stats.WalkSpeed
	humanoid.HipHeight = 0
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = root
	model:SetAttribute(MOBS.KindAttribute, kind.name)
	model:SetAttribute(MOBS.HealthAttribute, health)

	-- Creature rig (parts + Motor6Ds + State attrs). A kind without a Def keeps the stub body (1 part).
	local okAttach, parts = pcall(CreatureRegistry.attach, kind.name, root)
	if not okAttach then
		if not warned[kind.name] then
			warned[kind.name] = true
			warn(`[Mobs] creature rig for {kind.name} failed: {parts}`)
		end
		model:Destroy()
		return nil
	end
	local partCount = math.max(1, parts :: number)

	local row: MobRow = {
		model = model,
		root = root,
		humanoid = humanoid,
		kind = kind,
		health = health,
		damage = damage,
		nextAttackAt = 0,
		wanderUntil = 0,
		lastAction = nil,
		burst = { burstEnd = 0, restEnd = 0 },
		windup = { startedAt = nil },
		leaveDeadline = nil,
		isBoss = isBoss,
		parts = partCount,
		ring = ring,
		home = position,
		groupId = if opts then opts.groupId else nil,
		lastStepAt = os.clock(),
		sp = {},
		stateWritten = nil,
		targetWritten = nil,
		headingWritten = nil,
		hurtUntil = 0,
		attackUntil = 0,
		telegraphSeconds = 0,
		provoked = false,
	}
	MobRegistry.add(row)
	local module = Species.get(kind.name)
	if module.init then
		module.init(row)
	end
	CollectionService:AddTag(model, Config.Mobs.Tag)
	model.Destroying:Once(function()
		MobRegistry.unregister(model)
	end)
	model.Parent = parent
	root:SetNetworkOwner(nil)
	return model
end

-- Natural spawning ---------------------------------------------------------------------------------------

-- Chunk parts from ChunkService (lazy: the world may not be running, e.g. lobby or headless).
local function chunkParts(): number?
	if chunkService == nil then
		local ok, module = pcall(require, Server.World.ChunkService)
		chunkService = if ok then module else false
	end
	if chunkService == false then
		return nil
	end
	local ok, stats = pcall(chunkService.getStats)
	return if ok and type(stats) == "table" then stats.parts else nil
end

local function terrainY(x: number, z: number, nearY: number): number?
	if groundProbe == nil then
		local ok, module = pcall(require, Server.World.GroundProbe)
		groundProbe = if ok then module else false
	end
	if groundProbe == false then
		return nil
	end
	local ok, y = pcall(groundProbe.raycastY, x, z, nearY)
	return if ok then y else nil
end

-- Largest hot-spring bias near any player (1 = none).
local function spawnBias(infos: { PlayerInfo }): number
	local provider = spawnBiasProvider
	if not provider then
		return 1
	end
	local best = 1
	for _, info in infos do
		local ok, value = pcall(provider, info.root.Position)
		if ok and type(value) == "number" and value == value and value > best then
			best = value
		end
	end
	return best
end

-- One member of a spawn: structure footprint, ground, fire exclusion and (species) grounded-site checks.
local function spawnMember(
	kind: MobKind,
	x: number,
	z: number,
	anchorY: number,
	groupId: number?,
	fires: { any }
): boolean
	local blocker = spawnBlocker
	if blocker and blocker(x, z) then
		return false -- inside a structure footprint (massive structures keep their own dressing/horror spawns)
	end
	local ground = MobWorld.groundAt(x, z, anchorY)
	if not ground then
		return false
	end
	-- Never spawn inside a lit fire's repel circle (the safe zone); fire radii are up to 90 + margin.
	if MobRules.spawnExcluded(kind.category, ground.X, ground.Z, fires) then
		return false
	end
	-- Day wildlife keeps out of every lit fire's radius too (Config.Wildlife.OutsideFireOnly).
	if MobWildlife.dayBlocked(MobWorld.getDanger(), ground.X, ground.Z, fires) then
		return false
	end
	if
		kind.species and not MobSpecies.groundedOk(terrainY(ground.X, ground.Z, ground.Y), ground.Y)
	then
		return false -- ungrounded site: unbuilt chunk, roof, tree top
	end
	return MobSpawner.createMob(kind, ground, { groupId = groupId }) ~= nil
end

-- Live creatures within Wildlife.NearRadius of a point (flat distance).
local function countNear(center: Vector3): number
	local here = MobWorld.toPoint(center)
	local n = 0
	for _, row in MobRegistry.rows() do
		if
			MobRules.distance(here, MobWorld.toPoint(row.root.Position))
			<= Config.Wildlife.NearRadius
		then
			n += 1
		end
	end
	return n
end

local function playerDists(infos: { PlayerInfo }, x: number, z: number): { number }
	local candidate = { x = x, z = z }
	local dists: { number } = {}
	for _, info in infos do
		table.insert(dists, MobRules.distance(candidate, MobWorld.toPoint(info.root.Position)))
	end
	return dists
end

-- Random site 60..160 studs from one player (the anchor).
local function candidateSite(anchor: Vector3): (number, number)
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(Config.Mobs.SpawnMinDistance, Config.Mobs.SpawnMaxDistance)
	return anchor.X + math.cos(angle) * dist, anchor.Z + math.sin(angle) * dist
end

-- Spawns `count` members of a kind around (x, z); true when the first member was placed.
local function spawnGroup(
	kind: MobKind,
	count: number,
	x: number,
	z: number,
	anchorY: number
): boolean
	local fires = MobWorld.collectFires()
	local groupId = if count > 1 then MobSpawner.newGroupId() else nil
	for i = 1, count do
		local mx, mz = x, z
		if i > 1 then
			local a = rng:NextNumber(0, math.pi * 2)
			mx += math.cos(a) * Config.Mobs.Spawning.PackSpread
			mz += math.sin(a) * Config.Mobs.Spawning.PackSpread
		end
		if not spawnMember(kind, mx, mz, anchorY, groupId, fires) and i == 1 then
			return false
		end
	end
	return true
end

-- A killed animal is replaced RespawnDays later (by the day counter), away from every player.
function MobSpawner.noteKill(kindName: string)
	local kind = MobKinds.ByName[kindName]
	if not kind then
		return
	end
	local role = if kind.species then kind.species.role else "passive"
	if MobWildlife.replaces(role, kind.category) then
		MobWildlife.schedule(pending, kindName, MobWorld.getDay(), rng:NextNumber())
	end
end

-- Pending replacements not yet placed (QA / debug).
function MobSpawner.pendingCount(): number
	return #pending
end

-- Places one due replacement; true when it consumed this tick.
local function tryReplacement(infos: { PlayerInfo }, budget: number, danger: boolean): boolean
	local entry = MobWildlife.nextDue(pending, MobWorld.getDay())
	if not entry then
		return false
	end
	local kind = MobKinds.ByName[entry.kind]
	if not kind then
		MobWildlife.remove(pending, entry)
		return false
	end
	if MobRegistry.liveOf(kind.name) >= MobSpawnPick.cap(kind.name, danger, true) then
		MobWildlife.remove(pending, entry) -- the world already holds enough of this kind
		return false
	end
	local anchor = infos[rng:NextInteger(1, #infos)].root.Position
	local x, z = candidateSite(anchor)
	if not MobWildlife.respawnPointOk(playerDists(infos, x, z)) then
		return false
	end
	local ring = MobWorld.ringAt(Vector3.new(x, 0, z))
	local def = kind.species
	if def then
		if MobSpecies.ringWeight(def, ring) <= 0 then
			return false
		end
	elseif table.find(kind.biomes or {}, Biomes.forRing(ring).id) == nil then
		return false
	end
	if kind.cost > 0 and MobRegistry.costUsed() + kind.cost > budget then
		return false
	end
	if def and not MobSpecies.partsOk(MobRegistry.partsUsed(), def.partCap, chunkParts()) then
		return false
	end
	if spawnGroup(kind, 1, x, z, anchor.Y) then
		MobWildlife.remove(pending, entry)
		return true
	end
	return false
end

-- One natural-spawn attempt: site, weighted pick, cost / parts checks. True when a mob was placed.
local function attemptSpawn(
	infos: { PlayerInfo },
	anchorIndex: number,
	budget: number,
	day: number,
	danger: boolean,
	dread: number
): boolean
	local anchor = infos[anchorIndex].root.Position
	local x, z = candidateSite(anchor)
	if
		not MobRules.spawnDistanceOk(
			playerDists(infos, x, z),
			Config.Mobs.SpawnMinDistance,
			Config.Mobs.SpawnMaxDistance
		)
	then
		return false
	end
	local ring = MobWorld.ringAt(Vector3.new(x, 0, z))
	local live: { [string]: number } = {}
	for name in MobKinds.ByName do
		live[name] = MobRegistry.liveOf(name)
	end
	local pick = MobSpawnPick.pick({
		entries = MobKinds.SpawnEntries,
		ring = ring,
		day = day,
		danger = danger,
		dread = dread,
		live = live,
		limits = true,
	}, rng:NextNumber())
	local kind = if pick then MobKinds.ByName[pick] else nil
	if not kind then
		return false
	end
	local costUsed = MobRegistry.costUsed()
	if kind.cost > 0 and costUsed + kind.cost > budget then
		return false
	end
	local def = kind.species
	local count = MobSpawnPick.groupSize(kind.name, MobRegistry.liveOf(kind.name), danger, true)
	while count > 1 and kind.cost > 0 and costUsed + kind.cost * count > budget do
		count -= 1
	end
	if count < 1 then
		return false
	end
	if
		def and not MobSpecies.partsOk(MobRegistry.partsUsed(), def.partCap * count, chunkParts())
	then
		return false
	end
	return spawnGroup(kind, count, x, z, anchor.Y)
end

function MobSpawner.trySpawn(infos: { PlayerInfo })
	if #infos == 0 then
		return
	end
	local day = MobWorld.getDay()
	local danger = MobWorld.getDanger()
	local maxRing = 0
	for _, info in infos do
		maxRing = math.max(maxRing, MobWorld.ringAt(info.root.Position))
	end
	local budget = MobScaling.liveBudget(
		Config.Mobs.Budget,
		MobScaling.multipliers(day, maxRing, #infos),
		#infos,
		danger,
		Config.Mobs.NightBudgetMultiplier
	)
	-- Event and hot-spring multipliers: capped together, and MaxLiveMobs still holds.
	local extra = eventBudgetMultiplier * spawnBias(infos)
	extra = math.clamp(extra, 0, Config.Scaling.MaxSpawnMultiplier)
	budget = math.clamp(math.floor(budget * extra), 0, Config.Scaling.MaxLiveMobs)
	if MobRegistry.count() >= Config.Scaling.MaxLiveMobs then
		return
	end
	if tryReplacement(infos, MobWildlife.budget(budget, maxRing, #infos), danger) then
		return
	end

	-- The anchor player's ring sets how many creatures should be near them (Config.Wildlife targets).
	local anchorIndex = rng:NextInteger(1, #infos)
	local anchor = infos[anchorIndex].root.Position
	local anchorRing = MobWorld.ringAt(anchor)
	budget = MobWildlife.budget(budget, anchorRing, #infos)
	local attempts = MobWildlife.attempts(countNear(anchor), anchorRing)
	if attempts <= 0 then
		return
	end
	local points: { MobDread.Point } = {}
	for _, info in infos do
		table.insert(points, MobWorld.toPoint(info.root.Position))
	end
	local dread = MobDread.factor(points, anchorIndex, #infos)
	for _ = 1, attempts do
		if attemptSpawn(infos, anchorIndex, budget, day, danger, dread) then
			return
		end
	end
end

-- Spawn kind-name at a ground position (server/QA/debug), no budget checks.
function MobSpawner.spawn(kindName: string, position: Vector3): Model?
	local kind = MobKinds.ByName[kindName]
	return if kind then MobSpawner.createMob(kind, position) else nil
end

-- Boss path: spawn with server-computed health/damage (BossService). Marks the model with BossKind.
function MobSpawner.spawnScaled(
	kindName: string,
	position: Vector3,
	health: number,
	damage: number
): Model?
	local kind = MobKinds.ByName[kindName]
	if not kind then
		return nil
	end
	-- Bosses may break through the fire edge, but never appear inside a fire's warm radius.
	local px, pz =
		MobRules.spawnPoint(kind.category, position.X, position.Z, MobWorld.collectFires())
	local spot = position
	if px ~= position.X or pz ~= position.Z then
		spot = MobWorld.groundAt(px, pz, position.Y) or Vector3.new(px, position.Y, pz)
	end
	local model = MobSpawner.createMob(kind, spot, { health = health, damage = damage })
	if model and (kind.category == "miniboss" or kind.category == "boss") then
		model:SetAttribute(MobData.BossAttribute, kindName)
	end
	return model
end

return MobSpawner
