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
	ClientBridgeName: string,
	GiveCount: number,
	MobKinds: { string },
	SpawnMobDistance: number,
	SpawnMobDrop: number,
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

export type FireCost = { { id: string, count: number } }

-- One campfire tier (index = tier). UpgradeCost is what it costs to reach this tier from the one below.
export type FireTier = {
	WarmRadius: number, -- studs where warmth regenerates and wolves are repelled
	MaxFuelSeconds: number, -- burn-time cap
	WoodFuelSeconds: number, -- burn time added per wood
	BuildRadius: number, -- studs around the fire where structures may be placed
	LightRange: number, -- studs of PointLight range
	UpgradeCost: FireCost,
}

-- Client-only radius ring (soft dots on the ground). Visual only.
export type FireRingConfig = {
	FolderName: string,
	DotDiameter: number,
	DotThickness: number,
	Spacing: number, -- studs between dots along the circle
	MinDots: number,
	MaxDotsPerLayer: number,
	MaxDotsTotal: number, -- cap across every ring (mobile)
	FadeStart: number, -- studs from the player to a dot where fading begins
	FadeEnd: number, -- studs from the player to a dot where it is invisible
	WarmTransparencyDay: number,
	WarmTransparencyNight: number,
	BuildTransparencyDay: number,
	BuildTransparencyNight: number,
	WarmColor: { number }, -- {r, g, b} 0-255
	BuildColor: { number },
	GroundLift: number, -- studs above the ground hit
	RayHeight: number,
	RayLength: number,
	RaysPerStep: number,
	UpdateInterval: number,
	AllocateInterval: number,
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
	TierAttribute: string,
	WarmRadiusAttribute: string,
	BuildRadiusAttribute: string,
	LightRangeAttribute: string,
	UpgradeRange: number,
	UpgradeRateInterval: number,
	Tiers: { FireTier },
	Ring: FireRingConfig,
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
	FleeBurstSeconds: number, -- flee runs in bursts of this length...
	FleeRestSeconds: number, -- ...separated by pauses of this length (0 = no pauses)
	HitRadius: number, -- extra melee reach for this mob (body size + generosity)
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
	DeathRemoveDelay: number,
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
	ToolDamage: number,
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

-- Size {x, y, z} studs and Color {r, g, b} 0-255 as plain numbers (Config is also loaded by Lune tests).
export type HeldVisual = { Size: { number }, Color: { number }, GripOffset: number }

-- Held item visuals (server builds a Tool in the character hand for the selected slot).
export type HeldConfig = {
	ToolName: string,
	Default: HeldVisual,
	Visuals: { [string]: HeldVisual },
}

-- Client feedback for actions (swing, hit, prompts). Visual only; never gameplay.
export type FeedbackConfig = {
	SwingSeconds: number,
	SwingAngle: number,
	SoundVolume: number,
	HitParticleCount: number,
	HitParticleColor: { number }, -- {r, g, b} 0-255
	HitParticleSpeed: number,
	HitParticleLifetime: number,
	FlashSeconds: number,
	FlashColor: { number }, -- {r, g, b} 0-255
	PromptRange: number,
	AimSlack: number,
	PromptOffsetY: number,
	ItemNameSeconds: number,
}

-- Night danger: wolf attack telegraph, dawn exit, bite feedback, campfire light. Owned by the night-danger work.
export type NightConfig = {
	WindupSeconds: number, -- wolf growl/telegraph before a bite lands
	StrikeLeeway: number, -- studs beyond AttackRange a target may stand when the bite lands (dodge margin)
	RepelMargin: number, -- studs added to a fire's WarmRadius for the wolf repel edge (wolves never enter WarmRadius)
	DawnLeaveSeconds: number, -- seconds a wolf runs off at dawn before it despawns
	WindupAttribute: string, -- mob model attribute: true during the growl windup (client plays sound/tint)
	BiteAttribute: string, -- Player attribute: counter bumped on every mob bite (client flash + sound)
	FlashColor: { number }, -- {r, g, b} 0-255 screen flash on a bite
	FlashTransparency: number, -- starting transparency of the bite flash
	FlashSeconds: number, -- fade-out length of the bite flash
	TelegraphColor: { number }, -- {r, g, b} wolf tint during windup (client only)
	WarmRadiusAttribute: string, -- fire attribute: warm radius studs (owned by the fire code; Fire.WarmRadius if absent)
	FireLightRange: number, -- fallback warm light range = WarmRadius * this (clamped to FireLightMaxRange)
	FireLightMaxRange: number, -- Roblox PointLight range cap
	FireLightBrightness: number,
	FireLightColor: { number }, -- {r, g, b} 0-255
	FireLightName: string, -- name of the client-made PointLight
	CueVolume: number, -- dusk/dawn cue volume
}

export type LightingConfig = {
	TwilightPhase: number, -- share of a day that dusk (before night) and dawn (before day) ramp over
	UpdateInterval: number, -- seconds between Lighting writes
	DayClockTime: number,
	NightClockTime: number,
	DayAmbient: { number }, -- {r, g, b} 0-255
	NightAmbient: { number },
	DayOutdoorAmbient: { number },
	NightOutdoorAmbient: { number },
	DayBrightness: number,
	NightBrightness: number,
	DayFogColor: { number },
	NightFogColor: { number },
	DayFogStart: number,
	NightFogStart: number,
	DayFogEnd: number,
	NightFogEnd: number,
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
	Night: NightConfig,
	Lighting: LightingConfig,
	Combat: CombatConfig,
	Downed: DownedConfig,
	Net: NetConfig,
	Held: HeldConfig,
	Feedback: FeedbackConfig,
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
		ClientBridgeName = "ClientQABridge", -- Studio-only PlayerScripts BindableFunction: real client input handlers
		GiveCount = 10, -- items granted by the Studio-only "give" command
		MobKinds = { "ArcticHare", "Caribou", "Wolf" }, -- valid "spawnMob" args (MobService kind names)
		SpawnMobDistance = 10, -- studs in front of the player a "spawnMob" mob appears
		SpawnMobDrop = 3, -- studs below the player root used as the spawn ground height
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
		TierAttribute = "Tier", -- campfire attribute: current tier (1-based)
		WarmRadiusAttribute = "WarmRadius", -- campfire attribute: warm radius studs (follows tier)
		BuildRadiusAttribute = "BuildRadius", -- campfire attribute: build radius studs (follows tier)
		LightRangeAttribute = "LightRange", -- campfire attribute: light range studs (follows tier)
		UpgradeRange = 10, -- max studs from player to fire to upgrade it
		UpgradeRateInterval = 0.5, -- UpgradeFireRequest rate limit (seconds)
		-- Tier 1 equals the base WarmRadius/MaxFuelSeconds/WoodFuelSeconds above (tested). Index = tier.
		Tiers = {
			{
				WarmRadius = 18,
				MaxFuelSeconds = 600,
				WoodFuelSeconds = 120,
				BuildRadius = 30,
				LightRange = 24,
				UpgradeCost = {},
			},
			{
				WarmRadius = 26,
				MaxFuelSeconds = 900,
				WoodFuelSeconds = 150,
				BuildRadius = 45,
				LightRange = 34,
				UpgradeCost = { { id = "Wood", count = 15 }, { id = "Stone", count = 6 } },
			},
			{
				WarmRadius = 34,
				MaxFuelSeconds = 1200,
				WoodFuelSeconds = 180,
				BuildRadius = 60,
				LightRange = 44,
				UpgradeCost = { { id = "Wood", count = 30 }, { id = "Stone", count = 12 } },
			},
		},
		Ring = {
			FolderName = "FireRings", -- client-local folder under Workspace
			DotDiameter = 0.7,
			DotThickness = 0.1,
			Spacing = 3.4,
			MinDots = 16,
			MaxDotsPerLayer = 56,
			MaxDotsTotal = 110,
			FadeStart = 12,
			FadeEnd = 38,
			WarmTransparencyDay = 0.84,
			WarmTransparencyNight = 0.66,
			BuildTransparencyDay = 0.72,
			BuildTransparencyNight = 0.55,
			WarmColor = { 255, 190, 110 },
			BuildColor = { 150, 205, 255 },
			GroundLift = 0.12,
			RayHeight = 40,
			RayLength = 120,
			RaysPerStep = 24,
			UpdateInterval = 0.1,
			AllocateInterval = 0.5,
		},
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
		HotbarSize = 9, -- hotbar slots (indices 1..HotbarSize), keys 1-9
		BackpackSize = 15, -- extra slots after the hotbar
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
		-- Recipes with a station field unlock only within Range studs of a tagged station (server checks at craft).
		Stations = {
			workbench = { Tag = "Workbench", Range = 14, Label = "workbench" },
		},
		MaxTier = 1, -- highest recipe tier listed in the panel (0 = by hand)
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
		-- Exempt from the lit-fire build radius: extra campfires start a new camp, sleeping bags are for travel.
		RangeExempt = { Campfire = true, SleepingBag = true },
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
		DeathRemoveDelay = 0.4, -- seconds a killed mob stays (unattackable) so clients see the hit confirm
		SpawnRayHeight = 120, -- spawn ground raycast starts this far above the anchor
		SpawnRayLength = 300, -- spawn ground raycast length
		SpawnLift = 1, -- studs above ground a mob spawns
		Hare = {
			Health = 8, -- hit points
			Damage = 0, -- passive
			WalkSpeed = 6, -- wander speed
			FleeSpeed = 12, -- flee speed (below player WALK_SPEED 16, so a hare is catchable)
			AggroRange = 0, -- never aggroes
			AttackRange = 0, -- no attack
			AttackCooldown = 0, -- no attack
			FleeRange = 18, -- flees when a player is closer than this
			FleeBurstSeconds = 1.2, -- seconds of each flee sprint
			FleeRestSeconds = 1.4, -- seconds it freezes between sprints
			HitRadius = 4, -- extra melee reach (generous: small target)
			NightOnly = false, -- active during the day
			Weight = 5, -- relative spawn weight
			DropId = "RawMeat", -- drop on kill
			DropCount = 1, -- drop amount
		},
		Caribou = {
			Health = 24, -- hit points (3 axe hits on day 1)
			Damage = 0, -- passive
			WalkSpeed = 8, -- wander speed
			FleeSpeed = 13, -- flee speed (below player WALK_SPEED 16)
			AggroRange = 0, -- never aggroes
			AttackRange = 0, -- no attack
			AttackCooldown = 0, -- no attack
			FleeRange = 22, -- flees when a player is closer than this
			FleeBurstSeconds = 1.6, -- seconds of each flee sprint
			FleeRestSeconds = 1.0, -- seconds it stops between sprints
			HitRadius = 4, -- extra melee reach (large body)
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
			AttackCooldown = 2, -- seconds between bites (windup included)
			FleeRange = 0, -- does not flee (retreats only at fire edge)
			FleeBurstSeconds = 0, -- unused (no flee)
			FleeRestSeconds = 0, -- unused (no flee)
			HitRadius = 2, -- extra melee reach
			NightOnly = true, -- hunts at night
			Weight = 3, -- relative spawn weight
			DropId = "Hide", -- drop on kill
			DropCount = 1, -- drop amount
		},
	},
	Night = {
		WindupSeconds = 0.7,
		StrikeLeeway = 2,
		RepelMargin = 6,
		DawnLeaveSeconds = 8,
		WindupAttribute = "Windup",
		BiteAttribute = "BiteSeq",
		FlashColor = { 200, 20, 20 },
		FlashTransparency = 0.45,
		FlashSeconds = 0.45,
		TelegraphColor = { 200, 50, 40 },
		WarmRadiusAttribute = "WarmRadius",
		FireLightRange = 1.4,
		FireLightMaxRange = 60,
		FireLightBrightness = 1.6,
		FireLightColor = { 255, 150, 70 },
		FireLightName = "WarmLight",
		CueVolume = 0.4,
	},
	-- Day/night lighting (DayNightService writes Lighting from the day phase). Dark but readable on a phone.
	Lighting = {
		TwilightPhase = 0.06,
		UpdateInterval = 0.25,
		DayClockTime = 13,
		NightClockTime = 0,
		DayAmbient = { 120, 120, 128 },
		NightAmbient = { 52, 60, 84 },
		DayOutdoorAmbient = { 150, 150, 160 },
		NightOutdoorAmbient = { 70, 80, 110 },
		DayBrightness = 2,
		NightBrightness = 0.8,
		DayFogColor = { 200, 215, 230 },
		NightFogColor = { 20, 28, 48 },
		DayFogStart = 200,
		NightFogStart = 60,
		DayFogEnd = 1500,
		NightFogEnd = 380,
	},
	Combat = {
		MeleeRange = 8, -- base studs player to target center for a hit (plus MobStats.HitRadius and LagCompensation)
		MeleeCooldown = 0.5, -- seconds between swings
		MeleeBaseDamage = 4, -- fist / non-weapon damage (weapons use ItemCatalog damage)
		SpearDamage = 12, -- spear damage
		SpearRange = 9, -- spear reach in studs
		ToolDamage = 8, -- damage of a gather tool (axe/pickaxe) used as a melee weapon
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
	Held = {
		ToolName = "HeldItem", -- name of the server-built Tool in the character (visual only)
		Default = {
			Size = { 0.8, 0.8, 0.8 },
			Color = { 200, 200, 200 },
			GripOffset = 0,
		},
		Visuals = {
			Axe = {
				Size = { 0.4, 3, 0.4 },
				Color = { 150, 110, 70 },
				GripOffset = 1,
			},
			Pickaxe = {
				Size = { 0.4, 3, 0.4 },
				Color = { 120, 120, 130 },
				GripOffset = 1,
			},
			Spear = {
				Size = { 0.3, 5, 0.3 },
				Color = { 170, 140, 90 },
				GripOffset = 1.5,
			},
			Wood = {
				Size = { 0.8, 0.8, 2 },
				Color = { 130, 90, 55 },
				GripOffset = 0,
			},
			Stone = {
				Size = { 1, 0.8, 1 },
				Color = { 130, 130, 135 },
				GripOffset = 0,
			},
			RawMeat = {
				Size = { 1, 0.6, 1 },
				Color = { 190, 70, 70 },
				GripOffset = 0,
			},
			Campfire = {
				Size = { 1.4, 0.6, 1.4 },
				Color = { 230, 120, 40 },
				GripOffset = 0,
			},
			Workbench = {
				Size = { 1.6, 0.8, 1.2 },
				Color = { 140, 100, 60 },
				GripOffset = 0,
			},
			Hide = {
				Size = { 1.2, 0.2, 1.2 },
				Color = { 110, 110, 120 },
				GripOffset = 0,
			},
		},
	},
	Feedback = {
		SwingSeconds = 0.25, -- procedural swing length (used when Assets.SwingAnimation is empty)
		SwingAngle = 70, -- degrees the arm swings
		SoundVolume = 0.6, -- volume of action sounds
		HitParticleCount = 10, -- particles per hit burst
		HitParticleColor = { 235, 225, 200 }, -- chips/snow burst color
		HitParticleSpeed = 12, -- studs/s burst speed
		HitParticleLifetime = 0.5, -- seconds a hit particle lives
		FlashSeconds = 0.15, -- mob hit flash length
		FlashColor = { 255, 80, 80 }, -- mob hit flash color
		PromptRange = 12, -- studs: target pick and prompt range (server re-validates its own ranges)
		AimSlack = 4, -- studs from the mouse ray within which a target counts as aimed at (PC)
		PromptOffsetY = 3, -- studs above the target the prompt floats
		ItemNameSeconds = 1.5, -- seconds the selected item name shows above the hotbar
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
