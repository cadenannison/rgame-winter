--!strict
-- Config module: Survival. Survival loop: day clock, meters, fire, downed/revive, food, buffs, durability, warm spots, shelter sizes, clothing slots.
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

local Constants = require("./Constants")

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
	MaxWarmthDrainMultiplier: number, -- cap on the combined warmth drain (night x biome x event x buff)
	MaxHungerDrainMultiplier: number, -- cap on the combined hunger drain
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
	WarmColorDay: { number }, -- {r, g, b} 0-255; cool and slightly dark so dots read on white snow
	WarmColorNight: { number }, -- warm glow
	BuildColorDay: { number },
	BuildColorNight: { number },
	DayVisibilityMaxTransparency: number, -- by day the warm dots (near the player) must stay at or below this (QA asserts it)
	GroundLift: number, -- studs above the ground hit
	RayHeight: number,
	RayLength: number,
	RaysPerStep: number,
	UpdateInterval: number,
	AllocateInterval: number,
}

export type FireConfig = {
	BaseRadius: number, -- R0: radius added per tier; Tiers[1] (spec tier 0) = 3 * R0, each upgrade adds R0
	WarmRadius: number,
	RepelRadius: number,
	BurnSeconds: number,
	MaxFuelSeconds: number,
	WoodFuelSeconds: number,
	FuelOrder: { string }, -- auto-pick order when no fuel item is selected (fuel values live in Config.Items.Entries)
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
	Meter: FireMeterConfig,
	FuelFractionAttribute: string, -- campfire attribute: fuel / tier max fuel, 0-1, throttled by Meter.UpdateInterval
}

-- Client-only world-space burn-time bar above each campfire (BillboardGui). Visual only.
export type FireMeterConfig = {
	GuiName: string,
	UpdateInterval: number, -- server: min seconds between FuelFraction attribute writes while burning
	ShowRange: number, -- studs from the local player within which a meter is shown
	WidthPx: number,
	HeightPx: number,
	OffsetY: number, -- studs above the fire's pivot
	LowFraction: number, -- at or below this the bar pulses
	PulseSeconds: number, -- pulse period
	PulseMinAlpha: number, -- lowest bar opacity (0-1) during the pulse
	FullColor: { number }, -- {r, g, b} warm colour at full fuel
	LowColor: { number }, -- red at empty
	BackColor: { number },
	BackTransparency: number,
}

export type FoodConfig = {
	RawMeatHunger: number,
}

-- Warm spots: cabins + hot springs (brief 13), sleeping bags (brief 17), campfires (existing tag).
-- Warmth drain stops inside; the Stalker never enters.
export type WarmSpotConfig = {
	Tag: string,
	RadiusAttribute: string, -- number attribute: warm radius in studs
	CabinRadius: number,
	HotSpringRadius: number,
}

export type DownedConfig = {
	BleedoutSeconds: number,
	ReviveSeconds: number,
	ReviveRange: number,
	ReviveHealthFraction: number,
	DownedWalkSpeed: number,
	StateAttribute: string,
	DownedJumpPower: number, -- 0: a downed player cannot jump
	SpectateOnDeath: boolean, -- a dead (bled out) player spectates living teammates until the run ends
	SpectateCycleInterval: number, -- min seconds between spectate-target switches (rate limit)
	ReviveBarHoldRequired: boolean, -- reviver must keep holding the prompt for ReviveSeconds (cancels on release/move away)
	ReviveCancelRange: number, -- studs: channel cancels if reviver gets farther than this from the downed player
	DownedHealth: number, -- health a downed player keeps while bleeding out (display only, no further damage)
	DeadAttribute: string, -- Player attribute: true once bled out / killed (spectator)
	BleedAttribute: string, -- Player attribute: whole seconds of revive window left while downed
	ReviveProgressAttribute: string, -- Player attribute on the downed player: revive channel 0..1
	ReviveRefreshSeconds: number, -- client resends ReviveRequest this often while the reviver holds
	ReviveStaleSeconds: number, -- server cancels the channel if no refresh arrived for this long (release)
	PoseDropY: number, -- studs the lying body is lowered relative to the root (ragdoll-free prone pose)
	PoseTiltDegrees: number, -- pitch of the root joint while downed (90 = lying face down)
	PoseJointName: string, -- the root Motor6D tilted for the pose
	ReturnRemoteName: string, -- RemoteEvent (no payload) a dead player or finished run uses to return to the lobby
}

