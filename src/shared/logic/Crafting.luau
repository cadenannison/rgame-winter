--!strict
-- Pure crafting rules. Atomic: either the whole recipe applies or inventory is untouched.

local Inventory = require("./Inventory")
local ItemCatalog = require("../ItemCatalog")

local Crafting = {}

-- Returns (ok, reason). reason: "UnknownRecipe" | "NeedWorkbench" | "MissingMaterials" | "InventoryFull".
function Crafting.craft(
	inv: Inventory.Inv,
	recipeId: string,
	availableTier: number
): (boolean, string)
	local recipe = ItemCatalog.Recipes[recipeId]
	if recipe == nil then
		return false, "UnknownRecipe"
	end
	if recipe.tier > availableTier then
		return false, "NeedWorkbench"
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
-- Returns "Ok" | "UnknownRecipe" | "NeedWorkbench" | "MissingMaterials".
function Crafting.status(
	counts: { [string]: number },
	recipeId: string,
	availableTier: number
): string
	local recipe = ItemCatalog.Recipes[recipeId]
	if recipe == nil then
		return "UnknownRecipe"
	end
	if recipe.tier > availableTier then
		return "NeedWorkbench"
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
