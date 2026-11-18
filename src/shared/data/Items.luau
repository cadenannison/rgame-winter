--!strict
-- Phase 3 items and gather nodes (pure data). Owner: brief 17 (structures/progression).
-- Consumers: 13 (IronOre node placement), 16 (mob drops, bow/arrows), 18. Merged into ItemCatalog.Items
-- / ItemCatalog.Nodes at load; ids must not collide with ItemCatalog's Phase 1 ids (tested).

local Config = require("../Config")
local Clothing = require("./Clothing")
local Types = require("./Types")

local STACK = Config.Inventory.MaxStack
local TOOL_DURABILITY = 60 -- matches ItemCatalog Phase 1 tools
local WEAPON_DURABILITY = 45
local METAL = Config.Durability.MetalToolMultiplier
local TORCH_BURN_SECONDS = 240 -- torch durability = seconds of burn
local LANTERN_BURN_SECONDS = 600
local FLARE_BURN_SECONDS = 20
local STONE_PICK_DURABILITY = 80

local Items = {}

local list: { Types.ItemDef } = {
	-- Resources
	{ id = "IronOre", name = "Iron Ore", kind = "resource", maxStack = STACK },
	{ id = "IronIngot", name = "Iron Ingot", kind = "resource", maxStack = STACK },
	{ id = "FrostShard", name = "Frost Shard", kind = "resource", maxStack = STACK },
	{ id = "WardenCore", name = "Warden Core", kind = "resource", maxStack = 5 },
	{ id = "MatriarchFang", name = "Matriarch Fang", kind = "resource", maxStack = 5 },
	{ id = "ColossusHeart", name = "Colossus Heart", kind = "resource", maxStack = 5 },
	{ id = "WhiteoutPelt", name = "Whiteout Pelt", kind = "resource", maxStack = 5 },
	-- Food (buffs: shared/data/Food.luau EatBuffs)
	{ id = "RawFish", name = "Raw Fish", kind = "food", maxStack = STACK, hunger = 10 },
	{ id = "CookedMeat", name = "Cooked Meat", kind = "food", maxStack = STACK, hunger = 45 },
	{ id = "CookedFish", name = "Cooked Fish", kind = "food", maxStack = STACK, hunger = 35 },
	{ id = "Stew", name = "Stew", kind = "food", maxStack = 10, hunger = 70 },
	-- Tools
	{
		id = "StonePickaxe",
		name = "Stone Pickaxe",
		kind = "tool",
		maxStack = 1,
		toolType = "pickaxe",
		toolTier = Config.ToolTier.Stone,
		durability = STONE_PICK_DURABILITY,
		repairable = true,
	},
	{
		id = "IronAxe",
		name = "Iron Axe",
		kind = "tool",
		maxStack = 1,
		toolType = "axe",
		toolTier = Config.ToolTier.Metal,
		durability = TOOL_DURABILITY * METAL,
		repairable = true,
	},
	{
		id = "IronPickaxe",
		name = "Iron Pickaxe",
		kind = "tool",
		maxStack = 1,
		toolType = "pickaxe",
		toolTier = Config.ToolTier.Metal,
		durability = TOOL_DURABILITY * METAL,
		repairable = true,
	},
	-- Weapons
	{
		id = "IronSpear",
		name = "Iron Spear",
		kind = "weapon",
		maxStack = 1,
		damage = 20,
		durability = WEAPON_DURABILITY * METAL,
		repairable = true,
	},
	{
		id = "Bow",
		name = "Bow",
		kind = "weapon",
		maxStack = 1,
		damage = 14,
		durability = WEAPON_DURABILITY,
		ranged = true,
		ammoId = "Arrow",
		repairable = true,
	},
	{ id = "Arrow", name = "Arrow", kind = "ammo", maxStack = STACK },
	-- Lights (counter-play to the Stalker and the dark)
	{
		id = "Torch",
		name = "Torch",
		kind = "light",
		maxStack = 1,
		durability = TORCH_BURN_SECONDS,
		lightRadius = 20,
		repelsStalker = true,
	},
	{
		id = "Lantern",
		name = "Lantern",
		kind = "light",
		maxStack = 1,
		durability = LANTERN_BURN_SECONDS,
		lightRadius = 28,
		repelsStalker = true,
		repairable = true,
	},
	{
		id = "Flare",
		name = "Flare",
		kind = "light",
		maxStack = 5,
		durability = FLARE_BURN_SECONDS,
		lightRadius = 40,
		repelsStalker = true,
		endsHunt = true,
	},
	-- Map (opens Remotes.MapRequest; Config.Map.ItemId)
	{ id = "Map", name = "Map", kind = "map", maxStack = 1 },
}

-- Placeables (one per shared/data/Structures.luau entry; id == structureId).
local PLACEABLES = {
	{ "Forge", "Forge" },
	{ "CookingStation", "Cooking Station" },
	{ "StorageChest", "Storage Chest" },
	{ "Wall", "Wall" },
	{ "Door", "Door" },
	{ "SpikeTrap", "Spike Trap" },
	{ "Watchtower", "Watchtower" },
	{ "SleepingBag", "Sleeping Bag" },
	{ "MapTable", "Map Table" },
}
for _, p in PLACEABLES do
	table.insert(list, {
		id = p[1],
		name = p[2],
		kind = "placeable",
		maxStack = if p[1] == "Wall" then 10 else 1,
		structureId = p[1],
	})
end

-- Clothing (resistance from Clothing.Tiers).
local SLOT_NAMES = { Head = "Hood", Body = "Coat", Feet = "Boots" }
for tierIndex, pieces in Clothing.Pieces do
	local tierDef = Clothing.Tiers[tierIndex]
	for slot, itemId in pieces do
		table.insert(list, {
			id = itemId,
			name = `{tierDef.label} {SLOT_NAMES[slot] or slot}`,
			kind = "clothing",
			maxStack = 1,
			clothingSlot = slot,
			clothingTier = tierDef.tier,
			coldResistance = tierDef.resistancePerPiece,
		})
	end
end

Items.List = list

Items.ById = {} :: { [string]: Types.ItemDef }
for _, def in list do
	Items.ById[def.id] = def
end

-- Phase 3 gather nodes (merged into ItemCatalog.Nodes). Same shape as ItemCatalog.NodeDef.
Items.Nodes = {
	IronOre = {
		kind = "IronOre",
		toolType = "pickaxe",
		minTier = Config.ToolTier.Stone,
		yieldId = "IronOre",
		yieldCount = 1,
		verb = "Mine",
		toolId = "StonePickaxe",
	},
} :: { [string]: Types.NodeDef }

return Items
