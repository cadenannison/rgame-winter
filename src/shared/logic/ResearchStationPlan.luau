--!strict
-- Pure plan for the abandoned research station: a surface complex of ten rooms in four wings, two stair halls,
-- eight rooms on the first underground level (labs, server room, archive, cold storage, flooded corridor, boiler
-- room) and five on the second (vault, core lab, deep archive, cryo chamber). 25 rooms, three levels.
-- Local frame: y = 0 is the entrance floor; the garage (south, +z) is the entrance. Seed picks notes, chest
-- corners, light flicker and prop variants; the layout itself is fixed (the adapter rotates it by seed).

local Kit = require("./StructurePlanKitA")

local ResearchStationPlan = {}

export type Plan = Kit.Plan

local ID = "ResearchStation"
local Y1, Y2 = -14, -28
local H_SURFACE, H_UNDER = 12, 11
local LAMP_RANGE = 26
local LAMP_BRIGHTNESS = 1.1
local FLICKER_CHANCE = 0.45

local NOTES = {
	"Day 41. The heating failed in the east wing again. We moved the cots to the lobby. Nobody wants to sleep near the vents. They make that sound at night.",
	"Whoever keeps unplugging the radio: stop. We need it. We are not alone on the signal band.",
	"The samples in cold storage are fine. It is the shelf beside them I do not like. Something keeps scratching at the door.",
	"The pumps stopped and the lower corridor flooded overnight. Keep your lamp on when you cross. The water is very cold.",
	"Do not trust the lights on level two. They go out in pairs, and the echoes sound wrong.",
	"Dr. Hale left word: if you read this, leave the core running. Do not follow the footprints down.",
	"Generator fuel is low. We ran it all night so the dark outside would stay outside.",
	"I counted the lamps in the server hall twice. Twelve. When I came back there were eleven.",
	"Final entry. The others went down to the vault. I am staying by the stairs. It is quiet now. Too quiet.",
	"Kitchen inventory: tins, tins, tins. Someone has been eating at the mess table while the rest of us sleep.",
	"The cryo pods are empty. The logs say they never held anyone. The fog on the glass says otherwise.",
	"If the lights flicker twice, stay where you are and count to sixty. It usually passes.",
}

