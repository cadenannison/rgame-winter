--!strict
-- Data-driven item, recipe and gather-node tables. Pure data: no Roblox APIs.

local Config = require("./Config")

export type ItemDef = {
	id: string,
	name: string,
	kind: string, -- "resource" | "tool" | "weapon" | "placeable" | "food"
	maxStack: number,
	toolType: string?, -- "axe" | "pickaxe" (gather tools)
	toolTier: number?,
	durability: number?, -- starting durability for tools and weapons
	damage: number?, -- weapons
	structureId: string?, -- placeables
	hunger: number?, -- food: hunger restored per item
}

export type Recipe = {
	id: string,
	tier: number, -- workbench tier required (0 = by hand)
	inputs: { { id: string, count: number } },
	output: { id: string, count: number },
}

-- Placeable structure (placed via PlaceRequest; costs one item of itemId). Size in studs.
export type StructureDef = {
	id: string,
	itemId: string,
	role: string, -- "workbench" | "campfire"
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	tier: number?, -- workbench tier
}

export type NodeDef = {
	kind: string,
	toolType: string,
	minTier: number,
	yieldId: string,
	yieldCount: number,
	verb: string, -- prompt / toast verb ("Chop", "Mine")
	toolId: string, -- item that harvests it (prompt "Chop: needs Axe")
}

local ItemCatalog = {}

ItemCatalog.WorkbenchTag = "Workbench" -- CollectionService tag for placed workbenches
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

return ItemCatalog
