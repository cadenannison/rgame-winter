--!strict
-- SERVER-ONLY loot tuning. Lives under src/server (ServerScriptService.Server), which Rojo never replicates, so
-- clients cannot read any weight. Never require this from src/shared or src/client (tests/LootTests.luau checks
-- that Config carries no weights). Shape and rolling math: shared/logic/LootRoll (type LootRoll.Tables).
--
-- Structure type keys: small POI kinds ("cabin", "plane", "cave", "ruin", "campsite" = PoiPlan kinds) and the
-- massive ids in Config.Massive.Ids. Ring index = biome ring 0..3 (ringWeights[ring + 1]).

-- No requires on purpose (headless tests load this file by relative path). The table is checked against
-- LootRoll.Tables where it is passed (server loot service and tests/LootTests).
local Tables = {
	-- Chest rarity weights by ring. Better chests are much more likely farther out; ring 0 never makes epic+.
	ringWeights = {
		{ common = 80, uncommon = 18, rare = 2, epic = 0, legendary = 0 }, -- ring 0 start forest
		{ common = 55, uncommon = 33, rare = 10, epic = 2, legendary = 0 }, -- ring 1 frozen lake
		{ common = 30, uncommon = 35, rare = 24, epic = 9, legendary = 2 }, -- ring 2 mountains
		{ common = 12, uncommon = 25, rare = 33, epic = 22, legendary = 8 }, -- ring 3 deep tundra
	},
	-- Multipliers on the ring weights (missing rarity = 1). Small POIs skew common; massive structures skew rich.
	structureWeights = {
		cabin = { common = 1.2, uncommon = 1, rare = 0.6, epic = 0.2, legendary = 0 },
		plane = { common = 0.8, uncommon = 1.1, rare = 1.2, epic = 0.8, legendary = 0.3 },
		cave = { common = 0.8, uncommon = 1, rare = 1.3, epic = 1, legendary = 0.5 },
		ruin = { common = 0.7, uncommon = 1, rare = 1.4, epic = 1.2, legendary = 0.8 },
		campsite = { common = 1.3, uncommon = 1, rare = 0.5, epic = 0.1, legendary = 0 },
		ResearchStation = { common = 0.4, uncommon = 0.8, rare = 1.6, epic = 2, legendary = 2 },
		MineComplex = { common = 0.5, uncommon = 1, rare = 1.6, epic = 1.6, legendary = 1.5 },
		FrozenShipwreck = { common = 0.5, uncommon = 1, rare = 1.5, epic = 1.8, legendary = 1.5 },
		RuinedTemple = { common = 0.3, uncommon = 0.7, rare = 1.5, epic = 2.4, legendary = 3 },
		RangerLodge = { common = 0.8, uncommon = 1.3, rare = 1.3, epic = 0.8, legendary = 0.3 },
		ExpandedRuins = { common = 0.5, uncommon = 0.9, rare = 1.5, epic = 1.8, legendary = 1.8 },
	},
	-- Loot chests per structure (inclusive range). Depth tier 0..MaxTier comes from the structure plan (0 = entrance).
	structureChests = {
		cabin = { 1, 1 },
		plane = { 1, 2 },
		cave = { 1, 2 },
		ruin = { 1, 2 },
		campsite = { 1, 1 },
		ResearchStation = { 4, 7 },
		MineComplex = { 4, 6 },
		FrozenShipwreck = { 3, 5 },
		RuinedTemple = { 4, 6 },
		RangerLodge = { 3, 5 },
		ExpandedRuins = { 3, 6 },
	},
	-- Deeper chests roll better: each depth tier adds PerTier to the multiplier base, compounding per rarity rank.
	depth = { PerTier = 0.6, MaxTier = 4 },
	chests = {
		common = {
			items = { 1, 2 },
			categoryWeights = {
				material = 35,
				food = 30,
				tool = 10,
				gear = 12,
				clothing = 8,
				weapon = 5,
			},
			rarityWeights = { common = 90, uncommon = 9.5, rare = 0.5, epic = 0, legendary = 0 },
		},
		uncommon = {
			items = { 2, 3 },
			categoryWeights = {
				material = 28,
				food = 22,
				tool = 12,
				gear = 14,
				clothing = 12,
				weapon = 12,
			},
			rarityWeights = { common = 60, uncommon = 33, rare = 6.5, epic = 0.5, legendary = 0 },
		},
		rare = {
			items = { 2, 4 },
			categoryWeights = {
				material = 22,
				food = 12,
				tool = 16,
				gear = 16,
				clothing = 18,
				weapon = 16,
			},
			rarityWeights = { common = 25, uncommon = 40, rare = 28, epic = 6.5, legendary = 0.5 },
		},
		epic = {
			items = { 3, 5 },
			categoryWeights = {
				material = 15,
				food = 8,
				tool = 17,
				gear = 17,
				clothing = 22,
				weapon = 21,
			},
			rarityWeights = { common = 8, uncommon = 27, rare = 40, epic = 22, legendary = 3 },
		},
		legendary = {
			items = { 4, 6 },
			categoryWeights = {
				material = 12,
				food = 6,
				tool = 16,
				gear = 18,
				clothing = 24,
				weapon = 24,
			},
			rarityWeights = { common = 2, uncommon = 10, rare = 33, epic = 40, legendary = 15 },
		},
	},
	stackCounts = {
		material = { 2, 6 },
		food = { 1, 3 },
	},
}

return Tables
