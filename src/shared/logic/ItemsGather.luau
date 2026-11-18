--!strict
-- Pure gather rules: which tool may harvest which node.

local ItemCatalog = require("../ItemCatalog")
local Inventory = require("./Inventory")

local ItemsGather = {}

-- Node toolType "hand" (forage, relics) is harvestable with any held item or none.
-- Returns (ok, reason). reason: "UnknownNode" | "NoTool" | "WrongTool" | "TierTooLow" | "Ok".
function ItemsGather.canHarvest(nodeKind: string, tool: Inventory.Stack?): (boolean, string)
	local node = ItemCatalog.Nodes[nodeKind]
	if node == nil then
		return false, "UnknownNode"
	end
	if node.toolType == "hand" then
		return true, "Ok" -- hand-picked forage needs no tool
	end
	if tool == nil then
		return false, "NoTool"
	end
	local def = ItemCatalog.Items[tool.id]
	if def == nil or def.toolType ~= node.toolType then
		return false, "WrongTool"
	end
	if (def.toolTier or 0) < node.minTier then
		return false, "TierTooLow"
	end
	return true, "Ok"
end

return ItemsGather
