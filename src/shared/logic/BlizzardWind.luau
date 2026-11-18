--!strict
-- Pure blizzard wind / intensity / whiteout math (no Roblox APIs). Wind is a deterministic function of
-- (server time, seed) so every client agrees without a remote. Values come from Config.Blizzard.

export type WindCfg = {
	WindSeed: number,
	WindDirPeriod: number,
	WindDirSwing: number,
	WindBaseHeading: number,
	WindStrengthPeriod: number,
	WindMinStrength: number,
	WindMaxStrength: number,
	GustPeriod: number,
	GustBoost: number,
	GustThreshold: number,
}

export type Wind = {
	dirX: number, -- unit horizontal direction the wind blows toward
	dirZ: number,
	strength: number, -- studs/s horizontal particle speed (gusts included)
	gust: number, -- 0..1
}

local BlizzardWind = {}

-- Smooth 1D value noise in [0, 1] built from sines (portable, no math.noise dependency).
function BlizzardWind.noise(x: number, seed: number): number
	local a = math.sin(x * 1.0 + seed * 12.9898)
	local b = math.sin(x * 2.17 + seed * 78.233 + 1.3)
	local c = math.sin(x * 0.53 + seed * 37.719 + 4.1)
	return math.clamp((a * 0.5 + b * 0.3 + c * 0.2) * 0.5 + 0.5, 0, 1)
end

function BlizzardWind.clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

-- Wind at `t` seconds for blizzard `intensity` (0..1). Direction wanders around the base heading;
-- strength scales with intensity; gusts add a burst on top.
function BlizzardWind.sample(t: number, intensity: number, c: WindCfg): Wind
	local i = math.clamp(intensity, 0, 1)
	local n = BlizzardWind.noise(t / math.max(c.WindDirPeriod, 1e-3), c.WindSeed)
	local heading = c.WindBaseHeading + (n * 2 - 1) * c.WindDirSwing
	local s = BlizzardWind.noise(t / math.max(c.WindStrengthPeriod, 1e-3), c.WindSeed + 11.7)
	local g = BlizzardWind.noise(t / math.max(c.GustPeriod, 1e-3), c.WindSeed + 23.9)
	local thr = math.clamp(c.GustThreshold, 0, 0.99)
	local gust = math.clamp((g - (1 - thr) * 0.6 - 0.2) / math.max(thr, 0.01), 0, 1)
	local base = c.WindMinStrength + (c.WindMaxStrength - c.WindMinStrength) * i
	local strength = base * (0.85 + 0.3 * s) * (1 + c.GustBoost * gust * i)
	return { dirX = math.cos(heading), dirZ = math.sin(heading), strength = strength, gust = gust }
end

-- Particles per second: scales with intensity, never above what keeps live particles <= cap.
function BlizzardWind.emissionRate(
	intensity: number,
	ratePerIntensity: number,
	maxParticles: number,
	avgLifetime: number
): number
	local wanted = ratePerIntensity * math.clamp(intensity, 0, 1)
	local ceiling = maxParticles / math.max(avgLifetime, 1e-3)
	return math.max(0, math.min(wanted, ceiling))
end

function BlizzardWind.particleCap(isMobile: boolean, pc: number, mobile: number): number
	return if isMobile then mobile else pc
end

-- Moves `current` toward `target` taking `easeSeconds` for a full 0..1 swing.
function BlizzardWind.approach(
	current: number,
	target: number,
	dt: number,
	easeSeconds: number
): number
	local step = dt / math.max(easeSeconds, 1e-3)
	if current < target then
		return math.min(target, current + step)
	end
	return math.max(target, current - step)
end

local function smooth(t: number): number
	local c = math.clamp(t, 0, 1)
	return c * c * (3 - 2 * c)
end

-- Whiteout amount 0..1 from eased presence and intensity (peak reached at fullIntensity).
function BlizzardWind.whiteout(presence: number, intensity: number, fullIntensity: number): number
	local k = math.clamp(intensity / math.max(fullIntensity, 1e-3), 0, 1)
	return smooth(presence) * smooth(k)
end

function BlizzardWind.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Vignette alpha clamped to [0, ceiling].
function BlizzardWind.vignetteAlpha(requested: number, ceiling: number): number
	return math.clamp(requested, 0, math.clamp(ceiling, 0, 0.08))
end

-- Brightness scale for the white (night dimmer), from the ratio of current to day outdoor light.
function BlizzardWind.lightScale(current: number, day: number, minScale: number): number
	if day <= 0 then
		return 1
	end
	return math.clamp(current / day, math.clamp(minScale, 0, 1), 1)
end

-- Server-side step quantiser so the intensity attribute is not written every tick.
function BlizzardWind.quantize(x: number, step: number): number
	if step <= 0 then
		return x
	end
	return math.floor(x / step + 0.5) * step
end

return BlizzardWind
