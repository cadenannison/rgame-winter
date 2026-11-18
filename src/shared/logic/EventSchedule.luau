--!strict
-- Pure, seed-deterministic scheduling for dark events and blizzards. No Roblox APIs.
-- All times are run-elapsed seconds. State is server-only; clients never see timers.

local Clamp = require("./Clamp")

export type EventsCfg = {
	FirstDay: number,
	MinGapSeconds: number,
	CheckIntervalSeconds: number,
	BaseChancePerCheck: number,
	ChancePerDay: number,
	MaxChancePerCheck: number,
	MaxPerDay: number,
	BlizzardBufferSeconds: number,
	MinWarningSeconds: number,
	MaxWarningSeconds: number,
	MaxDurationSeconds: number,
	MaxWarmthDrainMultiplier: number,
	MaxFuelBurnMultiplier: number,
	MaxDreadGainMultiplier: number,
	MaxHuntChanceBonus: number,
}
export type TimeCfg = {
	DayLengthSeconds: number,
	BlizzardMinGap: number,
	BlizzardMaxGap: number,
}
export type DarkDef = {
	id: string,
	name: string,
	warningCue: string,
	minDay: number,
	weight: number,
	warningSeconds: number,
	durationSeconds: number,
	blockedByFullGroup: boolean,
	nightRules: boolean,
	silence: boolean,
	warmthDrainMultiplier: number,
	fuelBurnMultiplier: number,
	dreadGainMultiplier: number,
	huntChanceBonus: number,
}
export type BlizzardDef = {
	warningSeconds: number,
	durationSeconds: number,
	warmthDrainMultiplier: number,
	dreadGainMultiplier: number,
}
export type Tuning = {
	BlizzardVisibilityMin: number,
	FalseNightVisibility: number,
	MinVisibility: number,
	BlizzardSpawnMultiplier: number,
	FalseNightSpawnMultiplier: number,
	MaxSpawnMultiplier: number,
	RampStart: number,
	RampUpFraction: number,
	FadeFraction: number,
	FirstBlizzardScale: number,
	ScalePerBlizzard: number,
	StartFractionMax: number,
}
export type Params = {
	events: EventsCfg,
	time: TimeCfg,
	dark: { DarkDef },
	blizzard: BlizzardDef,
	tune: Tuning,
}

export type Phase = "idle" | "warning" | "active"
export type State = {
	rng: number,
	bPhase: Phase,
	bWarnAt: number,
	bStartAt: number,
	bEndAt: number,
	bLastEnd: number,
	bCount: number, -- blizzards started so far
	dPhase: Phase,
	dDef: DarkDef?,
	dStartAt: number,
	dEndAt: number,
	dWarnAt: number,
	dLastEnd: number,
	startsByDay: { [number]: number },
	nextCheckAt: number,
}
export type Transition = { kind: string, id: string }
export type Modifiers = {
	warmthDrain: number,
	fuelBurn: number,
	dreadGain: number,
	huntBonus: number,
	nightRules: boolean,
	silence: boolean,
	visibility: number,
	spawn: number,
	blizzard: boolean,
}

local MODULUS = 2147483647
local MULTIPLIER = 48271

local EventSchedule = {}

local function nextRandom(state: State): number
	state.rng = (state.rng * MULTIPLIER) % MODULUS
	return state.rng / MODULUS
end

local function randInt(state: State, lo: number, hi: number): number
	return lo + math.min(hi - lo, math.floor(nextRandom(state) * (hi - lo + 1)))
end

local function dayIndex(now: number, p: Params): number
	return math.floor(math.max(now, 0) / p.time.DayLengthSeconds)
end

local function darkWarning(def: DarkDef, p: Params): number
	return Clamp.clamp(def.warningSeconds, p.events.MinWarningSeconds, p.events.MaxWarningSeconds)
end

local function darkDuration(def: DarkDef, p: Params): number
	return math.min(def.durationSeconds, p.events.MaxDurationSeconds)
end

local function blizzardDuration(p: Params): number
	return math.min(p.blizzard.durationSeconds, p.events.MaxDurationSeconds)
end

-- Next blizzard: BlizzardMinGap..BlizzardMaxGap days (randomized) after `fromTime`. The first one
-- also gets a random time within its day.
local function scheduleBlizzard(state: State, p: Params, fromTime: number, first: boolean)
	local gap = randInt(state, p.time.BlizzardMinGap, p.time.BlizzardMaxGap)
	local len = p.time.DayLengthSeconds
	local start = fromTime + gap * len
	if first then
		start += nextRandom(state) * p.tune.StartFractionMax * len
	end
	state.bStartAt = start
	state.bWarnAt = math.max(0, start - p.blizzard.warningSeconds)
	state.bEndAt = start + blizzardDuration(p)
	state.bPhase = "idle"
end

