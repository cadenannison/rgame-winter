--!strict
-- Server-authoritative mobs: capped spawn budget near players, AI only near players, one Heartbeat loop
-- for all mobs, melee via AttackRequest. Spec: docs/systems/mobs.md
-- Split (Art Pass 3): MobKinds (kind table), MobRegistry (live rows + counters), MobWorld (queries),
-- MobSpawner (create + natural spawn), MobCombat (damage, kills, drops), MobState (State/Target attrs),
-- Drivers/Legacy + Species/* (per-kind AI). This file keeps the public API, the Heartbeat and the AI pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MobRules = require(Shared.logic.MobRules)
local World = require(Shared.logic.World)
local MobActions = require(script.Parent.MobActions)
local MobCombat = require(script.Parent.MobCombat)
local MobRegistry = require(script.Parent.MobRegistry)
local MobSpawner = require(script.Parent.MobSpawner)
local MobState = require(script.Parent.MobState)
local MobWorld = require(script.Parent.MobWorld)
local Species = require(script.Parent.Species)
local Types = require(script.Parent.MobTypes)

type PlayerInfo = Types.PlayerInfo

local MOBS = Config.Mobs
local MAX_STEP_DT = 1 -- clamp for a mob's per-step dt (a mob can wait out of AI range for a long time)

local MobService = {}

local started = false
local spawnHooks: { (infos: { PlayerInfo }, day: number, now: number) -> () } = {}
local spawnAccum = 0
local aiAccum = 0
local rng = Random.new()

-- Count of AI steps executed (tests/QA: stays flat with no player nearby).
MobService.AIStepCount = 0

local toPoint = MobWorld.toPoint

local function aiPass(infos: { PlayerInfo })
	local rows = MobRegistry.rows()
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
			MobRegistry.remove(model)
		end
	end

	local active = MobRules.selectActive(points, playerPoints, Config.Mobs.AIActiveRadius)
	-- Dawn: night-only mobs outside the AI radius are never stepped, so they could never finish leaving.
	if not MobWorld.getDanger() then
		local activeSet: { [number]: boolean } = {}
		for _, index in active do
			activeSet[index] = true
		end
		for i, model in models do
			local row = rows[model]
			if row and row.kind.stats.NightOnly and not activeSet[i] then
				MobRegistry.remove(model)
			end
		end
	end
	if #active == 0 then
		return
	end
	local env: Types.Env = {
		infos = infos,
		fires = MobWorld.collectFires(),
		danger = MobWorld.getDanger(),
		now = os.clock(),
		dt = 0,
		nearestInfo = nil,
		nearest = nil,
	}
	for _, index in active do
		local row = rows[models[index]]
		if row and row.model.Parent then
			MobService.AIStepCount += 1
			env.dt = math.clamp(env.now - row.lastStepAt, 0, MAX_STEP_DT)
			row.lastStepAt = env.now
			env.nearestInfo, env.nearest = MobWorld.nearestPlayer(row.root.Position, infos)
			Species.get(row.kind.name).step(row, env)
			row.provoked = false
			if row.model.Parent and MobRegistry.get(row.model) == row then
				MobState.sync(row, env.now)
			end
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
	local infos = MobWorld.collectPlayers()
	MobWorld.setPartyCount(#infos)
	if doAI then
		aiAccum = 0
		aiPass(infos)
	end
	if doSpawn then
		spawnAccum = 0
		MobSpawner.trySpawn(infos)
		local day = MobWorld.getDay()
		local now = os.clock()
		for _, hook in spawnHooks do
			pcall(hook, infos, day, now)
		end
	end
end

-- Wiring (init.server): called with (player, kindName, isBoss) when a player kills a mob.
MobService.setKillHandler = MobCombat.setKillHandler

-- Wiring (init.server): called with (player, kindName) just before a mob hit damages a player.
MobService.setHitHandler = MobActions.setHitHandler

-- Same path as AttackRequest (QA and server callers); runs the full validation.
MobService.handleAttack = MobCombat.handleAttack

-- Server/QA: spawn one mob of any kind (Phase 1, data/Mobs or Config.Mobs.Species) at a ground position.
MobService.spawn = MobSpawner.spawn

-- Boss path: spawn with server-computed health/damage (BossService). Marks the model with BossKind.
MobService.spawnScaled = MobSpawner.spawnScaled

-- Server-side damage for traps and projectiles. killer nil = no kill record or drop (traps).
MobService.damage = MobCombat.damage

function MobService.isMob(instance: Instance): boolean
	return MobCombat.resolve(instance) ~= nil
end

-- Live mob models with positions (aim assist, boss counts).
function MobService.getLive(): { { model: Model, position: Vector3, kind: string } }
	local out = {}
	for model, row in MobRegistry.rows() do
		table.insert(out, { model = model, position = row.root.Position, kind = row.kind.name })
	end
	return out
end

-- Studio debug (/debug mobs): live mobs within radius of a position, nearest first, with replicated State.
function MobService.debugNearby(
	position: Vector3,
	radius: number
): { { kind: string, distance: number, state: string, health: number } }
	local out = {}
	for _, row in MobRegistry.rows() do
		local d = (row.root.Position - position).Magnitude
		if d <= radius then
			local state = row.model:GetAttribute(Config.Creatures.StateAttribute)
			table.insert(out, {
				kind = row.kind.name,
				distance = d,
				state = if type(state) == "string" then state else "?",
				health = math.max(0, row.health),
			})
		end
	end
	table.sort(out, function(a, b)
		return a.distance < b.distance
	end)
	return out
end

-- Brief 18 wires BiomeService.getRing here (nil-safe: default ring 0).
MobService.setRingProvider = MobWorld.setRingProvider

-- Brief 18: EventService spawn modifier (1 = normal). Clamped by Scaling.MaxSpawnMultiplier at use.
MobService.setBudgetMultiplier = MobSpawner.setBudgetMultiplier

-- Current live budget multiplier from events (QA).
MobService.getBudgetMultiplier = MobSpawner.getBudgetMultiplier

-- Brief 18: hot-spring spawn bias fn(position) -> multiplier (1 = none). Nil-safe.
MobService.setSpawnBiasProvider = MobSpawner.setSpawnBiasProvider

-- World wiring (MassiveService): fn(x, z) -> true when natural mob spawns are not allowed at that point. Nil-safe.
MobService.setSpawnBlocker = MobSpawner.setSpawnBlocker

-- Called once per kill (any source) with (model, kindName, killer?). Used by BossService.
MobService.onKilled = MobCombat.onKilled

-- Called at every spawn tick with (players, day, now). Used by BossService.
function MobService.addSpawnHook(fn: (infos: { PlayerInfo }, day: number, now: number) -> ())
	table.insert(spawnHooks, fn)
end

-- Ground position a spawn distance away from an anchor (nil when no ground found).
function MobService.groundNear(anchor: Vector3, minDist: number, maxDist: number): Vector3?
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(minDist, maxDist)
	return MobWorld.groundAt(
		anchor.X + math.cos(angle) * dist,
		anchor.Z + math.sin(angle) * dist,
		anchor.Y
	)
end

MobService.getDay = MobWorld.getDay
MobService.ringAt = MobWorld.ringAt
MobService.getPartyCount = MobWorld.getPartyCount

-- Live mob parts (counted against Perf.MaxLiveParts with chunk parts; Config.Mobs.Spawning.MaxMobParts).
function MobService.getLiveParts(): number
	return MobRegistry.partsUsed()
end

-- Last AI action of a mob ("Wander" | "Flee" | "Rest" | "Chase" | "Attack" | "Windup" | "Retreat" | "Leave" |
-- species actions Alert, Return, Charge, Circle, Scatter, Drift), nil before its first step.
function MobService.getLastAction(model: Model): string?
	local row = MobRegistry.get(model)
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
	MobWorld.setFolder(mobsFolder)

	MobCombat.start()
	RunService.Heartbeat:Connect(onHeartbeat)
end

return MobService