local function addRooms(plan: Plan)
	local function room(
		id: string,
		kind: string,
		name: string,
		level: number,
		x0: number,
		z0: number,
		x1: number,
		z1: number,
		landmark: string,
		dark: boolean?
	)
		local y = if level == 0 then 0 elseif level == -1 then Y1 else Y2
		local h = if level == 0 then H_SURFACE else H_UNDER
		Kit.addRoom(plan, {
			id = id,
			kind = kind,
			name = name,
			level = level,
			x0 = x0,
			z0 = z0,
			x1 = x1,
			z1 = z1,
			y = y,
			h = h,
			landmark = landmark,
			dark = dark,
		})
	end
	-- surface (y = 0)
	room(
		"lobby",
		"lobby",
		"Reception",
		0,
		-16,
		-12,
		16,
		12,
		"reception desk and the faded station logo"
	)
	room(
		"westCorr",
		"corridor",
		"West Corridor",
		0,
		-44,
		-4,
		-16,
		4,
		"frosted windows and a long pipe run"
	)
	room("dorm", "living", "Dormitory", 0, -60, -14, -44, 14, "rows of bunk beds")
	room("mess", "living", "Mess Hall", 0, -44, 4, -16, 22, "long tables and the serving hatch")
	room("eastCorr", "corridor", "East Corridor", 0, 16, -4, 44, 4, "flickering strip lights")
	room("genHall", "utility", "Generator Hall", 0, 44, -16, 60, 16, "three humming generators")
	room(
		"northCorr",
		"corridor",
		"North Corridor",
		0,
		-4,
		-34,
		4,
		-12,
		"radio cables on the ceiling"
	)
	room("radio", "lab", "Radio Room", 0, -14, -45, 14, -34, "the radio console below the mast")
	room("offices", "lab", "Offices", 0, 16, 4, 44, 22, "overturned desks and a wall of memos")
	room("garage", "utility", "Vehicle Bay", 0, -16, 12, 16, 40, "wrecked tracked vehicle")
	-- first underground level (y = -14)
	room(
		"corrA",
		"corridor",
		"Maintenance Corridor",
		-1,
		-60,
		20,
		-28,
		28,
		"exposed pipes and a hazard stripe"
	)
	room("labA", "lab", "Lab A", -1, -60, 0, -36, 20, "long white lab benches")
	room("labB", "lab", "Lab B", -1, -36, 0, -12, 20, "glass sample cabinets")
	room("server", "utility", "Server Room", -1, -12, -8, 12, 20, "rows of humming server racks")
	room("archive", "lab", "Records Archive", -1, 12, 0, 36, 20, "tall filing shelves")
	room("cold", "cold", "Cold Storage", -1, 36, 0, 60, 20, "frosted walls and blocks of ice", true)
	room(
		"flooded",
		"corridor",
		"Flooded Corridor",
		-1,
		-36,
		-16,
		12,
		-8,
		"ankle deep black water",
		true
	)
	room("boiler", "utility", "Boiler Room", -1, -16, 20, 16, 40, "great rusted boiler tanks", true)
	-- second underground level (y = -28)
	room("corrB", "corridor", "Deep Corridor", -2, 36, 20, 60, 28, "red hazard markings")
	room("vault", "lab", "Specimen Vault", -2, 36, -4, 60, 20, "rows of empty specimen tanks", true)
	room("core", "lab", "Core Lab", -2, 12, -4, 36, 20, "the dark core in the middle")
	room("deep", "lab", "Deep Archive", -2, -12, -4, 12, 20, "sealed record lockers", true)
	room("cryo", "lab", "Cryo Chamber", -2, -36, -4, -12, 20, "frosted cryo pods in a ring", true)

	Kit.addHall(plan, {
		id = "hallW",
		name = "West Stairs",
		axis = "x",
		hi = "max",
		x0 = -60,
		z0 = 28,
		x1 = -16,
		z1 = 36,
		yLow = Y1,
		yHigh = 0,
		upperH = H_SURFACE,
		level = -1,
		landmark = "a long ramp down into the dark",
	})
	Kit.addHall(plan, {
		id = "hallE",
		name = "East Stairs",
		axis = "x",
		hi = "min",
		x0 = 16,
		z0 = 28,
		x1 = 60,
		z1 = 36,
		yLow = Y2,
		yHigh = Y1,
		upperH = H_UNDER,
		level = -2,
		landmark = "a ramp down toward a red glow",
		dark = true,
	})
end

local function addLinks(plan: Plan)
	-- surface
	Kit.link(plan, "lobby", "westCorr")
	Kit.link(plan, "lobby", "eastCorr")
	Kit.link(plan, "lobby", "northCorr")
	Kit.link(plan, "lobby", "garage")
	Kit.link(plan, "westCorr", "dorm")
	Kit.link(plan, "westCorr", "mess")
	Kit.link(plan, "eastCorr", "offices")
	Kit.link(plan, "eastCorr", "genHall")
	Kit.link(plan, "northCorr", "radio")
	Kit.link(plan, "hallW", "garage")
	-- first level
	Kit.link(plan, "corrA", "hallW", -54)
	Kit.link(plan, "corrA", "labA")
	Kit.link(plan, "labA", "labB")
	Kit.link(plan, "labB", "server")
	Kit.link(plan, "server", "archive")
	Kit.link(plan, "archive", "cold")
	Kit.link(plan, "server", "flooded")
	Kit.link(plan, "server", "boiler")
	Kit.link(plan, "boiler", "hallE")
	-- second level
	Kit.link(plan, "corrB", "hallE", 55)
	Kit.link(plan, "corrB", "vault")
	Kit.link(plan, "vault", "core")
	Kit.link(plan, "core", "deep")
	Kit.link(plan, "deep", "cryo")
	Kit.exit(plan, "garage", "z1", 0, 12)
	Kit.exit(plan, "dorm", "x0", 0, 8)
	Kit.exit(plan, "genHall", "x1", 0, 8)
end