export type FireRulesConfig = {
	SpawnExcludeCategories: { string }, -- data/Mobs categories that never spawn inside a lit fire's warm radius + SpawnMargin
	SpawnExcludeSpecials: { string }, -- "Stalker", "Lurker": never spawn there either
	SpawnMargin: number, -- studs beyond WarmRadius that the spawn exclusion extends
	RepelCategories: { string }, -- categories that never enter warm radius + Night.RepelMargin (bosses still ignore it)
	ClearLiveTrees: boolean, -- a fire placed after a chunk loaded removes trees inside its clear radius
	TreeClearRadius: number, -- studs: tier 1 clearing (= Forest.FireClearRadius)
	TreeClearPerTier: number, -- studs added per fire tier above 1
	TreeClearMaxRadius: number, -- cap
}

export type ShelterConfig = {
	InteriorWidth: number, -- studs: minimum enterable interior width (cabin, shelter)
	InteriorDepth: number, -- studs: minimum interior depth
	CeilingHeight: number, -- studs floor to ceiling (character 5 studs tall + head room)
	DoorWidth: number, -- studs: doorway clear width
	DoorHeight: number, -- studs: doorway clear height
	WallThickness: number,
	WatchtowerHeight: number, -- studs: platform height above ground (minimum)
	WatchtowerPlatformSize: number, -- studs: square platform side
	WatchtowerRailHeight: number,
	StairWidth: number, -- studs: if stairs are used instead of a ladder
	StairRise: number, -- studs: max rise per step (<= Humanoid step; walkable)
	StairRun: number, -- studs: tread depth
	LadderWidth: number, -- studs: climbable truss width (mobile climb needs >= 2)
	NarrowInteriorWidth: number, -- studs: minimum interior width of a fuselage (plane aisle)
	NarrowCeilingHeight: number, -- studs: minimum fuselage ceiling
	MaxPartsPerStructure: number, -- part budget of one structure's plan boxes (rest of MaxPartsPerPoi: crate, hearth, lights)
	MaxApronSteps: number, -- entry steps that bridge terrain below a sill
	FoundationMargin: number, -- studs the foundation overhangs the walls
	FootprintMargin: number, -- studs added to the structure radius for tree/camp exclusion
	InteriorLightRange: number,
	InteriorLightBrightness: number,
}

-- Clothing (data: shared/data/Clothing.luau). Worn = best piece per slot carried in the inventory.
export type ClothingConfig = {
	Slots: { string }, -- clothing slot names
	MaxTier: number,
	MaxColdResistance: number, -- cap on the summed resistance of every worn piece
}

export type BuffConfig = {
	MaxActive: number,
	MaxDurationSeconds: number,
	MaxWarmthDrainReduction: number, -- buff warmth drain multiplier >= 1 - this
	MaxHungerDrainReduction: number,
	MaxHealthRegenBonus: number,
	MaxSpeedBonus: number,
	ActiveAttribute: string, -- Player attribute: comma list of active buff ids (visible)
}

export type DurabilityConfig = {
	BrokenToolRemains: boolean, -- false: a tool at 0 is removed (Phase 1 behaviour)
	MetalToolMultiplier: number, -- metal tool durability vs basic
	UnbreakableItems: { [string]: boolean }, -- item ids that never lose durability (the starting Axe)
}

-- Sprint (owner: Agent 2). Extend this type and the table below.
export type SprintConfig = {
	SpeedMultiplier: number, -- walk speed multiplier while sprinting (1.3 = +30%)
	ExtraHungerPerSecond: number, -- hunger lost per second on top of the normal drain, only while moving
	MinHungerToStart: number, -- hunger needed to begin a sprint
	MinHungerToKeep: number, -- sprint ends when hunger falls to this
	MinMoveSpeed: number, -- studs/s of horizontal speed that counts as moving (cost applies only above it)
	RateInterval: number, -- Guard interval for SprintRequest (seconds)
	Attribute: string, -- Player attribute: true while the server has the player sprinting
	Key: string, -- Enum.KeyCode member name held to sprint (PC)
	ButtonSizePx: number, -- mobile toggle button (>= 44)
	ButtonOffsetPx: { number }, -- {x, y} px offset of the button from the screen's right/bottom edge
	IndicatorText: string, -- HUD label shown only while sprinting
	NoHungerText: string, -- toast when sprint is refused for low hunger
}

