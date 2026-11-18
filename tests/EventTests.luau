--!strict
-- Brief 14: EventSchedule (dark events + blizzard). Pure, fixed-seed, deterministic.

local Config = require("../src/shared/Config")
local Events = require("../src/shared/data/Events")
local EventSchedule = require("../src/shared/logic/EventSchedule")

local DAYS = 100
local STEP = 1
local SEEDS = { 1, 7, 42, 1234, 99991 }

local params: EventSchedule.Params = {
	events = Config.Events,
	time = Config.Time,
	dark = Events.Dark,
	blizzard = Events.Blizzard,
	tune = Events.Tuning,
}

type Span = { id: string, warnAt: number, startAt: number, endAt: number }
type Result = {
	darks: { Span },
	blizzards: { Span },
	trace: string,
	overlapBad: boolean,
	activeOverlapBad: boolean,
}

local function simulate(seed: number, fullGroup: boolean): Result
	local state = EventSchedule.new(seed, params, 0)
	local r: Result =
		{ darks = {}, blizzards = {}, trace = "", overlapBad = false, activeOverlapBad = false }
	local curD: Span? = nil
	local curB: Span? = nil
	local parts = {}
	local total = DAYS * Config.Time.DayLengthSeconds
	local t = 0
	while t <= total do
		for _, tr in EventSchedule.step(state, t, fullGroup, params) do
			table.insert(parts, `{tr.kind}:{tr.id}@{t}`)
			if tr.kind == "DarkWarn" then
				curD = { id = tr.id, warnAt = t, startAt = 0, endAt = 0 }
			elseif tr.kind == "DarkStart" and curD then
				curD.startAt = t
			elseif tr.kind == "DarkEnd" and curD then
				curD.endAt = t
				table.insert(r.darks, curD)
				curD = nil
			elseif tr.kind == "BlizzardWarn" then
				curB = { id = "Blizzard", warnAt = t, startAt = 0, endAt = 0 }
			elseif tr.kind == "BlizzardStart" and curB then
				curB.startAt = t
			elseif tr.kind == "BlizzardEnd" and curB then
				curB.endAt = t
				table.insert(r.blizzards, curB)
				curB = nil
			end
		end
		if curD and curB then
			r.activeOverlapBad = true
		end
		t += STEP
	end
	r.trace = table.concat(parts, ",")
	for _, d in r.darks do
		for _, b in r.blizzards do
			-- warning..end of each, plus buffer, must not touch
			local buf = Config.Events.BlizzardBufferSeconds
			if d.warnAt < b.endAt + buf and b.warnAt < d.endAt + buf then
				r.overlapBad = true
			end
		end
	end
	return r
end

