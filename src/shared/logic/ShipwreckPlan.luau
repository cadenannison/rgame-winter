--!strict
-- Frozen shipwreck plan (pure). Local origin: keel centre on the lake ice (ground 0). Stern at -X, bow at +X.
-- Three decks: L0 lower (crew, cargo hold, flooded bow), L1 main (open deck, galley, forecastle), L2 captain.

local Config = require("../Config")
local Kit = require("./PlanKitB")

local ShipwreckPlan = {}

local ID = "FrozenShipwreck"
local P = Kit.Props
local L0, L1, L2 = Kit.SURFACE_Y, 14, 27
local HALF = 18 -- half beam

function ShipwreckPlan.make(seed: number): Kit.Plan
	local plan = Kit.new(ID, 150, 44, seed)
	local rng = Kit.rng(seed + 101)

	local function room(
		id: string,
		kind: string,
		x1: number,
		x2: number,
		y: number,
		extra: { [string]: any }?
	)
		local r = Kit.room(plan, {
			id = id,
			kind = kind,
			x1 = x1,
			z1 = -HALF,
			x2 = x2,
			z2 = HALF,
			y = y,
			roof = (extra and extra.roof) :: boolean?,
			floor = (extra and extra.floor) :: boolean?,
			rail = (extra and extra.rail) :: boolean?,
			wallH = (extra and extra.wallH) :: number?,
			flooded = (extra and extra.flooded) :: boolean?,
			wall = "Hull",
			floorStyle = "Deck",
			roofStyle = "Deck",
		})
		return r
	end

	room("hold", "cargo hold", -35, 9, L0, { roof = false })
	room("crew", "crew quarters", -75, -35, L0, { roof = false })
	room("flooded", "flooded lower deck", 9, 53, L0, { roof = false, flooded = true })
	room("deck", "main deck", -35, 29, L1, { roof = false, rail = true, wallH = 5 })
	room("galley", "galley", -75, -35, L1, { roof = true })
	room("forecastle", "forecastle", 29, 53, L1, { roof = true })
	room("captain", "captain's quarters", 29, 53, L2, { roof = true, floor = false })

	Kit.connect(plan, "hold", "crew")
	Kit.connect(plan, "hold", "flooded")
	Kit.connect(plan, "deck", "galley")
	Kit.connect(plan, "deck", "forecastle")
	Kit.exterior(plan, "hold", "S", -12, 8) -- hull breach: the way in
	Kit.exterior(plan, "flooded", "N", 30, 8) -- second breach
	-- hold up to the main deck through a hatch; deck up to the captain's quarters
	local hatch = Kit.ramp(plan, "hold", "deck", -33, L0, -8, "X", 1, L1 - L0)
	Kit.hole(plan, "deck", hatch)
	Kit.ramp(plan, "deck", "captain", -10, L1, 8, "X", 1, L2 - L1)
	Kit.door(plan, "captain", "W", 8, L2)

	-- Hull shape: bow closes to a point past the forecastle.
	local bowAngle = math.deg(math.atan2(HALF, 22))
	for _, sign in { 1, -1 } do
		local b = Kit.box(
			`Bow_{if sign > 0 then "S" else "N"}`,
			64,
			14,
			9 * sign,
			28.4,
			26,
			1.5,
			"Hull",
			true
		)
		b.ry = bowAngle * sign
		Kit.shell(plan, b)
	end
	-- Keel skirt and ice shelf the hull is frozen into.
	Kit.shell(plan, Kit.box("Keel", 0, 0.2, 0, 148, 1, 40, "Hull", true))
	Kit.shell(plan, Kit.box("IceShelfS", -8, 0.4, 20, 90, 1.2, 4, "Ice", true))
	Kit.shell(plan, Kit.box("IceShelfN", 30, 0.4, -20, 70, 1.2, 4, "Ice", true))
	-- Stern castle rear and a broken mast stump stay as solid shell.
	local mast = Kit.landmark(plan, "deck", "Broken mast", "Hull", 2.5, 30, 2.5, 0.2, 0.1)
	mast.rz = 6

	Kit.landmark(plan, "hold", "Stacked cargo crates", "WallDark", 6, 5, 6, 0.8, -0.8)
	Kit.landmark(plan, "crew", "Red lantern post", "Lamp", 1, 7, 1, -0.8, 0.8, Kit.Lights.Warm)
	Kit.landmark(plan, "flooded", "Frozen ice pillar", "Ice", 4, 11, 4, 0.6, 0.6)
	Kit.landmark(plan, "galley", "Cast-iron stove", "MetalDark", 4, 5, 4, -0.8, -0.8)
	Kit.landmark(plan, "forecastle", "Anchor winch", "Metal", 5, 4, 5, 0.6, -0.6)
	Kit.landmark(plan, "captain", "Brass globe", "Brass", 3, 4, 3, 0.7, 0.5, Kit.Lights.Warm)

	-- Chests: best in the captain's quarters, deepest.
	Kit.chest(plan, "hold", -0.6, 0.8, 0)
	Kit.chest(plan, "crew", 0.5, -0.8, 1)
	Kit.chest(plan, "deck", 0.7, -0.7, 1)
	Kit.chest(plan, "galley", 0.7, 0.7, 2)
	Kit.chest(plan, "forecastle", -0.5, 0.5, 2)
	Kit.chest(plan, "flooded", 0.0, -0.7, 3)
	Kit.chest(plan, "captain", -0.6, -0.6, 3)
	Kit.chest(plan, "captain", 0.6, 0.0, Config.Loot.MaxDepthTier)

	Kit.finish(plan)

	-- Dressing (spawned near players only). Total stays under the structure's DressingParts budget.
	Kit.scatter(plan, rng, "hold", 22, { P.Barrel, P.Crate, P.Crate, P.Rope, P.Planks })
	Kit.scatter(plan, rng, "hold", 3, { P.HangLantern })
	Kit.scatter(plan, rng, "crew", 12, { P.Bunk, P.Crate, P.Bench, P.Rope })
	Kit.scatter(plan, rng, "crew", 2, { P.HangLantern })
	Kit.scatter(plan, rng, "flooded", 14, { P.IceShard, P.IceShard, P.Planks, P.Crate })
	Kit.scatter(plan, rng, "flooded", 4, { P.Mist })
	Kit.scatter(plan, rng, "flooded", 2, { P.ColdHangLantern })
	Kit.scatter(plan, rng, "deck", 22, { P.Barrel, P.Cannon, P.Rope, P.Planks, P.Crate })
	Kit.scatter(plan, rng, "deck", 4, { P.LampPost })
	Kit.scatter(plan, rng, "galley", 16, { P.Table, P.Bench, P.Barrel, P.Shelf, P.Crate })
	Kit.scatter(plan, rng, "galley", 2, { P.HangLantern })
	Kit.scatter(plan, rng, "forecastle", 10, { P.Rope, P.Barrel, P.Crate, P.Planks })
	Kit.scatter(plan, rng, "forecastle", 1, { P.HangLantern })
	Kit.scatter(plan, rng, "captain", 14, { P.Table, P.Shelf, P.Bunk, P.Rug, P.Crate })
	Kit.scatter(plan, rng, "captain", 2, { P.HangLantern })
	return plan
end

return ShipwreckPlan