function EventSchedule.new(seed: number, p: Params, now: number): State
	local s = math.floor(math.abs(seed)) % MODULUS
	if s == 0 then
		s = 1
	end
	local state: State = {
		rng = s,
		bPhase = "idle",
		bWarnAt = 0,
		bStartAt = 0,
		bEndAt = 0,
		bLastEnd = -math.huge,
		bCount = 0,
		dPhase = "idle",
		dDef = nil,
		dStartAt = 0,
		dEndAt = 0,
		dWarnAt = 0,
		dLastEnd = -math.huge,
		startsByDay = {},
		nextCheckAt = now + p.events.CheckIntervalSeconds,
	}
	scheduleBlizzard(state, p, dayIndex(now, p) * p.time.DayLengthSeconds, true)
	return state
end

-- Chance of a dark event start per check on this day (1-based). Zero before FirstDay; hard capped.
function EventSchedule.chance(day: number, p: Params): number
	local e = p.events
	if day < e.FirstDay then
		return 0
	end
	return math.min(e.MaxChancePerCheck, e.BaseChancePerCheck + e.ChancePerDay * (day - e.FirstDay))
end

-- Can a dark event whose warning+duration is `span` seconds start at `now`? Returns (ok, reason).
function EventSchedule.canStart(
	state: State,
	now: number,
	p: Params,
	span: number?
): (boolean, string)
	local e = p.events
	local day = dayIndex(now, p) + 1
	local total = span or (e.MaxWarningSeconds + e.MaxDurationSeconds)
	if day < e.FirstDay then
		return false, "FirstDay"
	end
	if state.dPhase ~= "idle" then
		return false, "Active"
	end
	if state.bPhase ~= "idle" then
		return false, "Blizzard"
	end
	if now - state.dLastEnd < e.MinGapSeconds then
		return false, "MinGap"
	end
	if now - state.bLastEnd < e.BlizzardBufferSeconds then
		return false, "BlizzardBuffer"
	end
	if (state.startsByDay[day] or 0) >= e.MaxPerDay then
		return false, "MaxPerDay"
	end
	if state.bWarnAt - (now + total) < e.BlizzardBufferSeconds then
		return false, "BlizzardBuffer"
	end
	return true, "ok"
end

local function pickDark(state: State, day: number, fullGroup: boolean, p: Params): DarkDef?
	local total = 0
	for _, def in p.dark do
		if def.minDay <= day and not (fullGroup and def.blockedByFullGroup) then
			total += def.weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = nextRandom(state) * total
	for _, def in p.dark do
		if def.minDay <= day and not (fullGroup and def.blockedByFullGroup) then
			roll -= def.weight
			if roll < 0 then
				return def
			end
		end
	end
	return nil
end

local function beginDark(state: State, def: DarkDef, now: number, p: Params)
	local day = dayIndex(now, p) + 1
	state.dDef = def
	state.dPhase = "warning"
	state.dWarnAt = now
	state.dStartAt = now + darkWarning(def, p)
	state.dEndAt = state.dStartAt + darkDuration(def, p)
	state.startsByDay[day] = (state.startsByDay[day] or 0) + 1
end

-- Debug/QA: force a dark event (still never during a blizzard or another event). Returns ok.
function EventSchedule.forceDark(state: State, now: number, id: string, p: Params): boolean
	if state.dPhase ~= "idle" or state.bPhase ~= "idle" then
		return false
	end
	for _, def in p.dark do
		if def.id == id then
			beginDark(state, def, now, p)
			return true
		end
	end
	return false
end

-- Debug/QA: force a blizzard warning now (not during a dark event).
function EventSchedule.forceBlizzard(state: State, now: number, p: Params): boolean
	if state.dPhase ~= "idle" or state.bPhase ~= "idle" then
		return false
	end
	state.bWarnAt = now
	state.bStartAt = now + p.blizzard.warningSeconds
	state.bEndAt = state.bStartAt + blizzardDuration(p)
	return true
end

-- Advances the schedule to `now`; returns transitions in order.
-- kinds: BlizzardWarn, BlizzardStart, BlizzardEnd, DarkWarn, DarkStart, DarkEnd.
function EventSchedule.step(
	state: State,
	now: number,
	fullGroup: boolean,
	p: Params
): { Transition }
	local out: { Transition } = {}
	-- Blizzard
	if state.bPhase == "idle" and now >= state.bWarnAt and state.dPhase == "idle" then
		state.bPhase = "warning"
		table.insert(out, { kind = "BlizzardWarn", id = "Blizzard" })
	end
	if state.bPhase == "warning" and now >= state.bStartAt then
		state.bPhase = "active"
		state.bCount += 1
		table.insert(out, { kind = "BlizzardStart", id = "Blizzard" })
	end
	if state.bPhase == "active" and now >= state.bEndAt then
		state.bPhase = "idle"
		state.bLastEnd = now
		table.insert(out, { kind = "BlizzardEnd", id = "Blizzard" })
		scheduleBlizzard(state, p, state.bStartAt, false)
		-- a re-schedule must land after now (debug jumps)
		if state.bWarnAt <= now then
			scheduleBlizzard(state, p, now, false)
		end
	end
	-- Dark event
	local def = state.dDef
	if state.dPhase == "warning" and def and now >= state.dStartAt then
		state.dPhase = "active"
		table.insert(out, { kind = "DarkStart", id = def.id })
	end
	if state.dPhase == "active" and def and now >= state.dEndAt then
		state.dPhase = "idle"
		state.dDef = nil
		state.dLastEnd = now
		table.insert(out, { kind = "DarkEnd", id = def.id })
	end
	if state.dPhase == "idle" and state.bPhase == "idle" and now >= state.nextCheckAt then
		state.nextCheckAt = now + p.events.CheckIntervalSeconds
		local day = dayIndex(now, p) + 1
		local chance = EventSchedule.chance(day, p)
		if chance > 0 and nextRandom(state) < chance then
			local pick = pickDark(state, day, fullGroup, p)
			if pick then
				local span = darkWarning(pick, p) + darkDuration(pick, p)
				if EventSchedule.canStart(state, now, p, span) then
					beginDark(state, pick, now, p)
					table.insert(out, { kind = "DarkWarn", id = pick.id })
				end
			end
		end
	end
	return out
