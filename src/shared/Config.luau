--!strict

export type DebugConfig = {
	CommandRateInterval: number,
	MaxDay: number,
	MaxClockSpeed: number,
	RingCount: number,
	WorldDayAttribute: string,
	WorldClockSpeedAttribute: string,
	WorldBlizzardAttribute: string,
	WorldDarkEventAttribute: string,
	WorldStalkerAttribute: string,
	PlayerInvincibleAttribute: string,
	PlayerRingAttribute: string,
	DarkEvents: { string },
	BridgeName: string,
}

export type TimeConfig = {
	DayLengthSeconds: number,
	DayFraction: number,
	StartClockHour: number,
	BlizzardMinGap: number,
	BlizzardMaxGap: number,
	BlizzardWarningSeconds: number,
	DayAttribute: string,
	IsNightAttribute: string,
	ClockAttribute: string,
}

export type MeterConfig = {
	MaxHealth: number,
	MaxWarmth: number,
	MaxHunger: number,
	HungerDrainPerSecond: number,
	WarmthDrainPerSecond: number,
	WarmthDrainNightMultiplier: number,
	WarmthRegenPerSecond: number,
	StarveDamagePerSecond: number,
	FreezeDamagePerSecond: number,
	HealthRegenPerSecond: number,
	RegenMinHunger: number,
	RegenMinWarmth: number,
	TickInterval: number,
	ReplicateInterval: number,
	WarmthAttribute: string,
	HungerAttribute: string,
}

export type FireConfig = {
	WarmRadius: number,
	RepelRadius: number,
	BurnSeconds: number,
	MaxFuelSeconds: number,
	WoodFuelSeconds: number,
	AddFuelRange: number,
	MaxPerTeam: number,
	CookRadius: number,
	Tag: string,
	FuelAttribute: string,
	LitAttribute: string,
}

export type ScalingConfig = {
	MobBudgetPerDay: number,
	MobHealthPerDay: number,
	MobDamagePerDay: number,
	MobBudgetPerExtraPlayer: number,
	MaxMobHealthMultiplier: number,
	MaxMobDamageMultiplier: number,
	MaxMobBudgetMultiplier: number,
}

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

export type InventoryConfig = {
	HotbarSize: number,
	BackpackSize: number,
	MaxStack: number,
	DropPickupRange: number,
	SlotAttribute: string,
	StarterItems: { { id: string, count: number } },
}

