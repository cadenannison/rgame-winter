--!strict
-- Expanded ruins complex plan (pure). Local origin: footprint centre at ground. Gate faces +Z (south).
-- Surface: outer yard, great hall, two wings, inner court, archive, tower. Underground (-17): crypt hall,
-- cellar, cistern, treasury, reached by a switchback shaft beside the tower. Nothing is visible all at once.

local Config = require("../Config")
local Kit = require("./PlanKitB")

local RuinsPlan = {}

local ID = "ExpandedRuins"
local P = Kit.Props
local G = Kit.SURFACE_Y
local DEEP = -17

function RuinsPlan.make(seed: number): Kit.Plan
	local plan = Kit.new(ID, 120, 120, seed)
	local rng = Kit.rng(seed + 404)
	Kit.pad(plan, 64, 64, 26, "Slate")

	local function surface(
		id: string,
		kind: string,
		x1: number,
		z1: number,
		x2: number,
		z2: number,
		roof: boolean
	)
		Kit.room(plan, {
			id = id,
			kind = kind,
			x1 = x1,
			z1 = z1,
			x2 = x2,
			z2 = z2,
			y = G,
			roof = roof,
			wall = "Stone",
			floorStyle = "StoneDark",
			roofStyle = "StoneDark",
		})
	end
	local function under(id: string, kind: string, x1: number, z1: number, x2: number, z2: number)
		Kit.room(plan, {
			id = id,
			kind = kind,
			x1 = x1,
			z1 = z1,
			x2 = x2,
			z2 = z2,
			y = DEEP,
			underground = true,
			wall = "StoneDark",
			floorStyle = "StoneDark",
			roofStyle = "StoneDark",
		})
	end

	surface("yard", "outer yard", -60, 36, 60, 60, false)
	surface("hall", "ruined hall", -30, 0, 30, 36, true)
	surface("westWing", "west wing", -60, 0, -30, 36, true)
	surface("eastWing", "east wing", 30, 0, 60, 36, true)
	surface("court", "inner court", -30, -45, 30, 0, false)
	surface("archive", "archive", -60, -45, -30, 0, true)
	surface("tower", "watch tower", -24, -60, 12, -45, true)
	under("cryptHall", "crypt hall", -24, -60, 12, -45)
	under("cellar", "cellar", 12, -60, 48, -45)
	under("cistern", "cistern", -24, -45, 12, -15)
	under("treasury", "treasury", 12, -45, 48, -15)
	Kit.stairwell(
		plan,
		"shaft",
		-60,
		-60,
		-24,
		-45,
		G,
		DEEP,
		"E",
		"tower",
		"cryptHall",
		"StoneDark"
	)
	plan.byId.shaft.landmark = "Stair shaft with rune lamp"

	Kit.exterior(plan, "yard", "S", 0, 12)
	Kit.connect(plan, "yard", "hall")
	Kit.connect(plan, "yard", "westWing")
	Kit.connect(plan, "yard", "eastWing")
	Kit.connect(plan, "hall", "court")
	Kit.connect(plan, "westWing", "archive")
	Kit.connect(plan, "court", "tower")
	Kit.connect(plan, "cryptHall", "cellar")
	Kit.connect(plan, "cryptHall", "cistern")
	Kit.connect(plan, "cistern", "treasury")
	Kit.connect(plan, "cellar", "treasury")

	Kit.landmark(plan, "yard", "Toppled gate arch", "Stone", 8, 12, 3, -0.8, 0.9)
	Kit.landmark(plan, "hall", "Broken throne", "StoneDark", 5, 7, 4, 0.8, -0.9)
	Kit.landmark(plan, "westWing", "Collapsed bookshelves", "WallDark", 8, 5, 2, 0.9, 0.5)
	Kit.landmark(plan, "eastWing", "Carved shrine", "Stone", 5, 8, 4, 0.7, 0.7, Kit.Lights.Rune)
	Kit.landmark(plan, "court", "Dry fountain", "StoneDark", 8, 3, 8, 0.1, -0.2)
	Kit.landmark(plan, "archive", "Scroll table", "Wall", 6, 3, 4, -0.6, -0.6)
	Kit.landmark(plan, "tower", "Signal brazier", "MetalDark", 3, 4, 3, 0.7, 0.6, Kit.Lights.Warm)
	Kit.landmark(plan, "cryptHall", "Skull-less sarcophagus row", "Stone", 10, 3, 3.6, 0, -0.8)
	Kit.landmark(plan, "cellar", "Barrel tower", "Wall", 4, 7, 4, 0.7, 0.7)
	Kit.landmark(plan, "cistern", "Dark water basin", "Water", 12, 1, 12, 0.2, 0.2)
	Kit.landmark(plan, "treasury", "Gilded pedestal", "Brass", 4, 4, 4, 0.5, -0.6, Kit.Lights.Warm)

	Kit.chest(plan, "yard", 0.6, 0.6, 0)
	Kit.chest(plan, "hall", -0.6, 0.3, 1)
	Kit.chest(plan, "westWing", -0.5, -0.4, 1)
	Kit.chest(plan, "eastWing", 0.5, -0.4, 1)
	Kit.chest(plan, "court", 0.7, 0.5, 1)
	Kit.chest(plan, "archive", -0.5, 0.5, 2)
	Kit.chest(plan, "tower", 0.2, -0.5, 2)
	Kit.chest(plan, "cryptHall", 0.5, 0.5, 2)
	Kit.chest(plan, "cellar", 0.3, 0.2, 3)
	Kit.chest(plan, "cistern", -0.6, 0.6, 3)
	Kit.chest(plan, "treasury", 0.0, 0.2, Config.Loot.MaxDepthTier)
	Kit.chest(plan, "treasury", -0.6, 0.6, Config.Loot.MaxDepthTier)

	Kit.finish(plan)

	Kit.scatter(plan, rng, "yard", 30, { P.Rubble, P.FallenColumn, P.Column, P.Rubble, P.Statue })
	Kit.scatter(plan, rng, "yard", 2, { P.ColdLampPost })
	Kit.scatter(plan, rng, "hall", 20, { P.Pew, P.Column, P.Rubble, P.Urn, P.Rubble })
	Kit.scatter(plan, rng, "hall", 3, { P.HangLantern })
	Kit.scatter(plan, rng, "westWing", 16, { P.Shelf, P.Table, P.Rubble, P.Crate })
	Kit.scatter(plan, rng, "westWing", 2, { P.HangLantern })
	Kit.scatter(plan, rng, "eastWing", 16, { P.Urn, P.Statue, P.Rubble, P.Pew })
	Kit.scatter(plan, rng, "eastWing", 2, { P.ColdHangLantern })
	Kit.scatter(plan, rng, "court", 24, { P.Rubble, P.FallenColumn, P.Column, P.Urn })
	Kit.scatter(plan, rng, "court", 2, { P.ColdLampPost })
	Kit.scatter(plan, rng, "archive", 16, { P.Shelf, P.Shelf, P.Table, P.Crate })
	Kit.scatter(plan, rng, "archive", 2, { P.HangLantern })
	Kit.scatter(plan, rng, "tower", 8, { P.Crate, P.Barrel, P.Rubble })
	Kit.scatter(plan, rng, "tower", 1, { P.HangLantern })
	Kit.scatter(plan, rng, "cryptHall", 14, { P.Sarcophagus, P.Urn, P.Rubble })
	Kit.scatter(plan, rng, "cryptHall", 2, { P.Mist })
	Kit.scatter(plan, rng, "cryptHall", 2, { P.ColdHangLantern })
	Kit.scatter(plan, rng, "cellar", 20, { P.Barrel, P.Barrel, P.Crate, P.Shelf })
	Kit.scatter(plan, rng, "cellar", 2, { P.HangLantern })
	Kit.scatter(plan, rng, "cistern", 12, { P.Column, P.Rubble, P.Urn })
	Kit.scatter(plan, rng, "cistern", 2, { P.Mist })
	Kit.scatter(plan, rng, "cistern", 2, { P.ColdHangLantern })
	Kit.scatter(plan, rng, "treasury", 14, { P.Urn, P.Crate, P.Statue, P.Sarcophagus })
	Kit.scatter(plan, rng, "treasury", 2, { P.RuneStone })
	Kit.scatter(plan, rng, "treasury", 1, { P.Mist })
	return plan
end

return RuinsPlan
