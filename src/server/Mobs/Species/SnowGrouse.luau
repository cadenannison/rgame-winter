--!strict
-- Snow Grouse (passive): flees in short bursts and returns to its spot once calm. Feather source.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MobBehaviors = require(Shared.logic.MobBehaviors)
local Mobs = script.Parent.Parent
local MobActions = require(Mobs.MobActions)
local MobState = require(Mobs.MobState)
local MobWorld = require(Mobs.MobWorld)
local SpeciesKit = require(Mobs.Drivers.SpeciesKit)
local Types = require(Mobs.MobTypes)

type MobRow = Types.MobRow
type Env = Types.Env

local Flee = MobBehaviors.Flee
local ReturnAfterFlee = MobBehaviors.ReturnAfterFlee

local SnowGrouse: Types.Species = {
	init = function(row: MobRow)
		row.sp.flee = Flee.new()
		row.sp.back = ReturnAfterFlee.new()
	end,
	step = function(row: MobRow, env: Env)
		local def = SpeciesKit.def(row)
		local tune = def.tune
		local pos = row.root.Position
		local flee, fleeOut = Flee.step(row.sp.flee, {
			dist = env.nearest,
			fleeRange = def.fleeRange,
			burstSeconds = tune.burstSeconds,
			restSeconds = tune.restSeconds,
		}, env.dt)
		row.sp.flee = flee
		local back, backOut = ReturnAfterFlee.step(row.sp.back, {
			fleeing = fleeOut.fleeing,
			homeDist = SpeciesKit.flat(pos, row.home),
			returnDelay = tune.returnDelay,
			homeRadius = tune.homeRadius,
		}, env.dt)
		row.sp.back = back
		MobState.setTarget(row, nil)
		local info = env.nearestInfo
		if fleeOut.fleeing and info then
			if fleeOut.moving then
				row.lastAction = "Flee"
				row.humanoid.WalkSpeed = def.runSpeed
				row.humanoid:MoveTo(
					pos + MobWorld.horizontalDir(info.root.Position, pos) * Config.Mobs.FleeStep
				)
			else
				row.lastAction = "Rest"
				MobActions.stop(row)
			end
		elseif backOut.goHome then
			row.lastAction = "Return"
			MobActions.moveToward(row, row.home.X, row.home.Z, def.walkSpeed)
		else
			row.lastAction = "Wander"
			MobActions.wander(row, env.now, SpeciesKit.rng)
		end
	end,
}

return SnowGrouse
