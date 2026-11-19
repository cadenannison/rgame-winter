--!strict
-- Dark events + blizzard. Schedule is server-only and seed-deterministic (EventSchedule); clients get
-- sensory Cues (coarse level) and visible Workspace attributes only: never a timer or countdown.
-- One Heartbeat loop. Cross-deps (mob budget, full-group test, run seed) are nil-safe setters wired by brief 18.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Events = require(Shared.data.Events)
local BlizzardWind = require(Shared.logic.BlizzardWind)
local EventSchedule = require(Shared.logic.EventSchedule)
local DayNightService = require(script.Parent.Parent.Survival.DayNightService)

local BLIZZARD_ID = Config.Blizzard.EventId
local SPAWN_PRECISION = 20 -- spawn multiplier sink is told in 1/20 steps

local params: EventSchedule.Params = {
	events = Config.Events,
	time = Config.Time,
	dark = Events.Dark,
	blizzard = Events.Blizzard,
	tune = Events.Tuning,
}

export type Modifiers = {
	warmthDrain: number,
	fuelBurn: number,
	dreadGain: number,
	huntBonus: number,
	nightRules: boolean,
	silence: boolean,
	visibility: number, -- 1 = normal, lower = shorter sight (capped by Events.Tuning.MinVisibility)
	spawn: number, -- mob budget multiplier (capped by Events.Tuning.MaxSpawnMultiplier)
}

local EventService = {}

local state: EventSchedule.State
local seed = 0
local seedSet = false
local started = false
local lastElapsed = 0
local accum = 0
local connection: RBXScriptConnection? = nil
local fullGroupPredicate: (() -> boolean)? = nil
local spawnSink: ((number) -> ())? = nil
local lastSpawnStep = -1
local lastCueKey = ""
local announcedStart = -1 -- bStartAt of the blizzard whose forecast toast was already sent
local blizzardStartCbs: { () -> () } = {}
local eventStartCbs: { (string) -> () } = {}
local eventEndCbs: { (string, { Player }) -> () } = {}

local function now(): number
	return DayNightService.getElapsed()
end

local function fire(callbacks: { (...any) -> () }, ...: any)
	for _, cb in callbacks do
		local args = table.pack(...)
		task.spawn(function()
			local ok, err = pcall(cb :: any, table.unpack(args, 1, args.n))
			if not ok then
				warn(`EventService callback failed: {err}`)
			end
		end)
	end
end

local function sendCue(kind: string, level: number?, eventId: string?)
	Remotes.event(Remotes.Cue)
		:FireAllClients({ kind = kind, level = level, event = eventId } :: Remotes.CuePayload)
end

-- Server-decided toast to every player (existing Notify remote; only on state change, never per tick).
local function notifyAll(text: string)
	Remotes.event(Remotes.Notify):FireAllClients(Config.Blizzard.NotifyKind, text)
end

