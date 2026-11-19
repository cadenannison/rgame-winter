--!strict
-- Pure planning kit for massive structures A (research station, mine complex). No Roblox APIs.
-- A plan is rooms (axis-aligned boxes with walls, doors and floors), stair halls (a ramp with small slope and
-- a flat landing), shell boxes (floors, walls, ceilings, lamps: always built), dressing groups (built only when
-- a player is near), chest slots, lurker and cue spots, and terrain carve boxes.
-- Local frame: +Y up, y = 0 is the entrance floor top, x/z horizontal. The server adapter
-- (server/World/Structures/StructureKitA) places it with World.heightAt. Checked by validate() in tests.

local Config = require("../Config")
local MassiveRules = require("./MassiveRules")

local Kit = {}

Kit.WALL = 1 -- wall thickness
Kit.SLAB = 1 -- floor and ceiling thickness
Kit.DOOR_WIDTH = 6
Kit.DOOR_HEIGHT = 9
Kit.LANDING = 8 -- flat run at the low end of a stair hall
Kit.RAMP_THICK = 1
Kit.MAX_RAMP_DEGREES = 30 -- walkable and mobile friendly
Kit.CHEST_PARTS = 2 -- budget reserve per chest (the chest art is built by LootService)
Kit.ADAPTER_RESERVE = 8 -- parts the adapter adds (approach ramps)
Kit.CHEST_INSET = 2.5 -- chests stand this far inside the walls
Kit.BANNED_WORDS = { "blood", "gore", "corpse", "bleed", "murder", "dead body", "mutilat" }

local T = Kit.WALL

export type Light = { range: number, brightness: number, color: string, flicker: boolean }

export type Box = {
	name: string,
	style: string,
	x: number, -- centre
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	rx: number?, -- degrees
	ry: number?,
	rz: number?,
	collide: boolean,
	shape: string?, -- "Cylinder": vertical, diameter sx
	face: string?, -- Enum.NormalId name of the part face that carries Sign/Note text (fixed in the part frame)
	role: string?, -- "Lamp", "Emitter", "Sign", "Note", "Eyes", "Water"
	text: string?,
	light: Light?,
	particle: string?, -- "Steam", "Dust", "Frost"
}

export type Door = { center: number, width: number, bottom: number }

export type Hall = {
	axis: string, -- "x" or "z": the direction of travel
	hi: string, -- "min" or "max": the end of the axis where the ramp reaches the upper level
	rampFrom: number, -- coordinate along the axis at the foot of the ramp
	rampTo: number, -- coordinate along the axis at the top
	yLow: number,
	yHigh: number,
	width: number, -- clear width
}

export type Room = {
	id: string,
	kind: string,
	name: string,
	level: number, -- 0 surface, -1, -2 ... underground
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	y: number, -- floor top
	h: number, -- floor top to ceiling underside
	landmark: string,
	dark: boolean,
	floor: string,
	wall: string,
	roof: string,
	doors: { [string]: { Door } },
	exit: boolean,
	hall: Hall?,
}

export type RoomSpec = {
	id: string,
	kind: string,
	name: string,
	level: number,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	y: number,
	h: number,
	landmark: string,
	dark: boolean?,
	floor: string?,
	wall: string?,
	roof: string?,
}

export type HallSpec = {
	id: string,
	name: string,
	axis: string,
	hi: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	yLow: number,
	yHigh: number,
	upperH: number,
	level: number,
	landmark: string,
	dark: boolean?,
}

export type Link = { a: string, b: string, sideA: string, sideB: string, door: Door }
export type Exit = { room: string, x: number, z: number, dx: number, dz: number, width: number }
export type Group = { room: string, x: number, z: number, boxes: { Box } }
export type Carve = {
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	open: boolean, -- reaches the surface: the adapter also clears terrain above it
}
export type Chest = { x: number, y: number, z: number, depth: number, room: string }
export type Spot = { x: number, y: number, z: number, room: string, kind: string }

export type Plan = {
	id: string,
	rooms: { Room },
	byId: { [string]: Room },
	links: { Link },
	exits: { Exit },
	shell: { Box },
	dressing: { Group },
	carves: { Carve },
	chests: { Chest },
	lurkers: { Spot },
	cues: { Spot },
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	summary: MassiveRules.PlanSummary,
}

