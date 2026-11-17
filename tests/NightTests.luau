--!strict
-- Headless tests for night danger: wolf windup/leave logic, fire repel geometry, lighting interpolation.

local Config = require("../src/shared/Config")
local MobAI = require("../src/shared/logic/MobAI")
local FireRepel = require("../src/shared/logic/FireRepel")
local LightingMath = require("../src/shared/logic/LightingMath")
local Sim = require("./sim")

local function windupNums()
	return Config.Night.WindupSeconds
end

return function(check: (string, boolean) -> ())
	-- Windup state machine
	local w: MobAI.Windup = { startedAt = nil }
	local ws = windupNums()
	check("windup idle when not ready", MobAI.windupStep(w, 0, false, true, ws) == "Idle")
	check("windup starts", MobAI.windupStep(w, 1, true, true, ws) == "Start")
	check("windup waits", MobAI.windupStep(w, 1 + ws / 2, true, true, ws) == "Wait")
	check("windup strikes after delay", MobAI.windupStep(w, 1 + ws, true, true, ws) == "Strike")
	check("windup cleared after strike", w.startedAt == nil)
	MobAI.windupStep(w, 5, true, true, ws)
	check(
		"windup cancels when target leaves reach",
		MobAI.windupStep(w, 5.1, true, false, ws) == "Cancel"
	)
	check("windup zero strikes at once", MobAI.windupStep(w, 9, true, true, 0) == "Strike")

	-- Dawn: wolf leaves instead of wandering
	local wolf = Config.Mobs.Wolf
	check("wolf leaves at dawn", MobAI.decide({
		behavior = "Hunt",
		nearestPlayerDist = 10,
		isNight = false,
		nightOnly = wolf.NightOnly,
		fleeRange = 0,
		aggroRange = wolf.AggroRange,
		attackRange = wolf.AttackRange,
		inFireRepel = false,
		canAttack = true,
	}) == "Leave")

	-- Fire repel geometry
	local fire: FireRepel.Fire = { x = 0, z = 0, radius = 18 }
	local m = Config.Night.RepelMargin
	check("repel radius uses attribute + margin", FireRepel.repelRadius(18, 22, m) == 18 + m)
	check("repel radius grows with upgrade", FireRepel.repelRadius(30, 22, m) == 30 + m)
	check("repel radius falls back", FireRepel.repelRadius(nil, 22, m) == 22)
	check("inside repel edge", FireRepel.insideAny(18 + m - 1, 0, { fire }, m, 22) == 1)
	check("outside repel edge", FireRepel.insideAny(18 + m + 1, 0, { fire }, m, 22) == nil)
	local tx, tz = FireRepel.clampTarget(3, 0, fire, 24)
	check("clamp pushes target out of repel circle", math.abs(tx - 24) < 1e-6 and tz == 0)
	local ox, oz = FireRepel.clampTarget(40, 0, fire, 24)
	check("clamp leaves outside target", ox == 40 and oz == 0)

	-- Lighting interpolation
	local df, tw = Config.Time.DayFraction, Config.Lighting.TwilightPhase
	check("noon is day", LightingMath.nightAmount(0.2, df, tw) == 0)
	check("midnight is night", LightingMath.nightAmount((df + 1) / 2, df, tw) == 1)
	check("dusk mid ramp", math.abs(LightingMath.nightAmount(df - tw / 2, df, tw) - 0.5) < 1e-6)
	check("dusk reaches full night at night start", LightingMath.nightAmount(df, df, tw) == 1)
	check("dawn mid ramp", math.abs(LightingMath.nightAmount(1 - tw / 2, df, tw) - 0.5) < 1e-6)
	check("dawn ends at day", LightingMath.nightAmount(0, df, tw) == 0)
	check(
		"dusk monotonic",
		LightingMath.nightAmount(df - tw * 0.7, df, tw)
			< LightingMath.nightAmount(df - tw * 0.3, df, tw)
	)
	local c = LightingMath.lerpColor({ 0, 100, 200 }, { 100, 200, 0 }, 0.5)
	check("lerpColor", c[1] == 50 and c[2] == 150 and c[3] == 100)
	check("fire light range clamped", LightingMath.fireLightRange(100, 1.4, 60) == 60)
	check("fire light range scales", LightingMath.fireLightRange(20, 1.5, 60) == 30)

	-- Night-danger simulation: wolf bites outside the fire, never enters the warm radius, leaves at dawn.
	local function build(): (Sim.Sim, Sim.NightStats)
		local sim = Sim.new({ seed = 3, dt = Sim.NIGHT_DT })
		local system, stats = Sim.nightDangerSystem()
		sim:addSystem(system)
		return sim, stats
	end
	local sim, stats = build()
	local r = sim:runDays(2)
	check("sim wolf chased at night", stats.chased)
	check("sim wolf telegraphed (windup)", stats.windupSeen)
	check("sim wolf bit the exposed player", stats.bites >= 1)
	check("sim wolf never entered warm radius", stats.minWolfFireDist > Config.Fire.WarmRadius)
	check("sim sheltered player not bitten", not stats.shelteredBitten)
	check("sim wolf retreated at fire edge", stats.retreated)
	check("sim wolf gone after dawn", stats.wolfGone)
	local sim2 = build()
	local r2 = sim2:runDays(2)
	check("sim night-danger deterministic", r.hash == r2.hash and r.events == r2.events)
end