export type Sections = {
	Sprint: SprintConfig,
	Time: TimeConfig,
	Meters: MeterConfig,
	Fire: FireConfig,
	Food: FoodConfig,
	Downed: DownedConfig,
	Clothing: ClothingConfig,
	Buffs: BuffConfig,
	Durability: DurabilityConfig,
	WarmSpot: WarmSpotConfig,
	FireRules: FireRulesConfig,
	Shelter: ShelterConfig,
}

local FIRE_R0 = Constants.FIRE_R0

local Sections: Sections = {
	Sprint = {
		SpeedMultiplier = 1.3, -- walk speed multiplier while sprinting
		ExtraHungerPerSecond = 0.25, -- on top of HungerDrainPerSecond (0.15): sprinting costs ~2.7x hunger
		MinHungerToStart = 20,
		MinHungerToKeep = 8,
		MinMoveSpeed = 2,
		RateInterval = 0.15,
		Attribute = "Sprinting",
		Key = "LeftShift",
		ButtonSizePx = 64,
		ButtonOffsetPx = { 96, 250 },
		IndicatorText = "SPRINTING",
		NoHungerText = "Too hungry to sprint",
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
		MaxWarmthDrainMultiplier = 6, -- cap on night x biome x event x buff warmth drain (Phase 3)
		MaxHungerDrainMultiplier = 1.5, -- cap on combined hunger drain (food debuffs)
	},
	Fire = {
		BaseRadius = FIRE_R0, -- R0: each upgrade adds R0 to the warm radius
		WarmRadius = 3 * FIRE_R0, -- studs where warmth regenerates (tier 1 = spec tier 0 = 3 R0 = 54)
		RepelRadius = 3 * FIRE_R0 + 6, -- fallback repel edge when a fire has no WarmRadius attribute (runtime: warm + Night.RepelMargin)
		BurnSeconds = 180, -- burn time from one fuel add
		MaxFuelSeconds = 600, -- cap on stored burn time
		WoodFuelSeconds = 120, -- burn time added per wood (= Items.Entries.Wood.fuelSeconds)
		FuelOrder = { "Wood", "Stick", "Pinecone", "Blubber" }, -- auto-pick priority; other fuel items follow by id
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
				WarmRadius = 3 * FIRE_R0, -- 54
				MaxFuelSeconds = 600,
				WoodFuelSeconds = 120,
				BuildRadius = 5 * FIRE_R0, -- 90
				LightRange = 4 * FIRE_R0, -- 72
				UpgradeCost = {},
			},
			{
				WarmRadius = 4 * FIRE_R0, -- 72
				MaxFuelSeconds = 900,
				WoodFuelSeconds = 150,
				BuildRadius = 7 * FIRE_R0, -- 126
				LightRange = 5 * FIRE_R0, -- 90
				UpgradeCost = { { id = "Wood", count = 15 }, { id = "Stone", count = 6 } },
			},
			{
				WarmRadius = 5 * FIRE_R0, -- 90
				MaxFuelSeconds = 1200,
				WoodFuelSeconds = 180,
				BuildRadius = 9 * FIRE_R0, -- 162
				LightRange = 6 * FIRE_R0, -- 108
				UpgradeCost = { { id = "Wood", count = 30 }, { id = "Stone", count = 12 } },
			},
		},
		Ring = {
			FolderName = "FireRings", -- client-local folder under Workspace
			DotDiameter = 1.8, -- scaled with the 3x radii (dots stay readable at 160 studs)
			DotThickness = 0.1,
			Spacing = 10, -- 2*pi*162 / 10 = 102 dots for the largest ring
			MinDots = 24,
			MaxDotsPerLayer = 110,
			MaxDotsTotal = 220,
			FadeStart = 30,
			FadeEnd = 110,
			WarmTransparencyDay = 0.35,
			WarmTransparencyNight = 0.5,
			BuildTransparencyDay = 0.3,
			BuildTransparencyNight = 0.5,
			DayVisibilityMaxTransparency = 0.5,
			WarmColorDay = { 150, 120, 80 },
			WarmColorNight = { 255, 190, 110 },
			BuildColorDay = { 60, 120, 190 },
			BuildColorNight = { 150, 205, 255 },
			GroundLift = 0.12,
			RayHeight = 40,
			RayLength = 200, -- covers terrain relief (Terrain.Biomes amplitudes)
			RaysPerStep = 24,
			UpdateInterval = 0.1,
			AllocateInterval = 0.5,
		},
		FuelFractionAttribute = "FuelFraction",
		Meter = {
			GuiName = "FireMeter",
			UpdateInterval = 1,
			ShowRange = 100,
			WidthPx = 80,
			HeightPx = 10,
			OffsetY = 4,
			LowFraction = 0.2,
			PulseSeconds = 0.8,
			PulseMinAlpha = 0.35,
			FullColor = { 255, 190, 70 },
			LowColor = { 220, 50, 40 },
			BackColor = { 20, 20, 24 },
			BackTransparency = 0.4,
		},
	},
	Food = {
		RawMeatHunger = 25, -- hunger restored by eating one Raw Meat (ItemCatalog food rows read this)
	},
	Downed = {
		BleedoutSeconds = 60, -- time downed before death
		ReviveSeconds = 4, -- seconds of channel to revive a teammate
		ReviveRange = 8, -- max studs reviver to downed player
		ReviveHealthFraction = 0.3, -- fraction of max health restored on revive
		DownedWalkSpeed = 3, -- crawl speed while downed
		StateAttribute = "Downed", -- Player attribute: true while downed
		DownedJumpPower = 0, -- downed players cannot jump
		SpectateOnDeath = true, -- a bled-out player spectates living teammates until the run ends
		SpectateCycleInterval = 0.4, -- min seconds between spectate-target switches
		ReviveBarHoldRequired = true, -- reviver holds the prompt for ReviveSeconds
		ReviveCancelRange = 12, -- studs: channel cancels beyond this (> ReviveRange so latency does not cancel)
		DownedHealth = 1, -- health shown while downed (no further damage taken)
		DeadAttribute = "RunDead",
		BleedAttribute = "DownedBleed",
		ReviveProgressAttribute = "ReviveProgress",
		ReviveRefreshSeconds = 0.4,
		ReviveStaleSeconds = 1.1, -- must exceed ReviveRefreshSeconds plus network jitter
		PoseDropY = 2,
		PoseTiltDegrees = 90,
		PoseJointName = "RootJoint",
		ReturnRemoteName = "ReturnToLobbyRequest",
	},
	Clothing = {
		Slots = { "Head", "Body", "Feet" },
		MaxTier = 3,
		MaxColdResistance = 12,
	},
	Buffs = {
		MaxActive = 2,
		MaxDurationSeconds = 360,
		MaxWarmthDrainReduction = 0.4,
		MaxHungerDrainReduction = 0.4,
		MaxHealthRegenBonus = 1,
		MaxSpeedBonus = 0.15,
		ActiveAttribute = "Buffs",
	},
	Durability = {
		BrokenToolRemains = false,
		MetalToolMultiplier = 2,
		UnbreakableItems = { Axe = true }, -- the starting Axe never loses durability (other tools still wear)
	},
	WarmSpot = {
		Tag = "WarmSpot",
		RadiusAttribute = "WarmSpotRadius",
		CabinRadius = 14,
		HotSpringRadius = 18,
	},
	FireRules = {
		SpawnExcludeCategories = { "hostile", "miniboss", "boss" },
		SpawnExcludeSpecials = { "Stalker", "Lurker" },
		SpawnMargin = 6,
		RepelCategories = { "hostile", "miniboss" },
		ClearLiveTrees = true,
		TreeClearRadius = 12,
		TreeClearPerTier = 4,
		TreeClearMaxRadius = 24,
	},
	Shelter = {
		InteriorWidth = 14,
		InteriorDepth = 14,
		CeilingHeight = 9,
		DoorWidth = 5,
		DoorHeight = 8,
		WallThickness = 1,
		WatchtowerHeight = 28,
		WatchtowerPlatformSize = 10,
		WatchtowerRailHeight = 3.5,
		StairWidth = 5,
		StairRise = 1.5,
		StairRun = 2,
		LadderWidth = 3,
		NarrowInteriorWidth = 8,
		NarrowCeilingHeight = 8,
		MaxPartsPerStructure = 52,
		MaxApronSteps = 10,
		FoundationMargin = 1,
		FootprintMargin = 6,
		InteriorLightRange = 20,
		InteriorLightBrightness = 1.4,
	},
}

return Sections
