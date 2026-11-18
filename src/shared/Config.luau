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
	ModeStoreName: string, -- Studio-only DataStore holding the "/debug mode" override
	ModeStoreKey: string,
	ModeReadTimeout: number, -- seconds boot waits for that read before using the default mode
	GiveCount: number,
	MobKinds: { string },
	SpawnMobDistance: number,
	SpawnMobDrop: number,
	TeleportLogMax: number,
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

export type ScalingConfig = {
	MobBudgetPerDay: number,
	MobHealthPerDay: number,
	MobDamagePerDay: number,
	MobBudgetPerExtraPlayer: number,
	MaxMobHealthMultiplier: number,
	MaxMobDamageMultiplier: number,
	MaxMobBudgetMultiplier: number,
	-- Phase 3: depth (biome ring 0..3) and party scaling; every factor has a hard cap.
	MaxLiveMobs: number, -- absolute cap on live mobs in the run, after every multiplier
	MobBudgetPerRing: number,
	MaxRingBudgetMultiplier: number,
	MobHealthPerRing: number,
	MaxRingHealthMultiplier: number,
	MobDamagePerRing: number,
	MaxRingDamageMultiplier: number,
	MaxPartyBudgetMultiplier: number, -- cap on MobBudgetPerExtraPlayer scaling
	MobHealthPerExtraPlayer: number,
	MaxPartyHealthMultiplier: number,
	HotSpringSpawnBias: number, -- budget multiplier while a player is near a hot spring (springs attract mobs)
	HotSpringBiasRange: number, -- studs from a hot spring within which the bias applies
	MaxSpawnMultiplier: number, -- cap on event x hot-spring budget multipliers (MaxLiveMobs still applies)
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
	Ghost: GhostConfig,
	-- Phase 3 structure names (set by brief 17; read by 15/16)
	HealthAttribute: string, -- structure attribute: current health (breakable structures)
	BlockerTag: string, -- tag on walls and closed doors (mob pathing treats them as solid)
	TrapTag: string, -- tag on spike traps (damages mobs only)
	StorageTag: string, -- tag on storage chests
	DoorOpenAttribute: string, -- door attribute: true while open
}

-- Warm spots: cabins + hot springs (brief 13), sleeping bags (brief 17), campfires (existing tag).
-- Warmth drain stops inside; the Stalker never enters.
export type WarmSpotConfig = {
	Tag: string,
	RadiusAttribute: string, -- number attribute: warm radius in studs
	CabinRadius: number,
	HotSpringRadius: number,
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
	BuriedAttribute: string, -- mob model: snow lurker lies hidden until a player is close
	HeldRangedAttribute: string, -- Player: the selected item is a ranged weapon (client shows Shoot)
	BossAttribute: string, -- mob model on bosses (client may show a name plate)
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
	PadRateInterval: number,
	PadModeRateInterval: number,
	DailyClaimRateInterval: number,
	-- Phase 3
	PingRateInterval: number,
	StorageRateInterval: number,
	MapRateInterval: number,
	RepairRateInterval: number,
	CookRateInterval: number,
	ShootRateInterval: number,
	-- Phase 4
	ShopRateInterval: number,
	RobuxPromptRateInterval: number,
	EquipRateInterval: number,
	SettingsRateInterval: number,
	MetaStateRateInterval: number,
	HintRateInterval: number,
}

-- Phase 2 lobby: pads, party timer, lobby attributes. Owned by brief 7 (contracts); used by briefs 8 and 10.
export type LobbyConfig = {
	MaxPlayers: number, -- lobby server size
	PadCount: number, -- pads 1..PadCount; pad i holds up to i players
	PadTimerSeconds: number, -- countdown from first step; resets to this when someone joins
	PadModeFriends: string, -- host-only pad mode: Roblox friends of the host only
	PadModeOpen: string, -- open-fill: anyone in the lobby
	DefaultPadMode: string,
	PadTag: string, -- CollectionService tag on pad parts
	PadIndexAttribute: string, -- pad part attribute: 1..PadCount
	PlayerPadAttribute: string, -- Player attribute: pad index the player is on (0 = none)
	FriendCheckTimeout: number, -- seconds to wait on IsFriendsWith before refusing the join
	PollInterval: number, -- seconds between pad timer / off-pad checks (one loop for all pads)
	PadEdgeMargin: number, -- studs beyond the pad edge before a member counts as stepped off
	PadHeightMargin: number, -- studs above/below the pad that still count as on it
	LaunchHoldSeconds: number, -- pad stays locked after a successful teleport call, then resets
	PadJoinLift: number, -- studs above the pad top a remote join places the character root
	RootName: string, -- Workspace folder built by tools/build_lobby.luau
	SpawnName: string, -- SpawnLocation inside RootName; lobby players spawn here
	StatPublishSeconds: number, -- lobby stat attribute publish loop (one loop for every player)
	LeaderboardStoreName: string, -- OrderedDataStore for max days
	LeaderboardTopCount: number,
	LeaderboardRefreshSeconds: number, -- one GetSortedAsync per interval
	LeaderboardWriteIntervalSeconds: number, -- at most one UpdateAsync per interval
	LeaderboardMaxPending: number, -- cap on queued leaderboard writes
	LeaderboardRetryAfterFailSeconds: number,
	NameCacheMax: number, -- leaderboard display-name cache size
}

