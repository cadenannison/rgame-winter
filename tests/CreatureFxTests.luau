--!strict
-- Art Pass 3: pure creature FX helpers (telegraph ring, wisp light cap, crow flock).
local Fx = require("../src/shared/logic/CreatureFxLogic")

return function(check: (string, boolean) -> ())
	check("telegraph progress start", Fx.telegraphProgress(1.2, 0) == 0)
	check("telegraph progress half", math.abs(Fx.telegraphProgress(1.2, 0.6) - 0.5) < 1e-6)
	check(
		"telegraph progress clamps",
		Fx.telegraphProgress(1, 5) == 1 and Fx.telegraphProgress(1, -1) == 0
	)
	check("telegraph zero total is full", Fx.telegraphProgress(0, 0) == 1)
	check("fill radius monotonic", Fx.fillRadius(0.3, 10) < Fx.fillRadius(0.6, 10))
	check("fill radius ends at max", Fx.fillRadius(1, 10) == 10 and Fx.fillRadius(0, 10) == 0)
	check("fill transparency lerps", math.abs(Fx.fillTransparency(1, 0.8, 0.3) - 0.3) < 1e-9)

	local cands: { Fx.Candidate } = {
		{ id = 1, dist = 10 },
		{ id = 2, dist = 5 },
		{ id = 3, dist = 69 },
		{ id = 4, dist = 80 },
		{ id = 5, dist = 20 },
		{ id = 6, dist = 30 },
	}
	local pick = Fx.selectLights(cands, {}, 4, 70, 0.15)
	local n = 0
	for _ in pick do
		n += 1
	end
	check("wisp lights capped", n == 4)
	check(
		"wisp lights nearest first",
		pick[2] == true and pick[1] == true and pick[5] == true and pick[6] == true
	)
	check("wisp lights out of radius dropped", pick[4] == nil and pick[3] == nil)
	local sticky = Fx.selectLights({ { id = 9, dist = 75 } }, { [9] = true }, 4, 70, 0.15)
	check("wisp light hysteresis keeps lit", sticky[9] == true)
	check(
		"wisp light hysteresis no new",
		Fx.selectLights({ { id = 9, dist = 75 } }, {}, 4, 70, 0.15)[9] == nil
	)
	check("wisp lights zero cap", next(Fx.selectLights(cands, {}, 0, 70, 0.15)) == nil)

	check("scatter rises", Fx.scatterStep(0, true, 0.1, 2) == 0.2)
	check("scatter caps at 1", Fx.scatterStep(0.95, true, 1, 2) == 1)
	check("scatter falls", Fx.scatterStep(1, false, 0.25, 2) == 0.5)
	check("scatter states", Fx.isScatterState("Run") and not Fx.isScatterState("Idle"))

	local bounded = true
	for i = 1, 3 do
		for _, s in { 0, 0.5, 1 } do
			local o = Fx.flockOffset(i, 3, 12.3, s, 1, 0, 3, 3, 30)
			if o.x ~= o.x or o.y ~= o.y or o.z ~= o.z or math.sqrt(o.x * o.x + o.z * o.z) > 33 then
				bounded = false
			end
		end
	end
	check("flock offset finite and bounded", bounded)
	local ahead = Fx.flockOffset(2, 3, 0, 1, 1, 0, 3, 3, 30)
	check("flock scatters along heading", ahead.x > 20)
	local noHeading = Fx.flockOffset(1, 3, 0, 1, 0, 0, 3, 3, 30)
	check(
		"flock zero heading stays finite",
		noHeading.x == noHeading.x and noHeading.z == noHeading.z
	)
end
