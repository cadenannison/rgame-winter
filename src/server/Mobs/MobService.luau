--!strict
-- Server-authoritative mobs: capped spawn budget near players, AI only near players,
-- one Heartbeat loop for all mobs, melee via AttackRequest. Spec: docs/systems/mobs.md

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local MobAI = require(Shared.logic.MobAI)
local MobRules = require(Shared.logic.MobRules)
local MobScaling = require(Shared.logic.MobScaling)
local Biomes = require(Shared.data.Biomes)
local MobData = require(Shared.data.Mobs)
local Types = require(Shared.data.Types)
local Server = script.Parent.Parent
local Guard = require(Server.Net.Guard)
local SwingRelay = require(Server.Atmosphere.SwingRelay)
local FireRepel = require(Shared.logic.FireRepel)
local World = require(Shared.logic.World)
local InventoryService = require(Server.Items.InventoryService)

type MobKind = {
	name: string,
	stats: Config.MobStats,
	behavior: MobAI.Behavior,
	size: Vector3,
	color: Color3,
	category: string, -- "animal" | "hostile" | "miniboss" | "boss"
	cost: number, -- budget slots (0 for bosses)
	breaksFire: boolean, -- ignores the fire repel edge (heavy, ranged, bosses)
	breaksStructures: boolean,
	ambush: boolean,
	biomes: { string }?, -- set after the literal for Phase 1 kinds
	minDay: number,
}

type MobRow = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	kind: MobKind,
	health: number,
	damage: number,
	nextAttackAt: number,
	wanderUntil: number,
	lastAction: string?,
	burst: MobAI.Burst,
	windup: MobAI.Windup,
	leaveDeadline: number?,
	isBoss: boolean,
}

type PlayerInfo = { player: Player, root: BasePart, humanoid: Humanoid }

-- Visual/behavior data rows. Stats come from Config.Mobs.
local KINDS: { MobKind } = {
	{
		name = "ArcticHare",
		stats = Config.Mobs.Hare,
		behavior = "Flee",
		size = Vector3.new(1.5, 1.5, 2),
		color = Color3.fromRGB(240, 240, 245),
		category = "animal",
		cost = 1,
		breaksFire = false,
		breaksStructures = false,
		ambush = false,
		minDay = 1,
	},
	{
		name = "Caribou",
		stats = Config.Mobs.Caribou,
		behavior = "Flee",
		size = Vector3.new(2.5, 4, 5),
		color = Color3.fromRGB(150, 120, 90),
		category = "animal",
		cost = 1,
		breaksFire = false,
		breaksStructures = false,
		ambush = false,
		minDay = 1,
	},
	{
		name = "Wolf",
		stats = Config.Mobs.Wolf,
		behavior = "Hunt",
		size = Vector3.new(2, 3, 4),
		color = Color3.fromRGB(90, 90, 100),
		category = "hostile",
		cost = 1,
		breaksFire = false,
		breaksStructures = false,
		ambush = false,
		minDay = 1,
	},
}
-- Phase 1 kinds spawn in the biomes listed in data/Mobs.
for _, kind in KINDS do
	kind.biomes = MobData.LegacyBiomes[kind.name] or {}
end

-- Visuals for Phase 3 kinds (stats come from data/Mobs).
local VISUALS: { [string]: { size: Vector3, color: Color3 } } = {
	Fish = { size = Vector3.new(1, 0.8, 2), color = Color3.fromRGB(150, 190, 210) },
	PolarBear = { size = Vector3.new(4, 5, 7), color = Color3.fromRGB(235, 235, 240) },
	IceWraith = { size = Vector3.new(2, 5, 2), color = Color3.fromRGB(150, 220, 255) },
	SnowLurker = { size = Vector3.new(2.5, 3, 2.5), color = Color3.fromRGB(205, 215, 225) },
	CaveCrawler = { size = Vector3.new(2, 1.5, 3.5), color = Color3.fromRGB(70, 60, 80) },
	IceWarden = { size = Vector3.new(6, 10, 6), color = Color3.fromRGB(120, 180, 230) },
	CaveMatriarch = { size = Vector3.new(7, 7, 11), color = Color3.fromRGB(80, 55, 90) },
	RuinColossus = { size = Vector3.new(8, 14, 8), color = Color3.fromRGB(120, 115, 110) },
	WhiteoutBeast = { size = Vector3.new(7, 9, 11), color = Color3.fromRGB(245, 245, 250) },
}

