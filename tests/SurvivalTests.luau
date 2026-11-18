--!strict
-- Headless tests: DayClock, FireLogic, SurvivalLogic and a 100-day survival sim plugged into tests/sim.luau.

local Config = require("../src/shared/Config")
local DayClock = require("../src/shared/logic/DayClock")
local FireLogic = require("../src/shared/logic/FireLogic")
local FireRepel = require("../src/shared/logic/FireRepel")
local FireTiers = require("../src/shared/logic/FireTiers")
local SurvivalLogic = require("../src/shared/logic/SurvivalLogic")
local Sim = require("./sim")

local M = Config.Meters
local D = Config.Downed
local T = Config.Time
local F = Config.Fire

local PLAYERS = 3
local SIM_DAYS = 100
local SIM_SEED = 4242
local REFUEL_CHANCE = 0.01
local MOVE_CHANCE = 0.05
local EAT_CHANCE = 0.004
local EAT_AMOUNT = 30
local REVIVE_CHANCE = 0.05
local FAR_DISTANCE = 40
local EPS = 1e-6

local DAY_ENV: SurvivalLogic.Env = { inFire = false, isNight = false, invincible = false }
local NIGHT_ENV: SurvivalLogic.Env = { inFire = false, isNight = true, invincible = false }
local FIRE_ENV: SurvivalLogic.Env = { inFire = true, isNight = true, invincible = false }

type Stats = { violations: number, deaths: number }

local function survivalSystem(stats: Stats?): Sim.System
	local fire = FireLogic.new(F.BurnSeconds)
	local players: { SurvivalLogic.State } = {}
	local dist: { number } = {}
	local violations = 0
	local deaths = 0
	local out: Stats = stats or { violations = 0, deaths = 0 }

	local function invariants(s: SurvivalLogic.State)
		if
			s.health < 0
			or s.warmth < 0
			or s.hunger < 0
			or s.health > M.MaxHealth + EPS
			or s.warmth > M.MaxWarmth + EPS
			or s.hunger > M.MaxHunger + EPS
		then
			violations += 1
			out.violations = violations
		end
	end

	local function ableTeammate(index: number): boolean
		for i, other in players do
			if i ~= index and not other.downed and not other.dead then
				return true
			end
		end
		return false
	end

	return {
		name = "survival",
		init = function()
			for i = 1, PLAYERS do
				players[i] = SurvivalLogic.new(M)
				dist[i] = 0
			end
		end,
		step = function(sim, clock)
			local isNight = DayClock.at(clock.time, T).isNight
			FireLogic.burn(fire, clock.dt)
			if sim.rng:chance(REFUEL_CHANCE) then
				FireLogic.addFuel(fire, F.WoodFuelSeconds, F.MaxFuelSeconds)
			end
			for i, s in players do
				if sim.rng:chance(MOVE_CHANCE) then
					dist[i] = sim.rng:int(0, FAR_DISTANCE)
				end
				if sim.rng:chance(EAT_CHANCE) then
					SurvivalLogic.feed(s, EAT_AMOUNT, M)
				end
				if s.dead then
					players[i] = SurvivalLogic.new(M) -- respawn
					s = players[i]
					deaths += 1
					out.deaths = deaths
					sim:record("death", i)
				elseif s.downed then
					if SurvivalLogic.tickDowned(s, clock.dt) then
						SurvivalLogic.kill(s)
					elseif ableTeammate(i) and sim.rng:chance(REVIVE_CHANCE) then
						SurvivalLogic.revive(s, M, D)
						sim:record("revive", i)
					end
				else
					local env: SurvivalLogic.Env = {
						inFire = FireLogic.warms(fire, 0, 0, dist[i], 0, F.WarmRadius),
						isNight = isNight,
						invincible = false,
					}
					if SurvivalLogic.step(s, env, M, clock.dt) then
						if ableTeammate(i) then
							SurvivalLogic.down(s, D)
							sim:record("down", i)
						else
							SurvivalLogic.kill(s)
						end
					end
				end
				invariants(s)
			end
		end,
		onDay = function(sim, day)
			for i, s in players do
				sim:record("meters" .. i, s.health + s.warmth * 7 + s.hunger * 13)
			end
			sim:record("day", day)
			sim:record("violations", violations)
			sim:record("deaths", deaths)
		end,
	}
end

