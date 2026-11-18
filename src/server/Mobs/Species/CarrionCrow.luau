--!strict
-- Carrion Crow (ambient, no damage): circles its carrion spot, then scatters when a player gets close or the
-- Stalker hunts nearby, flying off toward the Stalker (Heading attribute) before it despawns. Rare feather.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MobBehaviors = require(Shared.logic.MobBehaviors)
local MobDread = require(Shared.logic.MobDread)
local Config = require(Shared.Config)
local Mobs = script.Parent.Parent
local AmbientCues = require(Mobs.AmbientCues)
local MobActions = require(Mobs.MobActions)
local MobRegistry = require(Mobs.MobRegistry)
local MobState = require(Mobs.MobState)
local SpeciesKit = require(Mobs.Drivers.SpeciesKit)
local Types = require(Mobs.MobTypes)

type MobRow = Types.MobRow
type Env = Types.Env

local Circle = MobBehaviors.Circle

local STALKER_SCATTER_RANGE = 150 -- studs: a Stalker hunt this close sends the crows up

local CarrionCrow: Types.Species = {
	init = function(row: MobRow)
		row.sp.circle = Circle.new(SpeciesKit.rng:NextNumber(0, math.pi * 2))
	end,
	step = function(row: MobRow, env: Env)
		local def = SpeciesKit.def(row)
		local tune = def.tune
		local pos = row.root.Position
		local here = { x = pos.X, z = pos.Z }
		local info = env.nearestInfo
		local playerPoint = if info
			then { x = info.root.Position.X, z = info.root.Position.Z }
			else nil
		local stalkerAt = AmbientCues.stalkerPosition()
		local stalkerPoint = if stalkerAt
				and SpeciesKit.flat(pos, stalkerAt) <= STALKER_SCATTER_RANGE
			then { x = stalkerAt.X, z = stalkerAt.Z }
			else nil
		local scatter = (env.nearest ~= nil and env.nearest <= tune.scatterRange)
			or stalkerPoint ~= nil
		local dir = MobDread.scatterDir(here, playerPoint, stalkerPoint)
		local state, out = Circle.step(row.sp.circle, {
			self = here,
			center = { x = row.home.X, z = row.home.Z },
			radius = tune.circleRadius,
			angularSpeed = tune.circleSpeed,
			scatter = scatter,
			scatterDir = row.sp.scatterDir or dir,
			scatterSeconds = tune.scatterSeconds,
			scatterStep = Config.Mobs.Dread.ScatterStep,
		}, env.dt)
		row.sp.circle = state
		if out.phase == "Gone" then
			MobRegistry.remove(row.model)
			return
		end
		MobState.setTarget(row, nil)
		MobState.setHeading(row, Vector3.new(out.heading.x, 0, out.heading.z))
		if out.phase == "Scatter" then
			row.sp.scatterDir = dir -- the line is fixed once they bolt
			row.lastAction = "Scatter"
			MobActions.moveToward(row, out.goal.x, out.goal.z, def.runSpeed)
		else
			row.lastAction = "Circle"
			MobActions.moveToward(row, out.goal.x, out.goal.z, def.walkSpeed)
		end
	end,
}

return CarrionCrow