local function kindFromDef(def: Types.MobDef): MobKind
	local look = VISUALS[def.kind]
	local hare = Config.Mobs.Hare
	local passive = def.category == "animal"
	return {
		name = def.kind,
		stats = {
			Health = def.health,
			Damage = def.damage,
			WalkSpeed = def.walkSpeed,
			-- MobService moves "Chase" at FleeSpeed, so hostiles use their chase speed here.
			FleeSpeed = if passive then def.fleeSpeed else def.chaseSpeed,
			AggroRange = def.aggroRange,
			AttackRange = def.attackRange,
			AttackCooldown = def.attackCooldown,
			FleeRange = def.fleeRange,
			FleeBurstSeconds = hare.FleeBurstSeconds,
			FleeRestSeconds = hare.FleeRestSeconds,
			HitRadius = def.hitRadius,
			NightOnly = def.nightOnly,
			Weight = def.weight,
			DropId = def.dropId,
			DropCount = def.dropCount,
		},
		behavior = if passive then "Flee" else "Hunt",
		size = if look then look.size else Vector3.new(3, 3, 3),
		color = if look then look.color else Color3.fromRGB(200, 200, 200),
		category = def.category,
		cost = def.budgetCost,
		breaksFire = def.breaksFireRadius,
		breaksStructures = def.breaksStructures,
		ambush = def.ambush,
		biomes = def.biomes,
		minDay = def.minDay,
	}
end

local KIND_BY_NAME: { [string]: MobKind } = {}
for _, kind in KINDS do
	KIND_BY_NAME[kind.name] = kind
end
for _, def in MobData.List do
	KIND_BY_NAME[def.kind] = kindFromDef(def)
end

local MOBS = Config.Mobs
local NIGHT = Config.Night
local HEALTH_ATTRIBUTE = MOBS.HealthAttribute

local MobService = {}

local started = false
local killHandler: ((Player, string, boolean) -> ())? = nil
local hitHandler: ((Player, string) -> ())? = nil
local folder: Folder? = nil
local rows: { [Model]: MobRow } = {}
local rowCount = 0
local costUsed = 0 -- budget slots held by live non-boss mobs
local partyCount = 1
local ringProvider: ((Vector3) -> number)? = nil
local eventBudgetMultiplier = 1 -- EventService spawn modifier (blizzard / false night)
local spawnBiasProvider: ((Vector3) -> number)? = nil -- hot springs attract mobs
local spawnBlocker: ((x: number, z: number) -> boolean)? = nil -- true = no natural spawn here (structure footprints)
local killedListeners: { (Model, string, Player?) -> () } = {}
local spawnHooks: { (infos: { PlayerInfo }, day: number, now: number) -> () } = {}
local spawnAccum = 0
local aiAccum = 0
local lastMeleeAt: { [Player]: number } = {}
local rng = Random.new()

-- Count of AI steps executed (tests/QA: stays flat with no player nearby).
MobService.AIStepCount = 0

local function getDay(): number
	local day = Workspace:GetAttribute(Config.Time.DayAttribute)
	return if type(day) == "number" then day else 1
end

local function getIsNight(): boolean
	return Workspace:GetAttribute(Config.Time.IsNightAttribute) == true
end

-- Night or an active blizzard: hostiles hunt.
local function getDanger(): boolean
	return getIsNight() or Workspace:GetAttribute(Config.Blizzard.ActiveAttribute) == true
end

-- Biome ring at a position (0 when no provider is wired: brief 18 wires BiomeService.getRing).
local function ringAt(position: Vector3): number
	local provider = ringProvider
	if not provider then
		return 0
	end
	local ok, ring = pcall(provider, position)
	return if ok and type(ring) == "number" and ring == ring then math.max(0, ring) else 0
end

