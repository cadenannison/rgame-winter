--!strict
-- Biome rings (pure data). Owner: brief 13 (WorldGen). Consumers: 14, 15, 16, 17, 18.
-- Index = ring + 1. Ring r covers Chebyshev distance [r, r + 1) * World.ChunkSize from the map center,
-- matching WorldLayout.ringOf on the 8x8 grid (rings 0..3). Caps: Config.Biome.

local Config = require("../Config")
local Types = require("./Types")

local CHUNK = Config.World.ChunkSize

local Biomes = {}

Biomes.List = {
	{
		id = "SnowyForest",
		name = "Snowy Forest",
		ring = 0,
		innerRadius = 0,
		outerRadius = CHUNK,
		coldSeverity = 1,
		requiredColdResistance = 0,
		mobTier = 1,
		lootTier = 1,
		nodeKinds = { "Tree", "Rock" },
		lurkerKind = "TreeWatcher",
		hotSprings = false,
		color = { 235, 240, 245 },
	},
	{
		id = "FrozenLake",
		name = "Frozen Lake",
		ring = 1,
		innerRadius = CHUNK,
		outerRadius = 2 * CHUNK,
		coldSeverity = 1.3,
		requiredColdResistance = 3,
		mobTier = 2,
		lootTier = 2,
		nodeKinds = { "Tree", "Rock" },
		lurkerKind = "IceScratcher",
		hotSprings = false,
		color = { 190, 215, 235 },
	},
	{
		id = "MountainsCaves",
		name = "Mountains and Caves",
		ring = 2,
		innerRadius = 2 * CHUNK,
		outerRadius = 3 * CHUNK,
		coldSeverity = 1.7,
		requiredColdResistance = 6,
		mobTier = 3,
		lootTier = 3,
		nodeKinds = { "Rock", "IronOre" },
		lurkerKind = "EyesInDark",
		hotSprings = true,
		color = { 160, 165, 175 },
	},
	{
		id = "DeepTundra",
		name = "Deep Tundra Ruins",
		ring = 3,
		innerRadius = 3 * CHUNK,
		outerRadius = 4 * CHUNK,
		coldSeverity = 2.2,
		requiredColdResistance = 9,
		mobTier = 4,
		lootTier = 4,
		nodeKinds = { "Rock", "IronOre" },
		lurkerKind = nil,
		hotSprings = true,
		color = { 215, 220, 230 },
	},
} :: { Types.BiomeDef }

-- id -> def
Biomes.ById = {} :: { [string]: Types.BiomeDef }
for _, def in Biomes.List do
	Biomes.ById[def.id] = def
end

-- POI loot tables by tier 1..4 (tier = BiomeLogic.lootTier(distance from camp)). rolls = picks per crate;
-- each pick is a weighted entry with count in [min, max]. value = rough worth, used by tests to prove
-- that expected loot never gets worse with tier. Item ids must exist in ItemCatalog.Items.
export type LootEntry = { id: string, weight: number, min: number, max: number, value: number }
export type LootTable = { rolls: number, entries: { LootEntry } }

Biomes.Loot = {
	{
		rolls = 1,
		entries = {
			{ id = "Wood", weight = 5, min = 2, max = 4, value = 1 },
			{ id = "Stone", weight = 4, min = 1, max = 3, value = 1 },
			{ id = "RawMeat", weight = 3, min = 1, max = 2, value = 2 },
		},
	},
	{
		rolls = 2,
		entries = {
			{ id = "Wood", weight = 3, min = 2, max = 4, value = 1 },
			{ id = "Hide", weight = 3, min = 1, max = 2, value = 3 },
			{ id = "RawMeat", weight = 3, min = 1, max = 3, value = 2 },
			{ id = "CookedMeat", weight = 2, min = 1, max = 2, value = 4 },
		},
	},
	{
		rolls = 2,
		entries = {
			{ id = "Hide", weight = 2, min = 1, max = 3, value = 3 },
			{ id = "CookedMeat", weight = 3, min = 1, max = 3, value = 4 },
			{ id = "IronOre", weight = 3, min = 1, max = 3, value = 5 },
			{ id = "Stew", weight = 1, min = 1, max = 1, value = 6 },
		},
	},
	{
		rolls = 3,
		entries = {
			{ id = "CookedMeat", weight = 2, min = 2, max = 3, value = 4 },
			{ id = "IronOre", weight = 3, min = 2, max = 4, value = 5 },
			{ id = "IronIngot", weight = 2, min = 1, max = 2, value = 8 },
			{ id = "FrostShard", weight = 2, min = 1, max = 2, value = 9 },
			{ id = "Stew", weight = 1, min = 1, max = 2, value = 6 },
		},
	},
} :: { LootTable }

-- Biome for a ring index (clamped to the outermost ring).
function Biomes.forRing(ring: number): Types.BiomeDef
	local index = math.clamp(math.floor(ring) + 1, 1, #Biomes.List)
	return Biomes.List[index]
end

return Biomes