end

-- Blizzard intensity [0,1]: eases in from RampStart, escalates to the peak, then eases off.
-- `count` = blizzards started so far (the current one included); later blizzards peak higher.
function EventSchedule.blizzardIntensity(progress: number, count: number, t: Tuning): number
	local x = Clamp.clamp(progress, 0, 1)
	local peak = math.min(1, t.FirstBlizzardScale + t.ScalePerBlizzard * math.max(count - 1, 0))
	local ramp: number
	if x < t.RampUpFraction then
		ramp = t.RampStart + (1 - t.RampStart) * (x / t.RampUpFraction)
	elseif x > 1 - t.FadeFraction then
		ramp = t.RampStart + (1 - t.RampStart) * ((1 - x) / t.FadeFraction)
	else
		ramp = 1
	end
	return Clamp.clamp(ramp * peak, 0, 1)
end

-- Coarse cue level 1..maxLevel for an intensity (0 -> 0).
function EventSchedule.cueLevel(intensity: number, maxLevel: number): number
	if intensity <= 0 then
		return 0
	end
	return Clamp.clamp(math.ceil(intensity * maxLevel), 1, maxLevel)
end

-- Coarse warning level 1..maxLevel by progress through the warning (rises as the event nears).
function EventSchedule.warningLevel(state: State, now: number, maxLevel: number): number
	local from: number, to: number
	if state.bPhase == "warning" then
		from, to = state.bWarnAt, state.bStartAt
	elseif state.dPhase == "warning" then
		from, to = state.dWarnAt, state.dStartAt
	else
		return 0
	end
	local progress = Clamp.clamp((now - from) / math.max(to - from, 1e-6), 0, 0.999)
	return Clamp.clamp(1 + math.floor(progress * maxLevel), 1, maxLevel)
end

function EventSchedule.isBlizzardActive(state: State): boolean
	return state.bPhase == "active"
end

function EventSchedule.activeDark(state: State): string
	if state.dPhase == "active" and state.dDef then
		return state.dDef.id
	end
	return ""
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Capped modifiers right now. Warnings are cues only and change nothing.
function EventSchedule.modifiers(state: State, now: number, p: Params): Modifiers
	local e, t = p.events, p.tune
	local m: Modifiers = {
		warmthDrain = 1,
		fuelBurn = 1,
		dreadGain = 1,
		huntBonus = 0,
		nightRules = false,
		silence = false,
		visibility = 1,
		spawn = 1,
		blizzard = false,
	}
	if state.bPhase == "active" then
		local dur = math.max(state.bEndAt - state.bStartAt, 1e-6)
		local i = EventSchedule.blizzardIntensity((now - state.bStartAt) / dur, state.bCount, t)
		m.blizzard = true
		m.warmthDrain = lerp(1, p.blizzard.warmthDrainMultiplier, i)
		m.dreadGain = lerp(1, p.blizzard.dreadGainMultiplier, i)
		m.visibility = lerp(1, t.BlizzardVisibilityMin, i)
		m.spawn = lerp(1, t.BlizzardSpawnMultiplier, i)
	elseif state.dPhase == "active" and state.dDef then
		local def = state.dDef
		m.warmthDrain = def.warmthDrainMultiplier
		m.fuelBurn = def.fuelBurnMultiplier
		m.dreadGain = def.dreadGainMultiplier
		m.huntBonus = def.huntChanceBonus
		m.nightRules = def.nightRules
		m.silence = def.silence
		if def.nightRules then
			m.visibility = t.FalseNightVisibility
			m.spawn = t.FalseNightSpawnMultiplier
		end
	end
	m.warmthDrain = Clamp.clamp(m.warmthDrain, 1, e.MaxWarmthDrainMultiplier)
	m.fuelBurn = Clamp.clamp(m.fuelBurn, 1, e.MaxFuelBurnMultiplier)
	m.dreadGain = Clamp.clamp(m.dreadGain, 1, e.MaxDreadGainMultiplier)
	m.huntBonus = Clamp.clamp(m.huntBonus, 0, e.MaxHuntChanceBonus)
	m.visibility = Clamp.clamp(m.visibility, t.MinVisibility, 1)
	m.spawn = Clamp.clamp(m.spawn, 1, t.MaxSpawnMultiplier)
	return m
end

return EventSchedule
