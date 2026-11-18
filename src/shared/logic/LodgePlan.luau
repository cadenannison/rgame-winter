--!strict
-- Ranger lodge plan (pure). Local origin: footprint centre at ground. Porch faces +Z (south).
-- Surface (warm, wooden): porch, main room with hearth, kitchen, bunk room, pantry, tack room.
-- Cellar at -14 reached by a stair shaft off the pantry.

local Config = require("../Config")
local Kit = require("./PlanKitB")

local LodgePlan = {}

local ID = "RangerLodge"
local P = Kit.Props
local G = Kit.SURFACE_Y
local DEEP = -14

function LodgePlan.make(seed: number): Kit.Plan
	local plan = Kit.new(ID, 70, 56, seed)
	local rng = Kit.rng(seed + 303)
	Kit.pad(plan, 39, 32, 22, "Snow")

	local function surface(id: string, kind: string, x1: number, z1: number, x2: number, z2: number)
		Kit.room(plan, {
			id = id,
			kind = kind,
			x1 = x1,
			z1 = z1,
			x2 = x2,
			z2 = z2,
			y = G,
			wall = "Wall",
			floorStyle = "Floor",
			roofStyle = "Roof",
		})
	end
	local function cellar(id: string, kind: string, x1: number, z1: number, x2: number, z2: number)
		Kit.room(plan, {
			id = id,
			kind = kind,
			x1 = x1,
			z1 = z1,
			x2 = x2,
			z2 = z2,
			y = DEEP,
			height = 10,
			underground = true,
			wall = "Foundation",
			floorStyle = "Foundation",
			roofStyle = "WallDark",
		})
	end

	surface("porch", "porch", -14, 14, 14, 28)
	surface("main", "main room", -14, -13, 14, 14)
	surface("bunk", "bunk room", -35, -13, -14, 14)
	surface("kitchen", "kitchen", 14, -13, 35, 14)
	surface("pantry", "pantry", -3, -28, 14, -13)
	surface("tack", "tack room", 14, -28, 35, -13)
	cellar("cellarA", "cellar", -3, -28, 14, -13)
	cellar("cellarB", "cold store", 14, -28, 35, -13)
	Kit.stairwell(plan, "shaft", -35, -28, -3, -13, G, DEEP, "E", "pantry", "cellarA", "Wall")
	plan.byId.shaft.landmark = "Cellar stairs with lantern"

	Kit.exterior(plan, "porch", "S", 0, 8)
	Kit.connect(plan, "porch", "main")
	Kit.connect(plan, "main", "bunk")
	Kit.connect(plan, "main", "kitchen")
	Kit.connect(plan, "main", "pantry")
	Kit.connect(plan, "pantry", "tack")
	Kit.connect(plan, "cellarA", "cellarB")

	Kit.landmark(plan, "porch", "Snowy rocking chair", "WallDark", 3, 3, 3, -0.8, 0.8)
	local hearth = Kit.landmark(
		plan,
		"main",
		"Stone hearth with fire",
		"Stone",
		7,
		6,
		3,
		-0.6,
		-0.95,
		Kit.Lights.Warm
	)
	Kit.landmark(plan, "bunk", "Antler wall", "WallDark", 6, 4, 1, -0.9, 0)
	Kit.landmark(plan, "kitchen", "Iron stove", "MetalDark", 4, 5, 4, 0.8, -0.8, Kit.Lights.Warm)
	Kit.landmark(plan, "pantry", "Hanging herb rack", "Wall", 5, 5, 1.2, 0.8, -0.9)
	Kit.landmark(plan, "tack", "Saddle rack", "Wall", 6, 4, 2, 0.5, -0.9)
	Kit.landmark(plan, "cellarA", "Wine barrels", "Wall", 3, 4, 3, 0, 0.9)
	Kit.landmark(plan, "cellarB", "Frosted ice block", "Ice", 4, 6, 4, 0.7, -0.6, Kit.Lights.Cold)

	Kit.chest(plan, "porch", 0.7, 0.5, 0)
	Kit.chest(plan, "main", 0.6, 0.4, 0)
	Kit.chest(plan, "bunk", -0.5, -0.3, 1)
	Kit.chest(plan, "kitchen", 0.3, 0.5, 1)
	Kit.chest(plan, "pantry", 0.3, 0.3, 2)
	Kit.chest(plan, "tack", -0.5, 0.2, 2)
	Kit.chest(plan, "cellarA", -0.4, 0.2, 3)
	Kit.chest(plan, "cellarB", 0.0, 0.3, Config.Loot.MaxDepthTier)

	Kit.finish(plan)

	-- The hearth: one fire and one chimney smoke (2 of the 4 particle slots) plus warm light.
	local hx = hearth.x
	local fire =
		Kit.box("HearthFire", hx, G + 1.2, hearth.z + hearth.sz / 2 + 1, 3, 2, 1.2, "Lamp", false)
	fire.fx = "Fire"
	fire.light = { color = "Warm", range = 34, brightness = 1.6 }
	Kit.dressAt(plan, "main", fire)
	local smoke = Kit.box("HearthSmoke", hx, G + 9, hearth.z, 2, 1, 1.2, "Lamp", false)
	smoke.fx = "Smoke"
	Kit.dressAt(plan, "main", smoke)

	Kit.scatter(plan, rng, "porch", 8, { P.Barrel, P.Crate, P.Bench, P.Rope })
	Kit.scatter(plan, rng, "porch", 1, { P.LampPost })
	Kit.scatter(plan, rng, "main", 14, { P.Table, P.Bench, P.Rug, P.Shelf, P.Barrel })
	Kit.scatter(plan, rng, "main", 3, { P.HangLantern })
	Kit.scatter(plan, rng, "bunk", 14, { P.Bunk, P.Bunk, P.Crate, P.Shelf })
	Kit.scatter(plan, rng, "bunk", 2, { P.HangLantern })
	Kit.scatter(plan, rng, "kitchen", 14, { P.Table, P.Shelf, P.Barrel, P.Crate, P.Bench })
	Kit.scatter(plan, rng, "kitchen", 2, { P.HangLantern })
	Kit.scatter(plan, rng, "pantry", 12, { P.Shelf, P.Barrel, P.Crate })
	Kit.scatter(plan, rng, "pantry", 1, { P.HangLantern })
	Kit.scatter(plan, rng, "tack", 10, { P.Crate, P.Rope, P.Shelf, P.Barrel })
	Kit.scatter(plan, rng, "tack", 1, { P.HangLantern })
	Kit.scatter(plan, rng, "cellarA", 16, { P.Barrel, P.Barrel, P.Crate, P.Shelf })
	Kit.scatter(plan, rng, "cellarA", 2, { P.HangLantern })
	Kit.scatter(plan, rng, "cellarB", 12, { P.IceShard, P.Crate, P.Barrel })
	Kit.scatter(plan, rng, "cellarB", 2, { P.ColdHangLantern })
	return plan
end

return LodgePlan
