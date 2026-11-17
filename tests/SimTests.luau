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
	local ok, a, b = Sim.determinism(12345, 100, function(sim)
		sim:addSystem(placeholderSystem())
	end)
	check("sim 100-day determinism (same seed)", ok and a.days == 101 and a.events > 100)
	check("sim run b matches a", a.hash == b.hash)

	local other = Sim.new({ seed = 999 })
	other:addSystem(placeholderSystem())
	check("sim different seed differs", other:runDays(100).hash ~= a.hash)

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
	}
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