export type ToolTierConfig = {
	Hand: number,
	Basic: number,
	Stone: number,
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

export type FoodConfig = {
	RawMeatHunger: number,
}

export type CraftConfig = {
	Range: number,
	WorkbenchRange: number,
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
}

export type MobStats = {
	Health: number,
	Damage: number,
	WalkSpeed: number,
	FleeSpeed: number,
	AggroRange: number,
	AttackRange: number,
	AttackCooldown: number,
	FleeRange: number,
	NightOnly: boolean,
	Weight: number,
	DropId: string?, -- item given to the killer (ItemCatalog id)
	DropCount: number,
}

export type MobConfig = {
	Budget: number,
	SpawnMinDistance: number,
	SpawnMaxDistance: number,
	DespawnDistance: number,
	AIActiveRadius: number,
	AITickInterval: number,
	SpawnInterval: number,
	NightBudgetMultiplier: number,
	Tag: string,
	FolderName: string,
	KindAttribute: string,
	HealthAttribute: string,
	WanderRadius: number,
	WanderInterval: number,
	FleeStep: number,
	RetreatStep: number,
	SpawnRayHeight: number,
	SpawnRayLength: number,
	SpawnLift: number,
	Hare: MobStats,
	Caribou: MobStats,
	Wolf: MobStats,
}

export type CombatConfig = {
	MeleeRange: number,
	MeleeCooldown: number,
	MeleeBaseDamage: number,
	SpearDamage: number,
	SpearRange: number,
	LagCompensation: number,
	WeaponDurabilityPerHit: number,
}

export type DownedConfig = {
	BleedoutSeconds: number,
	ReviveSeconds: number,
	ReviveRange: number,
	ReviveHealthFraction: number,
	DownedWalkSpeed: number,
	DisconnectHoldSeconds: number,
	StateAttribute: string,
}

export type NetConfig = {
	CraftRateInterval: number,
	PlaceRateInterval: number,
	GatherRateInterval: number,
	AttackRateInterval: number,
	UseRateInterval: number,
	SelectRateInterval: number,
}

export type Config = {
	Time: TimeConfig,
	Meters: MeterConfig,
	Fire: FireConfig,
	Scaling: ScalingConfig,
	World: WorldConfig,
	Inventory: InventoryConfig,
	ToolTier: ToolTierConfig,
	Gather: GatherConfig,
	Craft: CraftConfig,
	Food: FoodConfig,
	Build: BuildConfig,
	Mobs: MobConfig,
	Combat: CombatConfig,
	Downed: DownedConfig,
	Net: NetConfig,
	Debug: DebugConfig,
	RemoteFolderName: string,
	DefaultRateLimitInterval: number,
	ProfileStoreName: string,
	ProfileKeyPrefix: string,
	AutoSavePeriod: number,
	SchemaVersion: number,
	StartingCoins: number,
	MaxCoins: number,
	LoadFailKickMessage: string,
	SessionEndKickMessage: string,
	DebugForceLoadFailure: boolean,
	QAForceFailureAttribute: string,
	QAForceData: string,
	QAForceSpawn: string,
	DEBUG_DATA: boolean,
	DATA_LOAD_TIMEOUT: number,
	LoadFailKickDelay: number,
	ReadyAttribute: string,
	LoadFailedAttribute: string,
	SPAWN_LOAD_RETRIES: number,
	SPAWN_RETRY_DELAY: number,
	SPAWN_HUMANOID_WAIT: number,
	VOID_KILL_Y: number,
	VOID_CHECK_INTERVAL: number,
	WALK_SPEED: number,
	SpawnPointName: string,
}

local Config: Config = {
	-- Studio-only DebugService. Attributes live on Workspace (world state) or the Player.
	Debug = {
		CommandRateInterval = 0.2,
		MaxDay = 1000,
		MaxClockSpeed = 1000,
		RingCount = 4,
		WorldDayAttribute = "DebugDay",
		WorldClockSpeedAttribute = "DebugClockSpeed",
		WorldBlizzardAttribute = "DebugForceBlizzard",
		WorldDarkEventAttribute = "DebugForceDarkEvent",
		WorldStalkerAttribute = "DebugStalkerSummoned",
		PlayerInvincibleAttribute = "DebugInvincible",
		PlayerRingAttribute = "DebugTeleportRing",
		DarkEvents = { "FalseNight", "TheQuiet", "DeepFreeze" },
		BridgeName = "DebugBridge", -- Studio-only ServerStorage BindableFunction for tools/qa (another VM)
	},
	-- Time and day/night. Replicated via Workspace attributes below.
	Time = {
		DayLengthSeconds = 360, -- real seconds per in-game day (GDD: ~6 min)
		DayFraction = 0.6, -- share of the day that is daylight (rest is night)
		StartClockHour = 8, -- in-game hour (0-24) a run starts at
		BlizzardMinGap = 4, -- fewest days between blizzards
		BlizzardMaxGap = 5, -- most days between blizzards (randomized in range)
		BlizzardWarningSeconds = 45, -- warning period before a blizzard hits
		DayAttribute = "Day", -- Workspace attribute: current day number (starts at 1)
		IsNightAttribute = "IsNight", -- Workspace attribute: true at night
		ClockAttribute = "ClockHour", -- Workspace attribute: in-game hour 0-24
	},
	-- Survival meters. Drains are per second at base conditions.
	Meters = {
		MaxHealth = 100, -- health cap
		MaxWarmth = 100, -- warmth cap
		MaxHunger = 100, -- hunger cap (100 = full)
		HungerDrainPerSecond = 0.15, -- hunger lost per second
		WarmthDrainPerSecond = 0.5, -- warmth lost per second outside a fire radius
		WarmthDrainNightMultiplier = 1.6, -- warmth drain multiplier at night
		WarmthRegenPerSecond = 3, -- warmth gained per second inside a fire radius
		StarveDamagePerSecond = 1, -- health lost per second at 0 hunger
		FreezeDamagePerSecond = 1.5, -- health lost per second at 0 warmth
		HealthRegenPerSecond = 0.5, -- health regained per second when fed and warm
		RegenMinHunger = 50, -- hunger needed for health regen
		RegenMinWarmth = 50, -- warmth needed for health regen
		TickInterval = 0.5, -- server simulation step (seconds), one loop for all players
		ReplicateInterval = 0.5, -- min seconds between MetersUpdate sends per player
		WarmthAttribute = "Warmth", -- Player attribute: rounded warmth (health is on the Humanoid)
		HungerAttribute = "Hunger", -- Player attribute: rounded hunger
	},
	Fire = {
		WarmRadius = 18, -- studs where warmth regenerates
		RepelRadius = 22, -- studs where most hostiles are repelled (edge)
		BurnSeconds = 180, -- burn time from one fuel add
		MaxFuelSeconds = 600, -- cap on stored burn time
		WoodFuelSeconds = 120, -- burn time added per wood
		AddFuelRange = 10, -- max studs from player to fire to add fuel
		MaxPerTeam = 6, -- max active campfires per run
		CookRadius = 6, -- studs within which food can be cooked
		Tag = "Campfire", -- CollectionService tag
		FuelAttribute = "FuelSeconds", -- campfire attribute: replicated burn seconds left
		LitAttribute = "Lit", -- campfire attribute: replicated lit flag
	},
	Scaling = {
		MobBudgetPerDay = 0.05, -- fractional mob budget added per day survived
		MobHealthPerDay = 0.04, -- fractional mob health added per day
		MobDamagePerDay = 0.03, -- fractional mob damage added per day
		MobBudgetPerExtraPlayer = 0.35, -- fractional budget added per player beyond the first
		MaxMobHealthMultiplier = 4, -- cap on health scaling
		MaxMobDamageMultiplier = 3, -- cap on damage scaling
		MaxMobBudgetMultiplier = 3, -- cap on day scaling of the mob budget
	},
	World = {
		GridSize = 8, -- chunks per side (8x8 = 64)
		ChunkSize = 320, -- studs per chunk side (8 * 320 = 2560 studs square)
		DefaultSeed = 12345, -- seed when none is supplied (tests, Studio)
		StartForestRing = 1, -- ring index (0 = center) of the start forest, camp is in it
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
	Inventory = {
		HotbarSize = 6, -- hotbar slots (indices 1..HotbarSize)
		BackpackSize = 18, -- extra slots after the hotbar
		MaxStack = 50, -- default max items per stack
		DropPickupRange = 10, -- studs to pick up a dropped item
		SlotAttribute = "SelectedSlot", -- Player attribute: selected hotbar slot
		StarterItems = { { id = "Axe", count = 1 } }, -- given on join (trees need an axe; default, flagged)
	},
	ToolTier = {
		Hand = 0, -- no tool
		Basic = 1, -- wood tools (axe, pickaxe)
		Stone = 2, -- stone tools
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
		Range = 14, -- max studs from player to workbench for tier 1 recipes
		WorkbenchRange = 14, -- studs counted as "at a workbench"
		MaxTier = 1, -- highest workbench tier in Phase 1 (0 = by hand)
	},
	Food = {
		RawMeatHunger = 25, -- hunger restored by eating one Raw Meat (ItemCatalog food rows read this)
	},
	Build = {
		GridStep = 4, -- snap grid size in studs
		RotationStep = 90, -- rotation snaps to multiples of this many degrees
		PlaceRange = 30, -- max studs from player to placement point
		MinSpacing = 4, -- min studs between two structures (centers)
		MaxStructuresPerPlayer = 40, -- cap on placed structures
		GroundRayHeight = 20, -- ground raycast starts this far above the snapped point
		GroundRayLength = 60, -- ground raycast length (no ground hit = rejected)
		FolderName = "Structures", -- Workspace folder for placed structures
		StructureAttribute = "StructureId", -- structure attribute: ItemCatalog.Structures id
		OwnerAttribute = "OwnerUserId", -- structure attribute: placer's UserId
	},
	Mobs = {
		Budget = 12, -- base max live mobs near players (before scaling)
		SpawnMinDistance = 60, -- studs from every player at which mobs may spawn
		SpawnMaxDistance = 160, -- studs from a player beyond which no spawn
		DespawnDistance = 260, -- studs from all players beyond which a mob despawns
		AIActiveRadius = 200, -- AI runs only within this many studs of a player
		AITickInterval = 0.2, -- seconds between AI steps (one loop for all mobs)
		SpawnInterval = 3, -- seconds between spawn attempts
		NightBudgetMultiplier = 1.5, -- budget multiplier at night
		Tag = "Mob", -- CollectionService tag
		FolderName = "Mobs", -- Workspace folder for mob models
		KindAttribute = "MobKind", -- mob model attribute: kind name
		HealthAttribute = "MobHealth", -- mob model attribute: replicated health
		WanderRadius = 18, -- studs per wander step
		WanderInterval = 4, -- mean seconds between wander targets
		FleeStep = 24, -- studs per flee step
		RetreatStep = 20, -- studs per retreat step away from a fire
		SpawnRayHeight = 120, -- spawn ground raycast starts this far above the anchor
		SpawnRayLength = 300, -- spawn ground raycast length
		SpawnLift = 1, -- studs above ground a mob spawns
		Hare = {
			Health = 8, -- hit points
			Damage = 0, -- passive
			WalkSpeed = 8, -- wander speed
			FleeSpeed = 24, -- flee speed
			AggroRange = 0, -- never aggroes
			AttackRange = 0, -- no attack
			AttackCooldown = 0, -- no attack
			FleeRange = 30, -- flees when a player is closer than this
			NightOnly = false, -- active during the day
			Weight = 5, -- relative spawn weight
			DropId = "RawMeat", -- drop on kill
			DropCount = 1, -- drop amount
		},
		Caribou = {
			Health = 40, -- hit points
			Damage = 0, -- passive
			WalkSpeed = 10, -- wander speed
			FleeSpeed = 28, -- flee speed
			AggroRange = 0, -- never aggroes
			AttackRange = 0, -- no attack
			AttackCooldown = 0, -- no attack
			FleeRange = 40, -- flees when a player is closer than this
			NightOnly = false, -- active during the day
			Weight = 2, -- relative spawn weight
			DropId = "RawMeat", -- drop on kill
			DropCount = 3, -- drop amount
		},
		Wolf = {
			Health = 35, -- hit points
			Damage = 10, -- damage per bite
			WalkSpeed = 12, -- patrol speed
			FleeSpeed = 20, -- chase speed
			AggroRange = 50, -- studs at which it starts hunting
			AttackRange = 4, -- studs to bite
			AttackCooldown = 1.2, -- seconds between bites
			FleeRange = 0, -- does not flee (retreats only at fire edge)
			NightOnly = true, -- hunts at night
			Weight = 3, -- relative spawn weight
			DropId = "Hide", -- drop on kill
			DropCount = 1, -- drop amount
		},
	},
	Combat = {
		MeleeRange = 7, -- max studs player to target for a hit (server check, includes latency slack)
		MeleeCooldown = 0.5, -- seconds between swings
		MeleeBaseDamage = 4, -- fist / non-weapon damage (weapons use ItemCatalog damage)
		SpearDamage = 12, -- spear damage
		SpearRange = 9, -- spear reach in studs
		LagCompensation = 3, -- extra studs of tolerance for latency
		WeaponDurabilityPerHit = 1, -- durability lost per hit
	},
	Downed = {
		BleedoutSeconds = 60, -- time downed before death
		ReviveSeconds = 4, -- seconds of channel to revive a teammate
		ReviveRange = 8, -- max studs reviver to downed player
		ReviveHealthFraction = 0.3, -- fraction of max health restored on revive
		DownedWalkSpeed = 3, -- crawl speed while downed
		DisconnectHoldSeconds = 300, -- hold a disconnected player's character (5 min)
		StateAttribute = "Downed", -- Player attribute: true while downed
	},
	-- Minimum seconds between accepted requests per player, by remote (used with Guard).
	Net = {
		CraftRateInterval = 0.3, -- CraftRequest
		PlaceRateInterval = 0.5, -- PlaceRequest
		GatherRateInterval = 0.5, -- GatherRequest
		AttackRateInterval = 0.25, -- AttackRequest (single source; Combat.MeleeCooldown is the swing gate)
		UseRateInterval = 0.3, -- UseItemRequest, AddFuelRequest, ReviveRequest
		SelectRateInterval = 0.1, -- SelectSlotRequest
	},
	RemoteFolderName = "Remotes",
	DefaultRateLimitInterval = 0.1,
	ProfileStoreName = "PlayerProfiles",
	ProfileKeyPrefix = "Player_",
	AutoSavePeriod = 60,
	SchemaVersion = 1,
	StartingCoins = 0,
	MaxCoins = 1e15,
	LoadFailKickMessage = "Your data could not be loaded. Please rejoin in a moment.",
	SessionEndKickMessage = "Your session ended because you joined another server.",
	-- Studio-only test switch: simulates a failed profile load.
	DebugForceLoadFailure = false,
	-- Studio-only QA hook: set this ReplicatedStorage attribute to QAForceData (profile load fails) or
	-- QAForceSpawn (every LoadCharacterAsync attempt fails). Ignored outside Studio.
	QAForceFailureAttribute = "QAForceLoadFailure",
	QAForceData = "data",
	QAForceSpawn = "spawn",
	-- Verbose [Data] logging in DataService.
	DEBUG_DATA = true,
	-- Hard cap (seconds) on loading one player's profile before they are kicked.
	DATA_LOAD_TIMEOUT = 30,
	-- Seconds to let LoadFailed replicate before the kick.
	LoadFailKickDelay = 1,
	-- Player Attributes read by the client: true once the character is placed / if loading failed.
	ReadyAttribute = "Ready",
	LoadFailedAttribute = "LoadFailed",
	SPAWN_LOAD_RETRIES = 2,
	SPAWN_RETRY_DELAY = 1,
	SPAWN_HUMANOID_WAIT = 5,
	VOID_KILL_Y = -200,
	VOID_CHECK_INTERVAL = 0.5,
	WALK_SPEED = 16,
	SpawnPointName = "SpawnPoint",
}

return Config
