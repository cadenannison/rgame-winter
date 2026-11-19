--!strict
-- Data-driven item, recipe and gather-node tables. Pure data: no Roblox APIs.

local Config = require("./Config")
local Types = require("./data/Types")
local Phase3Items = require("./data/Items")
local Phase3Recipes = require("./data/Recipes")
local Phase3Structures = require("./data/Structures")
local RarityData = require("./data/Rarity")
local ForageData = require("./data/Forage")

-- Item, recipe and structure shapes live in shared/data/Types.luau (Phase 3 adds optional fields).
export type ItemDef = Types.ItemDef
export type Recipe = Types.Recipe
export type StructureDef = Types.StructureDef

export type NodeDef = Types.NodeDef
export type Rarity = RarityData.Rarity
export type LootCategory = RarityData.LootCategory

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
-- Forage round (data/Forage.luau): collectable items, their nodes, recipes and rarity tags.
for _, def in ForageData.Items do
	mergeInto(ItemCatalog.Items, def.id, def, "item")
	RarityData.Tags[def.id] = ForageData.Tags[def.id]
end
for kind, def in ForageData.Nodes do
	mergeInto(ItemCatalog.Nodes, kind, def, "node")
end
for _, def in ForageData.Recipes do
	mergeInto(ItemCatalog.Recipes, def.id, def, "recipe")
end

-- Loot-only gear for the upper rarity tiers (chest finds; no recipes). Stats derive from Config so tuning
-- stays in one place: weapon damage = SpearDamage * multiplier, durability = base * MetalToolMultiplier * wear.
local EPIC_WEAPON_MULT = 2.2
local LEGENDARY_WEAPON_MULT = 3
local EPIC_WEAR = 1.5
local LEGENDARY_WEAR = 2
local EPIC_LIGHT_RADIUS = 36
local LEGENDARY_LIGHT_RADIUS = 48
local EPIC_LIGHT_SECONDS = 900
local LEGENDARY_LIGHT_SECONDS = 1200
local METAL_WEAR = Config.Durability.MetalToolMultiplier
local LOOT_GEAR: { ItemDef } = {
	{
		id = "AuroraBlade",
		name = "Aurora Blade",
		kind = "weapon",
		maxStack = 1,
		damage = math.floor(Config.Combat.SpearDamage * EPIC_WEAPON_MULT),
		durability = math.floor(WEAPON_DURABILITY * METAL_WEAR * EPIC_WEAR),
		repairable = true,
	},
	{
		id = "SunpiercerSpear",
		name = "Sunpiercer Spear",
		kind = "weapon",
		maxStack = 1,
		damage = math.floor(Config.Combat.SpearDamage * LEGENDARY_WEAPON_MULT),
		durability = math.floor(WEAPON_DURABILITY * METAL_WEAR * LEGENDARY_WEAR),
		repairable = true,
	},
	{
		id = "AuroraPickaxe",
		name = "Aurora Pickaxe",
		kind = "tool",
		maxStack = 1,
		toolType = "pickaxe",
		toolTier = Config.ToolTier.Metal,
		durability = math.floor(TOOL_DURABILITY * METAL_WEAR * EPIC_WEAR),
		repairable = true,
	},
	{
		id = "SunforgedAxe",
		name = "Sunforged Axe",
		kind = "tool",
		maxStack = 1,
		toolType = "axe",
		toolTier = Config.ToolTier.Metal,
		durability = math.floor(TOOL_DURABILITY * METAL_WEAR * LEGENDARY_WEAR),
		repairable = true,
	},
	{
		id = "AuroraLantern",
		name = "Aurora Lantern",
		kind = "light",
		maxStack = 1,
		durability = EPIC_LIGHT_SECONDS,
		lightRadius = EPIC_LIGHT_RADIUS,
		repelsStalker = true,
		repairable = true,
	},
	{
		id = "SunBeacon",
		name = "Sun Beacon",
		kind = "light",
		maxStack = 1,
		durability = LEGENDARY_LIGHT_SECONDS,
		lightRadius = LEGENDARY_LIGHT_RADIUS,
		repelsStalker = true,
		repairable = true,
	},
}
for _, def in LOOT_GEAR do
	mergeInto(ItemCatalog.Items, def.id, def, "item")
end

-- Loot round: stamp rarity and loot category on every item from data/Rarity.Tags (missing tag = programmer error).
for id, def in ItemCatalog.Items do
	local tag = RarityData.Tags[id]
	assert(tag ~= nil, `ItemCatalog: item {id} has no Rarity.Tags entry`)
	def.rarity = tag.rarity
	def.lootCategory = tag.category
end

-- Items round: Config.Items is the single source of truth for stack size, category, equip slot and cold resistance.
for id, def in ItemCatalog.Items do
	local entry = Config.Items.Entries[id]
	local category = (entry and entry.category) or Config.Items.KindCategory[def.kind] or "material"
	def.category = category
	def.maxStack = (entry and entry.stack)
		or Config.Items.CategoryStack[category]
		or Config.Items.FallbackStack
	def.fuelSeconds = entry and entry.fuelSeconds
	if entry and entry.equipSlot then
		def.equipSlot = entry.equipSlot
		def.coldResistance = entry.coldResistance or def.coldResistance
	end
end

-- Max stack of an item id (Config.Items.FallbackStack for unknown ids).
function ItemCatalog.stackOf(id: string): number
	local def = ItemCatalog.Items[id]
	return if def then def.maxStack else Config.Items.FallbackStack
end

-- Rarity of an item id ("common" for unknown ids).
function ItemCatalog.rarityOf(id: string): RarityData.Rarity
	local def = ItemCatalog.Items[id]
	return if def and def.rarity then def.rarity else "common"
end

-- Items in Config.Durability.UnbreakableItems never lose durability and are never repaired (the starting Axe).
function ItemCatalog.isUnbreakable(id: string): boolean
	return Config.Durability.UnbreakableItems[id] == true
end

return ItemCatalog
