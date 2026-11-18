--!strict
-- Headless fixed-seed simulation harness (pure Luau, runs under lune). No Roblox APIs.
-- Each system plugs in via Sim.addSystem({ name, init, step }) and may record() events into the checksum.
-- Usage: local sim = Sim.new({ seed = 1 }); sim:addSystem(mySystem); local r = sim:runDays(100).

local MODULUS = 4294967296 -- 2^32

export type Rng = {
	state: number,
	next: (Rng) -> number, -- float in [0, 1)
	int: (Rng, number, number) -> number, -- inclusive
	chance: (Rng, number) -> boolean,
}

export type Clock = { time: number, day: number, dayLength: number, dt: number }

export type Sim = {
	seed: number,
	rng: Rng,
	clock: Clock,
	systems: { System },
	hash: number,
	events: number,
	addSystem: (Sim, System) -> (),
	record: (Sim, string, number) -> (),
	step: (Sim) -> (),
	runDays: (Sim, number) -> Result,
}

export type System = {
	name: string,
	init: ((Sim) -> ())?,
	step: (Sim, Clock) -> (),
	onDay: ((Sim, number) -> ())?,
}

export type Result = { hash: number, days: number, events: number, time: number }

local Sim = {}

-- Deterministic LCG; products stay below 2^53 so doubles are exact.
local function newRng(seed: number): Rng
	local rng = { state = seed % MODULUS } :: any
	function rng.next(self: Rng): number
		self.state = (self.state * 1664525 + 1013904223) % MODULUS
		return self.state / MODULUS
	end
	function rng.int(self: Rng, lo: number, hi: number): number
		return lo + math.floor(self:next() * (hi - lo + 1))
	end
	function rng.chance(self: Rng, p: number): boolean
		return self:next() < p
	end
	return rng :: Rng
end

Sim.newRng = newRng

export type Options = { seed: number?, dayLength: number?, dt: number? }

function Sim.new(opts: Options?): Sim
	local o: Options = opts or {}
	local seed = o.seed or 1
	local sim = {
		seed = seed,
		rng = newRng(seed),
		clock = { time = 0, day = 1, dayLength = o.dayLength or 360, dt = o.dt or 1 },
		systems = {},
		hash = 2166136261, -- FNV offset basis
		events = 0,
	} :: any

	function sim.addSystem(self: Sim, system: System)
		table.insert(self.systems, system)
		if system.init then
			system.init(self)
		end
	end

	-- Fold a named event into the determinism checksum (FNV-1a style, 32-bit).
	function sim.record(self: Sim, name: string, value: number)
		local h = self.hash
		for i = 1, #name do
			h = (bit32.bxor(h, string.byte(name, i)) * 16777619) % MODULUS
		end
		h = (bit32.bxor(h, math.floor(value * 1000) % MODULUS) * 16777619) % MODULUS
		self.hash = h
		self.events += 1
	end

	function sim.step(self: Sim)
		local c = self.clock
		c.time += c.dt
		local newDay = math.floor(c.time / c.dayLength) + 1
		for _, system in self.systems do
			system.step(self, c)
		end
		if newDay ~= c.day then
			c.day = newDay
			for _, system in self.systems do
				if system.onDay then
					system.onDay(self, newDay)
				end
			end
		end
	end

	function sim.runDays(self: Sim, days: number): Result
		local target = days * self.clock.dayLength
		while self.clock.time < target do
			self:step()
		end
		return {
			hash = self.hash,
			days = self.clock.day,
			events = self.events,
			time = self.clock.time,
		}
	end

	return sim :: Sim
end

-- Skeleton for the 100-day determinism check: build the sim twice with the same seed and compare hashes.
-- `plug` adds every system under test; real systems extend it as they land.
function Sim.determinism(seed: number, days: number, plug: (Sim) -> ()): (boolean, Result, Result)
	local a = Sim.new({ seed = seed })
	plug(a)
	local ra = a:runDays(days)
	local b = Sim.new({ seed = seed })
	plug(b)
	local rb = b:runDays(days)
	return ra.hash == rb.hash and ra.events == rb.events and ra.time == rb.time, ra, rb
end

