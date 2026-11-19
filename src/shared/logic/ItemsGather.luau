--!strict
-- Pure gather rules: which tool may harvest which node.

local Config = require("../Config")
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

-- Effort config for a node kind (Config.Gather.Effort via EffortKeyByKind; hand nodes are Forage).
function ItemsGather.effortOf(nodeKind: string): Config.GatherEffort
	local node = ItemCatalog.Nodes[nodeKind]
	local key = Config.Gather.EffortKeyByKind[nodeKind]
	if key == nil then
		key = if node and node.toolType == "hand" then "Forage" else "Stone"
	end
	return Config.Gather.Effort[key]
end

-- Whole hits to finish a node with a tool of this tier (instant = 1). Tier < 1 counts as tier 1.
function ItemsGather.hitsFor(nodeKind: string, toolTier: number): number
	local effort = ItemsGather.effortOf(nodeKind)
	if effort.Mode == "instant" then
		return 1
	end
	local byTier = effort.HitsByTier
	if byTier and #byTier > 0 then
		return math.max(1, byTier[math.clamp(math.floor(toolTier), 1, #byTier)])
	end
	return math.max(1, effort.Hits or Config.Gather.HitsToDeplete)
end

-- HitsLeft a fresh node starts with: the effort of the lowest tool that may harvest it.
function ItemsGather.baseHits(nodeKind: string): number
	local node = ItemCatalog.Nodes[nodeKind]
	return ItemsGather.hitsFor(nodeKind, math.max(1, if node then node.minTier else 1))
end

-- HitsLeft removed by one hit with this tool tier (better tools remove more, so progress stays one scale).
function ItemsGather.hitDamage(nodeKind: string, toolTier: number): number
	return ItemsGather.baseHits(nodeKind) / ItemsGather.hitsFor(nodeKind, toolTier)
end

-- Whether the node shows hit progress (instant pickups do not).
function ItemsGather.showsProgress(nodeKind: string): boolean
	return ItemsGather.effortOf(nodeKind).ShowProgress
end

-- Fraction of the node left (1 = untouched) from its HitsLeft attribute; nil when progress is not shown.
function ItemsGather.progressOf(nodeKind: string, hitsLeft: number): number?
	if not ItemsGather.showsProgress(nodeKind) then
		return nil
	end
	return math.clamp(hitsLeft / ItemsGather.baseHits(nodeKind), 0, 1)
end

-- Animals: hits to kill from health and weapon damage (server kill logic stays in MobService; display only).
function ItemsGather.animalHits(health: number, weaponDamage: number): number
	if weaponDamage <= 0 then
		return math.huge
	end
	return math.max(1, math.ceil(health / weaponDamage))
end

-- Chest opening: seconds the interact key is held (0 when the chest effort is not a hold).
function ItemsGather.chestHoldSeconds(): number
	local effort = Config.Gather.Effort.Chest
	return if effort.Mode == "hold" then (effort.HoldSeconds or 0) else 0
end

return ItemsGather