local function addLights(plan: Plan, rng: () -> number)
	local function lamp(id: string, color: string, fx: number?, fz: number?)
		local room = plan.byId[id]
		local x = (room.x0 + room.x1) / 2 + (fx or 0)
		local z = (room.z0 + room.z1) / 2 + (fz or 0)
		Kit.lamp(plan, room, x, z, {
			range = LAMP_RANGE,
			brightness = LAMP_BRIGHTNESS,
			color = color,
			flicker = rng() < FLICKER_CHANCE,
		})
	end
	lamp("lobby", "Warm", -7)
	lamp("lobby", "Warm", 7)
	lamp("westCorr", "Warm")
	lamp("dorm", "Warm")
	lamp("mess", "Warm")
	lamp("eastCorr", "Cold")
	lamp("genHall", "Warm", 0, -6)
	lamp("genHall", "Warm", 0, 6)
	lamp("northCorr", "Warm")
	lamp("radio", "Cold")
	lamp("offices", "Warm")
	lamp("garage", "Warm", 0, -7)
	lamp("garage", "Cold", 0, 8)
	lamp("hallW", "Warm", -10)
	lamp("hallW", "Cold", 14)
	lamp("corrA", "Warm")
	lamp("labA", "Cold")
	lamp("labB", "Cold")
	lamp("server", "Cold", -5)
	lamp("server", "Sick", 5)
	lamp("archive", "Warm")
	lamp("corrB", "Red")
	lamp("core", "Cold")
	lamp("hallE", "Red", 14)
	lamp("hallE", "Warm", -16)
	-- the antenna's warning light
	local radio = plan.byId.radio
	local mast = Kit.box("mast", "Mast", 0, radio.y + radio.h + 24, -40, 1.4, 46, 1.4, false)
	table.insert(plan.shell, mast)
	local top = Kit.box("mast_light", "Lamp", 0, radio.y + radio.h + 48, -40, 1.6, 1.6, 1.6, false)
	top.role = "Lamp"
	top.light = { range = 40, brightness = 2.2, color = "Red", flicker = true }
	table.insert(plan.shell, top)
	Kit.emitter(plan, plan.byId.genHall, 52, 8, -10, "Steam")
	Kit.emitter(plan, plan.byId.genHall, 52, 8, 10, "Steam")
	Kit.emitter(plan, plan.byId.cold, 48, 3, 10, "Frost")
	Kit.emitter(plan, plan.byId.flooded, -12, 2, -12, "Frost")
	Kit.emitter(plan, plan.byId.server, 0, 3, 6, "Dust")
end

local function addChests(plan: Plan, rng: () -> number)
	local function chest(id: string, depth: number, corner: number?)
		Kit.cornerChest(plan, plan.byId[id], rng, depth, corner)
	end
	chest("lobby", 0)
	chest("dorm", 0)
	chest("mess", 0)
	chest("garage", 0)
	chest("offices", 1)
	chest("genHall", 1)
	chest("radio", 1)
	chest("labA", 2)
	chest("labB", 2)
	chest("server", 2)
	chest("archive", 2)
	chest("boiler", 2)
	chest("cold", 3)
	chest("flooded", 3)
	chest("deep", 3)
	chest("vault", 4, 1)
	chest("core", 4)
	chest("cryo", 4)
	chest("vault", 4, 4)
end

local function addSpots(plan: Plan)
	local function lurk(id: string, side: string, along: number)
		local room = plan.byId[id]
		local x, z = Kit.facePoint(room, side, along, 0.5)
		Kit.lurker(plan, room, x, z, "eyes")
		local ry = if side == "x0" or side == "x1" then 90 else 0
		local ex, ez = Kit.facePoint(room, side, along, 0.2)
		local boxes = Kit.eyes(`{id}_eyes`, ex, room.y + 5.5, ez, ry)
		Kit.dress(plan, room, boxes)
	end
	lurk("flooded", "x0", -12)
	lurk("cold", "x1", 6)
	lurk("vault", "z0", 54)
	lurk("cryo", "z1", -30)
	lurk("deep", "x1", 14)
	lurk("boiler", "z1", 10)
	lurk("hallE", "z1", 56)
	local function cue(id: string, fx: number, fz: number, kind: string)
		local room = plan.byId[id]
		Kit.cue(plan, room, (room.x0 + room.x1) / 2 + fx, (room.z0 + room.z1) / 2 + fz, kind)
	end
	cue("flooded", 0, 0, "Drip")
	cue("server", 0, 0, "Hum")
	cue("genHall", 0, 0, "Hum")
	cue("dorm", 0, 0, "Creak")
	cue("cold", 0, 0, "Scratch")
	cue("radio", 0, 0, "Static")
	cue("hallW", -10, 0, "Wind")
	cue("cryo", 0, 0, "Whisper")
	cue("vault", 0, 0, "Drip")
