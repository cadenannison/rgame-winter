--!strict
-- Config module: Loot. Loot chests: tags, attributes, chest counts, rarity bonuses, beams.
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

local RarityData = require("../data/Rarity")

-- ===== Round: loot + massive structures + trees (contracts agent). See docs/INTEGRATION.md. =====
-- Loot drop weights are NOT here: they live in server/Loot/LootTables (server-only, never replicated).
export type LootConfig = {
	ChestTag: string, -- CollectionService tag on every world loot chest
	Rarities: { string }, -- chest (and item) rarities, worst to best; same list as data/Rarity.List
	ChestRarityAttribute: string, -- chest attribute: chest rarity (visuals only; contents stay server-side)
	ChestStructureAttribute: string, -- chest attribute: structure type id it belongs to
	ChestDepthAttribute: string, -- chest attribute: depth tier inside the structure (0 = entrance)
	ChestOpenedAttribute: string, -- chest attribute: true once looted (Boolean)
	MaxDepthTier: number, -- depth tiers are 0..MaxDepthTier (mirrors LootTables.depth.MaxTier, tested)
	OpenRange: number, -- studs: client prompt range
	ServerOpenRange: number, -- studs: server re-check range (> OpenRange for latency)
	OpenRateInterval: number, -- Guard interval for the open remote
	OpenedFadeSeconds: number, -- visuals: seconds an opened chest stays before it fades
	-- Items round: chest counts per structure class (deterministic from the run seed)
	Chests: { [string]: ChestCountRule },
	Rings: RingLootConfig,
	ChestSafety: ChestSafetyConfig,
	StructureClass: { [string]: string }, -- structure id (POI or Massive) -> Chests key
	DefaultClass: string,
	RingRarityBonus: { number }, -- index = ring (0..3): added rarity weight bonus; ring 3+ raises weights, not counts
	Beam: ChestBeamConfig,
	FirstOpenHintId: string, -- Config.Hints id for the one-time first-chest hint
}

-- Round contract (Agent D owns). Rings are player-facing 1..4 (1 = SnowyForest ... 4 = DeepTundra).
export type RingChestRule = {
	MaxPerStructure: number, -- ring 1 = 1, 2 = 2, 3 = 3, 4 = 4 (Massive keeps its own Chests.Massive range)
	ChestChance: number, -- per-chest chance 0..1; a structure may end up with none
}
export type RingLootConfig = {
	Chests: { [number]: RingChestRule },
	IronItems: { string }, -- ItemCatalog ids treated as iron (ore, ingots)
	IronMinRing: number, -- no iron before this ring
	IronWeightByRing: { number }, -- index = ring: relative iron weight (ring 1 = 0, ring 2 rare, ring 3+ more)
	IronNodeMinRing: number, -- iron resource nodes only from this ring
	OwnRangeClasses: { string }, -- Chests classes that keep their own Min..Max (not the ring cap/chance)
}
export type ChestSafetyConfig = {
	RequiresLineOfSight: boolean, -- ProximityPrompt.RequiresLineOfSight
	PromptMaxDistance: number, -- studs (small)
	ServerMaxDistance: number, -- studs: server re-check on open
	RaycastHeight: number, -- studs above the player root and above the chest pivot the wall check runs between
}

export type ChestCountRule = { Min: number, Max: number, TopRarity: number? } -- TopRarity = exact count of top rarity

export type ChestBeamConfig = {
	MinRarity: string, -- beams only for this rarity and above
	Height: number, -- studs (<= 12)
	MaxHeight: number, -- hard cap tests assert
	VisibleRadius: number, -- studs: client fades the beam out beyond this
	FadeBand: number, -- studs over which it fades
	MaxActive: number, -- beams alive at once per client
}

export type Sections = {
	Loot: LootConfig,
}

local Sections: Sections = {
	Loot = {
		ChestTag = "LootChest",
		Rarities = RarityData.List,
		ChestRarityAttribute = "ChestRarity",
		ChestStructureAttribute = "LootStructure",
		ChestDepthAttribute = "LootDepth",
		ChestOpenedAttribute = "LootOpened",
		MaxDepthTier = 4,
		OpenRange = 10,
		ServerOpenRange = 14,
		OpenRateInterval = 0.3,
		OpenedFadeSeconds = 20,
		Chests = {
			Small = { Min = 1, Max = 2 },
			Medium = { Min = 2, Max = 3 },
			Massive = { Min = 3, Max = 5 },
			Beacon = { Min = 3, Max = 4, TopRarity = 1 },
		},
		-- Beacon = the tall landmark structure the PM tested (assumed ResearchStation; confirm).
		StructureClass = {
			ResearchStation = "Beacon",
			MineComplex = "Massive",
			FrozenShipwreck = "Massive",
			RuinedTemple = "Massive",
			RangerLodge = "Medium",
			ExpandedRuins = "Massive",
			cabin = "Small",
			plane = "Small",
			ruin = "Medium",
			cave = "Medium",
			watchtower = "Small",
		},
		DefaultClass = "Small",
		Rings = {
			Chests = {
				[1] = { MaxPerStructure = 1, ChestChance = 0.6 },
				[2] = { MaxPerStructure = 2, ChestChance = 0.65 },
				[3] = { MaxPerStructure = 3, ChestChance = 0.7 },
				[4] = { MaxPerStructure = 4, ChestChance = 0.75 },
			},
			IronItems = { "IronOre", "IronIngot", "IronAxe", "IronPickaxe", "IronSpear" },
			IronMinRing = 2,
			IronWeightByRing = { 0, 0.05, 0.2, 0.4 }, -- chance an iron pick is kept (else swapped for a non-iron item); ring 1 = never
			IronNodeMinRing = 2,
			OwnRangeClasses = { "Massive", "Beacon" },
		},
		ChestSafety = {
			RequiresLineOfSight = true,
			PromptMaxDistance = 7,
			ServerMaxDistance = 9,
			RaycastHeight = 1.5,
		},
		RingRarityBonus = { 0, 0, 0.15, 0.3 },
		Beam = {
			MinRarity = "rare",
			Height = 10,
			MaxHeight = 12,
			VisibleRadius = 60,
			FadeBand = 15,
			MaxActive = 6,
		},
		FirstOpenHintId = "FirstChest",
	},
}

return Sections
