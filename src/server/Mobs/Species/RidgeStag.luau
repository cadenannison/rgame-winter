--!strict
-- Ridge Stag (neutral herd animal): a herd goes Alert when anyone nears (HerdAlert), only fights when hit
-- (Retaliate) and the whole herd joins in; telegraphed antler strike (dodgeable). Venison source.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MobBehaviors = require(Shared.logic.MobBehaviors)
local Mobs = script.Parent.Parent
local MobActions = require(Mobs.MobActions)
local MobRegistry = require(Mobs.MobRegistry)
local MobState = require(Mobs.MobState)
local SpeciesKit = require(Mobs.Drivers.SpeciesKit)
local Types = require(Mobs.MobTypes)
local Config = require(Shared.Config)

type MobRow = Types.MobRow
type Env = Types.Env

local HerdAlert = MobBehaviors.HerdAlert
local Retaliate = MobBehaviors.Retaliate

local RidgeStag: Types.Species = {
	init = function(row: MobRow)
		row.sp.herd = HerdAlert.new()
		row.sp.retaliate = Retaliate.new()
		row.sp.alerted = false
		row.sp.provokedNow = false
	end,
	step = function(row: MobRow, env: Env)
		local def = SpeciesKit.def(row)
		local tune = def.tune
		local sp = row.sp
		local pos = row.root.Position
		local here = { x = pos.X, z = pos.Z }
		-- Herd: alerted / freshly provoked members within the herd radius.
		local herd: { { x: number, z: number, alerted: boolean } } = {}
		local neighborProvoked = false
		for _, member in MobRegistry.group(row.groupId) do
			if member ~= row then
				local p = member.root.Position
				table.insert(herd, { x = p.X, z = p.Z, alerted = member.sp.alerted == true })
				if
					member.sp.provokedNow == true
					and SpeciesKit.flat(pos, p) <= tune.alertRadius
				then
					neighborProvoked = true
				end
			end
		end
		local threat = env.nearest ~= nil and env.nearest <= tune.alertRange
		local herdState, herdOut = HerdAlert.step(sp.herd, {
			threat = threat or row.provoked,
			neighborAlert = HerdAlert.neighborAlerted(here, herd, tune.alertRadius),
			alertSeconds = tune.alertSeconds,
		}, env.dt)
		sp.herd = herdState
		sp.alerted = herdOut.alerted
		sp.provokedNow = row.provoked
		local retState, retOut = Retaliate.step(sp.retaliate, {
			hit = row.provoked or neighborProvoked,
			dist = env.nearest,
			attackRange = def.attackRange,
			canAttack = env.now >= row.nextAttackAt,
			leash = tune.leash,
			retaliateSeconds = tune.retaliateSeconds,
		}, env.dt)
		sp.retaliate = retState
		local info = env.nearestInfo
		if retOut.angry and info then
			-- A wind-up in progress holds its place until the strike lands or the target leaves reach.
			SpeciesKit.engage(row, env, {
				chaseSpeed = def.runSpeed,
				leeway = Config.Night.StrikeLeeway,
				aoe = false,
			})
			return
		end
		SpeciesKit.resetTelegraph(row)
		if herdOut.alerted and info then
			row.lastAction = "Alert"
			MobState.setTarget(row, info.player)
			MobActions.stop(row)
			SpeciesKit.face(row, info.root.Position.X, info.root.Position.Z)
			return
		end
		row.lastAction = "Wander"
		MobState.setTarget(row, nil)
		MobActions.wander(row, env.now, SpeciesKit.rng)
	end,
}

return RidgeStag
