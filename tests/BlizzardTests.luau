--!strict
-- Blizzard wind / whiteout / duration logic tests. Registered in tests/run.luau.

local Config = require("../src/shared/Config")
local BlizzardWind = require("../src/shared/logic/BlizzardWind")
local Events = require("../src/shared/data/Events")
local LightingMath = require("../src/shared/logic/LightingMath")

return function(check: (string, boolean) -> ())
	local B = Config.Blizzard
	check(
		"blizzard: duration = DurationDays x day length",
		math.abs(Events.Blizzard.durationSeconds - B.DurationDays * Config.Time.DayLengthSeconds)
			< 1e-6
	)
	check("blizzard: default ~1.5 days", B.DurationDays == 1.5)
	check("blizzard: vignette clamped <= 0.08", BlizzardWind.vignetteAlpha(0.5, 1) == 0.08)
	check(
		"blizzard: vignette default none",
		BlizzardWind.vignetteAlpha(B.VignetteAlpha, B.VignetteMaxAlpha) == 0
	)
	check("blizzard: vignette never negative", BlizzardWind.vignetteAlpha(-1, 0.08) == 0)

	-- Wind: unit direction, deterministic, bounded strength, direction actually varies.
	local minDir, maxDir = math.huge, -math.huge
	local maxS, minS, gusts, unit = 0, math.huge, 0, true
	for i = 0, 600 do
		local w = BlizzardWind.sample(i * 1.5, 1, B)
		local len = math.sqrt(w.dirX * w.dirX + w.dirZ * w.dirZ)
		unit = unit and math.abs(len - 1) < 1e-6
		local h = math.atan2(w.dirZ, w.dirX)
		minDir, maxDir = math.min(minDir, h), math.max(maxDir, h)
		maxS, minS = math.max(maxS, w.strength), math.min(minS, w.strength)
		if w.gust > 0.5 then
			gusts += 1
		end
	end
	check("blizzard: wind direction is unit", unit)
	check("blizzard: wind direction varies over time", maxDir - minDir > 0.2)
	check(
		"blizzard: wind direction stays within swing",
		maxDir - minDir <= 2 * B.WindDirSwing + 1e-6
	)
	check("blizzard: strength varies and gusts occur", maxS > minS * 1.1 and gusts > 0)
	check(
		"blizzard: strength bounded",
		maxS <= B.WindMaxStrength * 1.15 * (1 + B.GustBoost) + 1e-6 and minS > 0
	)
	check(
		"blizzard: deterministic",
		BlizzardWind.sample(123.4, 0.6, B).strength == BlizzardWind.sample(123.4, 0.6, B).strength
	)
	check(
		"blizzard: stronger at higher intensity",
		BlizzardWind.sample(50, 1, B).strength > BlizzardWind.sample(50, 0.1, B).strength
	)

	-- Emission scales with intensity and respects the cap (mobile lower).
	local life = (B.StreakLifetime[1] + B.StreakLifetime[2]) * 0.5
	local pcCap = BlizzardWind.particleCap(false, B.MaxParticles, B.MaxParticlesMobile)
	local mobCap = BlizzardWind.particleCap(true, B.MaxParticles, B.MaxParticlesMobile)
	check("blizzard: mobile cap lower", mobCap < pcCap)
	local lo = BlizzardWind.emissionRate(0.2, B.RatePerIntensity, pcCap, life)
	local hi = BlizzardWind.emissionRate(1, B.RatePerIntensity, pcCap, life)
	check("blizzard: emission scales with intensity", hi > lo and lo > 0)
	check(
		"blizzard: no emission at zero",
		BlizzardWind.emissionRate(0, B.RatePerIntensity, pcCap, life) == 0
	)
	check(
		"blizzard: live particles never exceed cap",
		BlizzardWind.emissionRate(1, 1e6, mobCap, life) * life <= mobCap + 1e-6
	)

	-- Whiteout ease and amount.
	local p, steps = 0, 0
	while p < 1 and steps < 10000 do
		p = BlizzardWind.approach(p, 1, 0.1, B.EaseSeconds)
		steps += 1
	end
	check("blizzard: eases in over EaseSeconds", math.abs(steps * 0.1 - B.EaseSeconds) < 0.2)
	check("blizzard: eases out", BlizzardWind.approach(1, 0, 1, B.EaseSeconds) < 1)
	check(
		"blizzard: no whiteout when absent",
		BlizzardWind.whiteout(0, 1, B.FullWhiteoutIntensity) == 0
	)
	check(
		"blizzard: full whiteout at peak",
		BlizzardWind.whiteout(1, B.FullWhiteoutIntensity, B.FullWhiteoutIntensity) == 1
	)
	check(
		"blizzard: whiteout monotonic in intensity",
		BlizzardWind.whiteout(1, 0.3, 0.7) < BlizzardWind.whiteout(1, 0.5, 0.7)
	)
	local peakFog = BlizzardWind.lerp(1500, B.PeakVisibility, 1)
	check("blizzard: peak visibility ~60", math.abs(peakFog - 60) <= 10)
	check(
		"blizzard: light scale clamped",
		BlizzardWind.lightScale(0, 150, B.MinLightScale) == B.MinLightScale
	)
	check("blizzard: quantize", BlizzardWind.quantize(0.513, 0.02) == 0.52)

	-- Task 2: denser snow, mobile cap unchanged.
	check("blizzard: snow rate raised >= 2x", B.RatePerIntensity >= 520)
	check("blizzard: mobile cap stays 120", B.MaxParticlesMobile == 120)
	local avgLife = (B.StreakLifetime[1] + B.StreakLifetime[2]) * 0.5
	check(
		"blizzard: full intensity reaches the denser rate under the PC cap",
		BlizzardWind.emissionRate(1, B.RatePerIntensity, B.MaxParticles, avgLife)
			== B.RatePerIntensity
	)

	-- Task 3: visibility = biggest campfire radius, eased.
	local radius = BlizzardWind.maxFireRadius(Config.Fire.Tiers)
	local lastTier = Config.Fire.Tiers[#Config.Fire.Tiers]
	check(
		"blizzard: max fire radius is the last tier",
		radius == lastTier.WarmRadius and radius > 0
	)
	check("blizzard: no tiers -> 0", BlizzardWind.maxFireRadius({}) == 0)
	check("blizzard: fogEnd clear at 0", BlizzardWind.fogEnd(0, radius, 1500) == 1500)
	check("blizzard: fogEnd = radius at 1", BlizzardWind.fogEnd(1, radius, 1500) == radius)
	check(
		"blizzard: fogEnd eases between",
		BlizzardWind.fogEnd(0.5, radius, 1500) == (1500 + radius) / 2
	)
	check("blizzard: fogEnd never beyond clear", BlizzardWind.fogEnd(1, 9999, 400) == 400)
	check("blizzard: fogEnd clamps whiteout", BlizzardWind.fogEnd(5, radius, 1500) == radius)

	-- Task 4: tint follows the time of day.
	check("lighting: noon is day", LightingMath.nightFromClock(13, 13, 0) == 0)
	check("lighting: midnight is night", LightingMath.nightFromClock(0, 13, 0) == 1)
	check(
		"lighting: dusk is between",
		math.abs(LightingMath.nightFromClock(6.5, 13, 0) - 0.5) < 1e-6
	)
	local day = LightingMath.blizzardTint(B.WhiteColor, B.NightColor, 0)
	local nightTint = LightingMath.blizzardTint(B.WhiteColor, B.NightColor, 1)
	check(
		"lighting: day tint is the white",
		day[1] == B.WhiteColor[1] and day[3] == B.WhiteColor[3]
	)
	check(
		"lighting: night tint is dark blue-grey",
		nightTint[1] == B.NightColor[1]
			and nightTint[3] > nightTint[1]
			and nightTint[1] + nightTint[2] + nightTint[3] < 300
	)
	local dusk = LightingMath.blizzardTint(B.WhiteColor, B.NightColor, 0.5)
	check("lighting: dusk tint between", dusk[1] < day[1] and dusk[1] > nightTint[1])
	check(
		"blizzard: atmosphere offset hides the dark sky",
		B.AtmoOffset >= 0.7 and B.AtmoGlare == 0
	)

	-- Task 5: forecast.
	check(
		"blizzard: forecast lead ~half a day",
		math.abs(B.ForecastLeadSeconds - Config.Time.DayLengthSeconds / 2) <= 30
	)
	check("blizzard: forecast text", B.ForecastText == "The wind starts to howl...")
	check(
		"blizzard: forecast due inside the lead window",
		BlizzardWind.forecastDue(1000, 1135, 1180, 180, -1)
	)
	check(
		"blizzard: no forecast before the window",
		not BlizzardWind.forecastDue(100, 1135, 1180, 180, -1)
	)
	check(
		"blizzard: forecast only once per start",
		not BlizzardWind.forecastDue(1000, 1135, 1180, 180, 1180)
	)
	check(
		"blizzard: debug start (warn = now) never forecasts",
		not BlizzardWind.forecastDue(1000, 1000, 1000, 180, -1)
	)

	-- Status line.
	local line = BlizzardWind.statusText({
		active = true,
		phase = "active",
		intensity = 0.5,
		timeLeft = 125,
		untilStart = nil,
		forecastIn = nil,
	})
	check(
		"blizzard: status line has state, intensity, time left",
		string.find(line, "ON", 1, true) ~= nil
			and string.find(line, "0.50", 1, true) ~= nil
			and string.find(line, "2:05", 1, true) ~= nil
	)
	local idle = BlizzardWind.statusText({
		active = false,
		phase = "idle",
		intensity = 0,
		timeLeft = 0,
		untilStart = 200,
		forecastIn = 20,
	})
	check(
		"blizzard: idle status shows next + forecast",
		string.find(idle, "next 3:20", 1, true) ~= nil
			and string.find(idle, "forecast 0:20", 1, true) ~= nil
	)
	check("blizzard: status fits a toast", #idle <= 80 and #line <= 80)
end
