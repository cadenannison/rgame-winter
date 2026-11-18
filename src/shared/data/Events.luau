--!strict
-- Dark events and blizzard (pure data). Owner: brief 14 (EventService). Consumers: 15, 16, 18.
-- Scheduling rules and hard caps: Config.Events (no event before FirstDay, MinGapSeconds, MaxPerDay,
-- MaxChancePerCheck, BlizzardBufferSeconds). Timers stay server-side; clients get Remotes.Cue only.

local Config = require("../Config")
local Types = require("./Types")

local Events = {}

Events.Dark = {
	{
		id = "FalseNight",
		name = "False Night",
		minDay = 3,
		weight = 3,
		warningSeconds = 15,
		durationSeconds = 150,
		warningCue = "WarnFalseNight",
		blockedByFullGroup = true,
		nightRules = true,
		silence = false,
		warmthDrainMultiplier = 1.6, -- equals Meters.WarmthDrainNightMultiplier
		fuelBurnMultiplier = 1,
		dreadGainMultiplier = 1.5,
		huntChanceBonus = 0,
	},
	{
		id = "TheQuiet",
		name = "The Quiet",
		minDay = 4,
		weight = 2,
		warningSeconds = 10,
		durationSeconds = 60,
		warningCue = "WarnTheQuiet",
		blockedByFullGroup = true,
		nightRules = false,
		silence = true,
		warmthDrainMultiplier = 1,
		fuelBurnMultiplier = 1,
		dreadGainMultiplier = 1.5,
		huntChanceBonus = 0.1,
	},
	{
		id = "DeepFreeze",
		name = "Deep Freeze",
		minDay = 3,
		weight = 3,
		warningSeconds = 20,
		durationSeconds = 180,
		warningCue = "WarnDeepFreeze",
		blockedByFullGroup = false,
		nightRules = false,
		silence = false,
		warmthDrainMultiplier = 1.8,
		fuelBurnMultiplier = 1.8,
		dreadGainMultiplier = 1,
		huntChanceBonus = 0,
	},
} :: { Types.EventDef }

-- Blizzard cadence stays in Config.Time (BlizzardMinGap/MaxGap days, BlizzardWarningSeconds).
Events.Blizzard = {
	warningSeconds = 45, -- equals Config.Time.BlizzardWarningSeconds (tested)
	durationSeconds = 150,
	warmthDrainMultiplier = 1.8,
	dreadGainMultiplier = 1.5,
	fogEnd = 120,
	warningCue = "WarnBlizzard",
} :: Types.BlizzardDef

-- Event-only tuning owned here (caps MinVisibility / MaxSpawnMultiplier live in Config.Events).
Events.Tuning = {
	BlizzardVisibilityMin = 0.35, -- visibility multiplier at full intensity (1 = normal)
	FalseNightVisibility = 0.6,
	MinVisibility = Config.Events.MinVisibility, -- hard floor for any visibility modifier
	BlizzardSpawnMultiplier = 1.6, -- extra-mob budget multiplier at full intensity
	FalseNightSpawnMultiplier = 1.3,
	MaxSpawnMultiplier = Config.Events.MaxSpawnMultiplier, -- hard cap for any spawn modifier
	RampStart = 0.3, -- blizzard intensity when it hits (escalates from here)
	RampUpFraction = 0.6, -- share of the duration spent escalating to full
	FadeFraction = 0.1, -- share of the duration spent easing off at the end
	FirstBlizzardScale = 0.7, -- first blizzard peaks at this fraction; later ones escalate
	ScalePerBlizzard = 0.1, -- peak scale gained per earlier blizzard (max 1)
	StartFractionMax = 0.9, -- blizzard start falls within this share of its day
	StepSeconds = 0.5, -- server schedule step
}

Events.ById = {} :: { [string]: Types.EventDef }
for _, def in Events.Dark do
	Events.ById[def.id] = def
end

return Events
