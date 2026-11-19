--!strict
-- Pure lighting interpolation (no Roblox APIs). Colors are {r, g, b} 0-255 number triples.

local LightingMath = {}

local function smooth(t: number): number
	local c = math.clamp(t, 0, 1)
	return c * c * (3 - 2 * c)
end

-- 0 = full day, 1 = full night. Dusk ramps up over the last `twilight` of daylight (ending when night
-- begins at `dayFraction`); dawn ramps down over the last `twilight` of the night (ending at day start).
function LightingMath.nightAmount(phase: number, dayFraction: number, twilight: number): number
	local p = phase % 1
	if twilight <= 0 then
		return if p >= dayFraction then 1 else 0
	end
	if p < dayFraction - twilight then
		return 0
	elseif p < dayFraction then
		return smooth((p - (dayFraction - twilight)) / twilight)
	elseif p < 1 - twilight then
		return 1
	end
	return 1 - smooth((p - (1 - twilight)) / twilight)
end

function LightingMath.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function LightingMath.lerpColor(a: { number }, b: { number }, t: number): { number }
	return {
		LightingMath.lerp(a[1], b[1], t),
		LightingMath.lerp(a[2], b[2], t),
		LightingMath.lerp(a[3], b[3], t),
	}
end

-- Warm light range for a fire: the warm radius scaled and clamped to the engine cap.
function LightingMath.fireLightRange(warmRadius: number, scale: number, maxRange: number): number
	return math.clamp(warmRadius * scale, 0, maxRange)
end

-- 0 = day, 1 = night from the replicated Lighting.ClockTime (server writes mix(DayClock, NightClock, n)).
function LightingMath.nightFromClock(clock: number, dayClock: number, nightClock: number): number
	local span = dayClock - nightClock
	if math.abs(span) < 1e-6 then
		return 0
	end
	return math.clamp((dayClock - clock) / span, 0, 1)
end

-- Blizzard tint for the time of day: dayTint by day, nightTint (dark blue-grey) by night.
function LightingMath.blizzardTint(
	dayTint: { number },
	nightTint: { number },
	night: number
): { number }
	return LightingMath.lerpColor(dayTint, nightTint, math.clamp(night, 0, 1))
end

return LightingMath
