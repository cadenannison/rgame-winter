--!strict
-- Config module: Items. Items and crafting: inventory, tools, gathering, crafting, building, storage, item/equipment stats, repair, cooking, ping.
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

export type InventoryConfig = {
	HotbarSize: number,
	BackpackSize: number,
	MaxStack: number,
	DropPickupRange: number,
	SlotAttribute: string,
	StarterItems: { { id: string, count: number } },
	Columns: number, -- grid columns of the backpack panel (BackpackSize / Columns rows)
	SplitHoldSeconds: number, -- long-press time on touch that splits a stack in half
	FullHintSeconds: number, -- how long the "Inventory full" hint shows
}

export type ToolTierConfig = {
	Hand: number,
	Basic: number,
	Stone: number,
	Metal: number, -- Phase 3: forge tools
}

export type GatherConfig = {
	Range: number,
	Cooldown: number,
	RespawnSeconds: number,
	TreeTier: number,
	RockTier: number,
	TreeYield: number,
	RockYield: number,
	HitsToDeplete: number,
	ToolDurabilityPerUse: number,
	NodeTag: string,
}

-- A crafting station: tagged instances within Range studs of the player unlock recipes with this station.
export type CraftStation = {
	Tag: string,
	Range: number,
	Label: string, -- player-facing name ("workbench")
}

export type CraftConfig = {
	Stations: { [string]: CraftStation },
	MaxTier: number,
}

export type BuildConfig = {
	GridStep: number,
	RotationStep: number,
	PlaceRange: number,
	MinSpacing: number,
	MaxStructuresPerPlayer: number,
	GroundRayHeight: number,
	GroundRayLength: number,
	FolderName: string,
	StructureAttribute: string,
	OwnerAttribute: string,
	RangeExempt: { [string]: boolean }, -- structure ids placeable anywhere (no lit-fire build radius)
	Ghost: GhostConfig,
	-- Phase 3 structure names (set by brief 17; read by 15/16)
	HealthAttribute: string, -- structure attribute: current health (breakable structures)
	BlockerTag: string, -- tag on walls and closed doors (mob pathing treats them as solid)
	TrapTag: string, -- tag on spike traps (damages mobs only)
	StorageTag: string, -- tag on storage chests
	DoorOpenAttribute: string, -- door attribute: true while open
}

-- Client-only placement preview (transparent copy of the structure on the ground). Visual only.
export type GhostConfig = {
	Name: string,
	PickRange: number, -- studs: max cursor/screen-centre ray length to the ground
	Transparency: number,
	ValidColor: { number }, -- {r, g, b} 0-255
	InvalidColor: { number },
	RotateKeyName: string, -- Enum.KeyCode member name
	RotateButtonSize: number, -- px, mobile rotate button (>= 44)
	RotateButtonOffsetPx: number, -- px left of the right screen edge (sits beside the Act button)
	LabelOffsetY: number, -- studs above the ghost top for the reason label
	LabelWidthPx: number,
	LabelHeightPx: number,
	UpdateInterval: number, -- seconds between ghost refreshes
	ReasonText: { [string]: string }, -- validator reason code -> player text
}

export type StorageConfig = {
	ChestSlots: number, -- slots per player-placed storage chest (shared by the party)
	OpenRange: number, -- studs: prompt + server re-check range
	MaxChestsPerRun: number, -- legacy run-wide cap (kept for old code; MaxPerPlayer is the live rule)
	OpenAttribute: string, -- Player attribute: chest the player has open (structure id string, "" = none)
	-- Items round
	CraftWood: number, -- wood to craft one storage chest
	CraftStation: string, -- Config.Craft.Stations key
	CraftStationTier: number, -- workbench tier needed
	MaxPerPlayer: number, -- storage chests one player may have placed at once
	RevisionAttribute: string, -- chest attribute: revision counter (Number), bumped on every change
	MoveRateInterval: number, -- Guard interval for the inventory move remote
}

-- Items round: single source of truth for stack size, category, equip slot and cold resistance.
-- ItemCatalog stamps maxStack / category / equipSlot / coldResistance onto every item from here.
export type ItemEntry = {
	category: string?, -- Items.Categories key (nil = derive from the catalog kind)
	stack: number?, -- nil = category default
	equipSlot: string?, -- Equipment.Slots entry the item may be worn in
	coldResistance: number?, -- points while equipped (counts toward the HUD x/12 total)
}

