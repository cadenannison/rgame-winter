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

return Sim
