--!strict
-- Data-driven item, recipe and gather-node tables. Pure data: no Roblox APIs.

local Config = require("./Config")
local Types = require("./data/Types")
local Phase3Items = require("./data/Items")
local Phase3Recipes = require("./data/Recipes")
local Phase3Structures = require("./data/Structures")

-- Item, recipe and structure shapes live in shared/data/Types.luau (Phase 3 adds optional fields).
export type ItemDef = Types.ItemDef
export type Recipe = Types.Recipe
export type StructureDef = Types.StructureDef

export type NodeDef = Types.NodeDef

local ItemCatalog = {}

ItemCatalog.WorkbenchTag = Config.Craft.Stations.workbench.Tag -- CollectionService tag for placed workbenches
ItemCatalog.WorkbenchTierAttribute = "WorkbenchTier" -- optional Number attribute (default 1)
ItemCatalog.NodeKindAttribute = "NodeKind"
ItemCatalog.NodeHitsAttribute = "HitsLeft"
ItemCatalog.NodeDepletedAttribute = "Depleted"

local TOOL_DURABILITY = 60
local WEAPON_DURABILITY = 45

ItemCatalog.Items = {
	Wood = { id = "Wood", name = "Wood", kind = "resource", maxStack = Config.Inventory.MaxStack },
	Stone = {
		id = "Stone",
		name = "Stone",
		kind = "resource",
		maxStack = Config.Inventory.MaxStack,
	},
	Axe = {
		id = "Axe",
		name = "Axe",
		kind = "tool",
		maxStack = 1,
		toolType = "axe",
		toolTier = Config.ToolTier.Basic,
		durability = TOOL_DURABILITY,
	},
	Pickaxe = {
		id = "Pickaxe",
		name = "Pickaxe",
		kind = "tool",
		maxStack = 1,
		toolType = "pickaxe",
		toolTier = Config.ToolTier.Basic,
		durability = TOOL_DURABILITY,
	},
	Spear = {
		id = "Spear",
		name = "Spear",
		kind = "weapon",
		maxStack = 1,
		damage = Config.Combat.SpearDamage,
		durability = WEAPON_DURABILITY,
	},
	Workbench = {
		id = "Workbench",
		name = "Workbench",
		kind = "placeable",
		maxStack = 1,
		structureId = "Workbench",
	},
	Campfire = {
		id = "Campfire",
		name = "Campfire",
		kind = "placeable",
		maxStack = 1,
		structureId = "Campfire",
	},
	RawMeat = {
		id = "RawMeat",
		name = "Raw Meat",
		kind = "food",
		maxStack = Config.Inventory.MaxStack,
		hunger = Config.Food.RawMeatHunger,
	},
	Hide = { id = "Hide", name = "Hide", kind = "resource", maxStack = Config.Inventory.MaxStack },
} :: { [string]: ItemDef }

ItemCatalog.Recipes = {
	Axe = {
		id = "Axe",
		tier = 0,
		inputs = { { id = "Wood", count = 3 } },
		output = { id = "Axe", count = 1 },
	},
	-- Wood only: stone needs a pickaxe, so a stone input would make stone unobtainable.
	Pickaxe = {
		id = "Pickaxe",
		tier = 0,
		inputs = { { id = "Wood", count = 4 } },
		output = { id = "Pickaxe", count = 1 },
	},
	Workbench = {
		id = "Workbench",
		tier = 0,
		inputs = { { id = "Wood", count = 10 }, { id = "Stone", count = 4 } },
		output = { id = "Workbench", count = 1 },
	},
	Campfire = {
		id = "Campfire",
		tier = 0,
		inputs = { { id = "Wood", count = 5 }, { id = "Stone", count = 2 } },
		output = { id = "Campfire", count = 1 },
	},
	Spear = {
		id = "Spear",
		tier = 1,
		station = "workbench",
		inputs = { { id = "Wood", count = 3 }, { id = "Stone", count = 1 } },
		output = { id = "Spear", count = 1 },
	},
} :: { [string]: Recipe }

ItemCatalog.Structures = {
	Workbench = {
		id = "Workbench",
		itemId = "Workbench",
		role = "workbench",
		sizeX = 6,
		sizeY = 3,
		sizeZ = 4,
		tier = 1,
		station = "workbench",
	},
	Campfire = {
		id = "Campfire",
		itemId = "Campfire",
		role = "campfire",
		sizeX = 4,
		sizeY = 1,
		sizeZ = 4,
	},
} :: { [string]: StructureDef }

ItemCatalog.Nodes = {
	Tree = {
		kind = "Tree",
		toolType = "axe",
		minTier = Config.Gather.TreeTier,
		yieldId = "Wood",
		yieldCount = Config.Gather.TreeYield,
		verb = "Chop",
		toolId = "Axe",
	},
	Rock = {
		kind = "Rock",
		toolType = "pickaxe",
		minTier = Config.Gather.RockTier,
		yieldId = "Stone",
		yieldCount = Config.Gather.RockYield,
		verb = "Mine",
		toolId = "Pickaxe",
	},
} :: { [string]: NodeDef }

-- Phase 3 merge: briefs 13-17 extend their own shared/data/*.luau files, never this file.
-- Duplicate ids are programmer errors (tests/DataTests.luau checks them before this would fire).
local function mergeInto<T>(target: { [string]: T }, id: string, def: T, what: string)
	assert(target[id] == nil, `ItemCatalog: duplicate {what} id {id}`)
	target[id] = def
end
for _, def in Phase3Items.List do
	mergeInto(ItemCatalog.Items, def.id, def, "item")
end
for kind, def in Phase3Items.Nodes do
	mergeInto(ItemCatalog.Nodes, kind, def, "node")
end
for _, def in Phase3Recipes.List do
	mergeInto(ItemCatalog.Recipes, def.id, def, "recipe")
end
for _, def in Phase3Structures.List do
	mergeInto(ItemCatalog.Structures, def.id, def, "structure")
end

return ItemCatalog
