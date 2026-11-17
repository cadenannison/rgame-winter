--!strict
-- Data-driven item, recipe and gather-node tables. Pure data: no Roblox APIs.

local Config = require("./Config")

export type ItemDef = {
	id: string,
	name: string,
	kind: string, -- "resource" | "tool" | "weapon" | "placeable"
	maxStack: number,
	toolType: string?, -- "axe" | "pickaxe" (gather tools)
	toolTier: number?,
	durability: number?, -- starting durability for tools and weapons
	damage: number?, -- weapons
	structureId: string?, -- placeables
}

export type Recipe = {
	id: string,
	tier: number, -- workbench tier required (0 = by hand)
	inputs: { { id: string, count: number } },
	output: { id: string, count: number },
}

export type NodeDef = {
	kind: string,
	toolType: string,
	minTier: number,
	yieldId: string,
	yieldCount: number,
}

local ItemCatalog = {}

ItemCatalog.WorkbenchTag = "Workbench" -- CollectionService tag for placed workbenches
ItemCatalog.WorkbenchTierAttribute = "WorkbenchTier" -- optional Number attribute (default 1)
ItemCatalog.NodeKindAttribute = "NodeKind"
ItemCatalog.NodeHitsAttribute = "HitsLeft"
ItemCatalog.NodeDepletedAttribute = "Depleted"

local TOOL_DURABILITY = 60
local WEAPON_DURABILITY = 45
local SPEAR_DAMAGE = 12

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
		damage = SPEAR_DAMAGE,
		durability = WEAPON_DURABILITY,
	},
	Workbench = {
		id = "Workbench",
		name = "Workbench",
		kind = "placeable",
		maxStack = 1,
		structureId = "Workbench",
	},
} :: { [string]: ItemDef }

ItemCatalog.Recipes = {
	Axe = {
		id = "Axe",
		tier = 0,
		inputs = { { id = "Wood", count = 3 } },
		output = { id = "Axe", count = 1 },
	},
	Pickaxe = {
		id = "Pickaxe",
		tier = 0,
		inputs = { { id = "Wood", count = 2 }, { id = "Stone", count = 2 } },
		output = { id = "Pickaxe", count = 1 },
	},
	Workbench = {
		id = "Workbench",
		tier = 0,
		inputs = { { id = "Wood", count = 10 }, { id = "Stone", count = 4 } },
		output = { id = "Workbench", count = 1 },
	},
	Spear = {
		id = "Spear",
		tier = 1,
		inputs = { { id = "Wood", count = 3 }, { id = "Stone", count = 1 } },
		output = { id = "Spear", count = 1 },
	},
} :: { [string]: Recipe }

ItemCatalog.Nodes = {
	Tree = {
		kind = "Tree",
		toolType = "axe",
		minTier = Config.Gather.TreeTier,
		yieldId = "Wood",
		yieldCount = Config.Gather.TreeYield,
	},
	Rock = {
		kind = "Rock",
		toolType = "pickaxe",
		minTier = Config.Gather.RockTier,
		yieldId = "Stone",
		yieldCount = Config.Gather.RockYield,
	},
} :: { [string]: NodeDef }

return ItemCatalog
