--!strict
-- Pure repair rules: which items can be repaired, what it costs (a fraction of the recipe inputs, rounded
-- up) and the result. The workbench-nearby and inventory checks happen on the server at the action.

local Config = require("../Config")
local ItemCatalog = require("../ItemCatalog")
local Types = require("../data/Types")

local Repair = {}

function Repair.isRepairable(def: Types.ItemDef): boolean
	if def.durability == nil then
		return false
	end
	return def.repairable == true or def.kind == "tool" or def.kind == "weapon"
end

-- Full-repair cost: CostFraction of each recipe input (rounded up, at least MinCost). nil = no recipe.
function Repair.cost(itemId: string): { Types.Stack }?
	local recipe = ItemCatalog.Recipes[itemId]
	if recipe == nil then
		return nil
	end
	local out: { Types.Stack } = {}
	for _, input in recipe.inputs do
		local n =
			math.max(Config.Repair.MinCost, math.ceil(input.count * Config.Repair.CostFraction))
		table.insert(out, { id = input.id, count = n })
	end
	return out
end

-- (ok, reason): NotRepairable | FullDurability | NoRecipe | Ok.
function Repair.check(def: Types.ItemDef, durability: number?): (boolean, string)
	if not Repair.isRepairable(def) or durability == nil or def.durability == nil then
		return false, "NotRepairable"
	end
	if durability >= def.durability then
		return false, "FullDurability"
	end
	if Repair.cost(def.id) == nil then
		return false, "NoRecipe"
	end
	return true, "Ok"
end

-- True if counts (item id -> carried) cover every cost row.
function Repair.canAfford(cost: { Types.Stack }, counts: { [string]: number }): boolean
	for _, row in cost do
		if (counts[row.id] or 0) < row.count then
			return false
		end
	end
	return true
end

-- "2 Wood, 1 Stone".
function Repair.costText(cost: { Types.Stack }): string
	local parts: { string } = {}
	for _, row in cost do
		local def = ItemCatalog.Items[row.id]
		table.insert(parts, `{row.count} {if def then def.name else row.id}`)
	end
	return table.concat(parts, ", ")
end

-- Durability as a whole percent of the item maximum (0 when unknown).
function Repair.percent(def: Types.ItemDef, durability: number?): number
	if def.durability == nil or durability == nil or def.durability <= 0 then
		return 0
	end
	return math.clamp(math.floor(durability / def.durability * 100 + 0.5), 0, 100)
end

return Repair