-- ===== night-danger section (wolf vs player vs fire; pure, mirrors MobService.stepMob) =====
-- Plug into a Sim built with dt = NIGHT_DT. A wolf hunts a player outside a fire; after the first bite
-- the player steps into the fire's warm radius. Exposes stats for tests.
local MobAI = require("../src/shared/logic/MobAI")
local FireRepel = require("../src/shared/logic/FireRepel")
local DayClock = require("../src/shared/logic/DayClock")
local SimConfig = require("../src/shared/Config")

export type NightStats = {
	bites: number,
	minWolfFireDist: number,
	windupSeen: boolean,
	shelteredBitten: boolean,
	wolfGone: boolean,
	chased: boolean,
	retreated: boolean,
}

Sim.NIGHT_DT = SimConfig.Mobs.AITickInterval

function Sim.nightDangerSystem(): (System, NightStats)
	local wolfCfg = SimConfig.Mobs.Wolf
	local night = SimConfig.Night
	local fire: FireRepel.Fire = { x = 0, z = 0, radius = SimConfig.Fire.WarmRadius }
	local stats: NightStats = {
		bites = 0,
		minWolfFireDist = math.huge,
		windupSeen = false,
		shelteredBitten = false,
		wolfGone = false,
		chased = false,
		retreated = false,
	}
	local wolf =
		{ x = 60, z = 0, nextAttackAt = 0, leaveAt = nil :: number?, alive = true, spawned = false }
	local windup: MobAI.Windup = { startedAt = nil }
	local player = { x = SimConfig.Fire.WarmRadius + 14, z = 0 }
	local system: System = {
		name = "nightDanger",
		step = function(sim, clock)
			if not wolf.alive then
				return
			end
			local info = DayClock.at(clock.time, SimConfig.Time)
			if not wolf.spawned then
				if not info.isNight then
					return -- the wolf appears when night first falls
				end
				wolf.spawned = true
			end
			local dist = math.sqrt((wolf.x - player.x) ^ 2 + (wolf.z - player.z) ^ 2)
			local fireIdx = FireRepel.insideAny(
				wolf.x,
				wolf.z,
				{ fire },
				night.RepelMargin,
				SimConfig.Fire.RepelRadius
			)
			local action = MobAI.decide({
				behavior = "Hunt",
				nearestPlayerDist = dist,
				isNight = info.isNight,
				nightOnly = wolfCfg.NightOnly,
				fleeRange = wolfCfg.FleeRange,
				aggroRange = wolfCfg.AggroRange,
				attackRange = wolfCfg.AttackRange,
				inFireRepel = fireIdx ~= nil,
				canAttack = clock.time >= wolf.nextAttackAt,
			})
			if windup.startedAt ~= nil and (action == "Chase" or action == "Attack") then
				action = "Attack"
			elseif action ~= "Attack" then
				windup.startedAt = nil
			end
			local move = wolfCfg.FleeSpeed * clock.dt
			local function toward(tx: number, tz: number, sign: number)
				local dx, dz = tx - wolf.x, tz - wolf.z
				local d = math.sqrt(dx * dx + dz * dz)
				if d > 1e-6 then
					local m = math.min(move, d)
					wolf.x += sign * dx / d * m
					wolf.z += sign * dz / d * m
				end
			end
			if action == "Chase" then
				stats.chased = true
				local tx, tz = FireRepel.clampTarget(
					player.x,
					player.z,
					fire,
					FireRepel.repelRadius(
						fire.radius,
						SimConfig.Fire.RepelRadius,
						night.RepelMargin
					)
				)
				toward(tx, tz, 1)
			elseif action == "Retreat" then
				stats.retreated = true
				toward(fire.x, fire.z, -1)
			elseif action == "Leave" then
				local deadline = wolf.leaveAt or (clock.time + night.DawnLeaveSeconds)
				wolf.leaveAt = deadline
				toward(player.x, player.z, -1)
				if clock.time >= deadline then
					wolf.alive = false
					stats.wolfGone = true
				end
			elseif action == "Attack" then
				local result = MobAI.windupStep(
					windup,
					clock.time,
					dist <= wolfCfg.AttackRange,
					dist <= wolfCfg.AttackRange + night.StrikeLeeway,
					night.WindupSeconds
				)
				if result == "Start" then
					stats.windupSeen = true
				elseif result == "Strike" then
					wolf.nextAttackAt = clock.time + wolfCfg.AttackCooldown
					if player.x == fire.x + 3 then
						stats.shelteredBitten = true
					end
					stats.bites += 1
					sim:record("bite", clock.time)
					-- Survivable: the bitten player runs into the fire's warm radius.
					player.x = fire.x + 3
				end
			end
			local fd = math.sqrt((wolf.x - fire.x) ^ 2 + (wolf.z - fire.z) ^ 2)
			stats.minWolfFireDist = math.min(stats.minWolfFireDist, fd)
		end,
	}
	return system, stats