-- Spawn table source: animals and hostiles only (bosses never use the normal budget).
local SPAWN_ENTRIES: { MobScaling.Entry } = {}
for _, kind in KIND_BY_NAME do
	if kind.category == "animal" or kind.category == "hostile" then
		table.insert(SPAWN_ENTRIES, {
			kind = kind.name,
			category = kind.category :: string,
			biomes = kind.biomes or ({} :: { string }),
			minDay = kind.minDay,
			nightOnly = kind.stats.NightOnly,
			weight = kind.stats.Weight,
		})
	end
end
table.sort(SPAWN_ENTRIES, function(a, b)
	return a.kind < b.kind
end)

local function collectPlayers(): { PlayerInfo }
	local list: { PlayerInfo } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			humanoid
			and root
			and root:IsA("BasePart")
			and humanoid.Health > 0
			and player:GetAttribute(Config.Downed.StateAttribute) ~= true
		then
			table.insert(list, { player = player, root = root, humanoid = humanoid })
		end
	end
	return list
end

local function toPoint(position: Vector3): MobRules.Point
	return { x = position.X, z = position.Z }
end

-- Drops a mob from the registry (once); keeps the budget counters in step.
local function unregister(model: Model)
	local row = rows[model]
	if row then
		rows[model] = nil
		rowCount -= 1
		if not row.isBoss then
			costUsed -= row.kind.cost
		end
	end
end

local function removeMob(model: Model)
	unregister(model)
	if model.Parent then
		model:Destroy()
	end
end

type CreateOpts = { health: number?, damage: number? }

local function createMob(kind: MobKind, position: Vector3, opts: CreateOpts?): Model?
	local parent = folder
	if not parent then
		return nil
	end
	local isBoss = kind.category == "miniboss" or kind.category == "boss"
	local scaledHealth, scaledDamage = MobScaling.mobStats(
		kind.name,
		kind.stats.Health,
		kind.stats.Damage,
		getDay(),
		ringAt(position),
		partyCount
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
	model:SetAttribute(HEALTH_ATTRIBUTE, health)

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
	}
	rows[model] = row
	rowCount += 1
	if not isBoss then
		costUsed += kind.cost
	end
	CollectionService:AddTag(model, Config.Mobs.Tag)
	model.Destroying:Once(function()
		unregister(model)
	end)
	model.Parent = parent
	root:SetNetworkOwner(nil)
	return model
end

local function groundAt(x: number, z: number, originY: number): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if folder then
		table.insert(exclude, folder)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(
		Vector3.new(x, originY + MOBS.SpawnRayHeight, z),
		Vector3.new(0, -MOBS.SpawnRayLength, 0),
		params
	)
	return if hit then hit.Position else nil
end

-- Lit campfires from the Fire tag (position + per-fire WarmRadius attribute, Config fallback).
local function collectFires(): { FireRepel.Fire }
	local out: { FireRepel.Fire } = {}
	for _, fire in CollectionService:GetTagged(Config.Fire.Tag) do
		local fuel = fire:GetAttribute(Config.Fire.FuelAttribute)
		if type(fuel) == "number" and fuel > 0 then
			local p: Vector3? = nil
			if fire:IsA("Model") then
				p = fire:GetPivot().Position
			elseif fire:IsA("BasePart") then
				p = fire.Position
			end
			if p then
				local r = fire:GetAttribute(NIGHT.WarmRadiusAttribute)
				table.insert(out, {
					x = p.X,
					z = p.Z,
					radius = if type(r) == "number" then r else Config.Fire.WarmRadius,
				})
			end
		end
	end
	return out
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

