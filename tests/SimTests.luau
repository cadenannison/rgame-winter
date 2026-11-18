--!strict
-- Tests for the sim harness and DebugCommands validation.

local Config = require("../src/shared/Config")
local DebugCommands = require("../src/shared/logic/DebugCommands")
local Sim = require("./sim")

-- Placeholder system: records a seeded roll every tick and a day marker per day.
local function placeholderSystem(): Sim.System
	return {
		name = "placeholder",
		step = function(sim, clock)
			if sim.rng:chance(0.01) then
				sim:record("roll", clock.time)
			end
		end,
		onDay = function(sim, day)
			sim:record("day", day)
		end,
	}
end

return function(check: (string, boolean) -> ())
	Sim.fireBuildChecks(check)
	local ok, a, b = Sim.determinism(12345, 100, function(sim)
		sim:addSystem(placeholderSystem())
	end)
	check("sim 100-day determinism (same seed)", ok and a.days == 101 and a.events > 100)
	check("sim run b matches a", a.hash == b.hash)

	local other = Sim.new({ seed = 999 })
	other:addSystem(placeholderSystem())
	check("sim different seed differs", other:runDays(100).hash ~= a.hash)

	-- Phase 3: 100 days, fixed seed, every cap holds, no meter leaves its range, deterministic.
	local stats: Sim.Phase3Stats? = nil
	local okP3, p3a, p3b = Sim.determinism(4242, 100, function(sim)
		local system, s = Sim.phase3System()
		sim:addSystem(system)
		stats = s
	end)
	check("phase3 100-day determinism", okP3 and p3a.hash == p3b.hash and p3a.events > 100)
	local st = stats :: Sim.Phase3Stats
	local broken = {}
	for name in st.capBroken do
		table.insert(broken, name)
	end
	table.sort(broken)
	if #broken > 0 then
		print(`  caps broken: {table.concat(broken, ", ")}`)
	end
	check("phase3 all caps hold (events, dread, hunt, mobs, warmth)", #broken == 0)
	check("phase3 no negative or NaN meters", not st.negativeMeter)
	check("phase3 events happened (dark + blizzard)", st.darkStarts > 0 and st.blizzards > 0)
	check("phase3 no dark event before FirstDay", not st.earlyDark)
	check("phase3 dark events per day capped", st.maxDarkPerDay <= Config.Events.MaxPerDay)
	check("phase3 dark event never overlaps a blizzard", not st.overlap)
	check("phase3 live mob budget capped", st.maxBudget <= Config.Scaling.MaxLiveMobs)
	check("phase3 hunt chance capped", st.maxHuntChance <= Config.Stalker.MaxHuntChance)
	check("phase3 warmth drain capped", st.maxWarmthMult <= Config.Meters.MaxWarmthDrainMultiplier)
	check("phase3 stalker never kills from full", st.strikesFromFull == 0)
	check("phase3 sheltering party survives 100 days", st.deaths == 0)

	-- Phase 4: 100 daily runs of meta progress; perks, counters, coins and achievements stay capped.
	local p4: Sim.Phase4Stats? = nil
	local okP4, p4a, p4b = Sim.determinism(9090, 100, function(sim)
		local system, s = Sim.phase4System()
		sim:addSystem(system)
		p4 = s
	end)
	check("phase4 100-day determinism", okP4 and p4a.hash == p4b.hash)
	local s4 = p4 :: Sim.Phase4Stats
	local broken4 = {}
	for name in s4.capBroken do
		table.insert(broken4, name)
	end
	table.sort(broken4)
	if #broken4 > 0 then
		print(`  phase4 caps broken: {table.concat(broken4, ", ")}`)
	end
	check("phase4 meta caps hold (progress, stats, coins, perks)", #broken4 == 0)
	check("phase4 achievements granted, each once", s4.grants > 0 and not s4.doubleGrant)
	check("phase4 profile valid every day", not s4.invalidProfile)
	check("phase4 perk magnitude capped", s4.maxPerkDelta <= Config.Meta.MaxPerkMagnitude)
	check("phase4 perk bonus yield never above base", not s4.yieldOver)

	local r1, r2 = Sim.newRng(7), Sim.newRng(7)
	check("rng reproducible", r1:next() == r2:next() and r1:int(1, 6) == r2:int(1, 6))
	local inRange = true
	for _ = 1, 200 do
		local v = r1:int(3, 5)
		inRange = inRange and v >= 3 and v <= 5
	end
	check("rng int inclusive range", inRange)

	local D = Config.Debug
	local limits: DebugCommands.Limits = {
		maxDay = D.MaxDay,
		maxClockSpeed = D.MaxClockSpeed,
		ringCount = D.RingCount,
		darkEvents = D.DarkEvents,
		itemIds = { "Wood" },
		mobKinds = D.MobKinds,
	}
	check("debug give known item", (DebugCommands.validate("give", "Wood", limits)))
	check("debug give rejects unknown", not DebugCommands.validate("give", "Gold", limits))
	check("debug runSummary takes no arg", (DebugCommands.validate("runSummary", nil, limits)))
	check("debug spawnMob hare", (DebugCommands.validate("spawnMob", "ArcticHare", limits)))
	check("debug spawnMob rejects number", not DebugCommands.validate("spawnMob", 3, limits))
	check("debug setDay valid", (DebugCommands.validate("setDay", 5, limits)))
	check("debug setDay rejects nan", not DebugCommands.validate("setDay", 0 / 0, limits))
	check("debug setDay rejects fraction", not DebugCommands.validate("setDay", 1.5, limits))
	check(
		"debug ring out of range",
		not DebugCommands.validate("teleportRing", D.RingCount + 1, limits)
	)
	check("debug darkEvent unknown", not DebugCommands.validate("darkEvent", "Nope", limits))
	check("debug bool required", not DebugCommands.validate("blizzard", 1, limits))
	check("debug unknown command", not DebugCommands.validate("hax", true, limits))
	check("debug non-string name", not DebugCommands.validate(5, true, limits))
end