end

-- ===== Fire tiers / build range / stations (pure-logic checks; run from SimTests) =====
local Config = require("../src/shared/Config")
local FireTiers = require("../src/shared/logic/FireTiers")
local Placement = require("../src/shared/logic/Placement")
local Crafting = require("../src/shared/logic/Crafting")
local ItemCatalog = require("../src/shared/ItemCatalog")

function Sim.fireBuildChecks(check: (string, boolean) -> ())
	local tiers = Config.Fire.Tiers
	check(
		"fire tier1 matches base config",
		tiers[1].WarmRadius == Config.Fire.WarmRadius
			and tiers[1].MaxFuelSeconds == Config.Fire.MaxFuelSeconds
			and tiers[1].WoodFuelSeconds == Config.Fire.WoodFuelSeconds
	)
	local rising = true
	for i = 2, #tiers do
		local a, b = tiers[i - 1], tiers[i]
		rising = rising
			and b.WarmRadius > a.WarmRadius
			and b.BuildRadius > a.BuildRadius
			and b.LightRange > a.LightRange
			and b.MaxFuelSeconds > a.MaxFuelSeconds
			and #b.UpgradeCost > 0
	end
	check("fire tiers strictly raise radii and burn", rising)
	check(
		"fire tier clamp",
		FireTiers.clamp(0) == 1
			and FireTiers.clamp(99) == FireTiers.maxTier()
			and FireTiers.clamp("x") == 1
			and FireTiers.clamp(0 / 0) == 1
	)
	check(
		"fire next cost nil at max",
		FireTiers.nextCost(FireTiers.maxTier()) == nil and FireTiers.nextCost(1) ~= nil
	)
	local cost = tiers[2].UpgradeCost
	check(
		"fire afford",
		not FireTiers.canAfford({}, cost) and FireTiers.canAfford({ Wood = 99, Stone = 99 }, cost)
	)
	check("fire cost text", FireTiers.costText(cost, function(id)
		return id
	end) == "15 Wood, 6 Stone")
	local fires = { { x = 0, z = 0, buildRadius = 30 } }
	check(
		"build range inside/outside",
		FireTiers.inBuildRange(fires, 29, 0)
			and not FireTiers.inBuildRange(fires, 31, 0)
			and not FireTiers.inBuildRange({}, 0, 0)
	)
	local c: Placement.Check = {
		structureId = "Workbench",
		target = { x = 40, z = 0 },
		player = { x = 20, z = 0 },
		placeRange = 99,
		minSpacing = 1,
		others = {},
		ownedCount = 0,
		maxOwned = 9,
		fireCount = 0,
		maxFires = 9,
		itemCount = 1,
		litFires = fires,
		buildExempt = false,
	}
	check("place refused beyond build radius", select(2, Placement.check(c)) == "OutOfBuildRange")
	c.buildExempt = Config.Build.RangeExempt.Workbench == true
	check("workbench not exempt", not c.buildExempt)
	c.litFires = { { x = 0, z = 0, buildRadius = tiers[2].BuildRadius } }
	check("upgraded fire allows it", (Placement.check(c)))
	c.litFires = {}
	check("no lit fire refuses", select(2, Placement.check(c)) == "OutOfBuildRange")
	c.structureId, c.buildExempt = "Campfire", Config.Build.RangeExempt.Campfire == true
	check("campfire exempt from build radius", (Placement.check(c)))
	check(
		"recipes with tier>=1 name a station",
		Crafting.requiredStation("Spear") == "workbench" and Crafting.requiredStation("Axe") == nil
	)
	check(
		"every recipe station is configured",
		(function()
			for _, r in ItemCatalog.Recipes do
				if r.station ~= nil and Config.Craft.Stations[r.station] == nil then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"status by station",
		Crafting.status({ Wood = 9, Stone = 9 }, "Spear", {}) == "NeedStation"
			and Crafting.status({ Wood = 9, Stone = 9 }, "Spear", { workbench = true }) == "Ok"
	)
end

-- Run end (brief 9): scripted mix of downed, revived, dead, disconnected and rejoined players on RunState.
local RunState = require("../src/server/Run/RunState")

export type RunEndStats = {
	endedAt: number,
	endCount: number,
	revivedOk: boolean,
	lateReviveRefused: boolean,
	rejoinedOk: boolean,
	lateRejoinRefused: boolean,
	finalStatuses: { [number]: string },
}

function Sim.runEndSystem(): (System, RunEndStats)
	local opts = {
		rejoinWindow = Config.Run.RejoinWindowSeconds,
		reviveLimit = Config.Downed.BleedoutSeconds,
	}
	local run = RunState.new({ 1, 2, 3, 4 }, opts)
	local stats: RunEndStats = {
		endedAt = -1,
		endCount = 0,
		revivedOk = false,
		lateReviveRefused = false,
		rejoinedOk = false,
		lateRejoinRefused = false,
		finalStatuses = {},
	}
	local limit = opts.reviveLimit
	local window = opts.rejoinWindow
	local over = false
	local system: System = {
		name = "runEnd",
		step = function(sim, clock)
			if over then
				return
			end
			local t = clock.time
			if t == 10 or t == 60 then
				RunState.setDowned(run, 1, t) -- p1 downed twice: revived at t=30, bleeds out after t=60
			elseif t == 20 then
				RunState.disconnect(run, 2, t) -- p2 drops, rejoins at t=50
			elseif t == 30 then
				stats.revivedOk = RunState.revive(run, 1, t)
			elseif t == 40 then
				RunState.setDead(run, 3)
			elseif t == 50 then
				stats.rejoinedOk = RunState.rejoin(run, 2, t)
			elseif t == 70 then
				RunState.setDowned(run, 2, t) -- bleeds out at t=70+limit
				RunState.disconnect(run, 4, t) -- p4 drops and never returns until the window ends
			elseif t == 70 + limit + 1 then
				stats.lateReviveRefused = not RunState.revive(run, 2, t)
			end
			RunState.tick(run, t)
			if t == 70 + window + 1 then
				stats.lateRejoinRefused = not RunState.rejoin(run, 4, t)
			end
			if RunState.isOver(run) then
				over = true
				stats.endCount += 1
				stats.endedAt = t
				for _, id in run.order do
					stats.finalStatuses[id] = tostring(RunState.status(run, id))
				end
				sim:record("runEnd", t)
			end
		end,
	}
	return system, stats
end

-- ===== Phase 3 section (events, dread, hunts, mob scaling, biome survival; pure, brief 18) =====
-- A seeded three-player party wanders the rings (some members underdressed), shelters at a fire when cold,
-- eats when hungry. Every step checks the hard caps and meter bounds; transitions feed the checksum.
local EventSchedule = require("../src/shared/logic/EventSchedule")
local DreadLogic = require("../src/shared/logic/DreadLogic")
local MobScaling = require("../src/shared/logic/MobScaling")
local SurvivalLogic = require("../src/shared/logic/SurvivalLogic")
local BiomeLogic = require("../src/shared/logic/BiomeLogic")
local EventsData = require("../src/shared/data/Events")

export type Phase3Stats = {
	darkStarts: number,
	blizzards: number,
	maxDarkPerDay: number,
	earlyDark: boolean, -- a dark event started before Events.FirstDay
	overlap: boolean, -- a dark event and a blizzard were active together
	capBroken: { [string]: boolean }, -- name -> a cap was exceeded
	negativeMeter: boolean, -- a meter left [0, max] or became NaN
	maxDread: number,
	maxHuntChance: number,
	maxBudget: number,
	maxWarmthMult: number,
	deaths: number,
	strikesFromFull: number, -- Stalker strikes that would kill a full-health player (must stay 0)
}

local PHASE3_PARTY = 3
local PHASE3_EAT_BELOW = 30
local PHASE3_WARM_BELOW = 35
local PHASE3_WARM_UNTIL = 95
local PHASE3_DRESSED_RESISTANCE = 9 -- tier-3 clothing (deep tundra requirement)

function Sim.phase3System(): (System, Phase3Stats)
	local C = SimConfig
	local params: EventSchedule.Params = {
		events = C.Events,
		time = C.Time,
		dark = EventsData.Dark :: any,
		blizzard = EventsData.Blizzard :: any,
		tune = EventsData.Tuning :: any,
	}
	local stats: Phase3Stats = {
		darkStarts = 0,
		blizzards = 0,
		maxDarkPerDay = 0,
		earlyDark = false,
		overlap = false,
		capBroken = {},
		negativeMeter = false,
		maxDread = 0,
		maxHuntChance = 0,
		maxBudget = 0,
		maxWarmthMult = 0,
		deaths = 0,
		strikesFromFull = 0,
	}
	local state: EventSchedule.State
	local dread = 0
	local darkToday = 0
	type Member = {
		meters: SurvivalLogic.State,
		ring: number,
		resistance: number,
		sheltering: boolean,
	}
	local party: { Member } = {}

	local function cap(name: string, value: number, limit: number)
		if value ~= value or value > limit + 1e-9 then
			stats.capBroken[name] = true
		end
	end

	local function meterOk(m: SurvivalLogic.State): boolean
		local M = C.Meters
		for _, pair in
			{ { m.health, M.MaxHealth }, { m.warmth, M.MaxWarmth }, { m.hunger, M.MaxHunger } }
		do
			local v, max = pair[1], pair[2]
			if v ~= v or v < 0 or v > max then
				return false
			end
		end
		return true
	end

	local system: System = {
		name = "phase3",
		init = function(sim)
			state = EventSchedule.new(sim.seed, params, 0)
			for i = 1, PHASE3_PARTY do
				-- member 1 dressed for the deep tundra, the others underdressed
				local res = if i == 1 then PHASE3_DRESSED_RESISTANCE else (i - 2) * 3
				table.insert(party, {
					meters = SurvivalLogic.new(C.Meters),
					ring = 0,
					resistance = res,
					sheltering = false,
				})
			end
		end,
		step = function(sim, clock)
			local t, dt, day = clock.time, clock.dt, clock.day
			local isNight = (t % clock.dayLength) / clock.dayLength >= C.Time.DayFraction
			local fullGroup = sim.rng:chance(0.3)
			for _, tr in EventSchedule.step(state, t, fullGroup, params) do
				sim:record(tr.kind, t)
				if tr.kind == "DarkStart" then
					stats.darkStarts += 1
					darkToday += 1
					stats.maxDarkPerDay = math.max(stats.maxDarkPerDay, darkToday)
					if day < C.Events.FirstDay then
						stats.earlyDark = true
					end
				elseif tr.kind == "BlizzardStart" then
					stats.blizzards += 1
				end
			end
			local blizzard = EventSchedule.isBlizzardActive(state)
			if blizzard and EventSchedule.activeDark(state) ~= "" then
				stats.overlap = true
			end
			local mods = EventSchedule.modifiers(state, t, params)
			cap("event warmthDrain", mods.warmthDrain, C.Events.MaxWarmthDrainMultiplier)
			cap("event fuelBurn", mods.fuelBurn, C.Events.MaxFuelBurnMultiplier)
			cap("event dreadGain", mods.dreadGain, C.Events.MaxDreadGainMultiplier)
			cap("event huntBonus", mods.huntBonus, C.Events.MaxHuntChanceBonus)
			cap("event spawn", mods.spawn, C.Events.MaxSpawnMultiplier)
			if mods.visibility < C.Events.MinVisibility - 1e-9 then
				stats.capBroken["event visibility"] = true
			end

			-- party: wander rings by day, shelter when cold, eat when hungry
			local deepest = 0
			for _, member in party do
				local m = member.meters
				if not m.dead then
					if sim.rng:chance(0.01) then
						member.ring = math.clamp(member.ring + sim.rng:int(-1, 1), 0, 3)
					end
					if m.warmth < PHASE3_WARM_BELOW then
						member.sheltering = true
					elseif m.warmth >= PHASE3_WARM_UNTIL then
						member.sheltering = false
					end
					if m.hunger < PHASE3_EAT_BELOW then
						SurvivalLogic.feed(m, C.Food.RawMeatHunger, C.Meters)
					end
					local biome = BiomeLogic.drainMultiplier(member.ring, member.resistance)
					local env: SurvivalLogic.Env = {
						inFire = member.sheltering,
						isNight = isNight or mods.nightRules,
						invincible = false,
						warmthDrainMultiplier = biome * mods.warmthDrain,
					}
					local mult = SurvivalLogic.warmthDrainMultiplier(env, C.Meters)
					stats.maxWarmthMult = math.max(stats.maxWarmthMult, mult)
					cap("survival warmth multiplier", mult, C.Meters.MaxWarmthDrainMultiplier)
					if SurvivalLogic.step(m, env, C.Meters, dt) then
						SurvivalLogic.kill(m)
						stats.deaths += 1
						sim:record("death", t)
					end
					if not meterOk(m) then
						stats.negativeMeter = true
					end
					deepest = math.max(deepest, member.ring)
				end
			end

			-- dread and hunt chance (party-level, hidden)
			dread = DreadLogic.step(dread, {
				isolation = if fullGroup then C.Isolation.WeightGroup else C.Isolation.WeightAlone,
				farFromCamp = deepest > 0,
				dark = isNight or mods.nightRules,
				blizzard = blizzard,
				nearFire = party[1].sheltering and party[2].sheltering and party[3].sheltering,
				day = day,
				ring = deepest,
				eventMultiplier = mods.dreadGain,
			}, dt)
			stats.maxDread = math.max(stats.maxDread, dread)
			cap("dread", dread, C.Dread.Max)
			cap(
				"dread gain multiplier",
				DreadLogic.gainMultiplier(day, deepest, mods.dreadGain),
				DreadLogic.maxGainMultiplier()
			)
			local hunt = DreadLogic.huntChance(dread, day, mods.huntBonus)
			stats.maxHuntChance = math.max(stats.maxHuntChance, hunt)
			cap("hunt chance", hunt, C.Stalker.MaxHuntChance)
			if
				DreadLogic.strikeDamage(C.Meters.MaxHealth, C.Meters.MaxHealth)
				>= C.Meters.MaxHealth
			then
				stats.strikesFromFull += 1
			end

			-- mob scaling (live budget incl. event spawn multiplier, then MaxLiveMobs)
			local mult = MobScaling.multipliers(day, deepest, PHASE3_PARTY)
			cap(
				"mob health",
				mult.health,
				C.Scaling.MaxMobHealthMultiplier
					* C.Scaling.MaxRingHealthMultiplier
					* C.Scaling.MaxPartyHealthMultiplier
			)
			cap(
				"mob damage",
				mult.damage,
				C.Scaling.MaxMobDamageMultiplier * C.Scaling.MaxRingDamageMultiplier
			)
			local budget = MobScaling.liveBudget(
				C.Mobs.Budget,
				mult,
				PHASE3_PARTY,
				isNight or blizzard,
				C.Mobs.NightBudgetMultiplier
			)
			local extra = math.clamp(
				mods.spawn * C.Scaling.HotSpringSpawnBias,
				0,
				C.Scaling.MaxSpawnMultiplier
			)
			budget = math.clamp(math.floor(budget * extra), 0, C.Scaling.MaxLiveMobs)
			stats.maxBudget = math.max(stats.maxBudget, budget)
			cap("live mobs", budget, C.Scaling.MaxLiveMobs)
			if clock.time % 60 == 0 then
				sim:record("dread", math.floor(dread))
			end
		end,
		onDay = function(_sim, _day)
			darkToday = 0
		end,
	}
	return system, stats
end

-- ===== Phase 4 section (meta progress, achievements, perks; pure, brief 21) =====
-- One profile plays 100 daily runs: every progress counter is hammered with large adds (to hit the caps),
-- deepestRing is raised, a run is paid out, achievements are evaluated and granted, and the equipped perk
-- rotates through the shop perks. Every step checks the perk multipliers; every day checks profile caps.
local ProfileSchema = require("../src/shared/logic/ProfileSchema")
local AchievementLogic = require("../src/shared/logic/AchievementLogic")
local PerkLogic = require("../src/shared/logic/PerkLogic")
local RunPayout = require("../src/shared/logic/RunPayout")
local Achievements = require("../src/shared/data/Achievements")
local Shop = require("../src/shared/data/Shop")
local Types = require("../src/shared/data/Types")

export type Phase4Stats = {
	capBroken: { [string]: boolean },
	grants: number, -- achievement grants (each id at most once)
	doubleGrant: boolean, -- an id was granted twice
	invalidProfile: boolean, -- ProfileSchema.validate failed after a day
	maxPerkDelta: number, -- largest |multiplier - 1| seen
	yieldOver: boolean, -- a bonus yield exceeded its base
}

local PHASE4_BIG_ADD = 1e8 -- per-day progress add: reaches Meta.MaxStatValue within the 100 days

function Sim.phase4System(): (System, Phase4Stats)
	local C = SimConfig
	local stats: Phase4Stats = {
		capBroken = {},
		grants = 0,
		doubleGrant = false,
		invalidProfile = false,
		maxPerkDelta = 0,
		yieldOver = false,
	}
	local profile = ProfileSchema.default()
	local granted: { [string]: boolean } = {}
	local perks: { Types.PerkEffect } = {}
	for _, item in Shop.List do
		if item.category == "perk" and item.perk then
			table.insert(perks, item.perk)
		end
	end
	local carry = 0

	local function cap(name: string, value: number, limit: number)
		if value ~= value or value > limit + 1e-9 then
			stats.capBroken[name] = true
		end
	end

	local system: System = {
		name = "phase4",
		step = function(sim, clock)
			local effect = perks[(clock.day % math.max(#perks, 1)) + 1]
			for _, stat in C.Meta.PerkStats do
				local delta = math.abs(PerkLogic.multiplier(effect, stat) - 1)
				stats.maxPerkDelta = math.max(stats.maxPerkDelta, delta)
				cap("perk magnitude", delta, C.Meta.MaxPerkMagnitude)
			end
			local camp = PerkLogic.lowestMultiplier(perks, "fuelBurn")
			cap("team fuel perk", math.abs(camp - 1), C.Meta.MaxPerkMagnitude)
			if sim.rng:chance(0.05) then
				local base = sim.rng:int(1, 3)
				local extra
				extra, carry =
					PerkLogic.bonusYield(carry, base, PerkLogic.multiplier(effect, "gatherSpeed"))
				if extra > base or extra < 0 or carry < 0 or carry >= 1 + 1e-9 then
					stats.yieldOver = true
				end
			end
		end,
		onDay = function(sim, day)
			for _, field in ProfileSchema.PROGRESS_FIELDS do
				if field ~= "deepestRing" then
					AchievementLogic.addProgress(
						profile,
						field,
						sim.rng:int(1, 100) * PHASE4_BIG_ADD
					)
				end
			end
			AchievementLogic.raiseProgress(profile, "deepestRing", sim.rng:int(0, 3))
			profile.crafted = math.min(profile.crafted + PHASE4_BIG_ADD, C.Meta.MaxStatValue)
			local summary = RunPayout.summarize({
				daysSurvived = day,
				kills = sim.rng:int(0, 20),
				bossKills = sim.rng:int(0, 1),
				partners = sim.rng:int(0, 3),
				darkEventsSurvived = sim.rng:int(0, 2),
			}, profile.maxDays)
			cap("run coins", summary.coinsEarned, C.Meta.MaxCoinsPerRun)
			RunPayout.apply(profile, summary)
			for _, def in AchievementLogic.evaluate(profile, Achievements.List) do
				if AchievementLogic.grant(profile, def) then
					if granted[def.id] then
						stats.doubleGrant = true
					end
					granted[def.id] = true
					stats.grants += 1
					sim:record("achievement", stats.grants)
				end
			end
			local entries = 0
			for _, value in profile.achievementProgress do
				entries += 1
				cap("progress value", value, C.Meta.MaxStatValue)
			end
			cap("progress entries", entries, C.Meta.MaxProgressEntries)
			for _, field in ProfileSchema.STAT_FIELDS do
				cap(`stat {field}`, ProfileSchema.getStat(profile, field), C.Meta.MaxStatValue)
			end
			cap("coins", profile.coins, C.MaxCoins)
			if not ProfileSchema.validate(profile) then
				stats.invalidProfile = true
			end
		end,
	}
	return system, stats
end

return Sim
