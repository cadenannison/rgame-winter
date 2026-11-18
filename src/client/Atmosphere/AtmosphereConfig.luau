--!strict
-- Client-local presentation constants for the atmosphere layer (brief 20). Caps and gameplay numbers stay
-- in shared/Config (Perf, Settings, Hints); sounds and particle textures come from shared/Assets only.

local AtmosphereConfig = {
	SoundCleanupSeconds = 8, -- hard stop for any one-shot sound that never fires Ended
	SoundMaxDistance = 120, -- RollOffMaxDistance for positional sounds
	EmitCount = 12, -- particles per one-shot burst before caps and scaling
	ParticleLifetime = 1.2,
	ParticleSpeed = 8,
	ParticleSize = 0.8,
	BurstCleanupSeconds = 3,
	-- Ambient loop (one loop for every ambient emitter and sound).
	LoopInterval = 0.25, -- seconds between ambient updates
	LoopFadePerSecond = 1.2, -- volume units/second a loop fades toward its target
	SnowHeight = 26, -- studs above the camera for the falling-snow volume
	SnowAreaSize = 70, -- studs: edge of the snow volume
	SnowRate = 14, -- base particles/second (clamped to Perf.MaxParticleRate)
	BlizzardRateScale = 2.5,
	FireCrackleRange = 40, -- studs within which the nearest fire is audible
	FireEmberRate = 6,
	-- Day banner.
	BannerSeconds = 2.5,
	BannerFadeSeconds = 0.6,
	BannerText = "Day {day} survived",
	-- Settings UI (>= 44 px touch targets).
	ButtonSize = 48,
	ButtonPosition = UDim2.fromScale(0.985, 0.2),
	PanelWidth = 280,
	ToggleHeight = 48,
	PanelColor = Color3.fromRGB(18, 28, 40),
	TextColor = Color3.fromRGB(232, 242, 250),
	OnColor = Color3.fromRGB(110, 190, 130),
	OffColor = Color3.fromRGB(70, 84, 100),
	ReduceScaresLabel = "Reduce scares",
	ReduceScaresHelp = "Softer frost, no flashes, calmer visuals. Danger is unchanged.",
	SettingsLabel = "Settings",
	OverrideSeconds = 3, -- how long an optimistic toggle stands before the server value wins
	-- Hints (timings and lookup range live in Config.Hints).
	HintPosition = UDim2.new(0.5, 0, 0, 64),
	HintWidth = 340,
	HintGuiOrder = 6,
	DisplayOrder = 7,
}

return AtmosphereConfig
