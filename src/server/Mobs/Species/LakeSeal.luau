--!strict
-- Lake Seal (neutral, territorial): a close player gets a warning posture (State Alert, no damage); if the
-- player keeps coming (or hits it) the seal attacks with a telegraphed lunge for a while, then calms down.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MobBehaviors = require(Shared.logic.MobBehaviors)
local Mobs = script.Parent.Parent
local MobActions = require(Mobs.MobActions)
local MobState = require(Mobs.MobState)
local SpeciesKit = require(Mobs.Drivers.SpeciesKit)
local Types = require(Mobs.MobTypes)

type MobRow = Types.MobRow
type Env = Types.Env

local TerritorialWarn = MobBehaviors.TerritorialWarn

local LakeSeal: Types.Species = {
	init = function(row: MobRow)
		row.sp.warn = TerritorialWarn.new()
	end,
	step = function(row: MobRow, env: Env)
		local def = SpeciesKit.def(row)
		local tune = def.tune
		local sp = row.sp
		local warn, out = TerritorialWarn.step(sp.warn, {
			dist = env.nearest,
			hit = row.provoked,
			warnRange = tune.warnRange,
			warnSeconds = tune.warnSeconds,
			commitRange = tune.commitRange,
			attackSeconds = tune.attackSeconds,
			cooldownSeconds = tune.cooldownSeconds,
			loseRange = tune.loseRange,
		}, env.dt)
		sp.warn = warn
		local info = env.nearestInfo
		if out.phase == "Attack" and info then
			SpeciesKit.engage(row, env, {
				chaseSpeed = def.runSpeed,
				leeway = Config.Night.StrikeLeeway,
				aoe = false,
			})
			return
		end
		SpeciesKit.resetTelegraph(row)
		if out.phase == "Warn" and info then
			row.lastAction = "Alert"
			MobState.setTarget(row, info.player)
			MobActions.stop(row)
			SpeciesKit.face(row, info.root.Position.X, info.root.Position.Z)
			return
		end
		MobState.setTarget(row, nil)
		if out.phase == "Cool" then
			row.lastAction = "Idle"
			MobActions.stop(row)
			return
		end
		row.lastAction = "Wander"
		MobActions.wander(row, env.now, SpeciesKit.rng)
	end,
}

return LakeSeal
