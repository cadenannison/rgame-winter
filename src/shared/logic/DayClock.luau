--!strict
-- Pure day/night clock math. No Roblox APIs.

export type TimeCfg = {
	DayLengthSeconds: number,
	DayFraction: number,
	StartClockHour: number,
}

export type Info = {
	day: number, -- 1-based day counter
	isNight: boolean,
	hour: number, -- in-game hour [0, 24)
	phase: number, -- [0, 1) progress through the day
}

local DAYLIGHT_HOURS = 12 -- in-game hours mapped onto the daylight span
local HOURS_PER_DAY = 24

local DayClock = {}

-- Daylight is the first DayFraction of the day and starts at StartClockHour; night is the rest.
function DayClock.at(elapsed: number, t: TimeCfg): Info
	local e = math.max(elapsed, 0)
	local day = math.floor(e / t.DayLengthSeconds) + 1
	local phase = (e % t.DayLengthSeconds) / t.DayLengthSeconds
	local isNight = phase >= t.DayFraction
	local hour: number
	if isNight then
		hour = t.StartClockHour
			+ DAYLIGHT_HOURS
			+ (phase - t.DayFraction) / (1 - t.DayFraction) * DAYLIGHT_HOURS
	else
		hour = t.StartClockHour + phase / t.DayFraction * DAYLIGHT_HOURS
	end
	return { day = day, isNight = isNight, hour = hour % HOURS_PER_DAY, phase = phase }
end

-- Elapsed seconds at the start (dawn) of a given day.
function DayClock.elapsedForDay(day: number, t: TimeCfg): number
	return (math.max(day, 1) - 1) * t.DayLengthSeconds
end

-- True when the published Day attribute value is a new day (dawn: the counter rolls over as the night ends
-- and daylight starts at StartClockHour). lastDay nil = first observation (nothing to regrow yet, harmless).
function DayClock.isNewDay(lastDay: number?, day: unknown): boolean
	return type(day) == "number" and day == day and day ~= lastDay
end

return DayClock
