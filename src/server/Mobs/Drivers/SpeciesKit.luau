--!strict
-- Helpers shared by the Art Pass 3 species modules: species def access, dawn leave, fire retreat, a fire-safe
-- chase and the telegraphed melee engagement (chase -> Telegraph wind-up -> strike only if still in reach).
-- Pure timing/decisions come from src/shared/logic/MobBehaviors*.luau; this file only maps them to movement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local FireRepel = require(Shared.logic.FireRepel)
local MobBehaviors = require(Shared.logic.MobBehaviors)
local CombatBehaviors = require(Shared.logic.MobBehaviorsCombat)
local CreatureFxLogic = require(Shared.logic.CreatureFxLogic)
local MobRules = require(Shared.logic.MobRules)
local MobSpecies = require(Shared.logic.MobSpecies)
local Mobs = script.Parent.Parent
local MobActions = require(Mobs.MobActions)
local MobRegistry = require(Mobs.MobRegistry)
local MobState = require(Mobs.MobState)
local MobWorld = require(Mobs.MobWorld)
local Types = require(Mobs.MobTypes)

type MobRow = Types.MobRow
type Env = Types.Env

local NIGHT = Config.Night
local MOBS = Config.Mobs
local Telegraph = MobBehaviors.Telegraph

local SpeciesKit = {}

SpeciesKit.rng = Random.new()

function SpeciesKit.def(row: MobRow): Types.SpeciesDef
	return row.kind.species :: Types.SpeciesDef
end

-- Aggro range scaled by ring (outer rings are meaner; capped by Scaling.MaxRingDamageMultiplier).
function SpeciesKit.aggro(row: MobRow): number
	local def = SpeciesKit.def(row)
	return def.aggroRange * MobSpecies.aggroScale(def, row.ring)
end

function SpeciesKit.flat(a: Vector3, b: Vector3): number
	return MobRules.distance(MobWorld.toPoint(a), MobWorld.toPoint(b))
end

-- Turns the body toward a flat point (posture / telegraph); position unchanged.
function SpeciesKit.face(row: MobRow, x: number, z: number)
	local pos = row.root.Position
	if (x - pos.X) ^ 2 + (z - pos.Z) ^ 2 > 0.01 then
		row.root.CFrame = CFrame.lookAt(pos, Vector3.new(x, pos.Y, z))
	end
end

-- Dawn: night-only species run from the nearest player and despawn after Night.DawnLeaveSeconds.
-- Returns true when it handled this step.
function SpeciesKit.leaveAtDawn(row: MobRow, env: Env): boolean
	local def = SpeciesKit.def(row)
	if not def.nightOnly or env.danger then
		row.leaveDeadline = nil
		return false
	end
	local deadline = row.leaveDeadline or (env.now + NIGHT.DawnLeaveSeconds)
	row.leaveDeadline = deadline
	if env.now >= deadline then
		MobRegistry.remove(row.model)
		return true
	end
	row.lastAction = "Leave"
	MobState.setTarget(row, nil)
	local pos = row.root.Position
	row.humanoid.WalkSpeed = def.runSpeed
	if env.nearestInfo then
		row.humanoid:MoveTo(
			pos + MobWorld.horizontalDir(env.nearestInfo.root.Position, pos) * MOBS.RetreatStep
		)
	end
	return true
end

-- Hostile species back off from lit fires (same edge the wolf respects). Returns true when it retreated.
function SpeciesKit.retreatFromFire(row: MobRow, env: Env): boolean
	local fire = MobActions.insideFire(row, env.fires)
	if not fire then
		return false
	end
	local pos = row.root.Position
	row.lastAction = "Retreat"
	MobState.setTarget(row, nil)
	row.humanoid.WalkSpeed = SpeciesKit.def(row).runSpeed
	row.humanoid:MoveTo(
		pos + MobWorld.horizontalDir(Vector3.new(fire.x, pos.Y, fire.z), pos) * MOBS.RetreatStep
	)
	return true