return function(check: (string, boolean) -> ())
	local E = Config.Events
	local len = Config.Time.DayLengthSeconds

	-- chance
	check(
		"events: no chance before day 3",
		EventSchedule.chance(1, params) == 0 and EventSchedule.chance(2, params) == 0
	)
	check(
		"events: chance on day 3 is base",
		EventSchedule.chance(3, params) == E.BaseChancePerCheck
	)
	check("events: chance capped", EventSchedule.chance(10000, params) == E.MaxChancePerCheck)
	check(
		"events: chance rises slowly",
		EventSchedule.chance(10, params) > EventSchedule.chance(3, params)
	)

	-- canStart reasons
	local s0 = EventSchedule.new(5, params, 0)
	local ok0, why0 = EventSchedule.canStart(s0, 1 * len, params)
	check("events: canStart rejects before FirstDay", not ok0 and why0 == "FirstDay")
	local s1 = EventSchedule.new(5, params, 0)
	s1.bWarnAt = 1e9
	local ok1 = EventSchedule.canStart(s1, 3 * len, params)
	check("events: canStart ok on day 3 with no blizzard near", ok1)
	s1.dLastEnd = 3 * len - 10
	local ok2, why2 = EventSchedule.canStart(s1, 3 * len, params)
	check("events: canStart enforces min gap", not ok2 and why2 == "MinGap")
	s1.dLastEnd = -math.huge
	s1.startsByDay[4] = E.MaxPerDay
	local ok3, why3 = EventSchedule.canStart(s1, 3 * len + 1, params)
	check("events: canStart enforces per-day cap", not ok3 and why3 == "MaxPerDay")
	s1.startsByDay = {}
	s1.bWarnAt = 3 * len + 100
	local ok4, why4 = EventSchedule.canStart(s1, 3 * len, params)
	check(
		"events: canStart keeps clear of an upcoming blizzard",
		not ok4 and why4 == "BlizzardBuffer"
	)
	s1.bWarnAt = 1e9
	s1.bLastEnd = 3 * len - 5
	local ok5, why5 = EventSchedule.canStart(s1, 3 * len, params)
	check("events: canStart keeps clear after a blizzard", not ok5 and why5 == "BlizzardBuffer")

	-- 100-day simulation
	local all = true
	local noEarly = true
	local gapsOk = true
	local perDayOk = true
	local noOverlap = true
	local blizzardCadence = true
	local blizzardCount = 0
	local darkCount = 0
	local fullGroupOk = true
	local maxDarks = math.floor(DAYS * len / (E.MinGapSeconds + 1)) + 1
	local maxBlizz = math.floor(DAYS / Config.Time.BlizzardMinGap) + 1
	for _, seed in SEEDS do
		local r = simulate(seed, false)
		local again = simulate(seed, false)
		all = all and r.trace == again.trace
		darkCount += #r.darks
		blizzardCount += #r.blizzards
		noOverlap = noOverlap and not r.overlapBad and not r.activeOverlapBad
		local byDay: { [number]: number } = {}
		for i, d in r.darks do
			noEarly = noEarly and d.warnAt >= (E.FirstDay - 1) * len
			local day = math.floor(d.warnAt / len) + 1
			byDay[day] = (byDay[day] or 0) + 1
			if i > 1 then
				gapsOk = gapsOk and d.warnAt - r.darks[i - 1].endAt >= E.MinGapSeconds
			end
		end
		for _, n in byDay do
			perDayOk = perDayOk and n <= E.MaxPerDay
		end
		for i, b in r.blizzards do
			if i > 1 then
				local gapDays = (b.startAt - r.blizzards[i - 1].startAt) / len
				blizzardCadence = blizzardCadence
					and gapDays >= Config.Time.BlizzardMinGap - 1e-6
					and gapDays <= Config.Time.BlizzardMaxGap + 1e-6
			end
			blizzardCadence = blizzardCadence
				and b.startAt - b.warnAt >= params.blizzard.warningSeconds - 1e-6
		end
		fullGroupOk = fullGroupOk and #r.darks <= maxDarks and #r.blizzards <= maxBlizz
		local grp = simulate(seed, true)
		for _, d in grp.darks do
			fullGroupOk = fullGroupOk and d.id == "DeepFreeze"
		end
	end
	check("events: same seed gives identical 100-day schedule", all)
	check("events: no dark event before day 3 (100 days, 5 seeds)", noEarly)
	check("events: min gap between dark events holds", gapsOk)
	check("events: per-day cap holds", perDayOk)
	check("events: dark events never overlap blizzards (buffer)", noOverlap)
	check("events: blizzards every 4-5 days with a warning", blizzardCadence and blizzardCount > 0)
	check("events: dark events actually occur", darkCount > 0)
	check("events: frequency bounded over 100 days", fullGroupOk)
	check("events: full group only gets non-blocked events", fullGroupOk)
	local diff = simulate(1, false).trace ~= simulate(7, false).trace
	check("events: different seeds differ", diff)

	-- modifiers and intensity
	local st = EventSchedule.new(3, params, 0)
	local idle = EventSchedule.modifiers(st, 0, params)
	check(
		"events: idle modifiers are neutral",
		idle.warmthDrain == 1 and idle.visibility == 1 and idle.spawn == 1 and not idle.blizzard
	)
	EventSchedule.forceBlizzard(st, 100, params)
	EventSchedule.step(st, 100, false, params)
	local warn = EventSchedule.modifiers(st, 110, params)
	check("events: warning period changes no rules", warn.warmthDrain == 1 and not warn.blizzard)
	check(
		"events: warning cue level coarse",
		EventSchedule.warningLevel(st, 110, Config.Cue.MaxLevel) >= 1
	)
	local startAt = st.bStartAt
	EventSchedule.step(st, startAt, false, params)
	local early = EventSchedule.modifiers(st, startAt + 1, params)
	local mid = EventSchedule.modifiers(st, startAt + 0.6 * (st.bEndAt - startAt), params)
	check(
		"events: blizzard escalates",
		mid.warmthDrain > early.warmthDrain and mid.spawn > early.spawn
	)
	check(
		"events: blizzard reduces visibility",
		mid.visibility < 1 and mid.visibility >= params.tune.MinVisibility
	)
	check(
		"events: blizzard modifiers capped",
		mid.warmthDrain <= E.MaxWarmthDrainMultiplier
			and mid.spawn <= params.tune.MaxSpawnMultiplier
			and mid.dreadGain <= E.MaxDreadGainMultiplier
	)
	check(
		"events: later blizzards peak higher",
		EventSchedule.blizzardIntensity(0.7, 4, params.tune)
			> EventSchedule.blizzardIntensity(0.7, 1, params.tune)
	)
	check(
		"events: cue level coarse range",
		EventSchedule.cueLevel(1, Config.Cue.MaxLevel) == Config.Cue.MaxLevel
			and EventSchedule.cueLevel(0.01, Config.Cue.MaxLevel) == 1
			and EventSchedule.cueLevel(0, 3) == 0
	)
	local sd = EventSchedule.new(3, params, 4 * len)
	check(
		"events: forceDark works when idle",
		EventSchedule.forceDark(sd, 4 * len, "DeepFreeze", params)
	)
	check(
		"events: forceDark refused while active",
		not EventSchedule.forceDark(sd, 4 * len, "FalseNight", params)
	)
	EventSchedule.step(sd, sd.dStartAt, false, params)
	local dm = EventSchedule.modifiers(sd, sd.dStartAt, params)
	check(
		"events: deep freeze drains faster and burns fuel faster",
		dm.warmthDrain > 1 and dm.fuelBurn > 1
	)
	local sf = EventSchedule.new(3, params, 4 * len)
	EventSchedule.forceDark(sf, 4 * len, "FalseNight", params)
	EventSchedule.step(sf, sf.dStartAt, false, params)
	local fm = EventSchedule.modifiers(sf, sf.dStartAt, params)
	check(
		"events: false night applies night rules",
		fm.nightRules and fm.visibility < 1 and fm.spawn > 1
	)
	local sq = EventSchedule.new(3, params, 4 * len)
	EventSchedule.forceDark(sq, 4 * len, "TheQuiet", params)
	EventSchedule.step(sq, sq.dStartAt, false, params)
	local qm = EventSchedule.modifiers(sq, sq.dStartAt, params)
	check(
		"events: the quiet silences and spikes hunt bonus",
		qm.silence and qm.huntBonus > 0 and qm.huntBonus <= E.MaxHuntChanceBonus
	)
	EventSchedule.step(sq, sq.dEndAt, false, params)
	check(
		"events: event ends back to neutral",
		EventSchedule.modifiers(sq, sq.dEndAt, params).warmthDrain == 1
			and EventSchedule.activeDark(sq) == ""
	)
end
