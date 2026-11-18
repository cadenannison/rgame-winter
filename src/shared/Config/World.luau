--!strict
-- Config module: World. World gen: world layout, terrain, forest, trees, biomes, POI/structure sizes, massive structures, site ground, map, shadows.
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

local Constants = require("./Constants")

export type WorldConfig = {
	GridSize: number,
	ChunkSize: number,
	DefaultSeed: number,
	StartForestRing: number,
	CampMinRingDistance: number,
	CampGuaranteedWoodCount: number,
	CampGuaranteedFoodCount: number,
	CampGuaranteeRadius: number,
	StreamInRadius: number,
	StreamOutRadius: number,
	StreamInterval: number,
	TreesPerChunk: number,
	RocksPerChunk: number,
	SpawnZonesPerChunk: number,
	ChunkTag: string,
	SeedAttribute: string,
	CampAttribute: string,
	ChunkFolderName: string,
	CampFolderName: string,
	CampSpawnOffset: number,
	SlotTags: SlotTags,
}

export type SlotTags = {
	Tree: string,
	Rock: string,
	Food: string,
	SpawnZone: string,
}

-- ===== Phase 3 contracts (brief 12). See docs/INTEGRATION.md "Phase 3" for owners/consumers. =====
-- Rule: every value that scales by day, depth (biome ring) or party size has a Max* hard cap here.
-- Per-entry tuning lives in src/shared/data/*.luau (owned by briefs 13-17); tests/DataTests.luau
-- checks those tables stay inside these caps. Hidden metrics (Dread, hunt chance, event timers) are
-- server-only values: these constants may replicate, the live values never do.
-- Biome rings (data: shared/data/Biomes.luau). Cold severity multiplies warmth drain.
export type BiomeConfig = {
	RingAttribute: string, -- Player attribute: biome ring the player stands in (0 = start forest)
	ColdResistanceAttribute: string, -- Player attribute: worn cold resistance (sum of clothing, capped)
	MaxColdSeverity: number, -- cap on any biome's warmth drain multiplier
	MaxRequiredColdResistance: number, -- cap on any biome's requiredColdResistance
	ResistanceDrainReductionPerPoint: number, -- drain *= 1 - points * this ...
	MinDrainFraction: number, -- ... floored here (gear never removes cold entirely)
	UnderdressedDrainPerPoint: number, -- extra drain multiplier per missing resistance point
	MaxUnderdressedMultiplier: number, -- cap on the underdressed multiplier
	UpdateInterval: number, -- seconds between biome/resistance recomputes (one loop)
	OreSlotTag: string, -- CollectionService tag on IronOre slot parts
	ThinIceWarmthPenalty: number, -- warmth lost when thin ice breaks under a player
	Tuning: BiomeTuning, -- world-gen tuning (BiomeLogic.Tuning aliases this)
}

export type BiomeTuning = {
	MaxLootTier: number,
	HearthBurnSeconds: number, -- warmth per Wood added to a cabin hearth
	HearthMaxSeconds: number, -- a hearth never holds more than this
	ThinIceCrackSeconds: number, -- continuous standing before a patch breaks
	ThinIceDamage: number, -- one-time damage to a player on a breaking patch
	ThinIcePatchRadius: number,
	ThinIcePatchCount: number,
	LootPromptRange: number,
}

-- Structure tuning (data/Structures.Tuning aliases this).
export type StructuresConfig = {
	DoorTag: string,
	WatchtowerTag: string,
	ChestIdAttribute: string,
	InteractRange: number,
	ServerInteractRange: number,
	DoorOpenTransparency: number,
	StructureTickSeconds: number,
	TrapHeight: number,
	WatchtowerStandHeight: number,
	WatchtowerRevealSeconds: number,
	WatchtowerTrussWidth: number,
}

-- One tree size class (Forest.Classes). Heights/radii are {min, max} studs, rolled by the seeded layout.
export type TreeClass = {
	Id: string,
	Weight: number, -- relative spawn weight
	Height: { number },
	TrunkRadius: { number },
	CanopyRadius: { number },
	MinSpacing: number, -- studs to the nearest other tree center (any class)
	Gatherable: boolean, -- can be chopped for wood
	WoodYield: number, -- wood per chop-out
}

export type ForestConfig = {
	Classes: { TreeClass }, -- Small, Medium, Large, Giant (in that order)
	TreesPerChunk: number, -- base tree slots per 320x320 chunk in the start forest (before multipliers)
	RingDensity: { number }, -- density multiplier per biome ring (index = ring + 1)
	CampBonusTrees: number, -- extra trees added to the chunk that holds the camp
	PoiClearRadius: number, -- studs around a POI centre with no trees
	SlotClearRadius: number, -- studs around rock/ore/food/spawn-zone slots with no trees
	TrunkNodeMaxHeight: number, -- studs: height cap of the gather-node trunk part
	MaxPartsPerTree: number, -- perf note: trunk + canopy parts only; no per-leaf parts
	SpawnClearRadius: number, -- studs around the player spawn pad with no trees at all
	FireClearRadius: number, -- studs around any campfire with no trees (clearing)
	NearCampRadius: number, -- studs from the camp fire where NearCampDensity applies
	NearCampDensity: number, -- density multiplier inside NearCampRadius (open enough to walk and build)
	CampEdgeRadius: number, -- studs from camp where the forest thickens back up (to NearCampRadius..this)
	CampEdgeDensity: number, -- density multiplier in that band (the treeline hugging the camp)
	GiantMaxPerChunk: number, -- cap on giants per chunk (landmarks, perf)
	PlacementAttempts: number, -- rejection-sampling tries per tree slot before it is dropped
	TagAttribute: string, -- tree model attribute: size class id
}

export type BiomeTerrain = { Amplitude: number, MaxStep: number }

export type TerrainConfig = {
	BlockSize: number, -- studs per square terrain block (blocks are flat-topped, stepped)
	HeightQuantum: number, -- block heights are multiples of this
	MaxStep: number, -- studs: max height difference between edge-adjacent blocks (hard cap, tested)
	ColumnDepth: number, -- studs of solid terrain built under each block top (> MaxStep so sides never show gaps)
	BlendWidth: number, -- studs across which biome amplitude blends at a ring boundary
	LowWavelength: number, -- studs: broad hill wavelength
	HighWavelength: number, -- studs: detail wavelength
	LowShare: number, -- fraction of amplitude in the broad octave (rest in detail)
	Biomes: { [string]: BiomeTerrain }, -- keyed by Biomes id; amplitude = max |height| studs
	CampFlatRadius: number, -- studs around the flat center (camp/spawn) with height exactly 0
	CampRampWidth: number, -- studs over which terrain rises smoothly from flat to full amplitude
	BaseHeight: number, -- ground level of the flat start area (Y of block tops at the camp)
	FloorY: number, -- bottom Y of terrain columns (decorative thickness below the lowest block)
	KillHeight: number, -- a character whose root falls below this Y is killed/respawned
	EdgeMargin: number, -- studs beyond the world edge (GridSize*ChunkSize/2) past which a player has fallen off
	EdgeWallHeight: number, -- studs of invisible-wall/cliff height at the world border
	MaxBlocksPerChunkBuild: number, -- builder yields after this many blocks (perf)
	BuildBlocksPerTick: number, -- blocks filled per Heartbeat while a chunk's terrain builds (hard per-tick budget)
	BuildMsPerTick: number, -- milliseconds of terrain building per Heartbeat; whichever limit hits first yields
}

export type MassiveBudget = {
	Parts: number, -- max live BaseParts of one structure (shell + loot + dressing)
	DressingParts: number, -- of Parts: interior dressing (spawned only near a player)
	Lights: number, -- max PointLight/SpotLight instances
	Particles: number, -- max enabled ParticleEmitters
}

export type MassiveStructure = {
	Id: string,
	Name: string,
	MinFootprintX: number, -- studs, structure-local X extent (minimum)
	MinFootprintZ: number,
	MinRooms: number,
	MinLevels: number, -- walkable floors incl. underground ones
	UndergroundDepth: number, -- studs below the entrance floor reached by the deepest level (0 = none)
	Rings: { number }, -- allowed biome rings (0 start forest .. 3 tundra)
	CountMin: number, -- per world (64 chunks), never above CountMax
	CountMax: number,
	Budget: MassiveBudget,
}

export type MassiveConfig = {
	Ids: { string }, -- keys of Structures, in display order
	Structures: { [string]: MassiveStructure },
	CorridorWidthMin: number, -- studs: every walkable corridor
	CeilingHeightMin: number, -- studs floor to ceiling in corridors and rooms
	DoorWidthMin: number,
	DoorHeightMin: number,
	StairWidthMin: number,
	MaxLiveStructures: number, -- built at once per server window
	MinSeparation: number, -- studs between massive structure centres (and from the camp)
	FootprintMargin: number, -- studs added to the footprint half-diagonal for tree/POI/mob exclusion
	DressingSpawnRadius: number, -- studs: interior dressing spawns when a player is this close to the structure centre
	DressingDespawnRadius: number, -- studs: dressing despawns past this (> spawn radius, hysteresis)
	DressingCheckInterval: number, -- seconds between proximity checks (one loop, all structures)
	DressingPartsPerTick: number, -- parts spawned or removed per Heartbeat
	MaxLiveParts: number, -- all massive structures at once (= MaxLiveStructures * largest Budget.Parts)
	-- Integration (placement + wiring)
	PlacementAttempts: number, -- rejection-sampling tries per structure
	EdgeMargin: number, -- studs a structure keeps inside the world edge, beyond its radius
	PoiMargin: number, -- studs between a structure footprint and any POI footprint
	MaxSiteRelief: number, -- studs: max (highest - lowest) World.heightAt over the footprint samples
	SiteSampleStep: number, -- studs between relief samples
	KillMargin: number, -- studs: deepest carve must stay this far above Terrain.KillHeight
	ChestsPerPartAllowance: number, -- parts per chest beyond the 2 each plan reserves (ChestStyle.Budget.MaxParts 8 - 2)
	MaxChestsPerStructure: number, -- estimate: chest slots per live structure
	TempleDreadScale: number, -- fraction of Dread.GainLurkerSighting applied per temple dread zone event
}

export type TreesConfig = {
	HeadHeight: number, -- studs: top of a standing player's head above the ground
	CanopyClearance: number, -- studs: lowest foliage bottom must be at least this far above HeadHeight
	MinCanopyBottom: number, -- = HeadHeight + CanopyClearance
	MinFoliageThickness: number, -- studs of foliage above the canopy bottom, at minimum
	MinTotalHeight: number, -- studs: shortest allowed tree (every size class)
	SizeClasses: { string }, -- Forest.Classes ids, small to giant
	GiantHeightMin: number,
	GiantHeightMax: number,
}

export type ShadowConfig = {
	GlobalShadows: boolean,
	TreesCastShadows: boolean,
	ShadowSoftness: number, -- Lighting.ShadowSoftness (0-1)
	ForestFloorDarkness: number, -- 0-1: how much darker the ground under a canopy reads by day
	ForestFloorDarknessNight: number, -- 0-1: same at night (lower so the floor stays readable)
	CanopyShadeRadiusFactor: number, -- shade disc radius as a multiple of CanopyRadius
	NightMinAmbient: { number }, -- {r, g, b} floor for Lighting.Ambient at night (readability)
	NightMinOutdoorAmbient: { number },
	NightMinBrightness: number, -- Lighting.Brightness floor at night
	MaxShadeDiscs: number, -- perf: cap on forest-floor shade parts/decals alive
	CanopyShadowMinRadius: number, -- studs: foliage parts of trees with at least this canopy radius cast shadows
}

-- Items round: terrain grounding for structures, fires and placeables (shared/logic/SiteGround).
export type SiteGroundConfig = {
	MaxSlope: number, -- max (highest - lowest) / footprint diagonal over the samples
	MaxRange: number, -- studs: max (max - min) height over the footprint; above = reject/relocate
	FillRange: number, -- studs: up to this range the site is flattened/filled instead of relocated
	SampleStep: number, -- studs between footprint grid samples
	SkirtWidth: number, -- studs of blended skirt around a flattened pad
	WaterHeight: number, -- height at or below which a sample counts as water
	MaxWaterFraction: number, -- reject when more than this fraction of samples is water
	CliffStep: number, -- studs: adjacent-sample height jump that counts as a cliff edge
	RaycastUp: number, -- studs above the site the grounding raycast starts
	RaycastDown: number, -- studs the raycast reaches down
	SinkMargin: number, -- studs a placed model's base sits above the surface (never buried)
	RelocateRadius: number, -- studs searched for a better site
	RelocateAttempts: number,
}

-- Fog-of-war map. Explored cells are per-run server state (not saved).
export type MapConfig = {
	CellSize: number, -- studs per map cell
	ExploreRadius: number, -- studs around a player marked explored
	ExploreTickSeconds: number,
	MaxCellsPerPayload: number,
	ItemId: string, -- item needed to open the map
	ButtonWidthPx: number,
	ButtonHeightPx: number,
	ButtonScaleX: number,
	ButtonScaleY: number,
	ButtonOffsetYPx: number,
}

export type Sections = {
	World: WorldConfig,
	Biome: BiomeConfig,
	SiteGround: SiteGroundConfig,
	Map: MapConfig,
	Structures: StructuresConfig,
	Forest: ForestConfig,
	Terrain: TerrainConfig,
	Massive: MassiveConfig,
	Trees: TreesConfig,
	Shadows: ShadowConfig,
}

local GIANT_TREE_HEIGHT = Constants.GIANT_TREE_HEIGHT
local MASSIVE_MAX_LIVE_PARTS = Constants.MASSIVE_MAX_LIVE_PARTS
local MASSIVE_MAX_LIVE_STRUCTURES = Constants.MASSIVE_MAX_LIVE_STRUCTURES

local Sections: Sections = {
	World = {
		GridSize = 8, -- chunks per side (8x8 = 64)
		ChunkSize = 320, -- studs per chunk side (8 * 320 = 2560 studs square)
		DefaultSeed = 12345, -- seed when none is supplied (tests, Studio)
		StartForestRing = 0, -- ring index (0 = center) of the start forest, camp is in it (Phase 3: biome ring 0)
		CampMinRingDistance = 1, -- min chunks of separation from the world edge for camp
		CampGuaranteedWoodCount = 6, -- trees guaranteed near camp
		CampGuaranteedFoodCount = 3, -- food sources guaranteed near camp
		CampGuaranteeRadius = 80, -- studs around camp for the guarantees
		StreamInRadius = 400, -- studs from a player at which chunks load
		StreamOutRadius = 520, -- studs beyond which chunks unload (> in radius, hysteresis)
		StreamInterval = 1, -- seconds between streaming checks
		TreesPerChunk = 12, -- tree slots per start-forest chunk
		RocksPerChunk = 5, -- rock slots per start-forest chunk
		SpawnZonesPerChunk = 2, -- mob spawn zone slots per chunk
		ChunkTag = "Chunk", -- CollectionService tag
		SeedAttribute = "WorldSeed", -- Workspace attribute: run seed (number); set before start to force a seed
		CampAttribute = "CampPosition", -- Workspace attribute: camp position (Vector3, y = 0)
		ChunkFolderName = "Chunks", -- Workspace folder for streamed chunk models
		CampFolderName = "Camp", -- Workspace folder for the camp campfire (never streamed out)
		CampSpawnOffset = 8, -- studs from the camp fire to the player spawn pad (inside WarmRadius)
		-- CollectionService tags on chunk slot parts (WorldLayout.SlotKinds mirrors these).
		SlotTags = {
			Tree = "TreeSlot",
			Rock = "RockSlot",
			Food = "FoodSlot",
			SpawnZone = "SpawnZoneSlot",
		},
	},
	-- ===== Phase 3 (brief 12 contracts; tuning placeholders pending balance) =====
	Biome = {
		RingAttribute = "BiomeRing",
		ColdResistanceAttribute = "ColdResistance",
		MaxColdSeverity = 3,
		MaxRequiredColdResistance = 12,
		ResistanceDrainReductionPerPoint = 0.05,
		MinDrainFraction = 0.35,
		UnderdressedDrainPerPoint = 0.25,
		MaxUnderdressedMultiplier = 3,
		UpdateInterval = 1,
		OreSlotTag = "OreSlot",
		ThinIceWarmthPenalty = 25,
		Tuning = {
			MaxLootTier = 4,
			HearthBurnSeconds = 90,
			HearthMaxSeconds = 360,
			ThinIceCrackSeconds = 3,
			ThinIceDamage = 12,
			ThinIcePatchRadius = 7,
			ThinIcePatchCount = 3,
			LootPromptRange = 10,
		},
	},
	SiteGround = {
		MaxSlope = 0.35,
		MaxRange = 14,
		FillRange = 6,
		SampleStep = 8,
		SkirtWidth = 10,
		WaterHeight = -1.5,
		MaxWaterFraction = 0.1,
		CliffStep = 7,
		RaycastUp = 40,
		RaycastDown = 120,
		SinkMargin = 0.15,
		RelocateRadius = 60,
		RelocateAttempts = 10,
	},
	Map = {
		CellSize = 64, -- 2560 / 64 = 40 cells per side
		ExploreRadius = 96,
		ExploreTickSeconds = 1,
		MaxCellsPerPayload = 1600,
		ItemId = "Map",
		ButtonWidthPx = 64, -- Map button (client): >= 44 px touch target
		ButtonHeightPx = 44,
		ButtonScaleX = 0.985, -- same right edge as the Craft button
		ButtonScaleY = 0.02,
		ButtonOffsetYPx = 48, -- below the 40 px Craft button + gap; clear of Ping (y 0.4) on a phone
	},
	Structures = {
		DoorTag = "StructureDoor", -- CollectionService tag on placed doors
		WatchtowerTag = "Watchtower", -- CollectionService tag on placed watchtowers
		ChestIdAttribute = "ChestId", -- chest attribute: unique id string (also the Player OpenChest value)
		InteractRange = 10, -- studs: client interact pick (chest, door, cook, repair)
		ServerInteractRange = 14, -- studs: server re-check (covers latency)
		DoorOpenTransparency = 0.7,
		StructureTickSeconds = 0.5, -- one loop: chest range, traps, watchtowers
		TrapHeight = 4, -- studs above the trap that still count as stepping on it
		WatchtowerStandHeight = 6, -- studs: a player root within this far above the tower top counts as on it
		WatchtowerRevealSeconds = 1, -- seconds between map reveals while standing on a tower
		WatchtowerTrussWidth = 2, -- ladder (TrussPart) beside the tower
	},
	Forest = {
		Classes = {
			{
				Id = "Small",
				Weight = 30,
				Height = { 18, 24 }, -- >= Trees.MinTotalHeight
				TrunkRadius = { 0.6, 0.8 },
				CanopyRadius = { 3.5, 4.5 },
				MinSpacing = 4,
				Gatherable = true,
				WoodYield = 2,
			},
			{
				Id = "Medium",
				Weight = 45,
				Height = { 24, 34 },
				TrunkRadius = { 0.9, 1.2 },
				CanopyRadius = { 5, 6.5 },
				MinSpacing = 6,
				Gatherable = true,
				WoodYield = 3,
			},
			{
				Id = "Large",
				Weight = 20,
				Height = { 40, 55 },
				TrunkRadius = { 1.5, 2 },
				CanopyRadius = { 7.5, 9.5 },
				MinSpacing = 9,
				Gatherable = true,
				WoodYield = 5,
			},
			{
				Id = "Giant",
				Weight = 5,
				Height = GIANT_TREE_HEIGHT,
				TrunkRadius = { 3.2, 4.8 },
				CanopyRadius = { 13, 17 },
				MinSpacing = 16,
				Gatherable = true,
				WoodYield = 10,
			},
		},
		TreesPerChunk = 32, -- base slots per chunk (old World.TreesPerChunk = 12 was sparse); worst 5x5 window stays <= Perf.MaxLiveTrees
		RingDensity = { 1, 0.25, 0.25, 0.12 }, -- start forest dense; lake sparse; mountains some; tundra sparse
		CampBonusTrees = 90, -- extra trees in the camp chunk (concentrates the forest around spawn and camp)
		PoiClearRadius = 26, -- no trees this close to a POI centre
		SlotClearRadius = 4, -- no trees this close to a rock, ore, food or spawn-zone slot
		TrunkNodeMaxHeight = 14, -- gatherable trunk part height cap (keeps the node within Gather.Range)
		MaxPartsPerTree = 3, -- trunk (the gather node) + 2 foliage tiers; no per-leaf parts
		SpawnClearRadius = 10, -- no trees on the spawn pad
		FireClearRadius = 12, -- clearing around every campfire
		NearCampRadius = 54, -- = Fire.WarmRadius (tier 1)
		NearCampDensity = 2.5, -- thick right up to the small fire clearing
		CampEdgeRadius = 110, -- band from NearCampRadius out to here is the thick treeline
		CampEdgeDensity = 3,
		GiantMaxPerChunk = 3,
		PlacementAttempts = 8,
		TagAttribute = "TreeClass",
	},
	Terrain = {
		BlockSize = 4, -- = Roblox Terrain voxel size, so blocks map 1:1 to voxels
		HeightQuantum = 1,
		MaxStep = 4, -- hard cap between edge-adjacent blocks; World tests scan this over many seeds
		ColumnDepth = 12,
		BlendWidth = 120,
		LowWavelength = 160,
		HighWavelength = 64,
		LowShare = 0.7,
		Biomes = {
			SnowyForest = { Amplitude = 6, MaxStep = 4 }, -- gentle rolling start forest
			FrozenLake = { Amplitude = 1, MaxStep = 1 }, -- nearly flat
			MountainsCaves = { Amplitude = 36, MaxStep = 4 }, -- largest relief
			DeepTundra = { Amplitude = 12, MaxStep = 4 },
		},
		CampFlatRadius = 40,
		CampRampWidth = 80,
		BaseHeight = 0,
		FloorY = -80, -- columns extend down to here
		KillHeight = -120, -- below lowest possible terrain (-max amplitude) minus margin
		EdgeMargin = 48,
		EdgeWallHeight = 60,
		MaxBlocksPerChunkBuild = 1600,
		BuildBlocksPerTick = 400, -- 6400 blocks per chunk = 16 ticks instead of one hitch
		BuildMsPerTick = 3,
	},
	Massive = {
		Ids = {
			"ResearchStation",
			"MineComplex",
			"FrozenShipwreck",
			"RuinedTemple",
			"RangerLodge",
			"ExpandedRuins",
		},
		Structures = {
			ResearchStation = {
				Id = "ResearchStation",
				Name = "Research Station",
				MinFootprintX = 110,
				MinFootprintZ = 80,
				MinRooms = 10,
				MinLevels = 2,
				UndergroundDepth = 14,
				Rings = { 2, 3 },
				CountMin = 1,
				CountMax = 2,
				Budget = { Parts = 1000, DressingParts = 280, Lights = 28, Particles = 6 },
			},
			MineComplex = {
				Id = "MineComplex",
				Name = "Mine Complex",
				MinFootprintX = 120,
				MinFootprintZ = 90,
				MinRooms = 8,
				MinLevels = 3,
				UndergroundDepth = 36,
				Rings = { 2 },
				CountMin = 1,
				CountMax = 2,
				Budget = { Parts = 950, DressingParts = 240, Lights = 32, Particles = 5 },
			},
			FrozenShipwreck = {
				Id = "FrozenShipwreck",
				Name = "Frozen Shipwreck",
				MinFootprintX = 130,
				MinFootprintZ = 44,
				MinRooms = 6,
				MinLevels = 3,
				UndergroundDepth = 0,
				Rings = { 1 },
				CountMin = 1,
				CountMax = 2,
				Budget = { Parts = 900, DressingParts = 260, Lights = 20, Particles = 6 },
			},
			RuinedTemple = {
				Id = "RuinedTemple",
				Name = "Ruined Temple",
				MinFootprintX = 100,
				MinFootprintZ = 100,
				MinRooms = 9,
				MinLevels = 2,
				UndergroundDepth = 20,
				Rings = { 2, 3 },
				CountMin = 1,
				CountMax = 1,
				Budget = { Parts = 1000, DressingParts = 260, Lights = 26, Particles = 6 },
			},
			RangerLodge = {
				Id = "RangerLodge",
				Name = "Ranger Lodge",
				MinFootprintX = 70,
				MinFootprintZ = 56,
				MinRooms = 7,
				MinLevels = 2,
				UndergroundDepth = 8,
				Rings = { 0, 1 },
				CountMin = 1,
				CountMax = 2,
				Budget = { Parts = 700, DressingParts = 200, Lights = 24, Particles = 4 },
			},
			ExpandedRuins = {
				Id = "ExpandedRuins",
				Name = "Expanded Ruins",
				MinFootprintX = 120,
				MinFootprintZ = 120,
				MinRooms = 12,
				MinLevels = 2,
				UndergroundDepth = 16,
				Rings = { 1, 2, 3 },
				CountMin = 1,
				CountMax = 2,
				Budget = { Parts = 1000, DressingParts = 300, Lights = 30, Particles = 6 },
			},
		},
		CorridorWidthMin = 6,
		CeilingHeightMin = 10, -- character 5 studs + head room; > Shelter.CeilingHeight (9)
		DoorWidthMin = 5,
		DoorHeightMin = 8,
		StairWidthMin = 5,
		MaxLiveStructures = MASSIVE_MAX_LIVE_STRUCTURES,
		MinSeparation = 400,
		FootprintMargin = 10,
		DressingSpawnRadius = 90,
		DressingDespawnRadius = 130,
		DressingCheckInterval = 0.5,
		DressingPartsPerTick = 40,
		MaxLiveParts = MASSIVE_MAX_LIVE_PARTS,
		PlacementAttempts = 400,
		EdgeMargin = 40,
		PoiMargin = 20,
		MaxSiteRelief = 60,
		SiteSampleStep = 16,
		KillMargin = 20,
		ChestsPerPartAllowance = 6,
		MaxChestsPerStructure = 5, -- Config.Loot.Chests Massive.Max (Beacon 4); LivePartsTests uses it
		TempleDreadScale = 0.5,
	},
	Trees = {
		HeadHeight = 5.5,
		CanopyClearance = 2,
		MinCanopyBottom = 7.5, -- HeadHeight + CanopyClearance (tested)
		MinFoliageThickness = 6,
		MinTotalHeight = 18,
		SizeClasses = { "Small", "Medium", "Large", "Giant" },
		GiantHeightMin = GIANT_TREE_HEIGHT[1],
		GiantHeightMax = GIANT_TREE_HEIGHT[2],
	},
	Shadows = {
		GlobalShadows = true,
		TreesCastShadows = true,
		ShadowSoftness = 0.15, -- crisp, menacing shadow edges
		ForestFloorDarkness = 0.5,
		ForestFloorDarknessNight = 0.2,
		CanopyShadeRadiusFactor = 1.2,
		NightMinAmbient = { 40, 48, 72 },
		NightMinOutdoorAmbient = { 60, 70, 100 },
		NightMinBrightness = 0.6,
		MaxShadeDiscs = 120,
		CanopyShadowMinRadius = 5, -- Medium and bigger canopies cast; Small ones only their trunk
	},
}

return Sections
