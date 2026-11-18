--!strict
-- Ruined temple plan (pure). Local origin: footprint centre at ground. Gate faces +Z (south).
-- Surface: courtyard, great hall, two side chambers, stair vestibule. Underground (-21): crypt hall,
-- ossuary, vault, legendary chamber, reached by a switchback stair shaft. Spooky but PG: runes, mist, cold light.

local Config = require("../Config")
local Kit = require("./PlanKitB")

local TemplePlan = {}

local ID = "RuinedTemple"
local P = Kit.Props
local G = Kit.SURFACE_Y
local DEEP = -21

function TemplePlan.make(seed: number): Kit.Plan
	local plan = Kit.new(ID, 100, 100, seed)
	local rng = Kit.rng(seed + 202)
	Kit.pad(plan, 54, 54, 30, "Glacier")

	local function surface(
		id: string,
		kind: string,
		x1: number,
		z1: number,
		x2: number,
		z2: number,
		roof: boolean,
		h: number?
	)
		Kit.room(plan, {
			id = id,
			kind = kind,
			x1 = x1,
			z1 = z1,
			x2 = x2,
			z2 = z2,
			y = G,
			height = h,
			roof = roof,
			wall = "Stone",
			floorStyle = "StoneDark",
			roofStyle = "StoneDark",
		})
	end
	local function crypt(id: string, kind: string, x1: number, z1: number, x2: number, z2: number)
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

	surface("courtyard", "outer courtyard", -50, 22, 50, 50, false)
	surface("hall", "great hall", -20, -26, 20, 22, true, 14)
	surface("chamberW", "west chamber", -50, -26, -20, 22, true)
	surface("chamberE", "east chamber", 20, -26, 50, 22, true)
	surface("vestibule", "stair vestibule", -50, -41, -21, -26, true)
	crypt("cryptHall", "crypt hall", -50, -41, -21, -26)
	crypt("ossuary", "ossuary", -50, -26, -21, -4)
	crypt("vault", "sealed vault", -21, -26, 21, -4)
	crypt("legendary", "legendary chamber", 21, -26, 50, -4)

	Kit.stairwell(
		plan,
		"shaft",
		-21,
		-41,
		21,
		-26,
		G,
		DEEP,
		"W",
		"vestibule",
		"cryptHall",
		"StoneDark"
	)
	plan.byId.shaft.landmark = "Spiral stair with rune lamp"

	Kit.exterior(plan, "courtyard", "S", 0, 12) -- broken gate
	Kit.connect(plan, "courtyard", "hall")
	Kit.connect(plan, "hall", "chamberW")
	Kit.connect(plan, "hall", "chamberE")
	Kit.connect(plan, "chamberW", "vestibule")
	Kit.connect(plan, "cryptHall", "ossuary")
	Kit.connect(plan, "ossuary", "vault")
	Kit.connect(plan, "vault", "legendary")

	-- Landmark per room (each visibly different).
	Kit.landmark(plan, "courtyard", "Broken gate arch", "Stone", 6, 12, 3, -0.7, 0.9)
	Kit.landmark(plan, "hall", "Great idol", "StoneDark", 5, 12, 5, 0, -0.9, Kit.Lights.Cold)
	Kit.landmark(plan, "chamberW", "Fallen pillar pile", "Stone", 7, 4, 5, -0.7, 0.6)
	Kit.landmark(plan, "chamberE", "Rune obelisk", "Rune", 3, 10, 3, 0.7, 0.6, Kit.Lights.Rune)
	Kit.landmark(plan, "vestibule", "Statue of the keeper", "StoneDark", 3, 9, 3, -0.8, 0.7)
	Kit.landmark(plan, "cryptHall", "Candle altar", "Stone", 5, 4, 3, -0.8, 0.7, Kit.Lights.Warm)
	Kit.landmark(plan, "ossuary", "Urn wall", "StoneDark", 10, 6, 2, -0.5, 0.9)
	Kit.landmark(plan, "vault", "Sealed door slab", "Metal", 8, 9, 1.5, 0, -0.9)
	Kit.landmark(
		plan,
		"legendary",
		"Glowing crystal throne",
		"Crystal",
		5,
		8,
		5,
		0.6,
		-0.6,
		Kit.Lights.Rune
	)

	Kit.chest(plan, "courtyard", 0.6, 0.6, 0)
	Kit.chest(plan, "hall", 0.0, 0.5, 1)
	Kit.chest(plan, "chamberW", -0.5, -0.5, 1)
	Kit.chest(plan, "chamberE", 0.5, -0.4, 1)
	Kit.chest(plan, "cryptHall", 0.4, -0.5, 2)
	Kit.chest(plan, "ossuary", -0.5, 0.5, 3)
	Kit.chest(plan, "vault", 0.6, 0.6, 3)
	Kit.chest(plan, "legendary", 0.0, 0.0, Config.Loot.MaxDepthTier)
	Kit.chest(plan, "legendary", -0.6, 0.6, Config.Loot.MaxDepthTier)

	-- Spooky zones: the crypt rooms raise the Dread cue hook (server-side, adapter).
	plan.dread.cryptHall = "Crypt"
	plan.dread.ossuary = "Crypt"
	plan.dread.vault = "Crypt"
	plan.dread.legendary = "Legendary"

	Kit.finish(plan)

	Kit.scatter(
		plan,
		rng,
		"courtyard",
		26,
		{ P.Rubble, P.FallenColumn, P.Column, P.Rubble, P.Statue }
	)
	Kit.scatter(plan, rng, "courtyard", 3, { P.ColdLampPost })
	Kit.scatter(plan, rng, "hall", 22, { P.Pew, P.Pew, P.Column, P.Rubble, P.Urn })
	Kit.scatter(plan, rng, "hall", 3, { P.ColdHangLantern })
	Kit.scatter(plan, rng, "chamberW", 14, { P.Rubble, P.Urn, P.Shelf, P.FallenColumn })
	Kit.scatter(plan, rng, "chamberW", 2, { P.ColdHangLantern })
	Kit.scatter(plan, rng, "chamberE", 14, { P.Rubble, P.Urn, P.Statue, P.FallenColumn })
	Kit.scatter(plan, rng, "chamberE", 2, { P.ColdHangLantern })
	Kit.scatter(plan, rng, "vestibule", 7, { P.Rubble, P.Urn })
	Kit.scatter(plan, rng, "vestibule", 1, { P.ColdHangLantern })
	Kit.scatter(plan, rng, "cryptHall", 14, { P.Sarcophagus, P.Urn, P.Rubble, P.Column })
	Kit.scatter(plan, rng, "cryptHall", 2, { P.Mist })
	Kit.scatter(plan, rng, "cryptHall", 2, { P.HangLantern })
	Kit.scatter(plan, rng, "ossuary", 22, { P.Urn, P.Urn, P.Sarcophagus, P.Rubble })
	Kit.scatter(plan, rng, "ossuary", 2, { P.Mist })
	Kit.scatter(plan, rng, "ossuary", 2, { P.ColdHangLantern })
	Kit.scatter(plan, rng, "vault", 16, { P.Urn, P.Sarcophagus, P.Column, P.Rubble })
	Kit.scatter(plan, rng, "vault", 2, { P.RuneStone })
	Kit.scatter(plan, rng, "vault", 1, { P.Mist })
	Kit.scatter(plan, rng, "legendary", 14, { P.Statue, P.Urn, P.Column, P.Sarcophagus })
	Kit.scatter(plan, rng, "legendary", 4, { P.RuneStone })
	Kit.scatter(plan, rng, "legendary", 1, { P.Mist })
	return plan
end

return TemplePlan
