--!strict
-- Brief 15: Dread, isolation, Stalker rules. Pure logic only (DreadLogic, Isolation).

local Config = require("../src/shared/Config")
local DreadLogic = require("../src/shared/logic/DreadLogic")
local Isolation = require("../src/shared/logic/Isolation")
local Lurkers = require("../src/shared/data/Lurkers")

type Point = Isolation.Point

local D, S, I, L = Config.Dread, Config.Stalker, Config.Isolation, Config.Lurkers
local MAX_HEALTH = Config.Meters.MaxHealth

-- Deterministic LCG in [0, 1).
local function rng(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

local function baseInputs(): DreadLogic.Inputs
	return {
		isolation = 0,
		farFromCamp = false,
		dark = false,
		blizzard = false,
		nearFire = false,
		day = 1,
		ring = 0,
		eventMultiplier = 1,
	}
end

-- One seeded run: party wanders around a camp with fires and warm spots; a Stalker hunts.
type SimResult = {
	trace: { number },
	maxDread: number,
	maxChance: number,
	maxDensity: number,
	hunts: number,
	huntsBlocked: boolean, -- a hunt started while the party was a full group
	huntsDay1: boolean,
	insideRepeller: boolean,
	killedFromFull: boolean,
	strikes: number,
}

local function simulate(seed: number, days: number, partySize: number): SimResult
	local rand = rng(seed)
	local repellers: { DreadLogic.Repeller } = {
		{ x = 0, z = 0, radius = Config.Fire.WarmRadius },
		{ x = 300, z = -200, radius = Config.WarmSpot.CabinRadius },
		{ x = -250, z = 350, radius = Config.WarmSpot.HotSpringRadius },
	}
	local players: { Point } = {}
	local health: { number } = {}
	for i = 1, partySize do
		players[i] = { x = (rand() - 0.5) * 40, z = (rand() - 0.5) * 40 }
		health[i] = MAX_HEALTH
	end
	local r: SimResult = {
		trace = {},
		maxDread = 0,
		maxChance = 0,
		maxDensity = 0,
		hunts = 0,
		huntsBlocked = false,
		huntsDay1 = false,
		insideRepeller = false,
		killedFromFull = false,
		strikes = 0,
	}
	local dread = 0
	local now = 0
	local cooldownUntil = 0
	local hunt: DreadLogic.Hunt? = nil
	local target = 0
	local sx, sz = 0, 0
	local dt = 5
	local ticksPerDay = math.floor(Config.Time.DayLengthSeconds / dt)
	for day = 1, days do
		for _ = 1, ticksPerDay do
			now += dt
			-- Wander; sometimes regroup at camp, sometimes stray far.
			local mode = rand()
			for i, p in players do
				if mode < 0.2 then
					p.x, p.z = p.x * 0.5, p.z * 0.5
				else
					p.x += (rand() - 0.5) * 80 * (i == 1 and 2 or 1)
					p.z += (rand() - 0.5) * 80
				end
				p.x = math.clamp(p.x, -1200, 1200)
				p.z = math.clamp(p.z, -1200, 1200)
			end
			local weights = Isolation.weights(players, partySize)
			local full = Isolation.fullGroup(players)
			local allWarm = true
			local far = false
			for _, p in players do
				if not DreadLogic.isInside(p.x, p.z, repellers, 0) then
					allWarm = false
				end
				if math.sqrt(p.x * p.x + p.z * p.z) > D.FarFromCampDistance then
					far = true
				end
			end
			local ring =
				math.min(math.floor(math.sqrt(players[1].x ^ 2 + players[1].z ^ 2) / 300), 3)
			local inputs = baseInputs()
			inputs.isolation = Isolation.maxWeight(weights)
			inputs.farFromCamp = far
			inputs.dark = rand() < 0.4
			inputs.blizzard = rand() < 0.1
			inputs.nearFire = allWarm
			inputs.day = day
			inputs.ring = ring
			inputs.eventMultiplier = rand() * 10 -- deliberately over the cap
			dread = DreadLogic.step(dread, inputs, dt)
			r.maxDread = math.max(r.maxDread, dread)
			local chance = DreadLogic.huntChance(dread, day, rand()) -- bonus over the cap
			r.maxChance = math.max(r.maxChance, chance)
			r.maxDensity =
				math.max(r.maxDensity, DreadLogic.lurkerDensity(day, ring + day, inputs.isolation))
			table.insert(r.trace, math.floor(dread * 1000))

			if hunt == nil then
				local ok = DreadLogic.canHunt({
					day = day,
					now = now,
					cooldownUntil = cooldownUntil,
					hunting = false,
					fullGroup = full,
					candidates = #players,
				})
				if ok and rand() < math.max(chance, 0.3) then
					local picked = Isolation.pick(weights, rand())
					if picked then
						r.hunts += 1
						r.huntsBlocked = r.huntsBlocked or full
						r.huntsDay1 = r.huntsDay1 or day < S.FirstHuntDay
						hunt = DreadLogic.newHunt()
						target = picked
						local p = players[target]
						local cx, cz, clear = DreadLogic.clampOutside(
							p.x + S.ApproachDistance,
							p.z,
							repellers,
							S.FireRepelMargin
						)
						sx, sz = cx, cz
						if not clear then
							hunt = nil
						end
					end
				end
			end
			local h = hunt
			if h then
				local p = players[target]
				local x, z, clear = DreadLogic.moveToward(
					sx,
					sz,
					p.x,
					p.z,
					S.ChaseSpeed,
					dt,
					repellers,
					S.FireRepelMargin
				)
				sx, sz = x, z
				if DreadLogic.isInside(sx, sz, repellers, S.FireRepelMargin) then
					r.insideRepeller = true
				end
				local distance = math.sqrt((sx - p.x) ^ 2 + (sz - p.z) ^ 2)
				if rand() < 0.3 then
					distance = 0 -- force strike opportunities
				end
				local light: DreadLogic.Light = if rand() < 0.1 then "torch" else "none"
				local out = DreadLogic.stepHunt(h, {
					distance = distance,
					light = light,
					targetSafe = DreadLogic.isInside(p.x, p.z, repellers, 0),
				}, dt)
				if out.strike then
					r.strikes += 1
					local before = health[target]
					health[target] =
						math.max(before - DreadLogic.strikeDamage(before, MAX_HEALTH), 0)
					if before >= MAX_HEALTH and health[target] <= 0 then
						r.killedFromFull = true
					end
					-- Alternate: sometimes the target was already hurt, sometimes healed back to full.
					if rand() < 0.5 then
						health[target] = MAX_HEALTH
					end
				end
				if out.done or not clear then
					hunt = nil
					cooldownUntil = now + S.HuntCooldownSeconds
				end
			end
		end
	end
	return r
end

return function(check: (string, boolean) -> ())
	-- Isolation ordering
	local alone =
		Isolation.weights({ { x = 0, z = 0 }, { x = 1000, z = 0 }, { x = 2000, z = 0 } }, 3)
	local pair = Isolation.weights({ { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 2000, z = 0 } }, 3)
	local group = Isolation.weights({ { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 20, z = 0 } }, 3)
	check("horror: alone > pair > group", alone[1] > pair[1] and pair[1] > group[1])
	check("horror: alone uses WeightAlone", alone[1] == I.WeightAlone and pair[1] == I.WeightPair)
	local solo = Isolation.weights({ { x = 0, z = 0 } }, 1)
	check("horror: solo uses reduced baseline", solo[1] == I.SoloBaseline and solo[1] < alone[1])
	check(
		"horror: full group detected",
		Isolation.fullGroup({ { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 20, z = 0 } })
	)
	check(
		"horror: straggler breaks full group",
		not Isolation.fullGroup({ { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 2000, z = 0 } })
	)
	check("horror: solo is never a full group", not Isolation.fullGroup({ { x = 0, z = 0 } }))
	check("horror: full group => no hunt", not DreadLogic.canHunt({
		day = 10,
		now = 1e6,
		cooldownUntil = 0,
		hunting = false,
		fullGroup = true,
		candidates = 3,
	}))
	check(
		"horror: no hunt on day 1",
		DreadLogic.huntChance(D.Max, 1, 1) == 0
			and not DreadLogic.canHunt({
				day = 1,
				now = 1e6,
				cooldownUntil = 0,
				hunting = false,
				fullGroup = false,
				candidates = 1,
			})
	)
	local mixed = Isolation.weights({ { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 2000, z = 0 } }, 3)
	check("horror: most isolated is the straggler", Isolation.mostIsolated(mixed) == 3)
	local picks = { 0, 0, 0 }
	local roll = rng(7)
	for _ = 1, 3000 do
		local i = Isolation.pick(mixed, roll())
		if i then
			picks[i] += 1
		end
	end
	check(
		"horror: weighted pick favours the straggler",
		picks[3] > picks[1] * 1.5 and picks[3] > picks[2] * 1.5
	)

	-- Dread
	local d0 = baseInputs()
	d0.isolation = I.WeightAlone
	d0.farFromCamp, d0.dark = true, true
	local up = DreadLogic.step(10, d0, 1)
	local warm = baseInputs()
	warm.nearFire = true
	check("horror: dread rises alone in the dark", up > 10)
	check("horror: dread falls near fire", DreadLogic.step(10, warm, 1) < 10)
	local soloInputs = baseInputs()
	soloInputs.isolation = I.SoloBaseline
	check(
		"horror: solo gains less than a lone straggler",
		DreadLogic.step(0, soloInputs, 10)
			< DreadLogic.step(
				0,
				(function()
					local x = baseInputs()
					x.isolation = I.WeightAlone
					return x
				end)(),
				10
			)
	)
	check(
		"horror: cue levels coarse",
		DreadLogic.cueLevel(0) == 0 and DreadLogic.cueLevel(D.Max) == Config.Cue.MaxLevel
	)

	-- Stalker never kills from full health
	local floorOk = true
	for h = 1, MAX_HEALTH do
		local dmg = DreadLogic.strikeDamage(h, MAX_HEALTH)
		if dmg < 0 or (h >= MAX_HEALTH and h - dmg <= 0) then
			floorOk = false
		end
	end
	check(
		"horror: strike never kills from full",
		floorOk and MAX_HEALTH - DreadLogic.strikeDamage(MAX_HEALTH, MAX_HEALTH) > 0
	)

	-- Never enters warm spots
	local reps: { DreadLogic.Repeller } =
		{ { x = 0, z = 0, radius = 18 }, { x = 30, z = 0, radius = 14 } }
	local cx, cz, clear = DreadLogic.clampOutside(5, 10, reps, S.FireRepelMargin)
	check(
		"horror: clamp pushes out of warm spots",
		clear and not DreadLogic.isInside(cx, cz, reps, S.FireRepelMargin)
	)
	local wx, wz = 100, 0
	local walkOk = true
	for _ = 1, 200 do
		local ok
		wx, wz, ok = DreadLogic.moveToward(wx, wz, 0, 0, S.ChaseSpeed, 0.5, reps, S.FireRepelMargin)
		if not ok or DreadLogic.isInside(wx, wz, reps, S.FireRepelMargin) then
			walkOk = false
		end
	end
	check("horror: chase stops at the fire edge", walkOk)

	-- Hunt state machine
	local hunt = DreadLogic.newHunt()
	local o = DreadLogic.stepHunt(hunt, { distance = 0, light = "none", targetSafe = false }, 0.1)
	check("horror: no strike during telegraph", not o.strike and hunt.phase == "Telegraph")
	DreadLogic.stepHunt(
		hunt,
		{ distance = 100, light = "none", targetSafe = false },
		S.TelegraphSeconds
	)
	o = DreadLogic.stepHunt(hunt, { distance = 0, light = "none", targetSafe = false }, 0.1)
	check("horror: strike then retreat", o.strike and o.retreatStarted and hunt.phase == "Retreat")
	local flare = DreadLogic.newHunt()
	o = DreadLogic.stepHunt(flare, { distance = 0, light = "flare", targetSafe = false }, 0.1)
	check("horror: flare ends hunt", o.retreatStarted and not o.strike)
	local torch = DreadLogic.newHunt()
	DreadLogic.stepHunt(
		torch,
		{ distance = 100, light = "none", targetSafe = false },
		S.TelegraphSeconds
	)
	o = DreadLogic.stepHunt(torch, { distance = 0, light = "torch", targetSafe = false }, 0.1)
	check(
		"horror: no strike on torch holder",
		not o.strike and torch.huntLeft < S.MaxHuntSeconds * 0.6
	)
	local safe = DreadLogic.newHunt()
	DreadLogic.stepHunt(
		safe,
		{ distance = 100, light = "none", targetSafe = false },
		S.TelegraphSeconds
	)
	o = DreadLogic.stepHunt(safe, { distance = 0, light = "none", targetSafe = true }, 0.1)
	check("horror: no strike inside warm spot", not o.strike)

	-- 100-day seeded sim: caps hold, invariants hold, deterministic
	local a = simulate(12345, 100, 3)
	local b = simulate(12345, 100, 3)
	local same = #a.trace == #b.trace and a.hunts == b.hunts and a.strikes == b.strikes
	for i, v in a.trace do
		if b.trace[i] ~= v then
			same = false
			break
		end
	end
	check("horror sim: deterministic", same)
	check("horror sim: dread capped", a.maxDread <= D.Max and a.maxDread >= 0)
	check("horror sim: hunt chance capped", a.maxChance <= S.MaxHuntChance)
	check("horror sim: lurker density capped", a.maxDensity <= L.MaxDensity)
	check("horror sim: hunts happen", a.hunts > 0 and a.strikes > 0)
	check("horror sim: full group never hunted", not a.huntsBlocked)
	check("horror sim: no day-1 hunt", not a.huntsDay1)
	check("horror sim: never inside warm spots", not a.insideRepeller)
	check("horror sim: never kills from full", not a.killedFromFull)
	local s1 = simulate(999, 100, 1)
	check(
		"horror sim (solo): caps and invariants",
		s1.maxDread <= D.Max
			and s1.maxChance <= S.MaxHuntChance
			and not s1.insideRepeller
			and not s1.killedFromFull
			and not s1.huntsDay1
	)
	check(
		"horror: gain multiplier capped",
		DreadLogic.gainMultiplier(1e6, 1e6, 1e6) <= DreadLogic.maxGainMultiplier()
	)

	-- Lurker data
	local lurkersOk = true
	for _, def in Lurkers.List do
		if def.dreadOnSight > D.Max or def.vanishDistance <= 0 then
			lurkersOk = false
		end
	end
	check(
		"horror: lurker data within caps",
		lurkersOk and Lurkers.ByKind.EyesInDark.torchRetreatRadius ~= nil
	)
end