-- Phase 2 run lifecycle. Owned by brief 7; used by brief 9.
export type RunConfig = {
	RejoinWindowSeconds: number, -- single source: disconnected party member's run state is held this long (revive limit = Downed.BleedoutSeconds)
	SummarySeconds: number, -- seconds the run summary shows before the party is sent back to the lobby
	ReturnRetryCount: number, -- teleport-to-lobby retries before kicking with a message
	PollInterval: number, -- seconds between run roster polls (own cadence, not Meters.TickInterval)
	SeedWaitSeconds: number, -- run server boot waits this long for the first player's teleport data (seed)
	ReturnFailedMessage: string, -- kick text when returning to the lobby failed
	RefusedMessage: string, -- kick text for a player not in this run's party
	DefaultCause: string, -- summary "what got you" when nothing was recorded
}

-- Teleport data contract between lobby and run servers. Validated by shared/logic/TeleportData via Guard.
export type TeleportConfig = {
	DataVersion: number, -- bump on any TeleportData shape change
	ModeRun: string,
	ModeLobby: string,
	MaxSeed: number, -- seeds are integers in [0, MaxSeed]
	MaxPartySize: number,
	ServerModeAttribute: string, -- Workspace attribute: ModeRun or ModeLobby, set at server boot
	StudioDefaultMode: string, -- Studio play mode when no Workspace ServerMode preset and no /debug mode override
	ModeWaitSeconds: number, -- client waits this long for the ServerMode attribute before defaulting to run UI
	RetryCount: number,
	RetryDelay: number, -- seconds, doubled each retry
}

