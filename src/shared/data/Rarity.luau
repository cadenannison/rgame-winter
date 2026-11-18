--!strict
-- Item rarity and loot category tags (pure data, replicated; contains no drop weights).
-- Every ItemCatalog item gets a rarity (and, when it can appear in loot, a lootCategory) stamped from
-- Rarity.Tags at load; tests/LootTests.luau checks coverage. Drop weights are SERVER-ONLY (server/Loot/LootTables).

export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary"
export type LootCategory = "gear" | "tool" | "weapon" | "clothing" | "material" | "food"
export type Tag = { rarity: Rarity, category: LootCategory? } -- category nil = never found in loot chests

local Rarity = {}

-- Worst to best. Rank = index. Chests use the same five names.
Rarity.List = { "common", "uncommon", "rare", "epic", "legendary" } :: { string }
Rarity.Categories = { "gear", "tool", "weapon", "clothing", "material", "food" } :: { string }

local rank: { [string]: number } = {}
for i, name in Rarity.List do
	rank[name] = i
end

function Rarity.rank(r: string): number
	return rank[r] or 0
end

function Rarity.isRarity(r: any): boolean
	return type(r) == "string" and rank[r] ~= nil
end

-- Display colours {r, g, b} for UI (client reads these; no gameplay meaning).
Rarity.Colors = {
	common = { 190, 195, 200 },
	uncommon = { 110, 200, 120 },
	rare = { 90, 160, 235 },
	epic = { 175, 110, 230 },
	legendary = { 245, 175, 60 },
} :: { [string]: { number } }

local function t(r: Rarity, c: LootCategory?): Tag
	return { rarity = r, category = c }
end

-- Every ItemCatalog id (Phase 1 + Phase 3 + generated placeables and clothing). Missing id = test failure.
Rarity.Tags = {
	-- materials
	Wood = t("common", "material"),
	Stone = t("common", "material"),
	Hide = t("common", "material"),
	Arrow = t("common", "material"),
	IronOre = t("common", "material"),
	IronIngot = t("uncommon", "material"),
	FrostShard = t("rare", "material"),
	WardenCore = t("legendary", "material"),
	MatriarchFang = t("legendary", "material"),
	ColossusHeart = t("legendary", "material"),
	WhiteoutPelt = t("legendary", "material"),
	-- creature drops and crafts (Art Pass 3; no loot category: never rolled into chests)
	Feather = t("common"),
	Venison = t("common"),
	Blubber = t("common"),
	Claw = t("uncommon"),
	Fang = t("uncommon"),
	DenseHide = t("uncommon"),
	CrystalShard = t("rare"),
	AuroraDust = t("rare"),
	FangSpear = t("uncommon"),
	InsulatedCoat = t("rare"),
	BlubberTorch = t("common"),
	AuroraTorch = t("rare"),
	-- food
	RawMeat = t("common", "food"),
	RawFish = t("common", "food"),
	CookedMeat = t("common", "food"),
	CookedFish = t("common", "food"),
	Stew = t("uncommon", "food"),
	-- tools
	Axe = t("common", "tool"),
	Pickaxe = t("common", "tool"),
	StonePickaxe = t("uncommon", "tool"),
	IronAxe = t("rare", "tool"),
	IronPickaxe = t("rare", "tool"),
	-- weapons
	Spear = t("common", "weapon"),
	Bow = t("uncommon", "weapon"),
	IronSpear = t("rare", "weapon"),
	-- gear (lights, map, carried utility)
	Torch = t("common", "gear"),
	Flare = t("uncommon", "gear"),
	Map = t("uncommon", "gear"),
	Lantern = t("rare", "gear"),
	SleepingBag = t("uncommon", "gear"),
	SpikeTrap = t("uncommon", "gear"),
	StorageChest = t("uncommon", "gear"),
	-- clothing tiers (Config.Clothing: 1 hide, 2 fur, 3 arctic)
	HideBoots = t("common", "clothing"),
	HideCoat = t("common", "clothing"),
	HideHood = t("common", "clothing"),
	FurBoots = t("uncommon", "clothing"),
	FurCoat = t("rare", "clothing"),
	FurHood = t("uncommon", "clothing"),
	ArcticBoots = t("rare", "clothing"),
	ArcticCoat = t("epic", "clothing"),
	ArcticHood = t("rare", "clothing"),
	-- loot-only upper tiers (ItemCatalog LOOT_GEAR)
	AuroraBlade = t("epic", "weapon"),
	AuroraPickaxe = t("epic", "tool"),
	AuroraLantern = t("epic", "gear"),
	SunpiercerSpear = t("legendary", "weapon"),
	SunforgedAxe = t("legendary", "tool"),
	SunBeacon = t("legendary", "gear"),
	-- placeables not found in chests
	Workbench = t("common"),
	Campfire = t("common"),
	Wall = t("common"),
	Door = t("common"),
	CookingStation = t("uncommon"),
	Forge = t("rare"),
	Watchtower = t("rare"),
	MapTable = t("rare"),
} :: { [string]: Tag }

return Rarity