end

-- Walks toward a player, never into a fire's repel circle (a sheltered player is safe).
function SpeciesKit.chase(row: MobRow, env: Env, speed: number)
	local info = env.nearestInfo
	if not info then
		return
	end
	local target = info.root.Position
	local tx, tz = target.X, target.Z
	for _, f in env.fires do
		tx, tz = FireRepel.clampTarget(tx, tz, f, MobWorld.repelOf(f))
	end
	row.lastAction = "Chase"
	MobState.setTarget(row, info.player)
	row.humanoid.WalkSpeed = speed
	row.humanoid:MoveTo(Vector3.new(tx, target.Y, tz))
end

-- Strike with the fire rule: no damage into a warm radius or from inside a repel edge.
local function strikeAllowed(row: MobRow, env: Env, info: Types.PlayerInfo): boolean
	return MobRules.biteAllowed(
		true,
		MobWorld.toPoint(row.root.Position),
		MobWorld.toPoint(info.root.Position),
		env.fires
	)
end

export type EngageOpts = {
	chaseSpeed: number,
	leeway: number, -- studs beyond attackRange the target may stand when the strike lands (dodge margin)
	aoe: boolean, -- slam: hits every player within reach, not only the nearest
}

-- Chase the nearest player; in range and ready, wind up (State Telegraph + TelegraphLeft) and strike only if
-- the target is still within reach. row.sp.tele holds the Telegraph machine state.
function SpeciesKit.engage(row: MobRow, env: Env, opts: EngageOpts)
	local def = SpeciesKit.def(row)
	local info, d = env.nearestInfo, env.nearest
	if not info or d == nil then
		return
	end
	local now = env.now
	local pos = row.root.Position
	local sp = row.sp
	if sp.tele == nil then
		sp.tele = Telegraph.new()
	end
	local tele = sp.tele :: CombatBehaviors.TelegraphState
	local inRange = d <= def.attackRange
	local ready = inRange and now >= row.nextAttackAt
	if tele.left == nil and not ready then
		-- Heavy species chew through a wall or door that blocks the way.
		if
			def.breaksStructures
			and now >= row.nextAttackAt
			and MobActions.breakStructure(row, pos)
		then
			row.nextAttackAt = now + def.attackCooldown
			row.lastAction = "Attack"
			MobState.attacked(row, now)
			return
		end
		SpeciesKit.chase(row, env, opts.chaseSpeed)
		return
	end
	local newTele, out = Telegraph.step(tele, {
		ready = ready,
		inReach = d <= def.attackRange + opts.leeway,
		seconds = def.telegraphSeconds,
	}, env.dt)
	sp.tele = newTele
	local event = out.event
	if event == "Start" or event == "Wait" then
		row.lastAction = "Windup"
		if event == "Start" then
			row.telegraphSeconds = def.telegraphSeconds
		end
		MobState.setTarget(row, info.player)
		MobActions.stop(row)
		SpeciesKit.face(row, info.root.Position.X, info.root.Position.Z)
	elseif event == "Strike" then
		row.lastAction = "Attack"
		row.nextAttackAt = now + def.attackCooldown
		MobState.setTarget(row, info.player)
		MobState.attacked(row, now)
		local reach = CreatureFxLogic.slamRadius(def.attackRange, opts.leeway)
		for _, candidate in env.infos do
			local dist = SpeciesKit.flat(pos, candidate.root.Position)
			local hit = if opts.aoe then dist <= reach else candidate == info
			if hit and dist <= reach and strikeAllowed(row, env, candidate) then
				MobActions.dealDamage(row, candidate)
			end
		end
	else
		SpeciesKit.chase(row, env, opts.chaseSpeed) -- Cancel (dodged) or nothing to do
	end
end

-- Clears a telegraph in progress (the target is gone / the mob lost interest).
function SpeciesKit.resetTelegraph(row: MobRow)
	row.sp.tele = Telegraph.new()
end

return SpeciesKit