-- Coin payouts and meta caps. ALL VALUES ARE PLACEHOLDERS pending balance. Owned by brief 7; used by brief 9.
export type MetaConfig = {
	CoinsPerRun: number, -- paid on every run end, even a bad one
	CoinsPerDaySurvived: number,
	CoinsPerKill: number,
	CoinsPerBossKill: number,
	CoinsPerFriendInParty: number, -- small social bonus per friend in the party
	MaxCoinsPerRun: number, -- hard cap on one run's payout
	DailyRewardCoins: number,
	MaxStatValue: number, -- clamp for every saved stat counter
	MaxAchievements: number, -- max entries in profile.achievements
	MaxAchievementIdLength: number,
	CoinsPerDarkEventSurvived: number, -- Phase 3: paid per dark event a player is alive at the end of
	-- Phase 4 (brief 21 contracts; consumers 19 meta, 20 atmosphere). Every saved table has a cap here.
	MinAchievementDefs: number, -- data/Achievements.luau holds MinAchievementDefs..MaxAchievementDefs entries
	MaxAchievementDefs: number, -- (<= MaxAchievements, the saved cap)
	MaxAchievementCoinReward: number, -- cap on one achievement's coin reward
	MaxProgressEntries: number, -- max entries in profile.achievementProgress
	MaxOwnedCosmetics: number, -- max entries in profile.ownedCosmetics
	MaxUnlockedGear: number, -- max entries in profile.unlockedGear
	MaxTitles: number, -- max entries in profile.titles
	MaxHintsSeen: number, -- max entries in profile.hintsSeen
	MaxItemIdLength: number, -- cosmetic / perk / gear / title / hint / progress key length cap
	MaxEquippedPerks: number, -- one perk equipped (and applied) per run
	PerkStats: { string }, -- the only modifiers a perk may change (fractions)
	MaxPerkMagnitude: number, -- cap on any perk's |amount| so none trivializes survival
	MinCoinPrice: number, -- coin shop price bounds
	MaxCoinPrice: number,
	MaxRobuxPrice: number, -- sanity cap on displayed Robux prices (the charged price is the product's)
	MaxCoinPackCoins: number, -- cap on coins one coin pack grants
	MaxStarterGearCount: number, -- cap on one starter gear grant at run start
	StarterGearWaitSeconds: number, -- run start: bounded wait for the inventory before granting gear
	StarterGearPollSeconds: number,
	CosmeticTagPrefix: string, -- character tag prefix (+ slot) for the equipped cosmetic
	CosmeticSlots: { string },
	ProductIds: { [string]: number }, -- developer product id by Shop productKey; 0 = placeholder (never prompted)
	MaxProcessedReceipts: number, -- receipt log cap (oldest evicted); grants are idempotent by PurchaseId
	MaxReceiptIdLength: number,
	RecordHintDays: number, -- HUD shows "N days to your record" when within this many days of maxDays
	BestDaysAttribute: string, -- Player attribute (run server): saved maxDays, for the record hint
	TitleAttribute: string, -- Player attribute: equipped title display name ("" = none), visible to all
	CosmeticAttribute: string, -- Player attribute: equipped cosmetic id ("" = none), visible to all
	MaxFriendBonusFriends: number, -- cap on friends counted for CoinsPerFriendInParty
}

-- Phase 4 performance budgets (brief 20). Target: 30+ FPS on a mid-range phone.
export type PerfConfig = {
	TargetFps: number,
	FpsSampleSeconds: number, -- client FPS sample window for the measurable check (tools/qa)
	MaxLiveParts: number, -- cap on BaseParts under the run world (chunks + structures + mobs + effects)
	MaxLiveMobs: number, -- same value as Scaling.MaxLiveMobs (single source MAX_LIVE_MOBS)
	ChunkLoadBudgetPerFrame: number, -- chunks built or unloaded per Heartbeat
	ChunkPartBudgetPerFrame: number, -- parts created per Heartbeat while a chunk builds
	MaxParticleEmitters: number, -- cap on enabled ParticleEmitters on one client
	MaxParticleRate: number, -- cap on any emitter's Rate
	MaxActiveSounds: number, -- cap on concurrently playing one-shot cue sounds on one client
	StreamingEnabled: boolean,
	StreamingTargetRadius: number,
	StreamingMinRadius: number,
	SwingBroadcastRange: number, -- studs: SwingBroadcast goes only to players this close to the swinger
	SwingMaxPerSecond: number, -- client cap on relayed swings animated per second
}

-- Phase 4 player settings (saved in profile.settings). Boolean settings only.
export type SettingsConfig = {
	Keys: { string }, -- valid SettingsSetRequest keys (profile.settings field names)
	ReduceScares: string, -- key "reduceScares"
	ReduceScaresAttribute: string, -- Player attribute mirrored from profile.settings.reduceScares
	DefaultReduceScares: boolean,
	ReducedScareVisualMultiplier: number, -- client: horror visual/sound intensity when reduced (0..1)
}

-- Phase 4 first-run hints (seen ids saved in profile.hintsSeen).
export type HintsConfig = {
	Ids: { string },
	ShowSeconds: number, -- a shown hint hides after this long (it still completes only on its action)
	CheckInterval: number, -- client seconds between hint trigger checks
	LookupRange: number, -- studs: a chest counts as nearby
	WarnWindowSeconds: number, -- a warning cue keeps its hint triggered this long
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

-- Clothing (data: shared/data/Clothing.luau). Worn = best piece per slot carried in the inventory.
export type ClothingConfig = {
	Slots: { string }, -- clothing slot names
	MaxTier: number,
	MaxColdResistance: number, -- cap on the summed resistance of every worn piece
}

-- Dark events (data: shared/data/Events.luau). Timers are server-only.
export type EventsConfig = {
	FirstDay: number, -- no dark event before this day (design: day 3)
	MinGapSeconds: number, -- min seconds from one dark event's end to the next start
	CheckIntervalSeconds: number, -- seconds between start rolls
	BaseChancePerCheck: number,
	ChancePerDay: number, -- added per day past FirstDay
	MaxChancePerCheck: number, -- hard cap on the roll chance
	MaxPerDay: number, -- hard cap on dark events started per in-game day
	BlizzardBufferSeconds: number, -- no dark event within this many seconds of a blizzard (before or after)
	MinWarningSeconds: number,
	MaxWarningSeconds: number,
	MaxDurationSeconds: number,
	MaxWarmthDrainMultiplier: number, -- cap for any event or blizzard modifier
	MaxFuelBurnMultiplier: number,
	MaxDreadGainMultiplier: number,
	MaxHuntChanceBonus: number,
	MinVisibility: number, -- floor for any event visibility modifier (1 = normal)
	MaxSpawnMultiplier: number, -- cap for any event mob-budget modifier
	ActiveAttribute: string, -- Workspace attribute: active event id ("" = none). Visible effect only, no timer.
}

-- Dread: hidden per-party value (never replicated). Cue levels are the only client view.
export type DreadConfig = {
	Max: number,
	TickInterval: number,
	GainAlonePerSecond: number,
	GainFarFromCampPerSecond: number,
	FarFromCampDistance: number, -- studs from the camp fire
	GainDarkPerSecond: number, -- night or false night, outside light
	GainBlizzardPerSecond: number,
	GainLurkerSighting: number, -- one-off per sighting
	DecayNearFirePerSecond: number,
	DecayPerSecond: number, -- passive decay elsewhere
	GainPerDay: number, -- gain multiplier added per day
	MaxDayGainMultiplier: number,
	GainPerRing: number, -- gain multiplier added per biome ring
	MaxRingGainMultiplier: number,
	CueThresholds: { number }, -- ascending; cue level = count of thresholds reached (0..#CueThresholds)
}

-- Isolation weights pick horror targets (Stalker, lurkers, scares).
export type IsolationConfig = {
	Range: number, -- studs: teammates within this count as "with" the player
	WeightAlone: number,
	WeightPair: number,
	WeightGroup: number, -- 3+ together
	SoloBaseline: number, -- one-player party weight (gentler than WeightAlone)
	FullGroupBlocksBigEvents: boolean, -- whole party within Range blocks hunts, false night, the quiet
}

-- The Stalker: unkillable pressure system. Hunt chance is hidden.
export type StalkerConfig = {
	FirstHuntDay: number, -- no hunts on day 1
	HuntCheckIntervalSeconds: number,
	BaseHuntChance: number,
	HuntChancePerDread: number,
	HuntChancePerDay: number,
	MaxHuntChance: number, -- hard cap per check (after event bonuses)
	HuntCooldownSeconds: number,
	TelegraphSeconds: number, -- tells play this long before it can strike
	MaxHuntSeconds: number,
	TorchHuntShorten: number, -- fraction of remaining hunt removed while the target holds a lit torch
	Damage: number, -- must stay below Meters.MaxHealth (never kills from full)
	WarmthLoss: number,
	KnockbackStuds: number,
	RetreatSeconds: number,
	WalkSpeed: number,
	ChaseSpeed: number,
	StrikeRange: number,
	ApproachDistance: number, -- studs it lurks at during the telegraph
	TorchRepelRadius: number,
	FlareRepelRadius: number,
	FireRepelMargin: number, -- studs beyond any WarmRadius it will not enter
	Tag: string,
}

-- Lurkers: never attack; vanish when approached or looked at.
export type LurkerConfig = {
	SpawnIntervalSeconds: number,
	BaseDensity: number, -- spawn chance per interval per player
	DensityPerDay: number,
	DensityPerRing: number,
	MaxDensity: number,
	MaxPerPlayer: number,
	MaxTotal: number,
	SpawnMinDistance: number,
	SpawnMaxDistance: number,
	VanishDistance: number,
	LookDotThreshold: number, -- camera look dot above this = looked at head-on
	LifetimeSeconds: number,
	Tag: string,
}

-- Phantom scares budget (Phase 4 adds content; caps are fixed now).
export type ScaresConfig = {
	MinCooldownSeconds: number,
	MaxPerDay: number,
	GroupChanceMultiplier: number, -- ambient scares on a full group are this much rarer
	ReducedSettingMultiplier: number, -- player "reduce scares" setting
}

-- Sensory cues to the client (Remotes.Cue). Coarse levels only; never a raw metric.
export type CueConfig = {
	Kinds: { string },
	MaxLevel: number,
	MinIntervalSeconds: number, -- per player per kind
	Horror: HorrorCueConfig, -- client presentation of the horror cues (visual only)
}

export type HorrorCueConfig = {
	FrostPerLevel: number, -- frost overlay opacity per DreadLevel step
	FrostTell: number, -- frost opacity during a Stalker tell
	DesatPerLevel: number, -- ColorCorrection saturation per level
	DesatTell: number,
	RumbleVolumePerLevel: number,
	FadeSeconds: number,
	GutterSeconds: number,
	GutterBrightness: number, -- fraction of normal light brightness while guttering
	PulseSeconds: number,
	FrostEdgeColor: { number },
	EdgeSize: number, -- screen fraction covered by each frost edge
	SoundMaxDistance: number,
	SoundCleanupSeconds: number, -- fallback cleanup if a sound never ends
}

export type BossConfig = {
	MiniBossFirstDay: number,
	MiniBossMaxAlive: number,
	MiniBossRespawnDays: number,
	BlizzardBossFirstDay: number,
	BlizzardBossChance: number,
	BlizzardBossChancePerDay: number,
	MaxBlizzardBossChance: number,
	HealthPerExtraPlayer: number,
	MaxHealthMultiplier: number,
	DamagePerDay: number,
	MaxDamageMultiplier: number,
}

export type BlizzardConfig = {
	EventId: string, -- EventService event id for a blizzard (onEventEnd)
	ActiveAttribute: string, -- Workspace attribute: true during a blizzard (visible weather)
	WarningAttribute: string, -- Workspace attribute: true during the warning (visible sky cue)
}

-- Projectiles (bow): the only way players can hurt each other.
export type ProjectileConfig = {
	Speed: number,
	MaxRange: number,
	MaxLifetime: number,
	MaxActivePerPlayer: number,
	AimAssistDegrees: number, -- mobile aim assist cone
	FriendlyFireMultiplier: number, -- damage a stray projectile deals to a teammate
	MeleeFriendlyFire: boolean, -- always false: melee never hurts players
}

export type StorageConfig = {
	ChestSlots: number,
	OpenRange: number,
	MaxChestsPerRun: number,
	OpenAttribute: string, -- Player attribute: chest the player has open (structure id string, "" = none)
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
	Lobby: LobbyConfig,
	Run: RunConfig,
	Teleport: TeleportConfig,
	Meta: MetaConfig,
	Held: HeldConfig,
	Feedback: FeedbackConfig,
	Debug: DebugConfig,
	Biome: BiomeConfig,
	Clothing: ClothingConfig,
	Events: EventsConfig,
	Dread: DreadConfig,
	Isolation: IsolationConfig,
	Stalker: StalkerConfig,
	Lurkers: LurkerConfig,
	Scares: ScaresConfig,
	Cue: CueConfig,
	Bosses: BossConfig,
	Blizzard: BlizzardConfig,
	Projectile: ProjectileConfig,
	Storage: StorageConfig,
	Map: MapConfig,
	Ping: PingConfig,
	Repair: RepairConfig,
	Cooking: CookingConfig,
	Buffs: BuffConfig,
	Durability: DurabilityConfig,
	WarmSpot: WarmSpotConfig,
	Structures: StructuresConfig,
	Perf: PerfConfig,
	Settings: SettingsConfig,
	Hints: HintsConfig,
	RemoteFolderName: string,
	DefaultRateLimitInterval: number,
	ProfileStoreName: string,
	ProfileKeyPrefix: string,
	StudioAssumeDead: number, -- Studio only: seconds of silence after which a session lock counts as a crashed Studio
	StudioStoreSuffix: string, -- appended to ProfileStoreName in Studio so tests never touch live profiles
	DataFallbackAttribute: string, -- Player attribute set (Studio only) when an in-memory profile is in use
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

-- Single source for the live mob cap (Scaling.MaxLiveMobs and Perf.MaxLiveMobs).
local MAX_LIVE_MOBS = 40

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
		ModeStoreName = "StudioDebug",
		ModeStoreKey = "ServerMode",
		ModeReadTimeout = 3,
		ClientBridgeName = "ClientQABridge", -- Studio-only PlayerScripts BindableFunction: real client input handlers
		GiveCount = 10, -- items granted by the Studio-only "give" command
		-- valid "spawnMob" args (MobService kind names; Phase 1 + data/Mobs)
		MobKinds = {
			"ArcticHare",
			"Caribou",
			"Wolf",
			"Fish",
			"PolarBear",
			"IceWraith",
			"SnowLurker",
			"CaveCrawler",
			"IceWarden",
			"CaveMatriarch",
			"RuinColossus",
			"WhiteoutBeast",
		},
		SpawnMobDistance = 10, -- studs in front of the player a "spawnMob" mob appears
		SpawnMobDrop = 3, -- studs below the player root used as the spawn ground height
		TeleportLogMax = 20, -- Studio fake TeleportAdapter: recorded calls kept for QA (oldest dropped)
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
			DotDiameter = 0.9,
			DotThickness = 0.1,
			Spacing = 3.4,
			MinDots = 16,
			MaxDotsPerLayer = 56,
			MaxDotsTotal = 110,
			FadeStart = 12,
			FadeEnd = 38,
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
			RayLength = 120,
			RaysPerStep = 24,
			UpdateInterval = 0.1,
			AllocateInterval = 0.5,
		},
		FuelFractionAttribute = "FuelFraction",
		Meter = {
			GuiName = "FireMeter",
			UpdateInterval = 1,
			ShowRange = 60,
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
	Scaling = {
		MobBudgetPerDay = 0.05, -- fractional mob budget added per day survived
		MobHealthPerDay = 0.04, -- fractional mob health added per day
		MobDamagePerDay = 0.03, -- fractional mob damage added per day
		MobBudgetPerExtraPlayer = 0.35, -- fractional budget added per player beyond the first
		MaxMobHealthMultiplier = 4, -- cap on health scaling
		MaxMobDamageMultiplier = 3, -- cap on damage scaling
		MaxMobBudgetMultiplier = 3, -- cap on day scaling of the mob budget
		MaxLiveMobs = MAX_LIVE_MOBS, -- absolute cap on live mobs (all multipliers applied, then clamped)
		MobBudgetPerRing = 0.1, -- budget added per biome ring out from the start forest
		MaxRingBudgetMultiplier = 1.4,
		MobHealthPerRing = 0.15,
		MaxRingHealthMultiplier = 1.6,
		MobDamagePerRing = 0.1,
		MaxRingDamageMultiplier = 1.4,
		MaxPartyBudgetMultiplier = 2.5, -- cap on the party-size budget factor (6 players)
		MobHealthPerExtraPlayer = 0.1,
		MaxPartyHealthMultiplier = 1.5,
		HotSpringSpawnBias = 1.25, -- hot springs attract mobs: slightly larger budget near one
		HotSpringBiasRange = 60,
		MaxSpawnMultiplier = 2, -- event x hot-spring budget cap (then MaxLiveMobs)
	},
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
		BuriedAttribute = "Buried",
		HeldRangedAttribute = "HeldRanged",
		BossAttribute = "BossKind",
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
		PadRateInterval = 0.5, -- PadJoinRequest, PadLeaveRequest
		PadModeRateInterval = 1, -- PadModeRequest
		DailyClaimRateInterval = 2, -- DailyClaimRequest
		PingRateInterval = 0.5, -- PingRequest
		StorageRateInterval = 0.2, -- StorageOpenRequest, StorageDepositRequest, StorageWithdrawRequest
		MapRateInterval = 2, -- MapRequest
		RepairRateInterval = 0.5, -- RepairRequest
		CookRateInterval = 0.3, -- CookRequest
		ShootRateInterval = 0.4, -- ShootRequest
		ShopRateInterval = 1, -- ShopBuyRequest
		RobuxPromptRateInterval = 3, -- RobuxPurchaseRequest
		EquipRateInterval = 0.5, -- EquipCosmeticRequest, EquipPerkRequest, EquipTitleRequest
		SettingsRateInterval = 0.5, -- SettingsSetRequest
		MetaStateRateInterval = 2, -- MetaStateRequest
		HintRateInterval = 0.5, -- HintSeenRequest
	},
	Lobby = {
		MaxPlayers = 15,
		PadCount = 6,
		PadTimerSeconds = 20,
		PadModeFriends = "friends",
		PadModeOpen = "open",
		DefaultPadMode = "open",
		PadTag = "LobbyPad",
		PadIndexAttribute = "PadIndex",
		PlayerPadAttribute = "PadIndex",
		FriendCheckTimeout = 5,
		PollInterval = 0.25,
		PadEdgeMargin = 2,
		PadHeightMargin = 8,
		LaunchHoldSeconds = 30,
		PadJoinLift = 3,
		RootName = "Lobby",
		SpawnName = "LobbySpawn",
		StatPublishSeconds = 2,
		LeaderboardStoreName = "ArcticMaxDays_v1",
		LeaderboardTopCount = 10,
		LeaderboardRefreshSeconds = 60,
		LeaderboardWriteIntervalSeconds = 6,
		LeaderboardMaxPending = 30,
		LeaderboardRetryAfterFailSeconds = 30,
		NameCacheMax = 200,
	},
	Run = {
		RejoinWindowSeconds = 300, -- design: 5-minute disconnect hold
		SummarySeconds = 15,
		ReturnRetryCount = 3,
		PollInterval = 0.5,
		SeedWaitSeconds = 20,
		ReturnFailedMessage = "Could not return to the lobby. Please rejoin.",
		RefusedMessage = "This run is not available to you.",
		DefaultCause = "Cold",
	},
	Teleport = {
		DataVersion = 1,
		ModeRun = "run",
		ModeLobby = "lobby",
		MaxSeed = 2147483647,
		MaxPartySize = 6,
		ServerModeAttribute = "ServerMode",
		StudioDefaultMode = "lobby", -- plain Studio Test = lobby; Workspace.ServerMode preset or "/debug mode run" for a run
		ModeWaitSeconds = 10,
		RetryCount = 3,
		RetryDelay = 1,
	},
	-- Placeholder payouts (balance pass later). Coins are earned only by playing.
	Meta = {
		CoinsPerRun = 5,
		CoinsPerDaySurvived = 10,
		CoinsPerKill = 1,
		CoinsPerBossKill = 25,
		CoinsPerFriendInParty = 2,
		MaxCoinsPerRun = 5000,
		DailyRewardCoins = 50,
		MaxStatValue = 1e9,
		MaxAchievements = 64,
		MaxAchievementIdLength = 32,
		CoinsPerDarkEventSurvived = 3,
		-- Phase 4 caps and placeholders (balance pass later).
		MinAchievementDefs = 20,
		MaxAchievementDefs = 30,
		MaxAchievementCoinReward = 500,
		MaxProgressEntries = 32,
		MaxOwnedCosmetics = 128,
		MaxUnlockedGear = 32,
		MaxTitles = 64,
		MaxHintsSeen = 64,
		MaxItemIdLength = 32,
		MaxEquippedPerks = 1,
		PerkStats = { "warmthDrain", "hungerDrain", "fuelBurn", "gatherSpeed", "moveSpeed" },
		MaxPerkMagnitude = 0.15,
		MinCoinPrice = 25,
		MaxCoinPrice = 20000,
		MaxRobuxPrice = 1000,
		MaxCoinPackCoins = 10000,
		MaxStarterGearCount = 5,
		StarterGearWaitSeconds = 15, -- run start: bounded wait for the inventory before granting gear
		StarterGearPollSeconds = 0.25,
		CosmeticTagPrefix = "Cosmetic_", -- + slot: character CollectionService tag for the equipped cosmetic
		CosmeticSlots = { "outfit", "trail", "camp", "pet" },
		-- Placeholders: 0 = not configured yet (the server refuses to prompt). Fill from the Creator Dashboard.
		ProductIds = {
			CoinPackSmall = 0,
			CoinPackMedium = 0,
			CoinPackLarge = 0,
			AuroraParka = 0,
			NorthernLightsTrail = 0,
			HuskyPup = 0,
		},
		MaxProcessedReceipts = 100,
		MaxReceiptIdLength = 64,
		RecordHintDays = 2,
		BestDaysAttribute = "BestDays",
		TitleAttribute = "Title",
		CosmeticAttribute = "Cosmetic",
		MaxFriendBonusFriends = 5,
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
	Clothing = {
		Slots = { "Head", "Body", "Feet" },
		MaxTier = 3,
		MaxColdResistance = 12,
	},
	Events = {
		FirstDay = 3, -- design: no dark event before day 3
		MinGapSeconds = 540, -- 1.5 in-game days
		CheckIntervalSeconds = 20,
		BaseChancePerCheck = 0.02,
		ChancePerDay = 0.002,
		MaxChancePerCheck = 0.05,
		MaxPerDay = 1,
		BlizzardBufferSeconds = 90,
		MinWarningSeconds = 5,
		MaxWarningSeconds = 30,
		MaxDurationSeconds = 240,
		MaxWarmthDrainMultiplier = 2.5,
		MaxFuelBurnMultiplier = 2.5,
		MaxDreadGainMultiplier = 3,
		MaxHuntChanceBonus = 0.15,
		MinVisibility = 0.25,
		MaxSpawnMultiplier = 2,
		ActiveAttribute = "DarkEvent",
	},
	Dread = {
		Max = 100,
		TickInterval = 1,
		GainAlonePerSecond = 0.25,
		GainFarFromCampPerSecond = 0.15,
		FarFromCampDistance = 200,
		GainDarkPerSecond = 0.2,
		GainBlizzardPerSecond = 0.3,
		GainLurkerSighting = 6,
		DecayNearFirePerSecond = 1.5,
		DecayPerSecond = 0.05,
		GainPerDay = 0.03,
		MaxDayGainMultiplier = 1.6,
		GainPerRing = 0.1,
		MaxRingGainMultiplier = 1.5,
		CueThresholds = { 25, 50, 75 }, -- length = Cue.MaxLevel
	},
	Isolation = {
		Range = 60,
		WeightAlone = 1,
		WeightPair = 0.45,
		WeightGroup = 0.1,
		SoloBaseline = 0.6,
		FullGroupBlocksBigEvents = true,
	},
	Stalker = {
		FirstHuntDay = 2, -- design: no hunts on day 1
		HuntCheckIntervalSeconds = 15,
		BaseHuntChance = 0.01,
		HuntChancePerDread = 0.0015,
		HuntChancePerDay = 0.003,
		MaxHuntChance = 0.2,
		HuntCooldownSeconds = 300,
		TelegraphSeconds = 12,
		MaxHuntSeconds = 60,
		TorchHuntShorten = 0.5,
		Damage = 35, -- below Meters.MaxHealth: never kills from full
		WarmthLoss = 30,
		KnockbackStuds = 20,
		RetreatSeconds = 20,
		WalkSpeed = 10,
		ChaseSpeed = 15, -- below WALK_SPEED: a player who reads the tells can reach fire
		StrikeRange = 6,
		ApproachDistance = 60,
		TorchRepelRadius = 14,
		FlareRepelRadius = 30,
		FireRepelMargin = 4,
		Tag = "Stalker",
	},
	Lurkers = {
		SpawnIntervalSeconds = 20,
		BaseDensity = 0.15,
		DensityPerDay = 0.01,
		DensityPerRing = 0.05,
		MaxDensity = 0.4,
		MaxPerPlayer = 2,
		MaxTotal = 8,
		SpawnMinDistance = 70,
		SpawnMaxDistance = 140,
		VanishDistance = 45,
		LookDotThreshold = 0.97,
		LifetimeSeconds = 40,
		Tag = "Lurker",
	},
	Scares = {
		MinCooldownSeconds = 90,
		MaxPerDay = 6,
		GroupChanceMultiplier = 0.2,
		ReducedSettingMultiplier = 0.4,
	},
	Cue = {
		-- Remotes.Cue kinds. Warn* = dark event / blizzard warning; Event* = start/end of a visible event.
		Kinds = {
			"DreadLevel", -- level 0..MaxLevel: ambient thinning, desaturation, frost edges
			"StalkerTell", -- hunt telegraph on the target: wildlife silent, frost creep
			"Footsteps", -- crunch behind the player (position)
			"FireGutter", -- a nearby fire gutters (position)
			"StalkerRetreat",
			"LurkerSighted",
			"IceCrack", -- thin ice cracking (position)
			"WarnBlizzard",
			"WarnFalseNight",
			"WarnTheQuiet",
			"WarnDeepFreeze",
			"EventStart", -- event = id
			"EventEnd", -- event = id
			"BossWarning", -- blizzard boss approaching camp
		},
		MaxLevel = 3,
		MinIntervalSeconds = 1,
		Horror = {
			FrostPerLevel = 0.22,
			FrostTell = 0.85,
			DesatPerLevel = -0.12,
			DesatTell = -0.45,
			RumbleVolumePerLevel = 0.15,
			FadeSeconds = 1.5,
			GutterSeconds = 2,
			GutterBrightness = 0.25,
			PulseSeconds = 0.6,
			FrostEdgeColor = { 215, 235, 255 },
			EdgeSize = 0.22,
			SoundMaxDistance = 120,
			SoundCleanupSeconds = 10,
		},
	},
	Bosses = {
		MiniBossFirstDay = 6,
		MiniBossMaxAlive = 1,
		MiniBossRespawnDays = 4,
		BlizzardBossFirstDay = 8,
		BlizzardBossChance = 0.35,
		BlizzardBossChancePerDay = 0.02,
		MaxBlizzardBossChance = 0.6,
		HealthPerExtraPlayer = 0.3,
		MaxHealthMultiplier = 2.5,
		DamagePerDay = 0.02,
		MaxDamageMultiplier = 1.5,
	},
	Blizzard = {
		EventId = "Blizzard", -- EventService.onEventEnd id for a blizzard (dark events use data/Events ids)
		ActiveAttribute = "Blizzard",
		WarningAttribute = "BlizzardWarning",
	},
	Projectile = {
		Speed = 140,
		MaxRange = 180,
		MaxLifetime = 2,
		MaxActivePerPlayer = 4,
		AimAssistDegrees = 6,
		FriendlyFireMultiplier = 0.5,
		MeleeFriendlyFire = false,
	},
	Storage = {
		ChestSlots = 20,
		OpenRange = 10,
		MaxChestsPerRun = 4,
		OpenAttribute = "OpenChest",
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
	},
	WarmSpot = {
		Tag = "WarmSpot",
		RadiusAttribute = "WarmSpotRadius",
		CabinRadius = 14,
		HotSpringRadius = 18,
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
	-- Phase 4 (brief 20 consumes; brief 21 owns the values).
	Perf = {
		TargetFps = 30,
		FpsSampleSeconds = 5,
		MaxLiveParts = 6000,
		MaxLiveMobs = MAX_LIVE_MOBS,
		ChunkLoadBudgetPerFrame = 1,
		ChunkPartBudgetPerFrame = 150,
		MaxParticleEmitters = 24,
		MaxParticleRate = 40,
		MaxActiveSounds = 12,
		StreamingEnabled = true,
		StreamingTargetRadius = 384,
		StreamingMinRadius = 96,
		SwingBroadcastRange = 150,
		SwingMaxPerSecond = 12, -- client cap on relayed swings animated per second
	},
	Settings = {
		Keys = { "reduceScares" },
		ReduceScares = "reduceScares",
		ReduceScaresAttribute = "ReduceScares",
		DefaultReduceScares = false,
		ReducedScareVisualMultiplier = 0.4,
	},
	Hints = {
		Ids = {
			"Biomes",
			"Clothing",
			"Map",
			"Storage",
			"Cooking",
			"Repair",
			"Ping",
			"Bow",
			"Blizzard",
			"DarkEvent",
			"Stalker",
			"Shop",
			"Perks",
			"Achievements",
			"Forge",
		},
		ShowSeconds = 12,
		CheckInterval = 1,
		LookupRange = 30,
		WarnWindowSeconds = 90,
	},
	RemoteFolderName = "Remotes",
	DefaultRateLimitInterval = 0.1,
	ProfileStoreName = "PlayerProfiles",
	ProfileKeyPrefix = "Player_",
	StudioAssumeDead = 90, -- ProfileStore default is 630s; autosave keeps live Studio locks fresh (AutoSavePeriod 60)
	StudioStoreSuffix = "_Studio",
	DataFallbackAttribute = "DataFallback",
	AutoSavePeriod = 60,
	SchemaVersion = 3, -- v2: Phase 2 stats, achievements, lastDailyClaim; v3: Phase 4 meta (shop, perks, settings, receipts)
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
