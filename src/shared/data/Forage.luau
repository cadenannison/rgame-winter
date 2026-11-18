--!strict
-- Forage round data (pure): new items, gather-node kinds, recipes and rarity tags for the collectables in
-- Config.Forage. Merged into ItemCatalog / Rarity.Tags at load. Stack sizes come from Config.Items.Entries.

local Config = require("../Config")
local Types = require("./Types")
local Rarity = require("./Rarity")

local Forage = {}

local function res(id: string, name: string): Types.ItemDef
	return { id = id, name = name, kind = "resource", maxStack = Config.Items.FallbackStack }
end
local function food(id: string, name: string, hunger: number): Types.ItemDef
	return {
		id = id,
		name = name,
		kind = "food",
		maxStack = Config.Items.FallbackStack,
		hunger = hunger,
	}
end

-- Hunger per item (food): small snacks next to RawMeat (25).
local PINECONE_HUNGER = 4
local WINTERBERRY_HUNGER = 8
local MUSHROOM_HUNGER = 6

Forage.Items = {
	res("Stick", "Stick"),
	food("Pinecone", "Pinecone", PINECONE_HUNGER),
	food("Winterberry", "Winterberry", WINTERBERRY_HUNGER),
	food("FrostMushroom", "Frost Mushroom", MUSHROOM_HUNGER),
	res("IceShard", "Ice Shard"),
	res("FrozenReed", "Frozen Reed"),
	res("Coal", "Coal"),
	res("IceBlock", "Ice Block"),
	res("ScrapMetal", "Scrap Metal"),
	res("Bone", "Bone"),
	res("Crystal", "Crystal"),
	res("RelicFragment", "Relic Fragment"),
	res("Rope", "Rope"),
} :: { Types.ItemDef }

-- Rarity tags (no lootCategory: never rolled into chests).
local function tag(r: Rarity.Rarity): Rarity.Tag
	return { rarity = r, category = nil }
end
Forage.Tags = {
	Stick = tag("common"),
	Pinecone = tag("common"),
	Winterberry = tag("common"),
	FrostMushroom = tag("uncommon"),
	IceShard = tag("uncommon"),
	FrozenReed = tag("common"),
	Coal = tag("common"),
	IceBlock = tag("common"),
	ScrapMetal = tag("uncommon"),
	Bone = tag("common"),
	Crystal = tag("rare"),
	RelicFragment = tag("rare"),
	Rope = tag("common"),
} :: { [string]: Rarity.Tag }

-- Gather-node kinds (merged into ItemCatalog.Nodes so the HUD prompt works). Hand-picked forage uses
-- toolType "hand" (ItemsGather accepts it with any/no tool); resource nodes name their tool.
Forage.Nodes = {} :: { [string]: Types.NodeDef }
for _, k in Config.Forage.Forage do
	Forage.Nodes[k.itemId] = {
		kind = k.itemId,
		toolType = "hand",
		minTier = 0,
		yieldId = k.itemId,
		yieldCount = k.minCount,
		verb = k.verb,
		toolId = "Axe",
	}
end
for _, k in Config.Forage.Nodes do
	Forage.Nodes[k.itemId] = {
		kind = k.itemId,
		toolType = k.toolType,
		minTier = k.minTier,
		yieldId = k.itemId,
		yieldCount = k.minCount,
		verb = k.verb,
		toolId = if k.toolType == "axe"
			then "Axe"
			elseif k.minTier >= Config.ToolTier.Metal then "IronPickaxe"
			elseif k.minTier >= Config.ToolTier.Stone then "StonePickaxe"
			else "Pickaxe",
	}
end
local relic = Config.Forage.Relic
Forage.Nodes[relic.itemId] = {
	kind = relic.itemId,
	toolType = "hand",
	minTier = 0,
	yieldId = relic.itemId,
	yieldCount = relic.minCount,
	verb = "Take",
	toolId = "Axe",
}

local function r(
	id: string,
	tier: number,
	station: string?,
	inputs: { Types.Stack },
	count: number?
): Types.Recipe
	return {
		id = id,
		tier = tier,
		station = station,
		inputs = inputs,
		output = { id = id, count = count or 1 },
	}
end

-- Simple recipes (key = output id). Sticks make wood, ice shards make frost shards, reeds make rope.
Forage.Recipes = {
	r("Wood", 0, nil, { { id = "Stick", count = 4 } }),
	r("FrostShard", 1, "workbench", { { id = "IceShard", count = 3 } }),
	r("Rope", 0, nil, { { id = "FrozenReed", count = 3 } }),
} :: { Types.Recipe }

return Forage
