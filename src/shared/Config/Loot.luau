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
	StructureClass: { [string]: string }, -- structure id (POI or Massive) -> Chests key
	DefaultClass: string,
	RingRarityBonus: { number }, -- index = ring (0..3): added rarity weight bonus; ring 3+ raises weights, not counts
	Beam: ChestBeamConfig,
	FirstOpenHintId: string, -- Config.Hints id for the one-time first-chest hint
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