local DEFAULT_STYLES: { [string]: { floor: string, wall: string, roof: string } } = {
	lobby = { floor = "Tile", wall = "Concrete", roof = "Roof" },
	corridor = { floor = "Concrete", wall = "Concrete", roof = "ConcreteDark" },
	hall = { floor = "Grate", wall = "ConcreteDark", roof = "ConcreteDark" },
	lab = { floor = "Tile", wall = "Concrete", roof = "ConcreteDark" },
	utility = { floor = "Grate", wall = "MetalDark", roof = "ConcreteDark" },
	living = { floor = "Wood", wall = "Wood", roof = "Roof" },
	cold = { floor = "Ice", wall = "Ice", roof = "ConcreteDark" },
	mine = { floor = "Rock", wall = "RockDark", roof = "RockDark" },
	cavern = { floor = "Rock", wall = "RockDark", roof = "RockDark" },
	shed = { floor = "Wood", wall = "WoodDark", roof = "Roof" },
}

-- Seeded generator in [0, 1). Deterministic across runs.
function Kit.rng(seed: number): () -> number
	local s = seed % 4294967296
	for _ = 1, 3 do
		s = (s * 1664525 + 1013904223) % 4294967296
	end
	return function(): number
		s = (s * 1664525 + 1013904223) % 4294967296
		return s / 4294967296
	end
end

