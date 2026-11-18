--!strict
-- Pure plan for the mine complex: a surface office block with a headframe, two stair halls, a branching drift
-- network on the first level (ore chamber, junction, collapsed gallery), a haulage level with a large cavern,
-- and a deep level of ore veins and a foreman's cache. 23 rooms, four levels, 42 studs deep.
-- Local frame: y = 0 is the entrance floor; the ore sorting shed (south, +z) is the entrance.

local Kit = require("./StructurePlanKitA")

local MineComplexPlan = {}

export type Plan = Kit.Plan

local ID = "MineComplex"
local Y1, Y2, Y3 = -14, -28, -42
local H_SURFACE, H_UNDER, H_CAVERN = 12, 11, 24
local LAMP_RANGE = 24
local LAMP_BRIGHTNESS = 0.9
local FLICKER_CHANCE = 0.5
local SUPPORT_HEIGHT = 7
local RAIL_GAUGE = 2.4

local NOTES = {
	"Shift log. The lower drift groaned all night. Foreman says it is only the timbers settling. The timbers do not settle in rhythm.",
	"We broke into a pocket of cold air on the third level. The lamps burned blue for an hour. Nobody will go back.",
	"Rails end at the cavern. We never laid them any further. Somebody did.",
	"Tally: forty carts of ore, one lamp lost, one boot found far from anyone's feet.",
	"The collapsed gallery was supposed to be empty. I heard picks working behind the rubble. Slow, careful picks.",
	"If you hear someone calling from the shaft, it is the echo. Do not call back. It learns.",
	"Pumps are failing. The sump fills faster each night. Keep to the high ledge and keep your light low.",
	"Foreman's cache is behind the old sump. Whoever finds this, take what you need and go up. The deep vein is not worth it.",
	"I put my lamp down for one minute. When I looked up the tunnel was a little longer than before.",
	"Last note. The lifts are dead, so we walk. Eleven went down. I count ten footsteps coming back.",
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
		dark: boolean?,
		h: number?
	)
		local y = if level == 0 then 0 elseif level == -1 then Y1 elseif level == -2 then Y2 else Y3
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
			h = h or (if level == 0 then H_SURFACE else H_UNDER),
			landmark = landmark,
			dark = dark,
		})
	end
	room("office", "shed", "Mine Office", 0, -16, -10, 16, 10, "the headframe tower above the roof")
	room(
		"change",
		"shed",
		"Change House",
		0,
		-16,
		-22,
		16,
		-10,
		"rows of hooks and abandoned boots"
	)
	room("sorting", "shed", "Ore Sorting Shed", 0, -16, 10, 16, 26, "ore chutes and a rusted scale")
	Kit.addHall(plan, {
		id = "hallA",
		name = "West Shaft",
		axis = "x",
		hi = "max",
		x0 = -60,
		z0 = -4,
		x1 = -16,
		z1 = 4,
		yLow = Y1,
		yHigh = 0,
		upperH = H_SURFACE,
		level = -1,
		landmark = "a long ramp into the mountain",
	})
	Kit.addHall(plan, {
		id = "hallB",
		name = "East Shaft",
		axis = "x",
		hi = "min",
		x0 = 16,
		z0 = -4,
		x1 = 60,
		z1 = 4,
		yLow = Y1,
		yHigh = 0,
		upperH = H_SURFACE,
		level = -1,
		landmark = "a ramp lit by one hanging lamp",
	})
	-- first level (y = -14)
	room("p1", "mine", "West Drift", -1, -60, 4, -28, 12, "a timber arch and a dropped pickaxe")
	room(
		"p2",
		"cavern",
		"Ore Chamber",
		-1,
		-60,
		12,
		-36,
		36,
		"veins of pale ore in the walls",
		true
	)
	room("p3", "mine", "Main Haul", -1, -28, 4, 12, 12, "rail tracks running east")
	room(
		"p4",
		"cavern",
		"Junction Hall",
		-1,
		12,
		4,
		36,
		28,
		"an overturned ore cart at the crossing"
	)
	room("q1", "mine", "East Drift", -1, 36, 4, 60, 12, "a hanging lantern on a hook")
	room("p5", "cavern", "Collapsed Gallery", -1, 36, 12, 60, 28, "a wall of fallen rock", true)
	Kit.addHall(plan, {
		id = "hallC",
		name = "Lower Shaft",
		axis = "x",
		hi = "min",
		x0 = -36,
		z0 = 28,
		x1 = 8,
		z1 = 36,
		yLow = Y2,
		yHigh = Y1,
		upperH = H_UNDER,
		level = -2,
		landmark = "a ramp down toward dripping water",
		dark = true,
	})
	-- haulage level (y = -28)
	room("r1", "mine", "Haulage Tunnel", -2, -28, 20, 12, 28, "twin rails and an abandoned cart")
	room("r2", "cavern", "Timber Store", -2, -28, 0, -8, 20, "stacks of split timber", true)
	room("r3", "mine", "Rail Junction", -2, -28, -8, -8, 0, "a rail switch and a dim lantern", true)
	room("r4", "utility", "Pump Room", -2, -8, 0, 12, 20, "a rusted pump and tangled pipes")
	room(
		"cav",
		"cavern",
		"Great Cavern",
		-2,
		-40,
		-54,
		16,
		-8,
		"a vast open cavern with a rail bridge",
		true,
		H_CAVERN
	)
	Kit.addHall(plan, {
		id = "hallD",
		name = "Deep Shaft",
		axis = "x",
		hi = "min",
		x0 = 16,
		z0 = -24,
		x1 = 60,
		z1 = -16,
		yLow = Y3,
		yHigh = Y2,
		upperH = H_UNDER,
		level = -3,
		landmark = "a ramp into total darkness",
		dark = true,
	})
	-- deep level (y = -42)
	room("s1", "mine", "Lower Landing", -3, 40, -16, 60, -8, "a single caged lamp", true)
	room("s2", "mine", "Deep Drift", -3, 16, -16, 40, -8, "rails ending in a heap of stone", true)
	room(
		"s3",
		"cavern",
		"Ore Vein Chamber",
		-3,
		-8,
		-24,
		16,
		0,
		"a glittering vein across the ceiling",
		true
	)
	room("s4", "mine", "Sump", -3, -32, -16, -8, -4, "black water in a low basin", true)
	room(
		"s5",
		"mine",
		"Foreman's Cache",
		-3,
		-32,
		-4,
		-8,
		12,
		"a locked-looking safe and a bunk",
		true
	)
