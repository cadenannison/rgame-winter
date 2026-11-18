--!strict
-- Phase 3 items and gather nodes (pure data). Owner: brief 17 (structures/progression).
-- Consumers: 13 (IronOre node placement), 16 (mob drops, bow/arrows), 18. Merged into ItemCatalog.Items
-- / ItemCatalog.Nodes at load; ids must not collide with ItemCatalog's Phase 1 ids (tested).

local Config = require("../Config")
local Clothing = require("./Clothing")
local Types = require("./Types")

-- Stack sizes come from Config.Items (ItemCatalog stamps the final value); these defaults mirror it.
local function stackOf(category: string): number
	return Config.Items.CategoryStack[category] or Config.Items.FallbackStack
end
local TOOL_DURABILITY = 60 -- matches ItemCatalog Phase 1 tools
local WEAPON_DURABILITY = 45
local METAL = Config.Durability.MetalToolMultiplier
local TORCH_BURN_SECONDS = 240 -- torch durability = seconds of burn
local LANTERN_BURN_SECONDS = 600
local BLUBBER_TORCH_BURN_SECONDS = 720 -- blubber burns long and slow (3x a plain torch)
local AURORA_TORCH_BURN_SECONDS = 480
local FLARE_BURN_SECONDS = 20
local STONE_PICK_DURABILITY = 80

local Items = {}

local list: { Types.ItemDef } = {
	-- Resources
	{ id = "IronOre", name = "Iron Ore", kind = "resource", maxStack = stackOf("material") },
	{ id = "IronIngot", name = "Iron Ingot", kind = "resource", maxStack = stackOf("material") },
	{
		id = "FrostShard",
		name = "Frost Shard",
		kind = "resource",
		maxStack = stackOf("rareMaterial"),
	},
	{
		id = "WardenCore",
		name = "Warden Core",
		kind = "resource",
		maxStack = stackOf("rareMaterial"),
	},
	{
		id = "MatriarchFang",
		name = "Matriarch Fang",
		kind = "resource",
		maxStack = stackOf("rareMaterial"),
	},
	{
		id = "ColossusHeart",
		name = "Colossus Heart",
		kind = "resource",
		maxStack = stackOf("rareMaterial"),
	},
	{
		id = "WhiteoutPelt",
		name = "Whiteout Pelt",
		kind = "resource",
		maxStack = stackOf("rareMaterial"),
	},
	-- Art Pass 3 creature drops (stack sizes from Config.Items.Entries). Uses: Feather/DenseHide -> InsulatedCoat,
	-- Blubber -> BlubberTorch, Claw/Fang/Bone -> FangSpear, CrystalShard/AuroraDust -> AuroraTorch, Venison = food.
	{ id = "Feather", name = "Feather", kind = "resource", maxStack = stackOf("material") },
	{ id = "Blubber", name = "Blubber", kind = "resource", maxStack = stackOf("animalPart") },
	{ id = "Claw", name = "Claw", kind = "resource", maxStack = stackOf("animalPart") },
	{ id = "Fang", name = "Fang", kind = "resource", maxStack = stackOf("animalPart") },
	{ id = "DenseHide", name = "Dense Hide", kind = "resource", maxStack = stackOf("animalPart") },
	{
		id = "CrystalShard",
		name = "Crystal Shard",
		kind = "resource",
		maxStack = stackOf("rareMaterial"),
	},
	{
		id = "AuroraDust",
		name = "Aurora Dust",
		kind = "resource",
		maxStack = stackOf("rareMaterial"),
	},
	-- Food (buffs: shared/data/Food.luau EatBuffs)
	{ id = "Venison", name = "Venison", kind = "food", maxStack = stackOf("meat"), hunger = 30 },
	{ id = "RawFish", name = "Raw Fish", kind = "food", maxStack = stackOf("meat"), hunger = 10 },
	{
		id = "CookedMeat",
		name = "Cooked Meat",
		kind = "food",
		maxStack = stackOf("meat"),
		hunger = 45,
	},
	{
		id = "CookedFish",
		name = "Cooked Fish",
		kind = "food",
		maxStack = stackOf("meat"),
		hunger = 35,
	},
	{ id = "Stew", name = "Stew", kind = "food", maxStack = stackOf("stew"), hunger = 70 },
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
	{ id = "Arrow", name = "Arrow", kind = "ammo", maxStack = stackOf("ammo") },
	-- Creature-drop crafts (data/Recipes.luau)
	{
		id = "FangSpear",
		name = "Fang Spear",
		kind = "weapon",
		maxStack = 1,
		damage = math.floor(Config.Combat.SpearDamage * 1.25),
		durability = WEAPON_DURABILITY,
		repairable = true,
	},
	{
		id = "InsulatedCoat",
		name = "Insulated Coat",
		kind = "clothing",
		maxStack = 1,
		clothingSlot = "Body",
		clothingTier = 2,
		coldResistance = 3,
	},
	{
		id = "BlubberTorch",
		name = "Blubber Torch",
		kind = "light",
		maxStack = 1,
		durability = BLUBBER_TORCH_BURN_SECONDS,
		lightRadius = 22,
		repelsStalker = true,
	},
	{
		id = "AuroraTorch",
		name = "Aurora Torch",
		kind = "light",
		maxStack = 1,
		durability = AURORA_TORCH_BURN_SECONDS,
		lightRadius = 30,
		repelsStalker = true,
	},
	-- Lights (counter-play to the Stalker and the dark)
	{
		id = "Torch",
		name = "Torch",
		kind = "light",
		maxStack = stackOf("torch"),
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
		maxStack = Config.Items.Entries.Flare.stack or stackOf("light"),
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
		maxStack = Config.Items.Entries[p[1]] and Config.Items.Entries[p[1]].stack
			or stackOf("placeable"),
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