end

local function addDressing(plan: Plan, rng: () -> number, seed: number)
	local noteIndex = seed % #NOTES
	local function nextNote(): string
		noteIndex = noteIndex % #NOTES + 1
		return NOTES[noteIndex]
	end
	local function dress(id: string, boxes: { Kit.Box })
		Kit.dress(plan, plan.byId[id], boxes)
	end
	local function add(into: { Kit.Box }, list: { Kit.Box })
		for _, b in list do
			table.insert(into, b)
		end
	end
	local function base(id: string, sign: string, side: string, along: number): { Kit.Box }
		return { Kit.sign(`{id}_sign`, plan.byId[id], side, along, sign) }
	end
	local function claws(id: string, side: string, along: number): { Kit.Box }
		return Kit.claws(`{id}_claws`, plan.byId[id], side, along, rng)
	end

	-- lobby
	local b = base("lobby", "RECEPTION", "z0", 10)
	add(b, Kit.desk("lobby_desk", 8, 0, -8, 0))
	add(b, Kit.overturned("lobby_desk2", -9, 0, 8, 40))
	table.insert(b, Kit.note("lobby_note", 8, 3.2, -8, nextNote()))
	table.insert(b, Kit.crate("lobby_crate", -12, 0, -9, 2.4, 20))
	add(b, claws("lobby", "z1", -10))
	dress("lobby", b)

	b = base("westCorr", "WEST WING", "z0", -30)
	table.insert(b, Kit.pipe("westCorr_pipe", -30, 10, -3, 26, true))
	add(b, claws("westCorr", "z1", -22))
	dress("westCorr", b)

	b = base("dorm", "DORMITORY", "x0", -9)
	local bunkZ = { -11, -7.5, 7.5, 11 }
	for i, z in bunkZ do
		table.insert(
			b,
			Kit.rot(
				Kit.box(`dorm_bunk{i}`, "MetalDark", -56.5, 2.6, z, 4.6, 5.2, 2.4, true),
				0,
				0,
				0
			)
		)
		table.insert(b, Kit.box(`dorm_mat{i}`, "Cloth", -56.5, 5.4, z, 4.2, 0.5, 2, false))
	end
	add(b, Kit.overturned("dorm_locker", -48, 0, 10.5, 90))
	table.insert(b, Kit.note("dorm_note", -52, 0.2, 8, nextNote()))
	add(b, claws("dorm", "z1", -47))
	dress("dorm", b)

	b = base("mess", "MESS HALL", "z1", -22)
	add(b, Kit.desk("mess_t1", -36, 0, 14, 0))
	add(b, Kit.desk("mess_t2", -26, 0, 17, 0))
	add(b, Kit.overturned("mess_bench", -40, 0, 18, 70))
	table.insert(b, Kit.note("mess_note", -36, 3.2, 14, nextNote()))
	table.insert(b, Kit.barrel("mess_barrel", -19, 0, 7))
	dress("mess", b)

	b = base("eastCorr", "EAST WING", "z0", 36)
	table.insert(b, Kit.pipe("eastCorr_pipe", 30, 10, 3, 26, true))
	add(b, claws("eastCorr", "z1", 24))
	dress("eastCorr", b)

	b = base("genHall", "GENERATORS", "z0", 50)
	local gens = { { 56, -11 }, { 56, 11 }, { 49.5, -12.5 } }
	for i, g in gens do
		table.insert(b, Kit.box(`gen{i}_body`, "Metal", g[1], 2.5, g[2], 5, 5, 4.6, true))
		table.insert(
			b,
			Kit.box(`gen{i}_stack`, "MetalDark", g[1] + 1.5, 6.5, g[2], 1.2, 3, 1.2, false)
		)
	end
	table.insert(b, Kit.pipe("gen_pipe", 46, 9, 0, 30, false))
	table.insert(b, Kit.note("gen_note", 50, 0.2, 13, nextNote()))
	dress("genHall", b)

	b = base("northCorr", "TO RADIO", "x1", -22)
	table.insert(b, Kit.pipe("north_cables", -3, 10, -23, 20, false))
	add(b, claws("northCorr", "x0", -26))
	dress("northCorr", b)

	b = base("radio", "RADIO ROOM", "x0", -40)
	add(b, Kit.desk("radio_console", 0, 0, -43, 0))
	add(b, Kit.overturned("radio_chair", -8, 0, -38, 100))
	table.insert(b, Kit.note("radio_note", 0, 3.2, -43, nextNote()))
	table.insert(b, Kit.crate("radio_crate", 11, 0, -37, 2.2, 5))
	dress("radio", b)

	b = base("offices", "OFFICES", "z1", 36)
	add(b, Kit.desk("off_d1", 22, 0, 8, 0))
	add(b, Kit.desk("off_d2", 38, 0, 8, 0))
	add(b, Kit.overturned("off_d3", 26, 0, 19, 20))
	table.insert(b, Kit.shelf("off_cab", 41, 0, 20, 0, 4)[1])
	table.insert(b, Kit.note("off_note", 22, 3.2, 8, nextNote()))
	dress("offices", b)

	b = base("garage", "VEHICLE BAY", "x0", 32)
	table.insert(b, Kit.box("bay_hull", "MetalDark", 9, 2, 27, 8, 3.6, 12, true))
	table.insert(
		b,
		Kit.rot(Kit.box("bay_track", "Rust", 5.2, 1.2, 27, 1.6, 2.4, 12, true), 0, 0, 0)
	)
	table.insert(b, Kit.rot(Kit.box("bay_cab", "Metal", 9, 4.6, 24, 6, 2.4, 5, true), 12, 0, 0))
	table.insert(b, Kit.crate("bay_crate1", -12, 0, 15, 2.4, 10))
	table.insert(b, Kit.crate("bay_crate2", -9.6, 0, 15, 2.4, 25))
	table.insert(b, Kit.barrel("bay_barrel", -13, 0, 21))
	dress("garage", b)

	b = base("hallW", "STAIRS DOWN", "z0", -40)
	add(b, claws("hallW", "z1", -30))
	dress("hallW", b)

	-- first level
	b = base("corrA", "MAINTENANCE", "z1", -50)
	table.insert(b, Kit.pipe("corrA_pipe", -44, 10, 22, 30, true))
	add(b, claws("corrA", "z0", -34))
	dress("corrA", b)

	b = base("labA", "LAB A", "x0", 14)
	add(b, Kit.desk("labA_b1", -52, Y1, 4, 0))
	add(b, Kit.desk("labA_b2", -44, Y1, 4, 0))
	add(b, Kit.overturned("labA_b3", -48, Y1, 9, 30))
	table.insert(b, Kit.note("labA_note", -52, Y1 + 3.2, 4, nextNote()))
	add(b, claws("labA", "z0", -52))
	dress("labA", b)

	b = base("labB", "LAB B", "z0", -30)
	table.insert(b, Kit.shelf("labB_cab1", -31, Y1, 17, 0, 6)[1])
	table.insert(b, Kit.shelf("labB_cab2", -19, Y1, 17, 0, 6)[1])
	add(b, Kit.desk("labB_b1", -30, Y1, 4, 0))
	add(b, Kit.overturned("labB_b2", -24, Y1, 11, 70))
	dress("labB", b)

	b = base("server", "SERVER ROOM", "z0", 8)
	local rackX = { -9, -5.8, 5.8, 9 }
	for i, x in rackX do
		add(b, Kit.rack(`rack{i}`, x, Y1, 15, 0))
		add(b, Kit.rack(`rackB{i}`, x, Y1, -2, 0))
	end
	table.insert(
		b,
		Kit.rot(Kit.box("rack_fallen", "MetalDark", 0, Y1 + 1.3, 8, 2.6, 7, 2.6, true), 0, 0, 82)
	)
	table.insert(b, Kit.note("server_note", 6, Y1 + 0.2, 4, nextNote()))
	dress("server", b)

	b = base("archive", "ARCHIVE", "z1", 18)
	for i = 1, 3 do
		add(b, Kit.shelf(`arch_s{i}`, 18 + (i - 1) * 7, Y1, 2.5, 0, 5.4))
	end
	table.insert(b, Kit.note("arch_note", 30, Y1 + 0.2, 17, nextNote()))
	add(b, claws("archive", "x1", 10))
	dress("archive", b)

	b = base("cold", "COLD STORAGE", "x0", 15)
	for i = 1, 4 do
		table.insert(
			b,
			Kit.rot(
				Kit.box(`ice{i}`, "Ice", 41 + (i - 1) * 4.5, Y1 + 1.5, 3.4, 3.4, 3, 3.4, true),
				0,
				i * 20,
				0
			)
		)
	end
	add(b, Kit.shelf("cold_shelf1", 56, Y1, 14, 0, 5))
	table.insert(b, Kit.note("cold_note", 56, Y1 + 0.2, 4, nextNote()))
	add(b, claws("cold", "x1", 12))
	dress("cold", b)

	b = base("flooded", "FLOODED", "x1", -12)
	local flooded = plan.byId.flooded
	local water = Kit.box(
		"flood_water",
		"Water",
		(flooded.x0 + flooded.x1) / 2,
		Y1 + 1.2,
		-12,
		46,
		0.2,
		6,
		false
	)
	water.role = "Water"
	table.insert(b, water)
	table.insert(b, Kit.crate("flood_crate", -20, Y1, -14, 2.2, 30))
	table.insert(b, Kit.note("flood_note", 4, Y1 + 0.2, -10, nextNote()))
	table.insert(b, Kit.pipe("flood_pipe", -12, 9, -9, 40, true))
	dress("flooded", b)

	b = base("boiler", "BOILERS", "x0", 30)
	for i = 1, 2 do
		local t = Kit.box(`boiler{i}`, "Rust", -8 + (i - 1) * 12, Y1 + 5, 36, 6, 10, 6, true)
		t.shape = "Cylinder"
		table.insert(b, t)
	end
	table.insert(b, Kit.pipe("boiler_pipe", 0, 10, 38, 30, true))
	add(b, claws("boiler", "x1", 26))
	dress("boiler", b)

	b = base("hallE", "STAIRS DOWN", "z0", 30)
	add(b, claws("hallE", "z1", 40))
	dress("hallE", b)

	-- second level
	b = base("corrB", "DEEP LEVEL", "x0", 24)
	table.insert(b, Kit.pipe("corrB_pipe", 48, 8.5, 22, 20, true))
	add(b, claws("corrB", "z1", 44))
	dress("corrB", b)

	b = base("vault", "VAULT", "x0", 8)
	for i = 1, 4 do
		local t = Kit.box(`tank{i}`, "Glass", 54, Y2 + 3, -1 + (i - 1) * 5.2, 3.4, 6, 3.4, true)
		t.shape = "Cylinder"
		table.insert(b, t)
	end
	add(b, Kit.overturned("vault_desk", 40, Y2, 16, 10))
	table.insert(b, Kit.note("vault_note", 40, Y2 + 0.2, 0, nextNote()))
	dress("vault", b)

	b = base("core", "CORE LAB", "x1", 8)
	local core = Kit.box("core_body", "Indicator", 24, Y2 + 4, 8, 5, 8, 5, true)
	core.shape = "Cylinder"
	table.insert(b, core)
	add(b, Kit.desk("core_c1", 16, Y2, 0, 0))
	add(b, Kit.desk("core_c2", 32, Y2, 16, 0))
	table.insert(b, Kit.note("core_note", 16, Y2 + 3.2, 0, nextNote()))
	dress("core", b)

	b = base("deep", "DEEP ARCHIVE", "z0", 0)
	for i = 1, 3 do
		add(b, Kit.shelf(`deep_s{i}`, -8 + (i - 1) * 8, Y2, 17, 0, 5.4))
	end
	table.insert(b, Kit.note("deep_note", 8, Y2 + 0.2, 0, nextNote()))
	add(b, claws("deep", "x0", 14))
	dress("deep", b)

	b = base("cryo", "CRYO CHAMBER", "z0", -30)
	for i = 1, 5 do
		local pod = Kit.box(`pod{i}`, "Glass", -33 + (i - 1) * 5, Y2 + 3, 16.5, 3, 6, 3, true)
		pod.shape = "Cylinder"
		table.insert(b, pod)
	end
	table.insert(b, Kit.note("cryo_note", -22, Y2 + 0.2, 2, nextNote()))
	add(b, claws("cryo", "x0", 10))
	dress("cryo", b)
end

function ResearchStationPlan.plan(seed: number): Plan
	local plan = Kit.newPlan(ID)
	local rng = Kit.rng(seed)
	addRooms(plan)
	addLinks(plan)
	addLights(plan, rng)
	addChests(plan, rng)
	addSpots(plan)
	addDressing(plan, rng, seed)
	Kit.finish(plan)
	return plan
end

return ResearchStationPlan
