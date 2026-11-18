--!strict
-- Pure cooking rules: which raw foods cook where, and how long the eaten buff lasts. The station
-- multiplier and the duration are capped by Config.Cooking / Config.Buffs. No Roblox APIs.

local Config = require("../Config")
local Food = require("../data/Food")
local Types = require("../data/Types")

local Cooking = {}

local byRaw: { [string]: Types.CookDef } = {}
for _, def in Food.Cook do
	byRaw[def.rawId] = def
end

function Cooking.defFor(rawId: string): Types.CookDef?
	return byRaw[rawId]
end

-- (ok, reason): NotCookable | NeedStation | NoHeat | Ok. atFire = a lit campfire is within
-- Config.Fire.CookRadius; atStation = a cooking station is within Config.Cooking.StationRange.
function Cooking.check(rawId: string, atFire: boolean, atStation: boolean): (boolean, string)
	local def = byRaw[rawId]
	if def == nil then
		return false, "NotCookable"
	end
	if def.stationOnly then
		if atStation then
			return true, "Ok"
		end
		return false, "NeedStation"
	end
	if atFire or atStation then
		return true, "Ok"
	end
	return false, "NoHeat"
end

function Cooking.buffFor(foodId: string): Types.BuffDef?
	local id = Food.EatBuffs[foodId]
	return if id then Food.BuffById[id] else nil
end

-- Seconds the buff lasts; station-cooked food gets the (capped) multiplier, all capped by MaxDurationSeconds.
function Cooking.buffDuration(def: Types.BuffDef, fromStation: boolean): number
	local multiplier = 1
	if fromStation then
		multiplier =
			math.min(Config.Cooking.StationBuffMultiplier, Config.Cooking.MaxStationBuffMultiplier)
	end
	return math.min(def.durationSeconds * multiplier, Config.Buffs.MaxDurationSeconds)
end

return Cooking
