--!strict
-- Pure clothing math. Worn resistance = the equipped pieces (Equipment), summed
-- and capped at Config.Clothing.MaxColdResistance. Biomes demand requiredColdResistance; below it the
-- drain multiplier applies (BiomeLogic / SurvivalService). No Roblox APIs.

local Config = require("../Config")
local Clothing = require("../data/Clothing")
local ItemCatalog = require("../ItemCatalog")
local Equipment = require("./Equipment")
local Inventory = require("./Inventory")
local WarmthHint = require("./WarmthHint")

local ClothingLogic = {}

-- Worn resistance: only equipped pieces count (Items round); the sum over worn items, capped.
function ClothingLogic.equipped(equip: Inventory.Inv): number
	return Equipment.resistance(equip)
end

-- Legacy carried-count form (kept for tests and tooling): best piece per clothing slot among carried ids.
-- counts: item id -> carried count.
function ClothingLogic.resistance(counts: { [string]: number }): number
	local total = 0
	for _, slot in Config.Clothing.Slots do
		local best = 0
		for _, pieces in Clothing.Pieces do
			local id = pieces[slot]
			local def = if id then ItemCatalog.Items[id] else nil
			if def and def.coldResistance and (counts[def.id] or 0) > 0 then
				best = math.max(best, def.coldResistance)
			end
		end
		total += best
	end
	return math.min(total, Config.Clothing.MaxColdResistance)
end

-- Resistance of a full set of one tier (every slot).
function ClothingLogic.setResistance(tier: number): number
	local pieces = Clothing.Pieces[tier]
	local total = 0
	if pieces == nil then
		return 0
	end
	for _, slot in Config.Clothing.Slots do
		local def = if pieces[slot] then ItemCatalog.Items[pieces[slot]] else nil
		total += if def and def.coldResistance then def.coldResistance else 0
	end
	return math.min(total, Config.Clothing.MaxColdResistance)
end

-- Missing resistance points for a biome requirement (0 = dressed enough).
function ClothingLogic.deficit(resistance: number, required: number): number
	return math.max(0, math.min(required, Config.Biome.MaxRequiredColdResistance) - resistance)
end

-- Player-facing warning, or nil when dressed enough. A general hint (WarmthHint bands), no numbers.
function ClothingLogic.warning(resistance: number, required: number, biomeName: string): string?
	return WarmthHint.message(resistance, required, biomeName)
end

return ClothingLogic
