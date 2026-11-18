--!strict
-- Aurora Wisp (ambient, night): a drifting light that hovers ahead of a nearby player on the hazard side to
-- lure them off the safe path. Touching it drains a small, capped amount of warmth. Rare aurora dust.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MobBehaviors = require(Shared.logic.MobBehaviors)
local MobDread = require(Shared.logic.MobDread)
local Mobs = script.Parent.Parent
local AmbientCues = require(Mobs.AmbientCues)
local MobActions = require(Mobs.MobActions)
local MobRegistry = require(Mobs.MobRegistry)
local MobState = require(Mobs.MobState)
local SpeciesKit = require(Mobs.Drivers.SpeciesKit)
local Types = require(Mobs.MobTypes)

type MobRow = Types.MobRow
type Env = Types.Env

local Lure = MobBehaviors.Lure

local SPENT_SECONDS = 6 -- a wisp that has drained its cap fades away after this long

local AuroraWisp: Types.Species = {
	init = function(row: MobRow)
		row.sp.lure = Lure.new()
	end,
	step = function(row: MobRow, env: Env)
		local def = SpeciesKit.def(row)
		if SpeciesKit.leaveAtDawn(row, env) then
			return
		end
		local tune = def.tune
		local pos = row.root.Position
		local here = { x = pos.X, z = pos.Z }
		local info = env.nearestInfo
		local playerPoint = if info
			then { x = info.root.Position.X, z = info.root.Position.Z }
			else nil
		local hazard: { x: number, z: number }? = nil
		if playerPoint then
			local nearestFire: { x: number, z: number }? = nil
			local best = math.huge
			for _, f in env.fires do
				local d = (f.x - playerPoint.x) ^ 2 + (f.z - playerPoint.z) ^ 2
				if d < best then
					best = d
					nearestFire = { x = f.x, z = f.z }
				end
			end
			local stalkerAt = AmbientCues.stalkerPosition()
			hazard = MobDread.hazardPoint(
				playerPoint,
				nearestFire,
				if stalkerAt then { x = stalkerAt.X, z = stalkerAt.Z } else nil,
				Config.Mobs.Dread.HazardLead
			)
		end
		local state, out = Lure.step(row.sp.lure, {
			self = here,
			player = if env.nearest ~= nil and env.nearest <= tune.lureRange
				then playerPoint
				else nil,
			hazard = hazard,
			lureRange = tune.lureRange,
			leadDistance = tune.leadDistance,
			touchRange = tune.touchRange,
			drainCooldown = tune.drainCooldown,
			drainAmount = tune.drainWarmth,
			drainCap = tune.drainCap,
		}, env.dt)
		row.sp.lure = state
		MobState.setTarget(row, nil)
		if out.mode == "Spent" then
			row.sp.spentAt = row.sp.spentAt or env.now
			if env.now - (row.sp.spentAt :: number) >= SPENT_SECONDS then
				MobRegistry.remove(row.model)
				return
			end
		end
		local goal = out.goal
		if out.mode == "Touch" and info then
			MobState.attacked(row, env.now)
			row.lastAction = "Attack"
			AmbientCues.drainWarmth(info.player, out.drain)
		elseif goal then
			row.lastAction = "Drift"
			local toGoal = Vector3.new(goal.x - pos.X, 0, goal.z - pos.Z)
			MobState.setHeading(row, if toGoal.Magnitude > 0.01 then toGoal.Unit else nil)
		else
			row.lastAction = "Wander"
			MobState.setHeading(row, nil)
		end
		if goal then
			MobActions.moveToward(
				row,
				goal.x,
				goal.z,
				if out.mode == "Lure" or out.mode == "Touch" then def.runSpeed else def.walkSpeed
			)
		else
			MobActions.wander(row, env.now, SpeciesKit.rng)
		end
	end,
}

return AuroraWisp
