--!strict
-- Blizzard wind / whiteout / duration logic tests. Registered in tests/run.luau.

local Config = require("../src/shared/Config")
local BlizzardWind = require("../src/shared/logic/BlizzardWind")
local Events = require("../src/shared/data/Events")

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
end