end

local function addLinks(plan: Plan)
	Kit.link(plan, "sorting", "office")
	Kit.link(plan, "office", "change")
	Kit.link(plan, "hallA", "office")
	Kit.link(plan, "office", "hallB")
	Kit.link(plan, "p1", "hallA", -55)
	Kit.link(plan, "p1", "p2")
	Kit.link(plan, "p1", "p3")
	Kit.link(plan, "p3", "p4")
	Kit.link(plan, "p4", "q1")
	Kit.link(plan, "q1", "hallB", 55)
	Kit.link(plan, "q1", "p5")
	Kit.link(plan, "p2", "hallC")
	Kit.link(plan, "r1", "hallC", 3)
	Kit.link(plan, "r1", "r2")
	Kit.link(plan, "r2", "r3")
	Kit.link(plan, "r2", "r4")
	Kit.link(plan, "cav", "r3")
	Kit.link(plan, "cav", "hallD")
	Kit.link(plan, "hallD", "s1", 55)
	Kit.link(plan, "s2", "s1")
	Kit.link(plan, "s3", "s2")
	Kit.link(plan, "s4", "s3")
	Kit.link(plan, "s5", "s4")
	Kit.exit(plan, "sorting", "z1", 0, 12)
	Kit.exit(plan, "change", "z0", 0, 8)