export type ItemsConfig = {
	CategoryStack: { [string]: number }, -- default stack size per category
	KindCategory: { [string]: string }, -- ItemDef.kind -> category fallback
	Entries: { [string]: ItemEntry }, -- per item id
	FallbackStack: number, -- unknown category
	MaxStack: number, -- absolute cap any stack may reach (validation)
}

export type EquipmentConfig = {
	Slots: { string }, -- slot ids in panel order
	SlotLabels: { [string]: string },
	ProfileKey: string, -- profile.equipment (string-key map slot -> item id)
	ShakeSeconds: number, -- client: wrong-slot shake duration
	ViewportRotateSpeed: number, -- degrees per second of the preview clone
}

export type PingConfig = {
	Kinds: { string },
	MaxRange: number, -- studs from the pinger
	LifetimeSeconds: number,
	MaxActivePerPlayer: number,
}

export type RepairConfig = {
	Station: string, -- Config.Craft.Stations key
	CostFraction: number, -- fraction of the item's recipe inputs (rounded up)
	MinCost: number,
}

export type CookingConfig = {
	StationRange: number, -- campfire cooking uses Fire.CookRadius
	Station: string, -- Config.Craft.Stations key for the cooking station
	StationBuffMultiplier: number, -- buff duration multiplier when cooked at the station
	MaxStationBuffMultiplier: number,
}

-- Forage, nodes and relics (placed lazily near players by server/Forage/ForageService; placeholder visuals).
-- Rings are biome ring indices 0..3 (0 start forest, 1 frozen lake, 2 mountains, 3 deep tundra).
export type ForageKind = {
	itemId: string,
	name: string,
	verb: string, -- prompt verb ("Pick")
	minRing: number,
	maxRing: number,
	weight: number, -- relative pick weight among kinds valid at the spot
	minCount: number, -- items per pick (1-3 parts each)
	maxCount: number,
	color: { number }, -- {r, g, b} 0-255, chosen to read on snow
	size: { number }, -- {x, y, z} studs (one Part)
	material: string, -- Enum.Material member name
}

export type ForageNodeKind = {
	itemId: string,
	name: string,
	verb: string,
	minRing: number,
	maxRing: number,
	weight: number,
	toolType: string, -- "pickaxe" | "axe"
	minTier: number, -- Config.ToolTier value the selected tool must reach
	minCount: number,
	maxCount: number,
	color: { number },
	size: { number },
	material: string,
}

export type ForageConfig = {
	Enabled: boolean,
	CellSize: number, -- studs: placement grid (one deterministic roll set per cell)
	SpawnRadius: number, -- studs around a player in which cells are populated
	DespawnRadius: number, -- cells farther than this from every player are released to the pool
	UpdateInterval: number, -- seconds between population passes (one loop for all players)
	MaxSpawnsPerPass: number, -- instances created per pass (smooths the cost)
	MaxLiveParts: number, -- hard cap on live forage/node/relic parts
	PartHeadroom: number, -- keep ChunkService parts + forage below Perf.MaxLiveParts - this
	ForagePerCellMax: number, -- forage roll slots per cell
	ForageChance: number, -- chance each slot yields a pickup (0..1)
	NodeChance: number, -- chance a cell holds a resource node (0..1)
	EdgeMargin: number, -- studs from the world edge where nothing spawns
	SiteMargin: number, -- extra studs around a structure site radius kept clear
	AvoidTags: { string }, -- CollectionService tags whose instances keep AvoidRadius clear
	AvoidRadius: number,
	GroundHalfSize: number, -- studs: SiteGround footprint half size sampled under each pickup
	GroundLift: number, -- studs a pickup floats above the ground
	NodeTag: string, -- extra tag on every forage instance (Config.Gather.NodeTag is also applied)
	KindAttribute: string, -- instance attribute: forage class ("forage" | "node" | "relic")
	CountAttribute: string, -- instance attribute: items this pick gives
	Forage: { ForageKind },
	Nodes: { ForageNodeKind },
	Relic: {
		itemId: string,
		name: string,
		minRing: number, -- structure sites in rings below this get none
		minPerSite: number,
		maxPerSite: number,
		RadiusMin: number, -- x site radius (>= 1 keeps relics outside the footprint)
		RadiusMax: number,
		color: { number },
		size: { number },
		material: string,
		minCount: number,
		maxCount: number,
	},
	CoinValues: { [string]: number }, -- coin credit per item picked up (claimed at run end via ForageService)
}

export type Sections = {
	Forage: ForageConfig,
	Inventory: InventoryConfig,
	ToolTier: ToolTierConfig,
	Gather: GatherConfig,
	Craft: CraftConfig,
	Build: BuildConfig,
	Storage: StorageConfig,
	Items: ItemsConfig,
	Equipment: EquipmentConfig,
	Ping: PingConfig,
	Repair: RepairConfig,
	Cooking: CookingConfig,
}

