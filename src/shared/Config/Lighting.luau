--!strict
-- Config module: Lighting. Lighting and atmosphere values (Config.Lighting).
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

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
	-- Moonlight: the night readability floor (ground and silhouettes visible, still clearly darker than day).
	-- Scary events may darken below it. All tunable.
	MoonAmbient: { number }, -- {r, g, b} minimum Lighting.Ambient at full night
	MoonOutdoorAmbient: { number }, -- minimum Lighting.OutdoorAmbient at full night
	MoonBrightness: number, -- minimum Lighting.Brightness at full night (soft moon light)
	MoonExposure: number, -- Lighting.ExposureCompensation at full night (0 by day)
}

export type Sections = {
	Lighting: LightingConfig,
}

local Sections: Sections = {
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
		MoonAmbient = { 66, 76, 108 },
		MoonOutdoorAmbient = { 88, 100, 138 },
		MoonBrightness = 1.1,
		MoonExposure = 0.35,
	},
}

return Sections
