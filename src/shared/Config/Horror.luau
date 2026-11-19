--!strict
-- Config module: Horror. Horror and events: dark events, blizzard, dread, isolation, stalker, lurkers, scares, cue kinds.
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

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

export type BlizzardConfig = {
	EventId: string, -- EventService event id for a blizzard (onEventEnd)
	ActiveAttribute: string, -- Workspace attribute: true during a blizzard (visible weather)
	WarningAttribute: string, -- Workspace attribute: true during the warning (visible sky cue)
	DurationDays: number, -- blizzard length in game days (x Time.DayLengthSeconds); not capped by Events.MaxDurationSeconds
	VignetteAlpha: number, -- max screen vignette alpha (clamped to <= VignetteMaxAlpha in code; 0 = none)
	VignetteMaxAlpha: number, -- hard ceiling for the vignette
	IntensityAttribute: string, -- Workspace attribute: current blizzard intensity 0..1 (server, 0 when none)
	IntensityStep: number, -- intensity attribute rounded to this step (limits replication writes)
	EaseSeconds: number, -- whiteout / particle ease in and out
	WarningPresence: number, -- 0..1 share of the effect shown during the warning
	-- Wind (pure noise over server time; see logic/BlizzardWind).
	WindSeed: number,
	WindDirPeriod: number, -- seconds for the wind direction noise to move one unit
	WindDirSwing: number, -- radians the direction wanders either side of the base heading
	WindBaseHeading: number, -- radians
	WindStrengthPeriod: number,
	WindMinStrength: number, -- studs/s of horizontal particle speed at intensity 0
	WindMaxStrength: number, -- studs/s at intensity 1
	GustPeriod: number, -- seconds between gust noise features
	GustBoost: number, -- extra strength share at full gust (0.5 = +50%)
	GustThreshold: number, -- noise above this counts as a gust (0..1)
	-- Snow particles (client only, follow the camera).
	Texture: string, -- built-in particle texture
	StreakWidth: number,
	StreakSquash: number, -- ParticleEmitter.Squash: stretches the streak along its velocity
	StreakLifetime: { number }, -- min, max seconds
	StreakTransparency: number,
	LightEmission: number,
	SpawnWidth: number, -- studs: emitter volume edge (across the wind)
	SpawnHeight: number,
	SpawnUpwind: number, -- studs upwind of the camera the volume sits
	RatePerIntensity: number, -- particles/second at intensity 1 (before the cap)
	MaxParticles: number, -- hard live-particle cap (PC)
	MaxParticlesMobile: number, -- hard live-particle cap (touch devices)
	WindUpdateInterval: number, -- seconds between wind/emitter writes
	-- Whiteout (client Atmosphere + fog).
	PeakVisibility: number, -- studs of visibility at peak (fog end)
	FogStartPeak: number,
	FullWhiteoutIntensity: number, -- intensity at which the whiteout reaches its peak
	WhiteColor: { number }, -- {r, g, b} 0-255 at full daylight
	MinLightScale: number, -- darkest the white is scaled to at night (0..1)
	AtmoDensity: number,
	AtmoOffset: number,
	AtmoHaze: number,
	AtmoGlare: number, -- Atmosphere.Glare at peak (0 = no sun disc seam)
	NightColor: { number }, -- {r, g, b} 0-255 fog / haze tint at full night (dark blue-grey)
	AmbientMix: number, -- 0..1 share of Ambient / OutdoorAmbient blended toward the tint at peak whiteout
	-- Forecast (server toasts via Remotes.Notify; cue via Remotes.Cue, never per tick).
	ForecastLeadSeconds: number, -- toast this long before the blizzard starts (~half a day)
	ForecastText: string,
	ArrivalText: string,
	ForecastCue: string, -- Remotes.Cue kind (data/AudioCues row)
	NotifyKind: string, -- Remotes.Notify kind
	-- Glow that stays faintly visible in the whiteout.
	GlowTags: { string },
	GlowMax: number, -- nearest N glow targets
	GlowRange: number, -- studs
	GlowColor: { number },
	GlowTransparency: number, -- fill transparency at peak whiteout (higher = fainter)
	GlowOutlineTransparency: number,
}

export type Sections = {
	Events: EventsConfig,
	Dread: DreadConfig,
	Isolation: IsolationConfig,
	Stalker: StalkerConfig,
	Lurkers: LurkerConfig,
	Scares: ScaresConfig,
	Cue: CueConfig,
	Blizzard: BlizzardConfig,
}

local Sections: Sections = {
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
			"BlizzardForecast", -- ~half a day before a blizzard (sound hook; toast comes through Notify)
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
	Blizzard = {
		EventId = "Blizzard", -- EventService.onEventEnd id for a blizzard (dark events use data/Events ids)
		ActiveAttribute = "Blizzard",
		WarningAttribute = "BlizzardWarning",
		DurationDays = 1.5, -- ~9 min at 6-min days
		VignetteAlpha = 0,
		VignetteMaxAlpha = 0.08,
		IntensityAttribute = "BlizzardIntensity",
		IntensityStep = 0.02,
		EaseSeconds = 20,
		WarningPresence = 0.12,
		WindSeed = 7.31,
		WindDirPeriod = 38,
		WindDirSwing = 0.7,
		WindBaseHeading = 0.6,
		WindStrengthPeriod = 14,
		WindMinStrength = 45,
		WindMaxStrength = 95,
		GustPeriod = 9,
		GustBoost = 0.55,
		GustThreshold = 0.25,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		StreakWidth = 0.12,
		StreakSquash = -2.5,
		StreakLifetime = { 0.7, 1.2 },
		StreakTransparency = 0.35,
		LightEmission = 1,
		SpawnWidth = 90,
		SpawnHeight = 50,
		SpawnUpwind = 40,
		RatePerIntensity = 720, -- ~2.8x the old 260
		MaxParticles = 900, -- PC cap scaled with the rate (mobile cap unchanged)
		MaxParticlesMobile = 120,
		WindUpdateInterval = 0.1,
		PeakVisibility = 60,
		FogStartPeak = 4,
		FullWhiteoutIntensity = 0.7,
		WhiteColor = { 236, 242, 250 },
		MinLightScale = 0.45,
		AtmoDensity = 0.55,
		AtmoOffset = 0.8, -- high offset hides the dark sky above the horizon (no black band over a white wall)
		AtmoHaze = 2.2,
		AtmoGlare = 0,
		NightColor = { 54, 64, 88 },
		AmbientMix = 0.35,
		ForecastLeadSeconds = 180, -- ~half a 6-min day
		ForecastText = "The wind starts to howl...",
		ArrivalText = "The blizzard has arrived. Stay near a fire.",
		ForecastCue = "BlizzardForecast",
		NotifyKind = "event",
		GlowTags = { "Campfire", "WarmSpot" }, -- (StructureBeacon was never applied; removed)
		GlowMax = 6,
		GlowRange = 220,
		GlowColor = { 255, 170, 90 },
		GlowTransparency = 0.82,
		GlowOutlineTransparency = 0.55,
	},
}

return Sections
