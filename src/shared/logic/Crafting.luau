--!strict
-- Pure crafting rules. Atomic: either the whole recipe applies or inventory is untouched.

local Inventory = require("./Inventory")
local Config = require("../Config")
local ItemCatalog = require("../ItemCatalog")

local Crafting = {}

-- Stations the player is near, keyed by Config.Craft.Stations name (computed by the caller).
export type Near = { [string]: boolean }

-- Station a recipe needs (nil = by hand).
function Crafting.requiredStation(recipeId: string): string?
	local recipe = ItemCatalog.Recipes[recipeId]
	return if recipe then recipe.station else nil
end

-- partyTier = the party-wide workbench tier (nil = Config.Workbench.MaxTier, for legacy callers); a workbench
-- recipe above it fails with "NeedBenchTier".
-- Returns (ok, reason). reason: "UnknownRecipe" | "NeedStation" | "NeedBenchTier" | "MissingMaterials" | "InventoryFull".
function Crafting.craft(
	inv: Inventory.Inv,
	recipeId: string,
	near: Near,
	partyTier: number?
): (boolean, string)
	local recipe = ItemCatalog.Recipes[recipeId]
	if recipe == nil then
		return false, "UnknownRecipe"
	end
	if recipe.station ~= nil and not near[recipe.station] then
		return false, "NeedStation"
	end
	if ItemCatalog.benchTierOf(recipeId) > (partyTier or Config.Workbench.MaxTier) then
		return false, "NeedBenchTier"
	end
	for _, input in recipe.inputs do
		if Inventory.count(inv, input.id) < input.count then
			return false, "MissingMaterials"
		end
	end
	local trial = Inventory.clone(inv)
	for _, input in recipe.inputs do
		Inventory.remove(trial, input.id, input.count)
	end
	local def = ItemCatalog.Items[recipe.output.id]
	if Inventory.add(trial, def.id, recipe.output.count, def.maxStack, def.durability) > 0 then
		return false, "InventoryFull"
	end
	-- Commit.
	for _, input in recipe.inputs do
		Inventory.remove(inv, input.id, input.count)
	end
	Inventory.add(inv, def.id, recipe.output.count, def.maxStack, def.durability)
	return true, "Ok"
end

-- Display check from item counts (client panel greys out what this rejects; server still decides).
-- Returns "Ok" | "UnknownRecipe" | "NeedStation" | "NeedBenchTier" | "MissingMaterials".
function Crafting.status(
	counts: { [string]: number },
	recipeId: string,
	near: Near,
	partyTier: number?
): string
	local recipe = ItemCatalog.Recipes[recipeId]
	if recipe == nil then
		return "UnknownRecipe"
	end
	if recipe.station ~= nil and not near[recipe.station] then
		return "NeedStation"
	end
	if ItemCatalog.benchTierOf(recipeId) > (partyTier or Config.Workbench.MaxTier) then
		return "NeedBenchTier"
	end
	for _, input in recipe.inputs do
		if (counts[input.id] or 0) < input.count then
			return "MissingMaterials"
		end
	end
	return "Ok"
end

-- Recipe ids with tier <= maxTier, sorted by tier then id (stable panel order).
function Crafting.listForTier(maxTier: number): { string }
	local ids: { string } = {}
	for id, recipe in ItemCatalog.Recipes do
		if recipe.tier <= maxTier then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a: string, b: string): boolean
		local ta, tb = ItemCatalog.Recipes[a].tier, ItemCatalog.Recipes[b].tier
		if ta ~= tb then
			return ta < tb
		end
		return a < b
	end)
	return ids
end

return Crafting
