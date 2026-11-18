--!strict
-- Frostbound Brute (hostile, slow, heavy): a long telegraphed ground slam that hits everyone inside its
-- reach when the wind-up ends. Dodge by leaving the slam radius during the wind-up. Fire-safe; chews walls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Mobs = script.Parent.Parent
local MobActions = require(Mobs.MobActions)
local MobState = require(Mobs.MobState)
local SpeciesKit = require(Mobs.Drivers.SpeciesKit)
local Types = require(Mobs.MobTypes)

type MobRow = Types.MobRow
type Env = Types.Env

local FrostboundBrute: Types.Species = {
	step = function(row: MobRow, env: Env)
		local def = SpeciesKit.def(row)
		if SpeciesKit.retreatFromFire(row, env) then
			SpeciesKit.resetTelegraph(row)
			return
		end
		local info, d = env.nearestInfo, env.nearest
		local tele = row.sp.tele :: { left: number? }?
		local winding = tele ~= nil and tele.left ~= nil
		if not info or d == nil or (d > SpeciesKit.aggro(row) and not winding) then
			SpeciesKit.resetTelegraph(row)
			row.lastAction = "Wander"
			MobState.setTarget(row, nil)
			MobActions.wander(row, env.now, SpeciesKit.rng)
			return
		end
		SpeciesKit.engage(row, env, {
			chaseSpeed = def.runSpeed,
			leeway = def.tune.strikeLeeway or Config.Night.StrikeLeeway,
			aoe = true,
		})
	end,
}

return FrostboundBrute