local function survivors(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if
			humanoid
			and humanoid.Health > 0
			and player:GetAttribute(Config.Downed.StateAttribute) ~= true
		then
			table.insert(list, player)
		end
	end
	return list
end

local intensityOverride: number? = nil -- debug: fixed intensity while a blizzard is active

-- Current blizzard intensity 0..1 (0 when none). Debug override wins while active.
local function currentIntensity(t: number): number
	if not EventSchedule.isBlizzardActive(state) then
		return 0
	end
	local override = intensityOverride
	if override ~= nil then
		return override
	end
	local dur = math.max(state.bEndAt - state.bStartAt, 1e-6)
	return EventSchedule.blizzardIntensity((t - state.bStartAt) / dur, state.bCount, params.tune)
end

local function publish(t: number)
	local active = EventSchedule.activeDark(state)
	if Workspace:GetAttribute(Config.Events.ActiveAttribute) ~= active then
		Workspace:SetAttribute(Config.Events.ActiveAttribute, active)
	end
	local blizzard = EventSchedule.isBlizzardActive(state)
	if Workspace:GetAttribute(Config.Blizzard.ActiveAttribute) ~= blizzard then
		Workspace:SetAttribute(Config.Blizzard.ActiveAttribute, blizzard)
	end
	local intensity = BlizzardWind.quantize(currentIntensity(t), Config.Blizzard.IntensityStep)
	if Workspace:GetAttribute(Config.Blizzard.IntensityAttribute) ~= intensity then
		Workspace:SetAttribute(Config.Blizzard.IntensityAttribute, intensity)
	end
	local warning = state.bPhase == "warning"
	if Workspace:GetAttribute(Config.Blizzard.WarningAttribute) ~= warning then
		Workspace:SetAttribute(Config.Blizzard.WarningAttribute, warning)
	end
end

local function warningKind(): string?
	if state.bPhase == "warning" then
		return Events.Blizzard.warningCue
	end
	local def = state.dDef
	if state.dPhase == "warning" and def then
		return def.warningCue
	end
	return nil
end

-- Sends the current sensory cue only when its coarse state changes.
local function updateCues(t: number)
	local maxLevel = Config.Cue.MaxLevel
	local key = ""
	local kind: string? = nil
	local level = 0
	local eventId: string? = nil
	local wk = warningKind()
	if wk then
		kind, level = wk, EventSchedule.warningLevel(state, t, maxLevel)
		key = `W{wk}{level}`
	elseif EventSchedule.isBlizzardActive(state) then
		local dur = math.max(state.bEndAt - state.bStartAt, 1e-6)
		local i =
			EventSchedule.blizzardIntensity((t - state.bStartAt) / dur, state.bCount, params.tune)
		kind, level, eventId = "EventStart", EventSchedule.cueLevel(i, maxLevel), BLIZZARD_ID
		key = `B{level}`
	end
	if key ~= lastCueKey then
		lastCueKey = key
		if kind then
			sendCue(kind, level, eventId)
		end
	end
end

local function updateSpawnSink(t: number)
	local sink = spawnSink
	if not sink then
		return
	end
	local step = math.floor(EventSchedule.modifiers(state, t, params).spawn * SPAWN_PRECISION + 0.5)
	if step ~= lastSpawnStep then
		lastSpawnStep = step
		local ok, err = pcall(sink :: any, step / SPAWN_PRECISION)
		if not ok then
			warn(`EventService spawn sink failed: {err}`)
		end
	end
end

local function handle(tr: EventSchedule.Transition)
	local kind, id = tr.kind, tr.id
	if kind == "BlizzardStart" then
		notifyAll(Config.Blizzard.ArrivalText)
		fire(blizzardStartCbs :: { (...any) -> () })
		fire(eventStartCbs :: { (...any) -> () }, BLIZZARD_ID)
	elseif kind == "BlizzardEnd" then
		intensityOverride = nil
		sendCue("EventEnd", 0, BLIZZARD_ID)
		lastCueKey = ""
		fire(eventEndCbs :: { (...any) -> () }, BLIZZARD_ID, survivors())
	elseif kind == "DarkStart" then
		sendCue("EventStart", Config.Cue.MaxLevel, id)
		lastCueKey = `D{id}`
		fire(eventStartCbs :: { (...any) -> () }, id)
	elseif kind == "DarkEnd" then
		sendCue("EventEnd", 0, id)
		lastCueKey = ""
		fire(eventEndCbs :: { (...any) -> () }, id, survivors())
	end
end

local function resetSchedule(t: number)
	-- Clock jumped backwards (debug setDay): drop any active event cleanly and re-plan.
	if EventSchedule.isBlizzardActive(state) then
		handle({ kind = "BlizzardEnd", id = BLIZZARD_ID })
	end
	if state.dPhase == "active" and state.dDef then
		handle({ kind = "DarkEnd", id = state.dDef.id })
	end
	state = EventSchedule.new(seed, params, t)
	lastCueKey = ""
end

local function pollDebug(t: number)
	if not RunService:IsStudio() then
		return
	end
	local D = Config.Debug
	if Workspace:GetAttribute(D.WorldBlizzardAttribute) == true then
		Workspace:SetAttribute(D.WorldBlizzardAttribute, nil)
		EventSchedule.forceBlizzard(state, t, params)
	end
	local id = Workspace:GetAttribute(D.WorldDarkEventAttribute)
	if type(id) == "string" and id ~= "" then
		Workspace:SetAttribute(D.WorldDarkEventAttribute, nil)
		EventSchedule.forceDark(state, t, id, params)
	end
end

-- About half a day before a scheduled blizzard: one toast and a sound-hook cue.
local function checkForecast(t: number)
	if state.bPhase ~= "idle" or state.dPhase ~= "idle" then
		return
	end
	if
		BlizzardWind.forecastDue(
			t,
			state.bWarnAt,
			state.bStartAt,
			Config.Blizzard.ForecastLeadSeconds,
			announcedStart
		)
	then
		announcedStart = state.bStartAt
		notifyAll(Config.Blizzard.ForecastText)
		sendCue(Config.Blizzard.ForecastCue, 0)
	end
end

local function tick()
	local t = now()
	if t < lastElapsed - 1 then
		resetSchedule(t)
	end
	lastElapsed = t
	pollDebug(t)
	local predicate = fullGroupPredicate
	local fullGroup = false
	if predicate then
		local ok, result = pcall(predicate)
		fullGroup = ok and result == true
	end
	for _, tr in EventSchedule.step(state, t, fullGroup, params) do
		handle(tr)
	end
	checkForecast(t)
	publish(t)
	updateCues(t)
	updateSpawnSink(t)
end

-- Capped modifiers for the current moment (warnings change nothing).
function EventService.getModifiers(): Modifiers
	local m = EventSchedule.modifiers(state, now(), params)
	return {
		warmthDrain = m.warmthDrain,
		fuelBurn = m.fuelBurn,
		dreadGain = m.dreadGain,
		huntBonus = m.huntBonus,
		nightRules = m.nightRules,
		silence = m.silence,
		visibility = m.visibility,
		spawn = m.spawn,
	}
end

function EventService.isBlizzard(): boolean
	return EventSchedule.isBlizzardActive(state)
end

-- Active dark event id, or "" (server use: other systems may branch on it).
function EventService.getActiveDarkEvent(): string
	return EventSchedule.activeDark(state)
end

function EventService.onBlizzardStart(cb: () -> ())
	table.insert(blizzardStartCbs, cb)
end

-- id is a Events.Dark id or "Blizzard".
function EventService.onEventStart(cb: (id: string) -> ())
	table.insert(eventStartCbs, cb)
end

-- survivors = players alive and not downed when the event ends (coins: Meta.CoinsPerDarkEventSurvived).
function EventService.onEventEnd(cb: (id: string, survivors: { Player }) -> ())
	table.insert(eventEndCbs, cb)
end

-- Isolation.fullGroup wiring (brief 18): true when the whole party travels together. Nil-safe.
function EventService.setFullGroupPredicate(fn: (() -> boolean)?)
	fullGroupPredicate = fn
end

-- Mob budget hook (brief 18 -> MobService): fn(multiplier) is called when the capped spawn
-- multiplier changes (1 = normal). Nil-safe; MobService is not edited.
function EventService.setSpawnMultiplierSink(fn: ((number) -> ())?)
	spawnSink = fn
	lastSpawnStep = -1
end

-- Run seed (brief 18). Call before start(); the same seed gives the same schedule.
function EventService.setSeed(value: number)
	seed = value
	seedSet = true
	if started then
		resetSchedule(now())
	end
end

-- QA/debug: force an event now (never overlaps another). Returns whether it started.
function EventService.forceBlizzard(): boolean
	return EventSchedule.forceBlizzard(state, now(), params)
end

-- Debug: start a blizzard now (no warning). Returns false during another event.
function EventService.startBlizzardNow(): boolean
	return EventSchedule.startBlizzardNow(state, now(), params)
end

-- Debug: end the current blizzard (or cancel its warning) on the next step.
function EventService.stopBlizzardNow()
	EventSchedule.stopBlizzardNow(state, now())
	intensityOverride = nil
end

-- Debug: pin the intensity (nil releases it back to the schedule curve).
function EventService.setIntensityOverride(value: number?)
	intensityOverride = if value == nil then nil else math.clamp(value, 0, 1)
end

-- Debug: snapshot for "/debug blizzard" (pure formatting in BlizzardWind.statusText).
function EventService.getBlizzardStatus(): BlizzardWind.Status
	local t = now()
	local active = EventSchedule.isBlizzardActive(state)
	local untilStart: number? = nil
	local forecastIn: number? = nil
	if state.bPhase ~= "active" and state.bStartAt - t < 1e8 then
		untilStart = math.max(state.bStartAt - t, 0)
		forecastIn = if announcedStart == state.bStartAt
			then 0
			else math.max(state.bStartAt - Config.Blizzard.ForecastLeadSeconds - t, 0)
	end
	return {
		active = active,
		phase = state.bPhase,
		intensity = currentIntensity(t),
		timeLeft = if active then math.max(state.bEndAt - t, 0) else 0,
		untilStart = untilStart,
		forecastIn = forecastIn,
	}
end

function EventService.forceDark(id: string): boolean
	return EventSchedule.forceDark(state, now(), id, params)
end

function EventService.start()
	if started then
		return
	end
	started = true
	if not seedSet then
		seed = Random.new():NextInteger(1, 2147483646)
	end
	lastElapsed = now()
	state = EventSchedule.new(seed, params, lastElapsed)
	publish(lastElapsed)
	connection = RunService.Heartbeat:Connect(function(dt: number)
		accum += dt
		if accum < Events.Tuning.StepSeconds then
			return
		end
		accum = 0
		tick()
	end)
end

function EventService.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	started = false
end

return EventService
