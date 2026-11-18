--!strict
-- Chunk variants per biome (pure data). Owner: brief 13 (WorldGen). Consumers: 16 (spawn zones), 18.
-- Several variants per biome; WorldGen picks by seed and weight and rotates them.

local Types = require("./Types")

local Chunks = {}

Chunks.Variants = {
	-- Snowy forest (start): dense trees, easy food.
	{
		id = "ForestDense",
		biome = "SnowyForest",
		weight = 3,
		trees = 14,
		rocks = 4,
		ore = 0,
		food = 3,
		spawnZones = 2,
		poiSlots = 1,
		poiKinds = { "cabin" },
	},
	{
		id = "ForestClearing",
		biome = "SnowyForest",
		weight = 2,
		trees = 8,
		rocks = 6,
		ore = 0,
		food = 4,
		spawnZones = 2,
		poiSlots = 1,
		poiKinds = { "campsite" },
	},
	{
		id = "ForestCreek",
		biome = "SnowyForest",
		weight = 2,
		trees = 10,
		rocks = 5,
		ore = 0,
		food = 3,
		spawnZones = 2,
		poiSlots = 1,
		poiKinds = { "cabin", "plane" },
	},
	-- Frozen lake: open ice, thin-ice patches, fish.
	{
		id = "LakeOpen",
		biome = "FrozenLake",
		weight = 3,
		trees = 3,
		rocks = 3,
		ore = 0,
		food = 3,
		spawnZones = 3,
		poiSlots = 1,
		poiKinds = { "thinice" },
	},
	{
		id = "LakeShore",
		biome = "FrozenLake",
		weight = 2,
		trees = 7,
		rocks = 4,
		ore = 0,
		food = 2,
		spawnZones = 2,
		poiSlots = 2,
		poiKinds = { "cabin", "thinice" },
	},
	{
		id = "LakeIsland",
		biome = "FrozenLake",
		weight = 1,
		trees = 5,
		rocks = 3,
		ore = 0,
		food = 2,
		spawnZones = 2,
		poiSlots = 1,
		poiKinds = { "plane", "campsite" },
	},
	-- Mountains and caves: rock, ore, hot springs.
	{
		id = "MountainPass",
		biome = "MountainsCaves",
		weight = 3,
		trees = 2,
		rocks = 8,
		ore = 3,
		food = 1,
		spawnZones = 3,
		poiSlots = 1,
		poiKinds = { "cave" },
	},
	{
		id = "MountainSpring",
		biome = "MountainsCaves",
		weight = 1,
		trees = 3,
		rocks = 6,
		ore = 2,
		food = 1,
		spawnZones = 2,
		poiSlots = 1,
		poiKinds = { "hotspring" },
	},
	{
		id = "CaveMouth",
		biome = "MountainsCaves",
		weight = 2,
		trees = 1,
		rocks = 7,
		ore = 4,
		food = 1,
		spawnZones = 3,
		poiSlots = 2,
		poiKinds = { "cave", "campsite" },
	},
	-- Deep tundra ruins: sparse, rich loot, the coldest ring.
	{
		id = "TundraRuins",
		biome = "DeepTundra",
		weight = 3,
		trees = 1,
		rocks = 5,
		ore = 3,
		food = 1,
		spawnZones = 3,
		poiSlots = 2,
		poiKinds = { "ruin" },
	},
	{
		id = "TundraFlats",
		biome = "DeepTundra",
		weight = 2,
		trees = 0,
		rocks = 4,
		ore = 2,
		food = 1,
		spawnZones = 3,
		poiSlots = 1,
		poiKinds = { "plane", "campsite" },
	},
	{
		id = "TundraSpring",
		biome = "DeepTundra",
		weight = 1,
		trees = 0,
		rocks = 3,
		ore = 2,
		food = 1,
		spawnZones = 2,
		poiSlots = 2,
		poiKinds = { "hotspring", "ruin" },
	},
} :: { Types.ChunkVariant }

-- Variants of one biome, in table order (deterministic for seeded picks).
function Chunks.forBiome(biomeId: string): { Types.ChunkVariant }
	local out: { Types.ChunkVariant } = {}
	for _, v in Chunks.Variants do
		if v.biome == biomeId then
			table.insert(out, v)
		end
	end
	return out
end

return Chunks