local function trySpawn(infos: { PlayerInfo })
	if #infos == 0 then
		return
	end
	local day = getDay()
	local danger = getDanger()
	local maxRing = 0
	for _, info in infos do
		maxRing = math.max(maxRing, ringAt(info.root.Position))
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
	if costUsed >= budget or rowCount >= Config.Scaling.MaxLiveMobs then
		return
	end

	local anchor = infos[rng:NextInteger(1, #infos)].root.Position
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(Config.Mobs.SpawnMinDistance, Config.Mobs.SpawnMaxDistance)
	local x = anchor.X + math.cos(angle) * dist
	local z = anchor.Z + math.sin(angle) * dist
	local candidate = { x = x, z = z }
	local dists: { number } = {}
	for _, info in infos do
		table.insert(dists, MobRules.distance(candidate, toPoint(info.root.Position)))
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
	local biomeId = Biomes.forRing(ringAt(Vector3.new(x, 0, z))).id
	local spawnTable = MobScaling.spawnTable(SPAWN_ENTRIES, biomeId, day, danger)
	local weights: { number } = {}
	for _, row in spawnTable do
		table.insert(weights, row.weight * MobScaling.weightFactor(row.kind, day))
	end
	local pick = MobRules.pickWeighted(weights, rng:NextNumber())
	if not pick then
		return
	end
	local kind = KIND_BY_NAME[spawnTable[pick].kind]
	if not kind or costUsed + kind.cost > budget then
		return
	end
	local blocker = spawnBlocker
	if blocker and blocker(x, z) then
		return -- inside a structure footprint (massive structures keep their own dressing/horror spawns)
	end
	local ground = groundAt(x, z, anchor.Y)
	if ground then
		-- Never spawn inside a lit fire's repel circle (the safe zone); fire radii are up to 90 + margin.
		if MobRules.spawnExcluded(kind.category, ground.X, ground.Z, collectFires()) then
			return
		end
		createMob(kind, ground)
	end
end

local function horizontalDir(from: Vector3, to: Vector3): Vector3
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return if d.Magnitude > 0.001 then d.Unit else Vector3.new(1, 0, 0)
end

local function repelOf(f: FireRepel.Fire): number
	return FireRepel.repelRadius(f.radius, Config.Fire.RepelRadius, NIGHT.RepelMargin)
end

local function setWindup(row: MobRow, on: boolean)
	if (row.model:GetAttribute(NIGHT.WindupAttribute) == true) ~= on then
		row.model:SetAttribute(NIGHT.WindupAttribute, on)
	end
end

local function biteSeq(player: Player)
	local n = player:GetAttribute(NIGHT.BiteAttribute)
	player:SetAttribute(NIGHT.BiteAttribute, (if type(n) == "number" then n else 0) + 1)
end

-- Damages the nearest wall/door within reach (server-side; StructureHealth is owned by structures).
local function breakStructure(row: MobRow, pos: Vector3): boolean
	local reach = row.kind.stats.AttackRange + row.kind.stats.HitRadius
	local best: Instance? = nil
	local bestDist = reach
	for _, structure in CollectionService:GetTagged(Config.Build.BlockerTag) do
		local p: Vector3? = nil
		if structure:IsA("Model") then
			p = structure:GetPivot().Position
		elseif structure:IsA("BasePart") then
			p = structure.Position
		end
		if p then
			local d = (p - pos).Magnitude
			if d <= bestDist then
				bestDist = d
				best = structure
			end
		end
	end
	if not best then
		return false
	end
	local health = best:GetAttribute(Config.Build.HealthAttribute)
	if type(health) == "number" then
		local left = health - row.damage
		if left <= 0 then
			best:Destroy()
		else
			best:SetAttribute(Config.Build.HealthAttribute, left)
		end
	end
	return true
end

local function stepMob(
	row: MobRow,
	infos: { PlayerInfo },
	fires: { FireRepel.Fire },
	isNight: boolean,
	now: number
)
	local pos = row.root.Position
	local stats = row.kind.stats
	local nearestInfo: PlayerInfo? = nil
	local nearest: number? = nil
	for _, info in infos do
		local d = MobRules.distance(toPoint(pos), toPoint(info.root.Position))
		if nearest == nil or d < nearest then
			nearest = d
			nearestInfo = info
		end
	end
	local hunter = row.kind.behavior == "Hunt"
	local repelled = MobRules.repelledByFire(row.kind.category, row.kind.breaksFire)
	local fireIndex = if hunter and repelled
		then FireRepel.insideAny(pos.X, pos.Z, fires, NIGHT.RepelMargin, Config.Fire.RepelRadius)
		else nil
	local fire = if fireIndex then fires[fireIndex] else nil
	local action = MobAI.decide({
		behavior = row.kind.behavior,
		nearestPlayerDist = nearest,
		isNight = isNight,
		nightOnly = stats.NightOnly,
		fleeRange = stats.FleeRange,
		aggroRange = stats.AggroRange,
		attackRange = stats.AttackRange,
		inFireRepel = fire ~= nil,
		canAttack = now >= row.nextAttackAt,
	})
	-- A windup in progress holds its place until the bite lands or the target leaves strike reach.
	if hunter and row.windup.startedAt ~= nil and (action == "Chase" or action == "Attack") then
		action = "Attack"
	end
	if hunter and action ~= "Attack" and row.windup.startedAt ~= nil then
		row.windup.startedAt = nil
		setWindup(row, false)
	end
	-- Ambusher: lies buried (half hidden) until a player is inside aggro range.
	if row.kind.ambush then
		local buried = action == "Wander"
		if (row.model:GetAttribute(MobData.BuriedAttribute) == true) ~= buried then
			row.model:SetAttribute(MobData.BuriedAttribute, buried)
			row.root.Transparency = if buried then 0.7 else 0
		end
	end
	-- Heavy mobs and bosses chew through a wall or door that blocks the way.
	if action == "Chase" and row.kind.breaksStructures and now >= row.nextAttackAt then
		if breakStructure(row, pos) then
			row.nextAttackAt = now + stats.AttackCooldown
			row.lastAction = "Attack"
			return
		end
	end
	row.lastAction = action
	if action ~= "Leave" then
		row.leaveDeadline = nil
	end

	local humanoid = row.humanoid
	if action == "Flee" and nearestInfo then
		-- Sprint / pause rhythm so a walking player can close in during the pauses.
		if MobAI.fleeBurst(row.burst, now, stats.FleeBurstSeconds, stats.FleeRestSeconds) then
			humanoid.WalkSpeed = stats.FleeSpeed
			humanoid:MoveTo(pos + horizontalDir(nearestInfo.root.Position, pos) * MOBS.FleeStep)
		else
			row.lastAction = "Rest"
			humanoid:MoveTo(pos)
		end
	elseif action == "Retreat" and fire then
		humanoid.WalkSpeed = stats.FleeSpeed
		humanoid:MoveTo(
			pos + horizontalDir(Vector3.new(fire.x, pos.Y, fire.z), pos) * MOBS.RetreatStep
		)
	elseif action == "Leave" then
		-- Dawn: run away from the nearest player, then despawn.
		local deadline = row.leaveDeadline or (now + NIGHT.DawnLeaveSeconds)
		row.leaveDeadline = deadline
		if now >= deadline then
			removeMob(row.model)
			return
		end
		humanoid.WalkSpeed = stats.FleeSpeed
		if nearestInfo then
			humanoid:MoveTo(pos + horizontalDir(nearestInfo.root.Position, pos) * MOBS.RetreatStep)
		end
	elseif action == "Chase" and nearestInfo then
		humanoid.WalkSpeed = stats.FleeSpeed
		local target = nearestInfo.root.Position
		local tx, tz = target.X, target.Z
		-- Never path into a fire's repel circle to reach a sheltered player.
		if repelled then
			for _, f in fires do
				tx, tz = FireRepel.clampTarget(tx, tz, f, repelOf(f))
			end
		end
		humanoid:MoveTo(Vector3.new(tx, target.Y, tz))
	elseif action == "Attack" and nearestInfo then
		-- Server recomputes distance at every phase of the bite.
		local d = MobRules.distance(toPoint(pos), toPoint(nearestInfo.root.Position))
		local reach = d <= stats.AttackRange + NIGHT.StrikeLeeway
		local result =
			MobAI.windupStep(row.windup, now, d <= stats.AttackRange, reach, NIGHT.WindupSeconds)
		if result == "Start" then
			row.lastAction = "Windup"
			humanoid:MoveTo(pos)
			setWindup(row, true)
		elseif result == "Wait" then
			row.lastAction = "Windup"
			humanoid:MoveTo(pos)
		elseif result == "Cancel" then
			setWindup(row, false)
		elseif result == "Strike" then
			setWindup(row, false)
			row.nextAttackAt = now + stats.AttackCooldown
			local biteOk = MobRules.biteAllowed(
				repelled,
				toPoint(pos),
				toPoint(nearestInfo.root.Position),
				fires
			)
			if
				biteOk
				and nearestInfo.player:GetAttribute(Config.Debug.PlayerInvincibleAttribute)
					~= true
			then
				local onHit = hitHandler
				if onHit then
					pcall(onHit, nearestInfo.player, row.kind.name)
				end
				nearestInfo.humanoid:TakeDamage(row.damage)
				biteSeq(nearestInfo.player)
			end
		end
	elseif row.kind.ambush and action == "Wander" then
		humanoid:MoveTo(pos) -- buried: hold still
	else
		humanoid.WalkSpeed = stats.WalkSpeed
		if now >= row.wanderUntil then
			row.wanderUntil = now + MOBS.WanderInterval * (0.5 + rng:NextNumber())
			local angle = rng:NextNumber(0, math.pi * 2)
			humanoid:MoveTo(
				pos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * MOBS.WanderRadius
			)
		end
	end
end

local function aiPass(infos: { PlayerInfo })
	local models: { Model } = {}
	local points: { MobRules.Point } = {}
	for model, row in rows do
		table.insert(models, model)
		table.insert(points, toPoint(row.root.Position))
	end
	local playerPoints: { MobRules.Point } = {}
	for _, info in infos do
		table.insert(playerPoints, toPoint(info.root.Position))
	end

	-- Despawn mobs with no player within range, or that fell off the world (kill height / edge).
	for i, model in models do
		local row = rows[model]
		local at = if row then row.root.Position else nil
		if
			(at ~= nil and World.shouldKill(at.X, at.Y, at.Z))
			or MobRules.shouldDespawn(
				MobRules.nearestDistance(points[i], playerPoints),
				Config.Mobs.DespawnDistance
			)
		then
			removeMob(model)
		end
	end

	local active = MobRules.selectActive(points, playerPoints, Config.Mobs.AIActiveRadius)
	-- Dawn: night-only mobs outside the AI radius are never stepped, so they could never finish leaving.
	if not getDanger() then
		local activeSet: { [number]: boolean } = {}
		for _, index in active do
			activeSet[index] = true
		end
		for i, model in models do
			local row = rows[model]
			if row and row.kind.stats.NightOnly and not activeSet[i] then
				removeMob(model)
			end
		end
	end
	if #active == 0 then
		return
	end
	local fires = collectFires()
	local isNight = getDanger()
	local now = os.clock()
	for _, index in active do
		local row = rows[models[index]]
		if row and row.model.Parent then
			MobService.AIStepCount += 1
			stepMob(row, infos, fires, isNight, now)
		end
	end
end

local function onHeartbeat(dt: number)
	aiAccum += dt
	spawnAccum += dt
	local doAI = aiAccum >= Config.Mobs.AITickInterval
	local doSpawn = spawnAccum >= Config.Mobs.SpawnInterval
	if not (doAI or doSpawn) then
		return
	end
	local infos = collectPlayers()
	partyCount = math.max(1, #infos)
	if doAI then
		aiAccum = 0
		aiPass(infos)
	end
	if doSpawn then
		spawnAccum = 0
		trySpawn(infos)
		local day = getDay()
		local now = os.clock()
		for _, hook in spawnHooks do
			pcall(hook, infos, day, now)
		end
	end
end

-- Killed: unregister at once (no second kill, no AI), publish health 0, remove after a short delay so
-- clients can play the hit confirm on the attribute change.
local function killMob(row: MobRow)
	local model = row.model
	unregister(model)
	CollectionService:RemoveTag(model, Config.Mobs.Tag)
	row.root.Anchored = true
	model:SetAttribute(HEALTH_ATTRIBUTE, 0)
	task.delay(MOBS.DeathRemoveDelay, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function resolveMob(target: Instance): MobRow?
	local model: Instance? = target
	if target:IsA("BasePart") then
		model = target.Parent
	end
	if model and model:IsA("Model") then
		return rows[model]
	end
	return nil
end

-- Applies server-computed damage. killer = the player credited (kill record, drop); nil for traps.
local function applyDamage(row: MobRow, damage: number, killer: Player?)
	if rows[row.model] ~= row then
		return -- already dead or removed
	end
	row.health -= damage
	row.model:SetAttribute(HEALTH_ATTRIBUTE, math.max(0, row.health))
	if row.health > 0 then
		return
	end
	local stats = row.kind.stats
	local name = row.kind.name
	killMob(row)
	if killer then
		local onKill = killHandler
		if onKill then
			pcall(onKill, killer, name, row.isBoss)
		end
		-- Drop goes straight to the killer's inventory (no world pickups yet).
		if stats.DropId and stats.DropCount > 0 then
			InventoryService.add(killer, stats.DropId, stats.DropCount)
		end
	end
	for _, listener in killedListeners do
		pcall(listener, row.model, name, killer)
	end
end

local function onAttack(player: Player, target: unknown)
	-- 1. type check
	if typeof(target) ~= "Instance" then
		return
	end
	local instance = target :: Instance
	-- 2. sanity: must be a live registered mob
	local row = resolveMob(instance)
	if not row or not row.model.Parent then
		return
	end
	-- 3. rate limit
	if not Guard.rateLimit(player, "Attack", Config.Net.AttackRateInterval) then
		return
	end
	-- 4. state: alive, not downed, melee cooldown
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return
	end
	if player:GetAttribute(Config.Downed.StateAttribute) == true then
		return
	end
	local now = os.clock()
	if now - (lastMeleeAt[player] or -math.huge) < Config.Combat.MeleeCooldown then
		return
	end
	-- 5. act: server-recomputed distance and damage
	local dist = MobRules.distance(toPoint(root.Position), toPoint(row.root.Position))
	local reach = Config.Combat.MeleeRange + row.kind.stats.HitRadius
	if not MobRules.canMelee(dist, reach, Config.Combat.LagCompensation) then
		return
	end
	lastMeleeAt[player] = now
	SwingRelay.notify(player) -- accepted swing: other clients animate it
	-- Damage from the equipped item: weapon data, gather tool = Combat.ToolDamage, else MeleeBaseDamage.
	local held = InventoryService.getSelected(player)
	local def = if held then ItemCatalog.Items[held.id] else nil
	-- A bow in melee is a fist: its damage is per arrow (ProjectileService).
	local isWeapon = def ~= nil
		and def.kind == "weapon"
		and def.damage ~= nil
		and def.ranged ~= true
	local isTool = def ~= nil and def.kind == "tool"
	local damage = if isWeapon
			and def
			and def.damage
		then def.damage
		elseif isTool then Config.Combat.ToolDamage
		else Config.Combat.MeleeBaseDamage
	if isWeapon or isTool then
		InventoryService.wearSelected(player, Config.Combat.WeaponDurabilityPerHit)
	end
	applyDamage(row, damage, player)
end

-- Wiring (init.server): called with (player, kindName, isBoss) when a player kills a mob.
function MobService.setKillHandler(fn: ((Player, string, boolean) -> ())?)
	killHandler = fn
end

-- Wiring (init.server): called with (player, kindName) just before a mob hit damages a player.
function MobService.setHitHandler(fn: ((Player, string) -> ())?)
	hitHandler = fn
end

-- Same path as AttackRequest (QA and server callers); runs the full validation.
MobService.handleAttack = onAttack

-- Server/QA: spawn one mob of any kind (Phase 1 or data/Mobs) at a ground position.
function MobService.spawn(kindName: string, position: Vector3): Model?
	local kind = KIND_BY_NAME[kindName]
	return if kind then createMob(kind, position) else nil
end

-- Boss path: spawn with server-computed health/damage (BossService). Marks the model with BossKind.
function MobService.spawnScaled(
	kindName: string,
	position: Vector3,
	health: number,
	damage: number
): Model?
	local kind = KIND_BY_NAME[kindName]
	if not kind then
		return nil
	end
	-- Bosses may break through the fire edge, but never appear inside a fire's warm radius.
	local px, pz = MobRules.spawnPoint(kind.category, position.X, position.Z, collectFires())
	local spot = position
	if px ~= position.X or pz ~= position.Z then
		spot = groundAt(px, pz, position.Y) or Vector3.new(px, position.Y, pz)
	end
	local model = createMob(kind, spot, { health = health, damage = damage })
	if model and (kind.category == "miniboss" or kind.category == "boss") then
		model:SetAttribute(MobData.BossAttribute, kindName)
	end
	return model
end

-- Server-side damage for traps and projectiles. killer nil = no kill record or drop (traps).
function MobService.damage(mob: Instance, amount: number, sourcePlayer: Player?)
	if typeof(mob) ~= "Instance" or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	local row = resolveMob(mob)
	if row and row.model.Parent then
		applyDamage(row, amount, sourcePlayer)
	end
end

function MobService.isMob(instance: Instance): boolean
	return resolveMob(instance) ~= nil
end

-- Live mob models with positions (aim assist, boss counts).
function MobService.getLive(): { { model: Model, position: Vector3, kind: string } }
	local out = {}
	for model, row in rows do
		table.insert(out, { model = model, position = row.root.Position, kind = row.kind.name })
	end
	return out
end

-- Brief 18 wires BiomeService.getRing here (nil-safe: default ring 0).
function MobService.setRingProvider(fn: ((Vector3) -> number)?)
	ringProvider = fn
end

-- Brief 18: EventService spawn modifier (1 = normal). Clamped by Scaling.MaxSpawnMultiplier at use.
function MobService.setBudgetMultiplier(multiplier: number)
	if type(multiplier) == "number" and multiplier == multiplier then
		eventBudgetMultiplier = math.clamp(multiplier, 0, Config.Scaling.MaxSpawnMultiplier)
	end
end

-- Current live budget multiplier from events (QA).
function MobService.getBudgetMultiplier(): number
	return eventBudgetMultiplier
end

-- Brief 18: hot-spring spawn bias fn(position) -> multiplier (1 = none). Nil-safe.
function MobService.setSpawnBiasProvider(fn: ((Vector3) -> number)?)
	spawnBiasProvider = fn
end

-- World wiring (MassiveService): fn(x, z) -> true when natural mob spawns are not allowed at that point. Nil-safe.
function MobService.setSpawnBlocker(fn: ((x: number, z: number) -> boolean)?)
	spawnBlocker = fn
end

-- Called once per kill (any source) with (model, kindName, killer?). Used by BossService.
function MobService.onKilled(fn: (Model, string, Player?) -> ())
	table.insert(killedListeners, fn)
end

-- Called at every spawn tick with (players, day, now). Used by BossService.
function MobService.addSpawnHook(fn: (infos: { PlayerInfo }, day: number, now: number) -> ())
	table.insert(spawnHooks, fn)
end

-- Ground position a spawn distance away from an anchor (nil when no ground found).
function MobService.groundNear(anchor: Vector3, minDist: number, maxDist: number): Vector3?
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(minDist, maxDist)
	return groundAt(anchor.X + math.cos(angle) * dist, anchor.Z + math.sin(angle) * dist, anchor.Y)
end

function MobService.getDay(): number
	return getDay()
end

function MobService.ringAt(position: Vector3): number
	return ringAt(position)
end

function MobService.getPartyCount(): number
	return partyCount
end

-- Last AI action of a mob ("Wander" | "Flee" | "Rest" | "Chase" | "Attack" | "Windup" | "Retreat" | "Leave"), nil before its first step.
function MobService.getLastAction(model: Model): string?
	local row = rows[model]
	return if row then row.lastAction else nil
end

function MobService.start()
	if started then
		return
	end
	started = true
	local mobsFolder = Instance.new("Folder")
	mobsFolder.Name = MOBS.FolderName
	mobsFolder.Parent = Workspace
	folder = mobsFolder

	Players.PlayerRemoving:Connect(function(player)
		lastMeleeAt[player] = nil
	end)
	Remotes.event(Remotes.AttackRequest).OnServerEvent:Connect(onAttack)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return MobService
