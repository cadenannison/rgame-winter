--!strict
-- Pure mob-on-player damage rules (no Roblox APIs): wolf damage as a share of the victim's max health,
-- the wolf's shorter attack cooldown, and armor (sum of worn Config.Armor.Values, capped at MaxReduction).

local Config = require("../Config")
local ItemCatalog = require("../ItemCatalog")
local Inventory = require("./Inventory")

local WOLF = "Wolf"

local MobDamage = {}

-- Total reduction fraction of a list of worn item ids, capped at Config.Armor.MaxReduction.
function MobDamage.reduction(wornIds: { string }): number
	local total = 0
	for _, id in wornIds do
		total += math.max(0, ItemCatalog.armorOf(id))
	end
	return math.clamp(total, 0, Config.Armor.MaxReduction)
end

-- Same, for a worn-gear inventory (InventoryService.getEquipment). nil = nothing worn.
function MobDamage.reductionOfEquipment(equip: Inventory.Inv?): number
	if equip == nil then
		return 0
	end
	local ids: { string } = {}
	for index = 1, equip.size do
		local stack = equip.slots[index]
		if stack then
			table.insert(ids, stack.id)
		end
	end
	return MobDamage.reduction(ids)
end

-- Damage before armor: wolves take WolfDamageFraction of the victim's max health, others their row damage.
function MobDamage.base(kindName: string, rowDamage: number, victimMaxHealth: number): number
	if kindName == WOLF then
		return Config.Combat.WolfDamageFraction * math.max(0, victimMaxHealth)
	end
	return rowDamage
end

-- Final damage to a player: base, then armor (reduction re-capped here so callers cannot exceed the cap).
function MobDamage.toPlayer(
	kindName: string,
	rowDamage: number,
	victimMaxHealth: number,
	reduction: number
): number
	local r = math.clamp(reduction, 0, Config.Armor.MaxReduction)
	return math.max(0, MobDamage.base(kindName, rowDamage, victimMaxHealth) * (1 - r))
end

-- Seconds between attacks (the wolf is faster by Combat.WolfCooldownMultiplier).
function MobDamage.cooldown(kindName: string, baseCooldown: number): number
	if kindName == WOLF then
		return baseCooldown * Config.Combat.WolfCooldownMultiplier
	end
	return baseCooldown
end

return MobDamage
