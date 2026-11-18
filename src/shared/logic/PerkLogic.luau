--!strict
-- Pure perk, cosmetic and title equip rules. No Roblox APIs. One perk equipped at a time (Meta.MaxEquippedPerks),
-- effect magnitude capped by Meta.MaxPerkMagnitude on a Meta.PerkStats modifier.

local Config = require("../Config")
local Types = require("../data/Types")
local ProfileSchema = require("./ProfileSchema")

local PerkLogic = {}

-- A perk effect is valid when its stat is allowed and |amount| is within the cap.
function PerkLogic.effectValid(effect: Types.PerkEffect?): boolean
	if effect == nil or not table.find(Config.Meta.PerkStats, effect.stat) then
		return false
	end
	return effect.amount == effect.amount
		and math.abs(effect.amount) <= Config.Meta.MaxPerkMagnitude
end

-- Run-time multiplier for one stat: 1 + amount when the effect targets it and is valid, else 1.
-- Always within [1 - MaxPerkMagnitude, 1 + MaxPerkMagnitude].
function PerkLogic.multiplier(effect: Types.PerkEffect?, stat: string): number
	if effect == nil or effect.stat ~= stat or not PerkLogic.effectValid(effect) then
		return 1
	end
	return 1 + effect.amount
end

-- Shared (camp-wide) stats such as fuelBurn: the lowest multiplier among the party's perks (best for a
-- reduction), never outside the per-perk cap.
function PerkLogic.lowestMultiplier(effects: { Types.PerkEffect }, stat: string): number
	local best = 1
	for _, effect in effects do
		best = math.min(best, PerkLogic.multiplier(effect, stat))
	end
	return best
end

-- gatherSpeed as yield: carry accumulates base * (multiplier - 1); whole items are paid out.
-- Returns (extra items, new carry). extra is never above base.
function PerkLogic.bonusYield(carry: number, base: number, multiplier: number): (number, number)
	local gain = math.max(0, base * (multiplier - 1))
	if gain ~= gain or base <= 0 then
		return 0, carry
	end
	local total = carry + gain
	local extra = math.min(math.floor(total), base)
	return extra, total - extra
end

-- Returns (ok, reason). "" id = unequip (always ok). Perk must be an owned perk item.
function PerkLogic.canEquipPerk(
	profile: ProfileSchema.Profile,
	id: string,
	item: Types.ShopItemDef?
): (boolean, string?)
	if id == "" then
		return true, nil
	end
	if item == nil or item.category ~= "perk" or not PerkLogic.effectValid(item.perk) then
		return false, "unavailable"
	end
	if not profile.ownedCosmetics[id] then
		return false, "locked"
	end
	return true, nil
end

-- Equips (or unequips) one perk; replaces the previous one so at most MaxEquippedPerks (1) is ever set.
function PerkLogic.equipPerk(
	profile: ProfileSchema.Profile,
	id: string,
	item: Types.ShopItemDef?
): (boolean, string?)
	local ok, reason = PerkLogic.canEquipPerk(profile, id, item)
	if ok then
		profile.equippedPerk = id
	end
	return ok, reason
end

function PerkLogic.equipCosmetic(
	profile: ProfileSchema.Profile,
	id: string,
	item: Types.ShopItemDef?
): (boolean, string?)
	if id == "" then
		profile.equippedCosmetic = ""
		return true, nil
	end
	if item == nil or item.category ~= "cosmetic" then
		return false, "unavailable"
	end
	if not profile.ownedCosmetics[id] then
		return false, "locked"
	end
	profile.equippedCosmetic = id
	return true, nil
end

function PerkLogic.equipTitle(
	profile: ProfileSchema.Profile,
	id: string,
	known: boolean
): (boolean, string?)
	if id == "" then
		profile.equippedTitle = ""
		return true, nil
	end
	if not known then
		return false, "unavailable"
	end
	if not profile.titles[id] then
		return false, "locked"
	end
	profile.equippedTitle = id
	return true, nil
end

-- Unequips anything the profile does not own (run on load). Returns true if anything changed.
function PerkLogic.sanitizeEquipped(
	profile: ProfileSchema.Profile,
	perkOk: (string) -> boolean
): boolean
	local changed = false
	if profile.equippedCosmetic ~= "" and not profile.ownedCosmetics[profile.equippedCosmetic] then
		profile.equippedCosmetic = ""
		changed = true
	end
	if
		profile.equippedPerk ~= ""
		and (not profile.ownedCosmetics[profile.equippedPerk] or not perkOk(profile.equippedPerk))
	then
		profile.equippedPerk = ""
		changed = true
	end
	if profile.equippedTitle ~= "" and not profile.titles[profile.equippedTitle] then
		profile.equippedTitle = ""
		changed = true
	end
	return changed
end

return PerkLogic