end

local function addLights(plan: Plan, rng: () -> number)
	local function lamp(id: string, color: string, fx: number?, fz: number?)
		local room = plan.byId[id]
		Kit.lamp(
			plan,
			room,
			(room.x0 + room.x1) / 2 + (fx or 0),
			(room.z0 + room.z1) / 2 + (fz or 0),
			{
				range = LAMP_RANGE,
				brightness = LAMP_BRIGHTNESS,
				color = color,
				flicker = rng() < FLICKER_CHANCE,
			}
		)
	end
	lamp("office", "Warm")
	lamp("change", "Warm")
	lamp("sorting", "Warm", -6)
	lamp("sorting", "Cold", 6)
	lamp("hallA", "Warm", -12)
	lamp("hallA", "Warm", 12)
	lamp("hallB", "Warm", 0)
	lamp("p1", "Warm", -8)
	lamp("p1", "Warm", 8)
	lamp("p3", "Warm", -10)
	lamp("p3", "Warm", 10)
	lamp("p4", "Warm", 0, -6)
	lamp("p4", "Warm", 0, 6)
	lamp("q1", "Warm")
	lamp("hallC", "Warm", 16)
	lamp("r1", "Warm", -10)
	lamp("r1", "Warm", 6)
	lamp("r4", "Cold")
	lamp("r3", "Red")
	lamp("hallD", "Red", 18)
	lamp("s1", "Red")
	lamp("s5", "Warm")
	-- headframe landmark above the office roof
	local office = plan.byId.office
	local top = office.y + office.h + Kit.SLAB
	table.insert(
		plan.shell,
		Kit.box("frame_leg1", "WoodDark", -6, top + 15, 0, 1.6, 30, 1.6, false)
	)
	table.insert(plan.shell, Kit.box("frame_leg2", "WoodDark", 6, top + 15, 0, 1.6, 30, 1.6, false))
	table.insert(plan.shell, Kit.box("frame_beam", "WoodDark", 0, top + 30, 0, 14, 1.6, 1.6, false))
	local wheel = Kit.box("frame_wheel", "Rust", 0, top + 26, 0, 9, 1, 9, false)
	wheel.shape = "Cylinder"
	table.insert(plan.shell, Kit.rot(wheel, 90, 0, 0))
	Kit.emitter(plan, plan.byId.cav, -12, -22, -30, "Dust")
	Kit.emitter(plan, plan.byId.cav, 8, -22, -20, "Dust")
	Kit.emitter(plan, plan.byId.p5, 48, -10, 20, "Dust")
	Kit.emitter(plan, plan.byId.r4, 2, -26, 10, "Steam")
end

local function addChests(plan: Plan, rng: () -> number)
	local function chest(id: string, depth: number, corner: number?)
		Kit.cornerChest(plan, plan.byId[id], rng, depth, corner)
	end
	chest("office", 0)
	chest("change", 0)
	chest("sorting", 0)
	chest("p1", 1)
	chest("p2", 1)
	chest("q1", 1)
	chest("p4", 2)
	chest("p5", 2)
	chest("r2", 2)
	chest("r4", 3)
	chest("cav", 3, 1)
	chest("cav", 3, 4)
	chest("s1", 3)
	chest("s2", 3)
	chest("s3", 4)
	chest("s4", 4)
	chest("s5", 4, 1)
end