function Kit.pick<V>(rng: () -> number, list: { V }): V
	return list[math.floor(rng() * #list) + 1]
end

-- Plans -----------------------------------------------------------------------------------------------

function Kit.newPlan(id: string): Plan
	return {
		id = id,
		rooms = {},
		byId = {},
		links = {},
		exits = {},
		shell = {},
		dressing = {},
		carves = {},
		chests = {},
		lurkers = {},
		cues = {},
		minX = 0,
		maxX = 0,
		minZ = 0,
		maxZ = 0,
		summary = {
			id = id,
			footprintX = 0,
			footprintZ = 0,
			rooms = 0,
			levels = 0,
			undergroundDepth = 0,
			minCorridorWidth = 0,
			minCeilingHeight = 0,
			parts = 0,
			dressingParts = 0,
			lights = 0,
			particles = 0,
		},
	}
end

function Kit.addRoom(plan: Plan, spec: RoomSpec): Room
	assert(plan.byId[spec.id] == nil, `duplicate room {spec.id}`)
	local style = DEFAULT_STYLES[spec.kind] or DEFAULT_STYLES.corridor
	local room: Room = {
		id = spec.id,
		kind = spec.kind,
		name = spec.name,
		level = spec.level,
		x0 = spec.x0,
		z0 = spec.z0,
		x1 = spec.x1,
		z1 = spec.z1,
		y = spec.y,
		h = spec.h,
		landmark = spec.landmark,
		dark = spec.dark == true,
		floor = spec.floor or style.floor,
		wall = spec.wall or style.wall,
		roof = spec.roof or style.roof,
		doors = {},
		exit = false,
		hall = nil,
	}
	table.insert(plan.rooms, room)
	plan.byId[room.id] = room
	return room
end

-- A stair hall: a ramp with a landing at its foot. The hall spans from its own floor (yLow) up past the upper
-- level (yHigh + upperH), so the upper room can open straight into the high end.
function Kit.addHall(plan: Plan, spec: HallSpec): Room
	local room = Kit.addRoom(plan, {
		id = spec.id,
		kind = "hall",
		name = spec.name,
		level = spec.level,
		x0 = spec.x0,
		z0 = spec.z0,
		x1 = spec.x1,
		z1 = spec.z1,
		y = spec.yLow,
		h = (spec.yHigh - spec.yLow) + spec.upperH,
		landmark = spec.landmark,
		dark = spec.dark,
	})
	local lo, hiEnd, width
	if spec.axis == "x" then
		lo, hiEnd, width = spec.x0 + T, spec.x1 - T, spec.z1 - spec.z0 - 2 * T
	else
		lo, hiEnd, width = spec.z0 + T, spec.z1 - T, spec.x1 - spec.x0 - 2 * T
	end
	local rampFrom, rampTo = lo + Kit.LANDING, hiEnd
	if spec.hi == "min" then
		rampFrom, rampTo = hiEnd - Kit.LANDING, lo
	end
	room.hall = {
		axis = spec.axis,
		hi = spec.hi,
		rampFrom = rampFrom,
		rampTo = rampTo,
		yLow = spec.yLow,
		yHigh = spec.yHigh,
		width = width,
	}
	return room
end

local function addDoor(room: Room, side: string, door: Door)
	local list = room.doors[side]
	if list == nil then
		list = {}
		room.doors[side] = list
	end
	table.insert(list, door)
end

-- Opens a doorway between two rooms that touch. centerOverride: world-local coordinate along the shared wall.
function Kit.link(plan: Plan, aId: string, bId: string, centerOverride: number?): Link
	local a, b = plan.byId[aId], plan.byId[bId]
	assert(a ~= nil and b ~= nil, `link {aId}-{bId}: unknown room`)
	local sideA, sideB, lo, hi
	if a.x1 == b.x0 then
		sideA, sideB, lo, hi = "x1", "x0", math.max(a.z0, b.z0), math.min(a.z1, b.z1)
	elseif a.x0 == b.x1 then
		sideA, sideB, lo, hi = "x0", "x1", math.max(a.z0, b.z0), math.min(a.z1, b.z1)
	elseif a.z1 == b.z0 then
		sideA, sideB, lo, hi = "z1", "z0", math.max(a.x0, b.x0), math.min(a.x1, b.x1)
	elseif a.z0 == b.z1 then
		sideA, sideB, lo, hi = "z0", "z1", math.max(a.x0, b.x0), math.min(a.x1, b.x1)
	else
		error(`link {aId}-{bId}: rooms do not touch`)
	end
	local width = math.min(Kit.DOOR_WIDTH, hi - lo - 2 * T)
	assert(width >= Config.Massive.DoorWidthMin, `link {aId}-{bId}: overlap too small`)
	local center = centerOverride or (lo + hi) / 2
	center = math.clamp(center, lo + T + width / 2, hi - T - width / 2)
	local bottom = a.y
	if a.hall ~= nil then
		bottom = b.y
	end
	assert(a.hall ~= nil or b.hall ~= nil or a.y == b.y, `link {aId}-{bId}: floors differ`)
	local door: Door = { center = center, width = width, bottom = bottom }
	addDoor(a, sideA, door)
	addDoor(b, sideB, door)
	local link: Link = { a = aId, b = bId, sideA = sideA, sideB = sideB, door = door }
	table.insert(plan.links, link)
	return link
end

-- A doorway to the outside. side: "x0" "x1" "z0" "z1".
function Kit.exit(plan: Plan, roomId: string, side: string, center: number, width: number)
	local room = plan.byId[roomId]
	assert(room ~= nil, `exit: unknown room {roomId}`)
	addDoor(room, side, { center = center, width = width, bottom = room.y })
	room.exit = true
	local x, z, dx, dz = 0, 0, 0, 0
	if side == "x0" then
		x, z, dx = room.x0, center, -1
	elseif side == "x1" then
		x, z, dx = room.x1, center, 1
	elseif side == "z0" then
		x, z, dz = center, room.z0, -1
	else
		x, z, dz = center, room.z1, 1
	end
	table.insert(plan.exits, { room = roomId, x = x, z = z, dx = dx, dz = dz, width = width })
end

-- Box helpers -----------------------------------------------------------------------------------------

function Kit.box(
	name: string,
	style: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	collide: boolean
): Box
	return {
		name = name,
		style = style,
		x = x,
		y = y,
		z = z,
		sx = sx,
		sy = sy,
		sz = sz,
		collide = collide,
	}
end

function Kit.rot(b: Box, rx: number?, ry: number?, rz: number?): Box
	b.rx, b.ry, b.rz = rx, ry, rz
	return b
end

-- Interior bounds of a room (inside the walls).
function Kit.inner(room: Room): (number, number, number, number)
	return room.x0 + T, room.x1 - T, room.z0 + T, room.z1 - T
end

-- A point on a wall's inner face: x, z for a given side, position along the wall and an offset into the room.
function Kit.facePoint(room: Room, side: string, along: number, off: number): (number, number)
	if side == "x0" then
		return room.x0 + T + off, along
	elseif side == "x1" then
		return room.x1 - T - off, along
	elseif side == "z0" then
		return along, room.z0 + T + off
	end
	return along, room.z1 - T - off
end

-- Shell ------------------------------------------------------------------------------------------------

local SIDES = { "x0", "x1", "z0", "z1" }

local function wallBoxes(room: Room, side: string, out: { Box })
	local alongX = side == "z0" or side == "z1"
	local plane, a0, a1
	if side == "x0" then
		plane, a0, a1 = room.x0 + T / 2, room.z0, room.z1
	elseif side == "x1" then
		plane, a0, a1 = room.x1 - T / 2, room.z0, room.z1
	elseif side == "z0" then
		plane, a0, a1 = room.z0 + T / 2, room.x0 + T, room.x1 - T
	else
		plane, a0, a1 = room.z1 - T / 2, room.x0 + T, room.x1 - T
	end
	local doors: { Door } = room.doors[side] or {}
	table.sort(doors, function(p: Door, q: Door): boolean
		return p.center < q.center
	end)
	local y0, y1 = room.y, room.y + room.h
	local function piece(from: number, to: number, yb: number, yt: number, tag: string)
		if to - from < 0.05 or yt - yb < 0.05 then
			return
		end
		local c, len = (from + to) / 2, to - from
		local ym, hy = (yb + yt) / 2, yt - yb
		local name = `{room.id}_{side}_{tag}`
		if alongX then
			table.insert(out, Kit.box(name, room.wall, c, ym, plane, len, hy, T, true))
		else
			table.insert(out, Kit.box(name, room.wall, plane, ym, c, T, hy, len, true))
		end
	end
	local cursor = a0
	for i = 1, #doors do
		local d = doors[i]
		local d0, d1 = d.center - d.width / 2, d.center + d.width / 2
		piece(cursor, d0, y0, y1, `w{i}`)
		piece(d0, d1, y0, d.bottom, `s{i}`)
		piece(d0, d1, d.bottom + Kit.DOOR_HEIGHT, y1, `l{i}`)
		cursor = d1
	end
	piece(cursor, a1, y0, y1, "e")
end

local function rampBox(room: Room, hall: Hall): Box
	local run = math.abs(hall.rampTo - hall.rampFrom)
	local rise = hall.yHigh - hall.yLow
	local len = math.sqrt(run * run + rise * rise)
	local angle = math.atan2(rise, run)
	local along = (hall.rampFrom + hall.rampTo) / 2
	local y = (hall.yLow + hall.yHigh) / 2 - Kit.RAMP_THICK / 2 / math.cos(angle)
	local deg = math.deg(angle)
	local rising = if hall.hi == "max" then 1 else -1
	local b: Box
	if hall.axis == "x" then
		local cz = (room.z0 + room.z1) / 2
		b = Kit.box(`{room.id}_ramp`, "Grate", along, y, cz, len, Kit.RAMP_THICK, hall.width, true)
		Kit.rot(b, 0, 0, deg * rising)
	else
		local cx = (room.x0 + room.x1) / 2
		b = Kit.box(`{room.id}_ramp`, "Grate", cx, y, along, hall.width, Kit.RAMP_THICK, len, true)
		Kit.rot(b, -deg * rising, 0, 0)
	end
	return b
end

-- Builds floors, walls, ceilings, ramps and carve boxes from the rooms and links, and the plan summary.
-- Call after every light/emitter/dressing/chest has been added.
function Kit.finish(plan: Plan)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, room in plan.rooms do
		minX, maxX = math.min(minX, room.x0), math.max(maxX, room.x1)
		minZ, maxZ = math.min(minZ, room.z0), math.max(maxZ, room.z1)
		local w, d = room.x1 - room.x0, room.z1 - room.z0
		local cx, cz = (room.x0 + room.x1) / 2, (room.z0 + room.z1) / 2
		table.insert(
			plan.shell,
			Kit.box(
				`{room.id}_floor`,
				room.floor,
				cx,
				room.y - Kit.SLAB / 2,
				cz,
				w,
				Kit.SLAB,
				d,
				true
			)
		)
		table.insert(
			plan.shell,
			Kit.box(
				`{room.id}_ceil`,
				room.roof,
				cx,
				room.y + room.h + Kit.SLAB / 2,
				cz,
				w,
				Kit.SLAB,
				d,
				true
			)
		)
		for _, side in SIDES do
			wallBoxes(room, side, plan.shell)
		end
		if room.hall ~= nil then
			table.insert(plan.shell, rampBox(room, room.hall))
		end
		table.insert(plan.carves, {
			x0 = room.x0,
			x1 = room.x1,
			z0 = room.z0,
			z1 = room.z1,
			y0 = room.y - Kit.SLAB,
			y1 = room.y + room.h + Kit.SLAB,
			open = room.y + room.h > 0,
		})
	end
	plan.minX, plan.maxX, plan.minZ, plan.maxZ = minX, maxX, minZ, maxZ
	plan.summary = Kit.summarize(plan)
end

function Kit.summarize(plan: Plan): MassiveRules.PlanSummary
	local floors: { [number]: boolean } = {}
	local depth, minCorridor, minCeiling = 0, math.huge, math.huge
	for _, room in plan.rooms do
		if room.kind ~= "hall" then
			floors[room.y] = true
		end
		depth = math.max(depth, -room.y)
		minCeiling = math.min(minCeiling, room.h)
		if room.kind == "corridor" or room.kind == "mine" then
			minCorridor =
				math.min(minCorridor, math.min(room.x1 - room.x0, room.z1 - room.z0) - 2 * T)
		elseif room.hall ~= nil then
			minCorridor = math.min(minCorridor, room.hall.width)
		end
	end
	local levels = 0
	for _ in floors do
		levels += 1
	end
	local dressing, lights, particles = 0, 0, 0
	for _, g in plan.dressing do
		dressing += #g.boxes
	end
	local all: { { Box } } = { plan.shell }
	for _, g in plan.dressing do
		table.insert(all, g.boxes)
	end
	for _, list in all do
		for _, b in list do
			if b.light ~= nil then
				lights += 1
			end
			if b.particle ~= nil then
				particles += 1
			end
		end
	end
	return {
		id = plan.id,
		footprintX = plan.maxX - plan.minX,
		footprintZ = plan.maxZ - plan.minZ,
		rooms = #plan.rooms,
		levels = levels,
		undergroundDepth = depth,
		minCorridorWidth = minCorridor,
		minCeilingHeight = minCeiling,
		parts = #plan.shell + dressing + #plan.chests * Kit.CHEST_PARTS + Kit.ADAPTER_RESERVE,
		dressingParts = dressing,
		lights = lights,
		particles = particles,
	}
end

-- Shell additions ------------------------------------------------------------------------------------

-- A ceiling lamp (a Lamp part with a light). Counts toward Budget.Lights.
function Kit.lamp(plan: Plan, room: Room, x: number, z: number, light: Light)
	local b = Kit.box(`{room.id}_lamp`, "Lamp", x, room.y + room.h - 0.5, z, 2, 0.5, 2, false)
	b.role = "Lamp"
	b.light = light
	table.insert(plan.shell, b)
end

-- An invisible particle anchor. Counts toward Budget.Particles.
function Kit.emitter(plan: Plan, room: Room, x: number, y: number, z: number, kind: string)
	local b = Kit.box(`{room.id}_emitter`, "Emitter", x, y, z, 1, 1, 1, false)
	b.role = "Emitter"
	b.particle = kind
	table.insert(plan.shell, b)
end

function Kit.dress(plan: Plan, room: Room, boxes: { Box })
	local cx, cz = (room.x0 + room.x1) / 2, (room.z0 + room.z1) / 2
	table.insert(plan.dressing, { room = room.id, x = cx, z = cz, boxes = boxes })
end

-- A loot chest slot on the floor of a room at (x, z).
function Kit.chest(plan: Plan, room: Room, x: number, z: number, depth: number)
	table.insert(plan.chests, { x = x, y = room.y, z = z, depth = depth, room = room.id })
end

-- A chest in a rng-chosen corner of the room interior (inset Kit.CHEST_INSET from the walls).
function Kit.cornerChest(plan: Plan, room: Room, rng: () -> number, depth: number, corner: number?)
	local x0, x1, z0, z1 = Kit.inner(room)
	local i = corner or (math.floor(rng() * 4) + 1)
	local x = if i % 2 == 0 then x1 - Kit.CHEST_INSET else x0 + Kit.CHEST_INSET
	local z = if i > 2 then z1 - Kit.CHEST_INSET else z0 + Kit.CHEST_INSET
	Kit.chest(plan, room, x, z, depth)
end

function Kit.lurker(plan: Plan, room: Room, x: number, z: number, kind: string)
	table.insert(plan.lurkers, { x = x, y = room.y, z = z, room = room.id, kind = kind })
end

function Kit.cue(plan: Plan, room: Room, x: number, z: number, kind: string)
	table.insert(plan.cues, { x = x, y = room.y + 2, z = z, room = room.id, kind = kind })
end

-- Dressing primitives (each returns boxes; y0 = the floor top they stand on) --------------------------

function Kit.crate(name: string, x: number, y0: number, z: number, size: number, yaw: number): Box
	return Kit.rot(Kit.box(name, "Wood", x, y0 + size / 2, z, size, size, size, true), 0, yaw, 0)
end

function Kit.barrel(name: string, x: number, y0: number, z: number): Box
	local b = Kit.box(name, "Rust", x, y0 + 1.5, z, 2.4, 3, 2.4, true)
	b.shape = "Cylinder"
	return b
end

function Kit.desk(name: string, x: number, y0: number, z: number, yaw: number): { Box }
	return {
		Kit.rot(Kit.box(`{name}_top`, "Wood", x, y0 + 3, z, 5, 0.4, 2.6, true), 0, yaw, 0),
		Kit.rot(Kit.box(`{name}_base`, "WoodDark", x, y0 + 1.4, z, 4.4, 2.8, 2, true), 0, yaw, 0),
	}
end

function Kit.overturned(name: string, x: number, y0: number, z: number, yaw: number): { Box }
	return {
		Kit.rot(Kit.box(`{name}_top`, "Wood", x, y0 + 1.4, z, 5, 0.4, 2.6, true), 0, yaw, 75),
		Kit.rot(
			Kit.box(`{name}_leg`, "WoodDark", x + 2.2, y0 + 0.2, z + 1, 0.4, 0.4, 3.2, false),
			0,
			yaw,
			15
		),
	}
end

function Kit.shelf(
	name: string,
	x: number,
	y0: number,
	z: number,
	yaw: number,
	len: number
): { Box }
	return {
		Kit.rot(Kit.box(`{name}_frame`, "MetalDark", x, y0 + 3.5, z, len, 7, 1.4, true), 0, yaw, 0),
		Kit.rot(
			Kit.box(`{name}_goods`, "Paper", x, y0 + 4.2, z, len - 0.6, 1.2, 1.1, false),
			0,
			yaw,
			0
		),
	}
end

function Kit.rack(name: string, x: number, y0: number, z: number, yaw: number): { Box }
	local light = Kit.box(`{name}_leds`, "Indicator", x, y0 + 5, z, 2.2, 0.4, 0.2, false)
	return {
		Kit.rot(Kit.box(`{name}_body`, "MetalDark", x, y0 + 3.5, z, 2.6, 7, 2.6, true), 0, yaw, 0),
		Kit.rot(light, 0, yaw, 0),
	}
end

function Kit.pipe(name: string, x: number, y: number, z: number, len: number, alongX: boolean): Box
	local b = Kit.box(
		name,
		"Rust",
		x,
		y,
		z,
		if alongX then len else 0.8,
		0.8,
		if alongX then 0.8 else len,
		false
	)
	return b
end

function Kit.rubble(
	name: string,
	x: number,
	y0: number,
	z: number,
	size: number,
	rng: () -> number
): { Box }
	return {
		Kit.rot(
			Kit.box(`{name}_a`, "Rubble", x, y0 + size * 0.4, z, size, size * 0.8, size * 0.9, true),
			rng() * 30,
			rng() * 360,
			rng() * 30
		),
		Kit.rot(
			Kit.box(
				`{name}_b`,
				"Rubble",
				x + size * 0.5,
				y0 + size * 0.25,
				z + size * 0.3,
				size * 0.6,
				size * 0.5,
				size * 0.6,
				true
			),
			rng() * 40,
			rng() * 360,
			rng() * 40
		),
	}
end

function Kit.note(name: string, x: number, y: number, z: number, text: string): Box
	local b = Kit.box(name, "Paper", x, y + 0.1, z, 1.4, 0.15, 1.8, false)
	b.role = "Note"
	b.face = "Top"
	b.text = text
	return b
end

-- Two scratch marks gouged into a wall. Dark grooves only.
function Kit.claws(
	name: string,
	room: Room,
	side: string,
	along: number,
	rng: () -> number
): { Box }
	local out: { Box } = {}
	for i = 1, 2 do
		local a = along + (i - 1.5) * 0.9
		local x, z = Kit.facePoint(room, side, a, 0.08)
		local tilt = (rng() - 0.5) * 24
		local y = room.y + 4.5 + rng()
		local b: Box
		if side == "x0" or side == "x1" then
			b = Kit.box(`{name}_{i}`, "Scratch", x, y, z, 0.15, 3.6, 0.22, false)
			Kit.rot(b, tilt, 0, 0)
		else
			b = Kit.box(`{name}_{i}`, "Scratch", x, y, z, 0.22, 3.6, 0.15, false)
			Kit.rot(b, 0, 0, tilt)
		end
		table.insert(out, b)
	end
	return out
end

-- A room label on a wall. The landmark that tells players where they are.
function Kit.sign(name: string, room: Room, side: string, along: number, text: string): Box
	local x, z = Kit.facePoint(room, side, along, 0.15)
	local y = room.y + math.min(room.h - 2.5, 7)
	local b: Box
	if side == "x0" or side == "x1" then
		b = Kit.box(name, "Sign", x, y, z, 0.2, 1.8, 6.4, false)
	else
		b = Kit.box(name, "Sign", x, y, z, 6.4, 1.8, 0.2, false)
	end
	b.role = "Sign"
	b.text = text
	-- the readable face looks into the room, never at the player
	b.face = if side == "x0"
		then "Right"
		elseif side == "x1" then "Left"
		elseif side == "z0" then "Back"
		else "Front"
	return b
end

-- Two pale eyes in the dark (face along +z of yaw). Dressing: vanish when a player comes close.
function Kit.eyes(name: string, x: number, y: number, z: number, yaw: number): { Box }
	local left = Kit.box(`{name}_l`, "Eyes", x - 0.35, y, z, 0.28, 0.16, 0.1, false)
	local right = Kit.box(`{name}_r`, "Eyes", x + 0.35, y, z, 0.28, 0.16, 0.1, false)
	left.role, right.role = "Eyes", "Eyes"
	return { Kit.rot(left, 0, yaw, 0), Kit.rot(right, 0, yaw, 0) }
end

-- Timber support frame across a tunnel (axis = direction the tunnel runs): two posts and a beam.
function Kit.support(
	name: string,
	x: number,
	y0: number,
	z: number,
	span: number,
	alongX: boolean,
	h: number
): { Box }
	local half = span / 2 - 0.4
	if alongX then
		return {
			Kit.box(`{name}_p1`, "Wood", x, y0 + h / 2, z - half, 0.8, h, 0.8, false),
			Kit.box(`{name}_p2`, "Wood", x, y0 + h / 2, z + half, 0.8, h, 0.8, false),
			Kit.box(`{name}_b`, "WoodDark", x, y0 + h - 0.4, z, 0.9, 0.8, span - 0.2, false),
		}
	end
	return {
		Kit.box(`{name}_p1`, "Wood", x - half, y0 + h / 2, z, 0.8, h, 0.8, false),
		Kit.box(`{name}_p2`, "Wood", x + half, y0 + h / 2, z, 0.8, h, 0.8, false),
		Kit.box(`{name}_b`, "WoodDark", x, y0 + h - 0.4, z, span - 0.2, 0.8, 0.9, false),
	}
end

-- Rail track along a tunnel: two rails and a few sleepers (no collision, so nothing trips a player).
function Kit.rails(
	name: string,
	x: number,
	y0: number,
	z: number,
	len: number,
	alongX: boolean,
	gauge: number
): { Box }
	local out: { Box } = {}
	local count = math.max(2, math.floor(len / 14))
	if alongX then
		table.insert(
			out,
			Kit.box(`{name}_r1`, "Rail", x, y0 + 0.2, z - gauge / 2, len, 0.3, 0.4, false)
		)
		table.insert(
			out,
			Kit.box(`{name}_r2`, "Rail", x, y0 + 0.2, z + gauge / 2, len, 0.3, 0.4, false)
		)
		for i = 1, count do
			local px = x - len / 2 + (i - 0.5) * len / count
			table.insert(
				out,
				Kit.box(`{name}_s{i}`, "WoodDark", px, y0 + 0.1, z, 1, 0.2, gauge + 1.6, false)
			)
		end
	else
		table.insert(
			out,
			Kit.box(`{name}_r1`, "Rail", x - gauge / 2, y0 + 0.2, z, 0.4, 0.3, len, false)
		)
		table.insert(
			out,
			Kit.box(`{name}_r2`, "Rail", x + gauge / 2, y0 + 0.2, z, 0.4, 0.3, len, false)
		)
		for i = 1, count do
			local pz = z - len / 2 + (i - 0.5) * len / count
			table.insert(
				out,
				Kit.box(`{name}_s{i}`, "WoodDark", x, y0 + 0.1, pz, gauge + 1.6, 0.2, 1, false)
			)
		end
	end
	return out
end

-- Validation ------------------------------------------------------------------------------------------

-- Rooms that cannot be walked to the outside through the links (empty = all reachable).
function Kit.unreachable(plan: Plan): { string }
	local seen: { [string]: boolean } = {}
	local queue: { string } = {}
	for _, room in plan.rooms do
		if room.exit then
			seen[room.id] = true
			table.insert(queue, room.id)
		end
	end
	local head = 1
	while head <= #queue do
		local id = queue[head]
		head += 1
		for _, link in plan.links do
			local other = if link.a == id then link.b elseif link.b == id then link.a else nil
			if other ~= nil and not seen[other] then
				seen[other] = true
				table.insert(queue, other)
			end
		end
	end
	local out: { string } = {}
	for _, room in plan.rooms do
		if not seen[room.id] then
			table.insert(out, room.id)
		end
	end
	return out
end

local function overlap1(a0: number, a1: number, b0: number, b1: number): boolean
	return math.min(a1, b1) - math.max(a0, b0) > 1e-6
end

function Kit.validate(plan: Plan): { string }
	local errs = MassiveRules.validatePlan(plan.summary)
	local M = Config.Massive
	local function need(ok: boolean, msg: string)
		if not ok then
			table.insert(errs, msg)
		end
	end
	for _, id in Kit.unreachable(plan) do
		need(false, `room {id} has no way back to the surface`)
	end
	need(#plan.exits >= 1, "no exit to the surface")
	need(
		Kit.DOOR_WIDTH >= M.DoorWidthMin and Kit.DOOR_HEIGHT >= M.DoorHeightMin,
		"door constants below Config"
	)
	need(Kit.LANDING >= Kit.DOOR_WIDTH + 2, "landing too short for a door")
	-- rooms never overlap (touching is fine)
	for i, a in plan.rooms do
		for j = i + 1, #plan.rooms do
			local b = plan.rooms[j]
			if
				overlap1(a.x0, a.x1, b.x0, b.x1)
				and overlap1(a.z0, a.z1, b.z0, b.z1)
				and overlap1(
					a.y - Kit.SLAB,
					a.y + a.h + Kit.SLAB,
					b.y - Kit.SLAB,
					b.y + b.h + Kit.SLAB
				)
			then
				need(false, `rooms {a.id} and {b.id} overlap`)
			end
		end
		need(a.landmark ~= "", `room {a.id} has no landmark`)
		need(a.h >= M.CeilingHeightMin, `room {a.id} ceiling too low`)
		for side, doors in a.doors do
			local lo, hi
			if side == "x0" or side == "x1" then
				lo, hi = a.z0 + T, a.z1 - T
			else
				lo, hi = a.x0 + T, a.x1 - T
			end
			for _, d in doors do
				need(d.width >= M.DoorWidthMin, `door in {a.id} too narrow`)
				need(
					d.center - d.width / 2 >= lo - 1e-6 and d.center + d.width / 2 <= hi + 1e-6,
					`door in {a.id} outside its wall`
				)
				need(d.bottom >= a.y - 1e-6, `door in {a.id} below the floor`)
				need(
					d.bottom + Kit.DOOR_HEIGHT <= a.y + a.h + 1e-6,
					`door in {a.id} taller than the room`
				)
				-- a side door of a stair hall must open on the flat landing, never on the slope
				local hall = a.hall
				if hall ~= nil then
					local longSide = if hall.axis == "x"
						then (side == "z0" or side == "z1")
						else (side == "x0" or side == "x1")
					if longSide then
						local d0, d1 = d.center - d.width / 2, d.center + d.width / 2
						local onLanding = if hall.hi == "max"
							then d1 <= hall.rampFrom + 1e-6
							else d0 >= hall.rampFrom - 1e-6
						need(onLanding, `hall {a.id} side door is on the ramp`)
						need(
							d.bottom == hall.yLow or d.bottom == hall.yHigh,
							`hall {a.id} door at odd height`
						)
					end
				end
			end
		end
		local hall = a.hall
		if hall ~= nil then
			local run = math.abs(hall.rampTo - hall.rampFrom)
			local angle = math.deg(math.atan2(hall.yHigh - hall.yLow, run))
			need(angle <= Kit.MAX_RAMP_DEGREES, `hall {a.id} ramp too steep ({angle})`)
			need(hall.width >= M.StairWidthMin, `hall {a.id} ramp too narrow`)
			need(run > 0, `hall {a.id} has no ramp`)
		end
	end
	-- chests: inside their room, off the walls, depth in range
	local maxDepth = Config.Loot.MaxDepthTier
	for _, c in plan.chests do
		local room = plan.byId[c.room]
		need(room ~= nil, "chest in unknown room")
		if room ~= nil then
			local x0, x1, z0, z1 = Kit.inner(room)
			need(
				c.x >= x0 + 1 and c.x <= x1 - 1 and c.z >= z0 + 1 and c.z <= z1 - 1,
				`chest in {c.room} too near a wall`
			)
			need(c.y == room.y, `chest in {c.room} off the floor`)
		end
		need(c.depth >= 0 and c.depth <= maxDepth, "chest depth out of range")
	end
	-- dressing never blocks a doorway (a clear box of DOOR_WIDTH x DOOR_HEIGHT, 3 studs deep each side)
	for _, g in plan.dressing do
		local room = plan.byId[g.room]
		if room ~= nil then
			for _, b in g.boxes do
				if b.collide then
					for side, doors in room.doors do
						for _, d in doors do
							local w, depth = d.width / 2, 3.2
							local cx, cz, hx, hz
							if side == "x0" or side == "x1" then
								cx = if side == "x0"
									then room.x0 + T + depth / 2
									else room.x1 - T - depth / 2
								cz, hx, hz = d.center, depth / 2, w
							else
								cz = if side == "z0"
									then room.z0 + T + depth / 2
									else room.z1 - T - depth / 2
								cx, hx, hz = d.center, w, depth / 2
							end
							local ex = math.max(b.sx, b.sz) / 2
							local ez = ex
							local hit = math.abs(b.x - cx) < hx + ex
								and math.abs(b.z - cz) < hz + ez
							local high = b.y - b.sy / 2 < d.bottom + Kit.DOOR_HEIGHT
								and b.y + b.sy / 2 > d.bottom + 0.2
							need(not (hit and high), `{b.name} blocks a door in {room.id}`)
						end
					end
				end
			end
		end
	end
	for _, list in { plan.shell } do
		for _, b in list do
			need(b.sx > 0 and b.sy > 0 and b.sz > 0, `{b.name} has no size`)
		end
	end
	local texts: { string } = {}
	for _, g in plan.dressing do
		for _, b in g.boxes do
			if b.text ~= nil then
				table.insert(texts, string.lower(b.text))
			end
		end
	end
	for _, text in texts do
		for _, word in Kit.BANNED_WORDS do
			need(string.find(text, word, 1, true) == nil, `text not PG: {word}`)
		end
	end
	return errs
end

return Kit