local Sections: Sections = {
	Forage = {
		Enabled = true,
		CellSize = 48,
		SpawnRadius = 150,
		DespawnRadius = 210,
		UpdateInterval = 1.5,
		MaxSpawnsPerPass = 24,
		MaxLiveParts = 240,
		PartHeadroom = 400,
		ForagePerCellMax = 2,
		ForageChance = 0.45,
		NodeChance = 0.07,
		EdgeMargin = 24,
		SiteMargin = 10,
		AvoidTags = { "LootChest", "Campfire", "StorageChest", "StructureBlocker", "Workbench" },
		AvoidRadius = 8,
		GroundHalfSize = 1.5,
		GroundLift = 0.2,
		NodeTag = "ForagePickup",
		KindAttribute = "ForageClass",
		CountAttribute = "ForageCount",
		Forage = {
			{
				itemId = "Stick",
				name = "Stick",
				verb = "Pick up",
				minRing = 0,
				maxRing = 3,
				weight = 5,
				minCount = 1,
				maxCount = 3,
				color = { 120, 80, 40 },
				size = { 2.4, 0.4, 0.5 },
				material = "Wood",
			},
			{
				itemId = "Pinecone",
				name = "Pinecone",
				verb = "Pick up",
				minRing = 0,
				maxRing = 1,
				weight = 3,
				minCount = 1,
				maxCount = 3,
				color = { 95, 60, 35 },
				size = { 0.9, 1.1, 0.9 },
				material = "Wood",
			},
			{
				itemId = "Winterberry",
				name = "Winterberries",
				verb = "Pick",
				minRing = 0,
				maxRing = 2,
				weight = 3,
				minCount = 1,
				maxCount = 3,
				color = { 200, 40, 60 },
				size = { 1.1, 1, 1.1 },
				material = "SmoothPlastic",
			},
			{
				itemId = "FrostMushroom",
				name = "Frost Mushroom",
				verb = "Pick",
				minRing = 1,
				maxRing = 3,
				weight = 2,
				minCount = 1,
				maxCount = 2,
				color = { 110, 140, 230 },
				size = { 1, 1.2, 1 },
				material = "SmoothPlastic",
			},
			{
				itemId = "IceShard",
				name = "Ice Shards",
				verb = "Pick up",
				minRing = 1,
				maxRing = 3,
				weight = 2,
				minCount = 1,
				maxCount = 2,
				color = { 90, 215, 235 },
				size = { 0.8, 1.8, 0.8 },
				material = "Ice",
			},
			{
				itemId = "FrozenReed",
				name = "Frozen Reeds",
				verb = "Pick",
				minRing = 1,
				maxRing = 3,
				weight = 3,
				minCount = 1,
				maxCount = 3,
				color = { 190, 170, 110 },
				size = { 0.5, 2.6, 0.5 },
				material = "Grass",
			},
		},
		Nodes = {
			{
				itemId = "Coal",
				name = "Coal Seam",
				verb = "Mine",
				minRing = 1,
				maxRing = 3,
				weight = 4,
				toolType = "pickaxe",
				minTier = 1,
				minCount = 2,
				maxCount = 4,
				color = { 35, 35, 40 },
				size = { 4, 3, 4 },
				material = "Slate",
			},
			{
				itemId = "IceBlock",
				name = "Ice Block",
				verb = "Chip",
				minRing = 1,
				maxRing = 3,
				weight = 3,
				toolType = "pickaxe",
				minTier = 1,
				minCount = 1,
				maxCount = 3,
				color = { 150, 225, 245 },
				size = { 4, 3.5, 4 },
				material = "Ice",
			},
			{
				itemId = "ScrapMetal",
				name = "Scrap Pile",
				verb = "Salvage",
				minRing = 2,
				maxRing = 3,
				weight = 3,
				toolType = "pickaxe",
				minTier = 2,
				minCount = 1,
				maxCount = 3,
				color = { 130, 100, 80 },
				size = { 3.5, 2, 3.5 },
				material = "CorrodedMetal",
			},
			{
				itemId = "Bone",
				name = "Bone Pile",
				verb = "Dig",
				minRing = 0,
				maxRing = 3,
				weight = 3,
				toolType = "axe",
				minTier = 1,
				minCount = 1,
				maxCount = 3,
				color = { 225, 220, 205 },
				size = { 3, 1.5, 3 },
				material = "Concrete",
			},
			{
				itemId = "Crystal",
				name = "Crystal Cluster",
				verb = "Mine",
				minRing = 3,
				maxRing = 3,
				weight = 1,
				toolType = "pickaxe",
				minTier = 3,
				minCount = 1,
				maxCount = 2,
				color = { 170, 110, 240 },
				size = { 3, 4.5, 3 },
				material = "Glass",
			},
		},
		Relic = {
			itemId = "RelicFragment",
			name = "Relic Fragment",
			minRing = 1,
			minPerSite = 1,
			maxPerSite = 2,
			RadiusMin = 1.15,
			RadiusMax = 1.6,
			color = { 235, 190, 80 },
			size = { 1.4, 0.6, 1.4 },
			material = "Metal",
			minCount = 1,
			maxCount = 1,
		},
		CoinValues = {
			Coal = 1,
			IceBlock = 1,
			Bone = 1,
			ScrapMetal = 2,
			Crystal = 8,
			RelicFragment = 5,
		},
	},
	Inventory = {
		HotbarSize = 9, -- hotbar slots (indices 1..HotbarSize), keys 1-9
		BackpackSize = 27, -- extra slots after the hotbar (3 rows of 9)
		MaxStack = 20, -- fallback max items per stack (Config.Items is the real source)
		DropPickupRange = 10, -- studs to pick up a dropped item
		SlotAttribute = "SelectedSlot", -- Player attribute: selected hotbar slot
		StarterItems = { { id = "Axe", count = 1 } }, -- given on join (trees need an axe; default, flagged)
		Columns = 9,
		SplitHoldSeconds = 0.45,
		FullHintSeconds = 2.5,
	},
	ToolTier = {
		Hand = 0, -- no tool
		Basic = 1, -- wood tools (axe, pickaxe)
		Stone = 2, -- stone tools
		Metal = 3, -- iron tools (forge)
	},
	Gather = {
		Range = 12, -- max studs from player to node
		Cooldown = 0.6, -- seconds between gather hits per player
		RespawnSeconds = 240, -- slow node respawn
		TreeTier = 1, -- min tool tier for trees (axe)
		RockTier = 1, -- min tool tier for rocks (pickaxe)
		TreeYield = 3, -- wood per full gather
		RockYield = 2, -- stone per full gather
		HitsToDeplete = 4, -- hits before a node is depleted
		ToolDurabilityPerUse = 1, -- durability lost per gather hit
		NodeTag = "ResourceNode", -- CollectionService tag
	},
	Craft = {
		-- Recipes with a station field unlock only within Range studs of a tagged station (server checks at craft).
		Stations = {
			workbench = { Tag = "Workbench", Range = 14, Label = "workbench" },
			forge = { Tag = "Forge", Range = 14, Label = "forge" }, -- Phase 3 tier 2
			cookingStation = { Tag = "CookingStation", Range = 12, Label = "cooking station" },
			mapTable = { Tag = "MapTable", Range = 12, Label = "map table" },
		},
		MaxTier = 2, -- highest recipe tier listed in the panel (0 = by hand, 2 = forge)
	},
	Build = {
		GridStep = 4, -- snap grid size in studs
		RotationStep = 90, -- rotation snaps to multiples of this many degrees
		PlaceRange = 30, -- max studs from player to placement point
		MinSpacing = 4, -- min studs between two structures (centers)
		MaxStructuresPerPlayer = 40, -- cap on placed structures
		GroundRayHeight = 40, -- ground raycast starts this far above the player (covers 45-degree slopes within PlaceRange)
		GroundRayLength = 100, -- ground raycast length (no ground hit = rejected)
		FolderName = "Structures", -- Workspace folder for placed structures
		StructureAttribute = "StructureId", -- structure attribute: ItemCatalog.Structures id
		OwnerAttribute = "OwnerUserId", -- structure attribute: placer's UserId
		-- Exempt from the lit-fire build radius: extra campfires start a new camp, sleeping bags are for travel.
		RangeExempt = { Campfire = true, SleepingBag = true },
		HealthAttribute = "StructureHealth",
		BlockerTag = "StructureBlocker",
		TrapTag = "SpikeTrap",
		StorageTag = "StorageChest",
		DoorOpenAttribute = "DoorOpen",
		Ghost = {
			Name = "PlacementGhost",
			PickRange = 80,
			Transparency = 0.55,
			ValidColor = { 90, 220, 110 },
			InvalidColor = { 230, 70, 60 },
			RotateKeyName = "R",
			RotateButtonSize = 56,
			RotateButtonOffsetPx = 150,
			LabelOffsetY = 3,
			LabelWidthPx = 200,
			LabelHeightPx = 26,
			UpdateInterval = 0.05,
			ReasonText = {
				OutOfRange = "Too far away",
				OutOfBuildRange = "Too far from the fire",
				TooClose = "Blocked",
				StructureCap = "Too many structures",
				FireCap = "Too many campfires",
				MissingItem = "You do not have that item",
				BadPosition = "Cannot place there",
				UnknownStructure = "Cannot place that",
			},
		},
	},
	Storage = {
		ChestSlots = 9,
		OpenRange = 10,
		MaxChestsPerRun = 4,
		OpenAttribute = "OpenChest",
		CraftWood = 8,
		CraftStation = "workbench",
		CraftStationTier = 1,
		MaxPerPlayer = 4,
		RevisionAttribute = "StorageRevision",
		MoveRateInterval = 0.08,
	},
	Items = {
		CategoryStack = {
			material = 20, -- wood, stone, coal, plant fibre, scrap metal, iron
			animalPart = 10, -- hide, bone
			rareMaterial = 10, -- crystals, ice shards, boss materials
			berries = 20,
			meat = 10, -- raw and cooked meat/fish
			stew = 5, -- stews and soups
			medical = 5, -- bandages, warming tonics
			torch = 10,
			ammo = 30,
			tool = 1,
			weapon = 1,
			clothing = 1,
			placeable = 1,
			key = 1,
			light = 1,
		},
		KindCategory = {
			resource = "material",
			tool = "tool",
			weapon = "weapon",
			placeable = "placeable",
			clothing = "clothing",
			ammo = "ammo",
			light = "light",
			map = "key",
			food = "meat",
		},
		Entries = {
			Hide = { category = "animalPart" },
			Bone = { category = "animalPart" },
			Crystal = { category = "rareMaterial" },
			IceShard = { category = "rareMaterial" },
			RelicFragment = { category = "rareMaterial" },
			Pinecone = { category = "berries" },
			Winterberry = { category = "berries" },
			FrostMushroom = { category = "berries" },
			FrostShard = { category = "rareMaterial" },
			ColossusHeart = { category = "rareMaterial" },
			MatriarchFang = { category = "rareMaterial" },
			WardenCore = { category = "rareMaterial" },
			WhiteoutPelt = { category = "rareMaterial" },
			RawMeat = { category = "meat" },
			CookedMeat = { category = "meat" },
			RawFish = { category = "meat" },
			CookedFish = { category = "meat" },
			Stew = { category = "stew" },
			Torch = { category = "torch" },
			Flare = { category = "light", stack = 5 },
			Wall = { category = "placeable", stack = 10 },
			HideHood = { equipSlot = "Head", coldResistance = 1 },
			HideCoat = { equipSlot = "Body", coldResistance = 1 },
			HideBoots = { equipSlot = "Feet", coldResistance = 1 },
			FurHood = { equipSlot = "Head", coldResistance = 2 },
			FurCoat = { equipSlot = "Body", coldResistance = 2 },
			FurBoots = { equipSlot = "Feet", coldResistance = 2 },
			ArcticHood = { equipSlot = "Head", coldResistance = 4 },
			ArcticCoat = { equipSlot = "Body", coldResistance = 4 },
			ArcticBoots = { equipSlot = "Feet", coldResistance = 4 },
		},
		FallbackStack = 20,
		MaxStack = 50,
	},
	Equipment = {
		Slots = { "Head", "Body", "Legs", "Feet", "Hands", "Neck", "Accessory1", "Accessory2" },
		SlotLabels = {
			Head = "Head",
			Body = "Body",
			Legs = "Legs",
			Feet = "Feet",
			Hands = "Hands",
			Neck = "Neck",
			Accessory1 = "Acc 1",
			Accessory2 = "Acc 2",
		},
		ProfileKey = "equipment",
		ShakeSeconds = 0.35,
		ViewportRotateSpeed = 24,
	},
	Ping = {
		Kinds = { "Go", "Danger", "Loot", "Help" },
		MaxRange = 400,
		LifetimeSeconds = 8,
		MaxActivePerPlayer = 3,
	},
	Repair = {
		Station = "workbench",
		CostFraction = 0.5,
		MinCost = 1,
	},
	Cooking = {
		StationRange = 12,
		Station = "cookingStation",
		StationBuffMultiplier = 1.5,
		MaxStationBuffMultiplier = 2,
	},
}

return Sections