local function addSpots(plan: Plan)
	local function lurk(id: string, side: string, along: number)
		local room = plan.byId[id]
		local x, z = Kit.facePoint(room, side, along, 0.5)
		Kit.lurker(plan, room, x, z, "eyes")
		local ry = if side == "x0" or side == "x1" then 90 else 0
		local ex, ez = Kit.facePoint(room, side, along, 0.2)
		Kit.dress(plan, room, Kit.eyes(`{id}_eyes`, ex, room.y + 5.5, ez, ry))
	end
	lurk("p2", "x0", 24)
	lurk("p5", "x1", 20)
	lurk("r3", "x0", -4)
	lurk("cav", "z0", -10)
	lurk("cav", "x0", -30)
	lurk("s3", "z0", 4)
	lurk("s4", "x0", -10)
	lurk("hallC", "z1", -4)
	local function cue(id: string, fx: number, fz: number, kind: string)
		local room = plan.byId[id]
		Kit.cue(plan, room, (room.x0 + room.x1) / 2 + fx, (room.z0 + room.z1) / 2 + fz, kind)
	end
	cue("r4", 0, 0, "Drip")
	cue("s4", 0, 0, "Drip")
	cue("hallA", -10, 0, "Wind")
	cue("p3", 0, 0, "Creak")
	cue("p5", 0, 0, "Rumble")
	cue("cav", 0, 0, "Echo")
	cue("s5", 0, 0, "Scratch")
	cue("s3", 0, 0, "Whisper")
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
	-- timber frames along a drift running in x at z = zc
	local function framesX(into: { Kit.Box }, id: string, xs: { number }, zc: number, span: number)
		local y0 = plan.byId[id].y
		for i, x in xs do
			add(into, Kit.support(`{id}_sup{i}`, x, y0, zc, span, true, SUPPORT_HEIGHT))
		end
	end

	-- surface
	local b = base("office", "MINE OFFICE", "x0", 6)
	add(b, Kit.desk("office_desk", 8, 0, -6, 0))
	add(b, Kit.overturned("office_chair", -9, 0, 6, 50))
	table.insert(b, Kit.note("office_note", 8, 3.2, -6, nextNote()))
	table.insert(b, Kit.shelf("office_shelf", -11, 0, -8.6, 0, 4)[1])
	dress("office", b)

	b = base("change", "CHANGE HOUSE", "x0", -16)
	for i = 1, 4 do
		table.insert(
			b,
			Kit.box(`hook{i}`, "WoodDark", -14.5, 3.2, -20 + (i - 1) * 2.6, 0.6, 5, 1.8, false)
		)
	end
	table.insert(b, Kit.crate("change_crate", 12, 0, -20, 2.4, 20))
	add(b, claws("change", "x1", -16))
	dress("change", b)

	b = base("sorting", "ORE SORTING", "x0", 18)
	table.insert(b, Kit.box("chute", "Rust", 11, 3, 14, 4, 6, 3, true))
	table.insert(b, Kit.rot(Kit.box("chute_slope", "Rust", 11, 2, 17, 3, 0.4, 5, false), 30, 0, 0))
	table.insert(b, Kit.barrel("sort_barrel", -13, 0, 24))
	table.insert(b, Kit.note("sort_note", -12, 0.2, 13, nextNote()))
	dress("sorting", b)

	b = base("hallA", "WEST SHAFT", "z0", -40)
	add(b, claws("hallA", "z1", -30))
	dress("hallA", b)
	b = base("hallB", "EAST SHAFT", "z1", 40)
	add(b, claws("hallB", "z0", 30))
	dress("hallB", b)

	-- first level
	b = base("p1", "WEST DRIFT", "z1", -50)
	framesX(b, "p1", { -52, -42, -34 }, 8, 8)
	add(b, Kit.rails("p1_rails", -44, Y1, 8, 28, true, RAIL_GAUGE))
	add(b, claws("p1", "z0", -38))
	dress("p1", b)

	b = base("p2", "ORE CHAMBER", "z1", -48)
	for i = 1, 3 do
		table.insert(
			b,
			Kit.rot(
				Kit.box(`ore{i}`, "Ore", -58.5, Y1 + 3 + i, 16 + i * 6, 0.8, 3, 2.4, false),
				0,
				0,
				(i - 2) * 8
			)
		)
	end
	add(b, Kit.rubble("p2_rub", -54, Y1, 33, 3, rng))
	table.insert(b, Kit.box("p2_cart", "Rust", -50, Y1 + 1.6, 22, 4, 2.4, 2.6, true))
	table.insert(b, Kit.note("p2_note", -55, Y1 + 0.2, 33, nextNote()))
	dress("p2", b)

	b = base("p3", "MAIN HAUL", "z1", 0)
	framesX(b, "p3", { -22, -12, -2, 8 }, 8, 8)
	add(b, Kit.rails("p3_rails", -8, Y1, 8, 38, true, RAIL_GAUGE))
	add(b, claws("p3", "z0", -16))
	dress("p3", b)

	b = base("p4", "JUNCTION", "z1", 24)
	table.insert(
		b,
		Kit.rot(Kit.box("cart_body", "Rust", 28, Y1 + 1.4, 12, 4.4, 2.2, 3.2, true), 0, 25, 70)
	)
	table.insert(
		b,
		Kit.rot(
			Kit.box("cart_wheel", "MetalDark", 30, Y1 + 0.8, 14, 1.4, 1.4, 0.4, false),
			0,
			25,
			0
		)
	)
	add(b, Kit.rails("p4_rails", 24, Y1, 8, 24, true, RAIL_GAUGE))
	add(b, Kit.rubble("p4_rub", 33, Y1, 25, 2.6, rng))
	table.insert(b, Kit.note("p4_note", 15, Y1 + 0.2, 25, nextNote()))
	dress("p4", b)

	b = base("q1", "EAST DRIFT", "z1", 44)
	framesX(b, "q1", { 40, 46, 56 }, 8, 8)
	table.insert(b, Kit.box("lantern", "Lamp", 48, Y1 + 6, 4.8, 0.8, 1, 0.8, false))
	add(b, Kit.rails("q1_rails", 48, Y1, 8, 24, true, RAIL_GAUGE))
	dress("q1", b)

	b = base("p5", "CAVE-IN", "z1", 40)
	for i = 1, 4 do
		add(b, Kit.rubble(`p5_rub{i}`, 56, Y1, 14 + i * 3.2, 3.6, rng))
	end
	table.insert(b, Kit.note("p5_note", 40, Y1 + 0.2, 14, nextNote()))
	add(b, claws("p5", "x0", 22))
	dress("p5", b)

	b = base("hallC", "LOWER SHAFT", "z1", -20)
	add(b, claws("hallC", "z0", -10))
	dress("hallC", b)

	-- haulage level
	b = base("r1", "HAULAGE", "z1", -20)
	framesX(b, "r1", { -22, -12, -2, 8 }, 24, 8)
	add(b, Kit.rails("r1_rails", -8, Y2, 24, 38, true, RAIL_GAUGE))
	table.insert(b, Kit.box("r1_cart", "Rust", -8, Y2 + 1.6, 24, 4, 2.4, 2.8, true))
	dress("r1", b)

	b = base("r2", "TIMBER STORE", "x0", 10)
	for i = 1, 3 do
		table.insert(
			b,
			Kit.rot(
				Kit.box(
					`logs{i}`,
					"Wood",
					-25,
					Y2 + 1.2 + (i - 1) * 1.8,
					12 + i * 1.5,
					5,
					1.6,
					8,
					true
				),
				0,
				i * 5,
				0
			)
		)
	end
	table.insert(b, Kit.note("r2_note", -12, Y2 + 0.2, 4, nextNote()))
	add(b, claws("r2", "z0", -18))
	dress("r2", b)

	b = base("r3", "JUNCTION", "z1", -14)
	add(b, Kit.rails("r3_rails", -18, Y2, -4, 20, true, RAIL_GAUGE))
	framesX(b, "r3", { -24, -14 }, -4, 8)
	dress("r3", b)

	b = base("r4", "PUMP ROOM", "z1", 2)
	local pump = Kit.box("pump_body", "Rust", 2, Y2 + 2, 6, 4, 4, 4, true)
	pump.shape = "Cylinder"
	table.insert(b, pump)
	table.insert(b, Kit.pipe("pump_pipe", 2, 9, 8, 18, true))
	table.insert(b, Kit.pipe("pump_pipe2", -6, 6, 10, 18, false))
	table.insert(b, Kit.note("r4_note", 9, Y2 + 0.2, 17, nextNote()))
	dress("r4", b)

	b = base("cav", "GREAT CAVERN", "z1", -30)
	add(b, Kit.rails("cav_rails", -12, Y2, -12, 52, true, RAIL_GAUGE))
	for i = 1, 3 do
		add(b, Kit.rubble(`cav_rub{i}`, -34 + i * 18, Y2, -48 + (i % 2) * 6, 4.4, rng))
	end
	table.insert(b, Kit.box("cav_bridge", "WoodDark", -10, Y2 + 3.4, -28, 16, 0.8, 5, true))
	table.insert(b, Kit.note("cav_note", -30, Y2 + 0.2, -12, nextNote()))
	for i = 1, 3 do
		table.insert(
			b,
			Kit.rot(
				Kit.box(
					`cav_ore{i}`,
					"Ore",
					-38.8,
					Y2 + 5 + i * 2,
					-20 - i * 9,
					0.8,
					3.4,
					2.6,
					false
				),
				0,
				0,
				i * 6
			)
		)
	end
	dress("cav", b)

	b = base("hallD", "DEEP SHAFT", "z1", -18)
	add(b, claws("hallD", "z0", 30))
	dress("hallD", b)

	-- deep level
	b = base("s1", "LOWER LANDING", "z0", 50)
	table.insert(b, Kit.box("cage", "MetalDark", 46, Y3 + 6.5, -12, 1.4, 1.4, 1.4, false))
	add(b, claws("s1", "x1", -12))
	dress("s1", b)

	b = base("s2", "DEEP DRIFT", "z0", 30)
	framesX(b, "s2", { 20, 28, 36 }, -12, 8)
	add(b, Kit.rails("s2_rails", 28, Y3, -12, 22, true, RAIL_GAUGE))
	add(b, Kit.rubble("s2_rub", 23, Y3, -9.5, 2, rng))
	dress("s2", b)

	b = base("s3", "VEIN CHAMBER", "x1", -6)
	for i = 1, 4 do
		table.insert(
			b,
			Kit.rot(
				Kit.box(`vein{i}`, "Ore", -6 + i * 4.5, Y3 + 9.6, -12, 2.6, 0.6, 14, false),
				0,
				0,
				(i - 2.5) * 6
			)
		)
	end
	add(b, Kit.rubble("s3_rub", 12, Y3, -3, 3, rng))
	table.insert(b, Kit.note("s3_note", -4, Y3 + 0.2, -20, nextNote()))
	dress("s3", b)

	b = base("s4", "THE SUMP", "z0", -20)
	local sump = Kit.box("sump_water", "Water", -20, Y3 + 1.1, -10, 20, 0.2, 8, false)
	sump.role = "Water"
	table.insert(b, sump)
	table.insert(b, Kit.pipe("sump_pipe", -20, 9, -14.6, 20, true))
	add(b, claws("s4", "z1", -14))
	dress("s4", b)

	b = base("s5", "FOREMAN'S CACHE", "x0", 4)
	table.insert(b, Kit.box("safe", "MetalDark", -29, Y3 + 1.8, 9, 3.2, 3.6, 3.2, true))
	table.insert(b, Kit.box("bunk", "Wood", -12, Y3 + 1.4, 8, 3, 2.8, 8, true))
	table.insert(b, Kit.box("bunk_mat", "Cloth", -12, Y3 + 3, 8, 2.6, 0.4, 7.6, false))
	table.insert(b, Kit.note("s5_note", -22, Y3 + 0.2, 4, nextNote()))
	dress("s5", b)
end

function MineComplexPlan.plan(seed: number): Plan
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

return MineComplexPlan
