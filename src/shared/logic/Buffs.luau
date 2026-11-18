--!strict
-- Pure food-buff state: a short list of {id, expires}. Add refreshes (never stacks) an id, the list is
-- capped at Config.Buffs.MaxActive (the soonest-expiring is evicted), durations are capped, and the
-- combined modifiers are clamped to the Config.Buffs reductions. No Roblox APIs.

local Config = require("../Config")
local Food = require("../data/Food")

export type Active = { id: string, expires: number }
export type Mods = { warmthDrain: number, hungerDrain: number, regenBonus: number, speed: number }

local Buffs = {}

function Buffs.new(): { Active }
	return {}
end

-- Removes expired entries. Returns true if the list changed.
function Buffs.prune(list: { Active }, now: number): boolean
	local changed = false
	for i = #list, 1, -1 do
		if list[i].expires <= now then
			table.remove(list, i)
			changed = true
		end
	end
	return changed
end

-- Adds or refreshes a buff for `duration` seconds (capped). Returns false for an unknown id.
function Buffs.add(list: { Active }, id: string, duration: number, now: number): boolean
	if Food.BuffById[id] == nil or duration ~= duration or duration <= 0 then
		return false
	end
	local expires = now + math.min(duration, Config.Buffs.MaxDurationSeconds)
	for _, entry in list do
		if entry.id == id then
			entry.expires = math.max(entry.expires, expires)
			return true
		end
	end
	if #list >= Config.Buffs.MaxActive then
		local soonest = 1
		for i, entry in list do
			if entry.expires < list[soonest].expires then
				soonest = i
			end
		end
		table.remove(list, soonest)
	end
	table.insert(list, { id = id, expires = expires })
	return true
end

-- Combined effect of every unexpired buff, clamped (reductions floor at 1 - Max*Reduction; debuffs may raise).
function Buffs.modifiers(list: { Active }, now: number): Mods
	local warmth, hunger, regen, speed = 1, 1, 0, 1
	for _, entry in list do
		local def = Food.BuffById[entry.id]
		if def and entry.expires > now then
			warmth *= def.warmthDrainMultiplier
			hunger *= def.hungerDrainMultiplier
			regen += def.healthRegenBonus
			speed *= def.speedMultiplier
		end
	end
	return {
		warmthDrain = math.max(warmth, 1 - Config.Buffs.MaxWarmthDrainReduction),
		hungerDrain = math.max(hunger, 1 - Config.Buffs.MaxHungerDrainReduction),
		regenBonus = math.min(regen, Config.Buffs.MaxHealthRegenBonus),
		speed = math.min(speed, 1 + Config.Buffs.MaxSpeedBonus),
	}
end

-- Visible attribute value: comma list of ids.
function Buffs.ids(list: { Active }): string
	local ids: { string } = {}
	for _, entry in list do
		table.insert(ids, entry.id)
	end
	return table.concat(ids, ",")
end

return Buffs