return function(check: (string, boolean) -> ())
	-- DayClock
	local dawn = DayClock.at(0, T)
	check(
		"clock starts day 1 daylight at start hour",
		dawn.day == 1 and not dawn.isNight and dawn.hour == T.StartClockHour
	)
	local dusk = DayClock.at(T.DayLengthSeconds * T.DayFraction, T)
	check("clock night begins at day fraction", dusk.isNight and dusk.day == 1)
	local nextDay = DayClock.at(T.DayLengthSeconds, T)
	check("clock rolls to day 2", nextDay.day == 2 and not nextDay.isNight)
	check("clock elapsedForDay", DayClock.at(DayClock.elapsedForDay(7, T), T).day == 7)

	-- FireLogic
	local fire = FireLogic.new(10)
	check("fire burns down", not FireLogic.burn(fire, 4) and fire.fuel == 6)
	check("fire goes out", FireLogic.burn(fire, 10) and not FireLogic.isLit(fire))
	local added = FireLogic.addFuel(fire, F.WoodFuelSeconds, F.MaxFuelSeconds)
	check("fire adds fuel and relights", added == F.WoodFuelSeconds and FireLogic.isLit(fire))
	check(
		"fire fuel capped",
		FireLogic.addFuel(fire, F.MaxFuelSeconds * 2, F.MaxFuelSeconds) > 0
			and fire.fuel == F.MaxFuelSeconds
	)
	check("fire radius inside", FireLogic.inRadius(0, 0, F.WarmRadius - 1, 0, F.WarmRadius))
	check("fire radius outside", not FireLogic.inRadius(0, 0, F.WarmRadius + 1, 0, F.WarmRadius))
	check(
		"unlit fire does not warm",
		not FireLogic.warms(FireLogic.new(0), 0, 0, 0, 0, F.WarmRadius)
	)

	-- Warmth drain outside / inside the fire radius
	local out = SurvivalLogic.new(M)
	SurvivalLogic.step(out, DAY_ENV, M, 10)
	check(
		"warmth drains outside radius (day)",
		math.abs(out.warmth - (M.MaxWarmth - M.WarmthDrainPerSecond * 10)) < EPS
	)
	local night = SurvivalLogic.new(M)
	SurvivalLogic.step(night, NIGHT_ENV, M, 10)
	check(
		"warmth drains faster at night",
		math.abs(
			night.warmth
				- (M.MaxWarmth - M.WarmthDrainPerSecond * M.WarmthDrainNightMultiplier * 10)
		) < EPS
	)
	local cold = SurvivalLogic.new(M)
	cold.warmth = 40
	SurvivalLogic.step(cold, FIRE_ENV, M, 5)
	check(
		"warmth regenerates inside radius",
		math.abs(cold.warmth - (40 + M.WarmthRegenPerSecond * 5)) < EPS
	)
	local capped = SurvivalLogic.new(M)
	SurvivalLogic.step(capped, FIRE_ENV, M, 100)
	check("warmth capped inside radius", capped.warmth == M.MaxWarmth)
	local inside = SurvivalLogic.new(M)
	local outside = SurvivalLogic.new(M)
	for _ = 1, 60 do
		SurvivalLogic.step(inside, {
			inFire = FireLogic.inRadius(0, 0, F.WarmRadius - 10, 0, F.WarmRadius),
			isNight = true,
			invincible = false,
		}, M, 1)
		SurvivalLogic.step(outside, {
			inFire = FireLogic.inRadius(0, 0, F.WarmRadius + 10, 0, F.WarmRadius),
			isNight = true,
			invincible = false,
		}, M, 1)
	end
	check(
		"inside fire keeps warmth, outside loses it",
		inside.warmth == M.MaxWarmth and outside.warmth < M.MaxWarmth
	)

	-- Health rules
	local frozen = SurvivalLogic.new(M)
	frozen.warmth = 0
	SurvivalLogic.step(frozen, NIGHT_ENV, M, 2)
	check(
		"freezing damages health",
		math.abs(frozen.health - (M.MaxHealth - M.FreezeDamagePerSecond * 2)) < EPS
	)
	local god = SurvivalLogic.new(M)
	god.warmth = 0
	SurvivalLogic.step(god, { inFire = false, isNight = true, invincible = true }, M, 5)
	check("invincible takes no meter damage", god.health == M.MaxHealth)
	local hurt = SurvivalLogic.new(M)
	hurt.health = 10
	SurvivalLogic.step(hurt, FIRE_ENV, M, 4)
	check(
		"health regens when fed and warm",
		math.abs(hurt.health - (10 + M.HealthRegenPerSecond * 4)) < EPS
	)
	local dying = SurvivalLogic.new(M)
	dying.health = 1
	dying.hunger = 0
	check(
		"starvation reaches zero health",
		SurvivalLogic.step(dying, DAY_ENV, M, 5) and dying.health == 0
	)

	-- Downed and revive
	local d = SurvivalLogic.new(M)
	SurvivalLogic.down(d, D)
	check("down sets bleedout", d.downed and d.bleed == D.BleedoutSeconds and d.health == 0)
	SurvivalLogic.step(d, NIGHT_ENV, M, 10)
	check("downed meters are frozen", d.warmth == M.MaxWarmth)
	check(
		"bleedout kills",
		not SurvivalLogic.tickDowned(d, D.BleedoutSeconds - 1) and SurvivalLogic.tickDowned(d, 2)
	)
	local r = SurvivalLogic.new(M)
	SurvivalLogic.down(r, D)
	check(
		"revive restores fraction of health",
		SurvivalLogic.revive(r, M, D)
			and r.health == M.MaxHealth * D.ReviveHealthFraction
			and not r.downed
	)
	check("cannot revive a standing player", not SurvivalLogic.revive(r, M, D))

	-- 100-day determinism and bounds
	local ok, a, b = Sim.determinism(SIM_SEED, SIM_DAYS, function(sim)
		sim:addSystem(survivalSystem())
	end)
	check(
		"survival sim 100 days same seed same result",
		ok and a.days == SIM_DAYS + 1 and a.hash == b.hash
	)
	local other = Sim.new({ seed = SIM_SEED + 1 })
	other:addSystem(survivalSystem())
	check("survival sim different seed differs", other:runDays(SIM_DAYS).hash ~= a.hash)

	-- Meters never negative / caps hold across the whole run (violations counted every step).
	local stats = { violations = 0, deaths = 0 }
	local probe = Sim.new({ seed = SIM_SEED })
	probe:addSystem(survivalSystem(stats))
	local base = probe:runDays(SIM_DAYS)
	check(
		"survival sim meters never negative and caps hold",
		stats.violations == 0 and base.hash == a.hash
	)
	check("survival sim exercises deaths or downs", base.events > SIM_DAYS)

	-- Fire radius chain: tier radii follow (2 + tier) * R0 with spec tier = index - 1.
	local R0 = F.BaseRadius
	check(
		"fire warm radius tier 1 = 3 R0",
		F.Tiers[1].WarmRadius == 3 * R0 and F.WarmRadius == 3 * R0
	)
	local progression = true
	for i, row in F.Tiers do
		if row.WarmRadius ~= (2 + i) * R0 then
			progression = false
		end
		if i > 1 and row.WarmRadius - F.Tiers[i - 1].WarmRadius ~= R0 then
			progression = false
		end
		if row.BuildRadius <= row.WarmRadius or row.LightRange <= row.WarmRadius then
			progression = false
		end
	end
	check("fire tier radii = (2+tier)*R0, +R0 per upgrade", progression)
	check(
		"fire tier rows resolve through FireTiers.get",
		FireTiers.get(3).WarmRadius == 5 * R0 and FireTiers.get(0).WarmRadius == 3 * R0
	)
	local top = F.Tiers[#F.Tiers]
	check(
		"fire build range reaches top-tier build radius only",
		FireTiers.inBuildRange(
			{ { x = 0, z = 0, buildRadius = top.BuildRadius } },
			top.BuildRadius,
			0
		)
			and not FireTiers.inBuildRange(
				{ { x = 0, z = 0, buildRadius = top.BuildRadius } },
				top.BuildRadius + 1,
				0
			)
	)
	check(
		"fire repel radius = warm + margin per tier",
		FireRepel.repelRadius(top.WarmRadius, F.RepelRadius, Config.Night.RepelMargin)
				== top.WarmRadius + Config.Night.RepelMargin
			and F.RepelRadius == F.WarmRadius + Config.Night.RepelMargin
	)
	local R = F.Ring
	local capsOk = true
	for _, row in F.Tiers do
		for _, radius in { row.WarmRadius, row.BuildRadius } do
			local n = FireTiers.ringDotCount(radius, R.Spacing, R.MinDots, R.MaxDotsPerLayer)
			if n < R.MinDots or n > R.MaxDotsPerLayer then
				capsOk = false
			end
		end
	end
	check("fire ring dots within per-layer caps for all tiers", capsOk)
	check(
		"fire ring spacing scales dots with radius",
		FireTiers.ringDotCount(top.BuildRadius, R.Spacing, R.MinDots, R.MaxDotsPerLayer)
			> FireTiers.ringDotCount(F.Tiers[1].WarmRadius, R.Spacing, R.MinDots, R.MaxDotsPerLayer)
	)
	check(
		"fire ring top build ring keeps spacing (not capped)",
		2 * math.pi * top.BuildRadius / R.Spacing <= R.MaxDotsPerLayer
	)
	check(
		"fire ring dot cap hit for huge radius",
		FireTiers.ringDotCount(1e6, R.Spacing, R.MinDots, R.MaxDotsPerLayer) == R.MaxDotsPerLayer
	)
	check(
		"fire ring total cap fits at least one full fire",
		R.MaxDotsTotal >= R.MaxDotsPerLayer + R.MinDots
	)
	check("fire meter shows within top warm radius", F.Meter.ShowRange >= top.WarmRadius)
end
