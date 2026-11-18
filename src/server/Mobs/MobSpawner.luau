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
local MobSpecies = require(Shared.logic.MobSpecies)
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
	if
		kind.species and not MobSpecies.groundedOk(terrainY(ground.X, ground.Z, ground.Y), ground.Y)
	then
		return false -- ungrounded site: unbuilt chunk, roof, tree top
	end
	return MobSpawner.createMob(kind, ground, { groupId = groupId }) ~= nil
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

	local anchorIndex = rng:NextInteger(1, #infos)
	local anchor = infos[anchorIndex].root.Position
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(Config.Mobs.SpawnMinDistance, Config.Mobs.SpawnMaxDistance)
	local x = anchor.X + math.cos(angle) * dist
	local z = anchor.Z + math.sin(angle) * dist
	local candidate = { x = x, z = z }
	local dists: { number } = {}
	for _, info in infos do
		table.insert(dists, MobRules.distance(candidate, MobWorld.toPoint(info.root.Position)))
	end
	if
		not MobRules.spawnDistanceOk(
			dists,
			Config.Mobs.SpawnMinDistance,
			Config.Mobs.SpawnMaxDistance
		)
	then
		return
	end
	local ring = MobWorld.ringAt(Vector3.new(x, 0, z))
	local biomeId = Biomes.forRing(ring).id
	-- Legacy rows (biome lists) and species rows (ring weights) share one weighted pick.
	local names: { string } = {}
	local weights: { number } = {}
	for _, row in MobScaling.spawnTable(MobKinds.SpawnEntries, biomeId, day, danger) do
		table.insert(names, row.kind)
		table.insert(weights, row.weight * MobScaling.weightFactor(row.kind, day))
	end
	local points: { MobDread.Point } = {}
	for _, info in infos do
		table.insert(points, MobWorld.toPoint(info.root.Position))
	end
	local dread = MobDread.factor(points, anchorIndex, #infos)
	for _, kind in MobKinds.SpeciesKinds do
		local def = kind.species
		if def and MobSpecies.underCap(def, MobRegistry.liveOf(kind.name)) then
			local w = MobSpecies.spawnWeight(def, ring, day, danger)
			if w > 0 then
				table.insert(names, kind.name)
				table.insert(weights, MobDread.weight(def.role, w, dread))
			end
		end
	end
	local pick = MobRules.pickWeighted(weights, rng:NextNumber())
	if not pick then
		return
	end
	local kind = MobKinds.ByName[names[pick]]
	if not kind then
		return
	end
	local costUsed = MobRegistry.costUsed()
	if kind.cost > 0 and costUsed + kind.cost > budget then
		return
	end
	local def = kind.species
	local count = 1
	if def then
		count = MobSpecies.groupSize(def, MobRegistry.liveOf(kind.name))
		while count > 1 and kind.cost > 0 and costUsed + kind.cost * count > budget do
			count -= 1
		end
		if
			count < 1
			or not MobSpecies.partsOk(MobRegistry.partsUsed(), def.partCap * count, chunkParts())
		then
			return
		end
	end
	local fires = MobWorld.collectFires()
	local groupId = if count > 1 then MobSpawner.newGroupId() else nil
	for i = 1, count do
		local mx, mz = x, z
		if i > 1 then
			local a = rng:NextNumber(0, math.pi * 2)
			mx += math.cos(a) * Config.Mobs.Spawning.PackSpread
			mz += math.sin(a) * Config.Mobs.Spawning.PackSpread
		end
		if not spawnMember(kind, mx, mz, anchor.Y, groupId, fires) and i == 1 then
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
