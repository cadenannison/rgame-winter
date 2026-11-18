--!strict
-- Pure plan toolkit for massive structures B (shipwreck, temple, lodge, ruins). No Roblox APIs.
-- A plan is local-space data: rooms (axis-aligned rects with floor Y), doors, ramps, shell boxes (large
-- parts), terrain carves, dressing (small props spawned near players) and loot chest slots. Local origin is
-- the footprint centre at ground level (+Y up, underground negative). Rotation by yaw happens in the adapter.

local Config = require("../Config")
local MassiveRules = require("./MassiveRules")

local Kit = {}

Kit.WALL_T = 1.5
Kit.SLAB = 1
Kit.DOOR_W = 6
Kit.DOOR_H = 9
Kit.RAMP_RUN = 3 -- run per unit rise (gentle, mobile friendly)
Kit.RAMP_W = 7
Kit.LANE_W = 6
Kit.SURFACE_Y = 1 -- ground-level floors sit 1 stud above terrain (one easy step)
Kit.ROOM_H = 12

local WALL_T, DOOR_W, DOOR_H = Kit.WALL_T, Kit.DOOR_W, Kit.DOOR_H

export type Light = { color: string, range: number, brightness: number }
export type Box = {
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	style: string,
	collide: boolean,
	rx: number?,
	ry: number?,
	rz: number?,
	light: Light?,
	fx: string?,
}
export type Rect = { x1: number, z1: number, x2: number, z2: number }
export type Door = { side: string, c: number, width: number, y: number }
export type Room = {
	id: string,
	kind: string,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	y: number,
	height: number,
	roof: boolean,
	floor: boolean,
	underground: boolean,
	tower: boolean,
	landmark: string,
	depth: number,
	wallH: number,
	rail: boolean,
	wall: string,
	floorStyle: string,
	roofStyle: string,
	flooded: boolean,
	doors: { Door },
	holes: { Rect },
	clear: { Rect },
}
export type RoomSpec = {
	id: string,
	kind: string,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	y: number,
	height: number?,
	roof: boolean?,
	floor: boolean?,
	underground: boolean?,
	depth: number?,
	wallH: number?,
	rail: boolean?,
	wall: string?,
	floorStyle: string?,
	roofStyle: string?,
	flooded: boolean?,
}
export type Chest = { room: string, x: number, y: number, z: number, depth: number }
export type Dress = { room: string, box: Box }
export type Pad = { halfX: number, halfZ: number, depth: number, top: string }
export type Plan = {
	id: string,
	seed: number,
	yaw: number, -- quarter turns 0..3
	footprintX: number,
	footprintZ: number,
	rooms: { Room },
	byId: { [string]: Room },
	links: { { string } },
	entrance: string,
	shell: { Box },
	carves: { Box },
	dressing: { Dress },
	chests: { Chest },
	rampWidths: { number },
	pad: Pad?,
	dread: { [string]: string }, -- room id -> zone kind
}
export type PropKind = {
	name: string,
	style: string,
	sx: number,
	sy: number,
	sz: number,
	collide: boolean,
	light: Light?,
	fx: string?,
	hang: boolean?, -- true: hangs from the ceiling
}

-- Deterministic RNG in [0,1) (Park-Miller; products stay exact in doubles).
function Kit.rng(seed: number): () -> number
	local state = (math.floor(math.abs(seed)) % 2147483646) + 1
	local function step(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	for _ = 1, 6 do
		step() -- warm up: nearby seeds must not give nearby first draws
	end
	return step
end

function Kit.new(id: string, footprintX: number, footprintZ: number, seed: number): Plan
	local rng = Kit.rng(seed * 31 + 7)
	return {
		id = id,
		seed = seed,
		yaw = math.floor(rng() * 4) % 4,
		footprintX = footprintX,
		footprintZ = footprintZ,
		rooms = {},
		byId = {},
		links = {},
		entrance = "",
		shell = {},
		carves = {},
		dressing = {},
		chests = {},
		rampWidths = {},
		pad = nil,
		dread = {},
	}
end

local function box(
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	style: string,
	collide: boolean
): Box
	return {
		name = name,
		x = x,
		y = y,
		z = z,
		sx = sx,
		sy = sy,
		sz = sz,
		style = style,
		collide = collide,
	}
end
Kit.box = box

function Kit.shell(plan: Plan, b: Box): Box
	table.insert(plan.shell, b)
	return b
end

function Kit.pad(plan: Plan, halfX: number, halfZ: number, depth: number, top: string)
	plan.pad = { halfX = halfX, halfZ = halfZ, depth = depth, top = top }
end

function Kit.room(plan: Plan, s: RoomSpec): Room
	assert(plan.byId[s.id] == nil, `duplicate room {s.id}`)
	local room: Room = {
		id = s.id,
		kind = s.kind,
		x1 = s.x1,
		z1 = s.z1,
		x2 = s.x2,
		z2 = s.z2,
		y = s.y,
		height = s.height or Kit.ROOM_H,
		roof = if s.roof == nil then true else s.roof,
		floor = if s.floor == nil then true else s.floor,
		underground = s.underground or false,
		tower = false,
		landmark = "",
		depth = s.depth or 0,
		wallH = s.wallH or s.height or Kit.ROOM_H,
		rail = s.rail or false,
		wall = s.wall or "Wall",
		floorStyle = s.floorStyle or "Floor",
		roofStyle = s.roofStyle or "Roof",
		flooded = s.flooded or false,
		doors = {},
		holes = {},
		clear = {},
	}
	table.insert(plan.rooms, room)
	plan.byId[s.id] = room
	return room
end

function Kit.link(plan: Plan, a: string, b: string)
	assert(plan.byId[a] and plan.byId[b], `link {a}-{b}: unknown room`)
	table.insert(plan.links, { a, b })
end

local function addDoor(room: Room, side: string, c: number, y: number, width: number?)
	local w = width or DOOR_W
	table.insert(room.doors, { side = side, c = c, width = w, y = y })
	-- keep the doorway clear of props: 6 studs inside
	local half = w / 2 + 1
	if side == "N" then
		table.insert(room.clear, { x1 = c - half, z1 = room.z1, x2 = c + half, z2 = room.z1 + 7 })
	elseif side == "S" then
		table.insert(room.clear, { x1 = c - half, z1 = room.z2 - 7, x2 = c + half, z2 = room.z2 })
	elseif side == "W" then
		table.insert(room.clear, { x1 = room.x1, z1 = c - half, x2 = room.x1 + 7, z2 = c + half })
	else
		table.insert(room.clear, { x1 = room.x2 - 7, z1 = c - half, x2 = room.x2, z2 = c + half })
	end
end

local OPPOSITE = { N = "S", S = "N", W = "E", E = "W" }

-- Door through the shared wall of two same-level touching rooms (door centred on the overlap).
function Kit.connect(plan: Plan, aId: string, bId: string, width: number?)
	local a, b = plan.byId[aId], plan.byId[bId]
	assert(a and b, `connect {aId}-{bId}: unknown room`)
	assert(math.abs(a.y - b.y) < 0.01, `connect {aId}-{bId}: different levels`)
	local function over(a1: number, a2: number, b1: number, b2: number): (number, number)
		return math.max(a1, b1), math.min(a2, b2)
	end
	local sideA: string, c: number, lo: number, hi: number
	if math.abs(a.x2 - b.x1) < 0.01 then
		sideA = "E"
		lo, hi = over(a.z1, a.z2, b.z1, b.z2)
	elseif math.abs(a.x1 - b.x2) < 0.01 then
		sideA = "W"
		lo, hi = over(a.z1, a.z2, b.z1, b.z2)
	elseif math.abs(a.z2 - b.z1) < 0.01 then
		sideA = "S"
		lo, hi = over(a.x1, a.x2, b.x1, b.x2)
	elseif math.abs(a.z1 - b.z2) < 0.01 then
		sideA = "N"
		lo, hi = over(a.x1, a.x2, b.x1, b.x2)
	else
		error(`connect {aId}-{bId}: rooms do not touch`)
	end
	assert(hi - lo >= DOOR_W + 1, `connect {aId}-{bId}: overlap too small`)
	c = (lo + hi) / 2
	addDoor(a, sideA, c, a.y, width)
	addDoor(b, OPPOSITE[sideA], c, b.y, width)
	Kit.link(plan, aId, bId)
end

-- Door pair at an explicit position (stair shafts): c along the wall axis, y = sill height.
function Kit.doorPair(
	plan: Plan,
	aId: string,
	aSide: string,
	bId: string,
	bSide: string,
	c: number,
	y: number
)
	addDoor(plan.byId[aId], aSide, c, y, nil)
	addDoor(plan.byId[bId], bSide, c, y, nil)
	Kit.link(plan, aId, bId)
end

-- Door on one room only (open decks, tops of ramps). y = sill height.
function Kit.door(plan: Plan, id: string, side: string, c: number, y: number, width: number?)
	addDoor(plan.byId[id], side, c, y, width)
end

-- Door to the outside (the first one made is the plan entrance).
function Kit.exterior(plan: Plan, id: string, side: string, c: number, width: number?)
	local room = plan.byId[id]
	addDoor(room, side, c, room.y, width)
	if plan.entrance == "" then
		plan.entrance = id
	end
end

local function subtract(piece: Rect, hole: Rect): { Rect }
	if hole.x2 <= piece.x1 or hole.x1 >= piece.x2 or hole.z2 <= piece.z1 or hole.z1 >= piece.z2 then
		return { piece }
	end
	local out: { Rect } = {}
	local hx1, hx2 = math.max(hole.x1, piece.x1), math.min(hole.x2, piece.x2)
	if hx1 > piece.x1 then
		table.insert(out, { x1 = piece.x1, z1 = piece.z1, x2 = hx1, z2 = piece.z2 })
	end
	if hx2 < piece.x2 then
		table.insert(out, { x1 = hx2, z1 = piece.z1, x2 = piece.x2, z2 = piece.z2 })
	end
	if hole.z1 > piece.z1 then
		table.insert(out, { x1 = hx1, z1 = piece.z1, x2 = hx2, z2 = hole.z1 })
	end
	if hole.z2 < piece.z2 then
		table.insert(out, { x1 = hx1, z1 = hole.z2, x2 = hx2, z2 = piece.z2 })
	end
	return out
end

function Kit.hole(plan: Plan, roomId: string, rect: Rect)
	table.insert(plan.byId[roomId].holes, rect)
end

-- One straight ramp. Start point is the middle of the low/start edge; dir = +1/-1 travel along axis;
-- rise > 0 climbs, < 0 descends in the travel direction. Returns the footprint rect (use as a floor hole).
function Kit.ramp(
	plan: Plan,
	fromId: string,
	toId: string,
	x: number,
	y: number,
	z: number,
	axis: string,
	dir: number,
	rise: number,
	width: number?,
	style: string?
): Rect
	local w = width or Kit.RAMP_W
	local run = math.abs(rise) * Kit.RAMP_RUN
	local len = math.sqrt(run * run + rise * rise)
	local theta = math.deg(math.atan2(rise, run))
	local b: Box
	local rect: Rect
	if axis == "X" then
		local xe = x + dir * run
		b = box(
			`Ramp_{fromId}_{toId}`,
			(x + xe) / 2,
			y + rise / 2 - 0.5,
			z,
			len,
			1,
			w,
			style or "Floor",
			true
		)
		b.rz = dir * theta
		rect = { x1 = math.min(x, xe), z1 = z - w / 2, x2 = math.max(x, xe), z2 = z + w / 2 }
	else
		local ze = z + dir * run
		b = box(
			`Ramp_{fromId}_{toId}`,
			x,
			y + rise / 2 - 0.5,
			(z + ze) / 2,
			w,
			1,
			len,
			style or "Floor",
			true
		)
		b.rx = -dir * theta
		rect = { x1 = x - w / 2, z1 = math.min(z, ze), x2 = x + w / 2, z2 = math.max(z, ze) }
	end
	Kit.shell(plan, b)
	table.insert(plan.rampWidths, w)
	local pad: Rect = { x1 = rect.x1 - 1, z1 = rect.z1 - 1, x2 = rect.x2 + 1, z2 = rect.z2 + 1 }
	table.insert(plan.byId[fromId].clear, pad)
	table.insert(plan.byId[toId].clear, pad)
	Kit.link(plan, fromId, toId)
	return rect
end

-- Switchback stair shaft: a tall room carved from yBot up to ground, two flights and a landing. The top
-- door (sill yTop) joins `topId`, the bottom door (sill yBot) joins `bottomId`; both on the same wall `side`
-- ("W" or "E"). Needs depth >= 15 (two 6-wide lanes) and enough length for the flights plus a 6 landing.
function Kit.stairwell(
	plan: Plan,
	id: string,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	yTop: number,
	yBot: number,
	side: string,
	topId: string,
	bottomId: string,
	wall: string
): Room
	local room = Kit.room(plan, {
		id = id,
		kind = "stairwell",
		x1 = x1,
		z1 = z1,
		x2 = x2,
		z2 = z2,
		y = yBot,
		height = yTop + Kit.ROOM_H - yBot,
		underground = true,
		wall = wall,
	})
	room.tower = true
	local laneW = Kit.LANE_W
	assert(z2 - z1 >= 2 * WALL_T + 2 * laneW, `{id}: shaft too shallow`)
	local rise = (yBot - yTop) / 2 -- negative per flight
	local run = math.abs(rise) * Kit.RAMP_RUN
	local yMid = (yTop + yBot) / 2
	local s = if side == "W" then 1 else -1
	local startX = if s == 1 then x1 + WALL_T else x2 - WALL_T
	local farX = startX + s * run
	local wallFar = if s == 1 then x2 - WALL_T else x1 + WALL_T
	assert(math.abs(wallFar - farX) >= 6 and (wallFar - farX) * s >= 0, `{id}: landing too short`)
	local laneA = z1 + WALL_T + laneW / 2
	local laneB = z1 + WALL_T + laneW * 1.5
	Kit.ramp(plan, topId, id, startX, yTop, laneA, "X", s, rise, laneW, "Floor")
	Kit.ramp(plan, id, bottomId, farX, yMid, laneB, "X", -s, rise, laneW, "Floor")
	-- landing platform
	local lx1, lx2 = math.min(farX, wallFar), math.max(farX, wallFar)
	Kit.shell(
		plan,
		box(
			`Landing_{id}`,
			(lx1 + lx2) / 2,
			yMid - 0.5,
			(z1 + z2) / 2,
			lx2 - lx1,
			1,
			z2 - z1 - 2 * WALL_T,
			"Floor",
			true
		)
	)
	-- keep the shaft free of props
	table.insert(room.clear, { x1 = x1, z1 = z1, x2 = x2, z2 = z2 })
	local cTop = laneA
	local cBot = laneB
	local topSide = OPPOSITE[side]
	Kit.doorPair(plan, topId, topSide, id, side, cTop, yTop)
	Kit.doorPair(plan, bottomId, topSide, id, side, cBot, yBot)
	return room
end

-- Distinct visible prop in a room, placed toward a corner (fx, fz in [-1,1] of the half extents).
function Kit.landmark(
	plan: Plan,
	roomId: string,
	name: string,
	style: string,
	sx: number,
	sy: number,
	sz: number,
	fx: number,
	fz: number,
	light: Light?
): Box
	local room = plan.byId[roomId]
	local cx, cz = (room.x1 + room.x2) / 2, (room.z1 + room.z2) / 2
	local hx, hz =
		(room.x2 - room.x1) / 2 - sx / 2 - WALL_T - 1, (room.z2 - room.z1) / 2 - sz / 2 - WALL_T - 1
	local b = box(
		`Landmark_{roomId}`,
		cx + fx * hx,
		room.y + sy / 2,
		cz + fz * hz,
		sx,
		sy,
		sz,
		style,
		true
	)
	b.light = light
	room.landmark = name
	table.insert(room.clear, {
		x1 = b.x - sx / 2 - 1,
		z1 = b.z - sz / 2 - 1,
		x2 = b.x + sx / 2 + 1,
		z2 = b.z + sz / 2 + 1,
	})
	return Kit.shell(plan, b)
end

function Kit.chest(plan: Plan, roomId: string, fx: number, fz: number, depth: number)
	local room = plan.byId[roomId]
	local cx, cz = (room.x1 + room.x2) / 2, (room.z1 + room.z2) / 2
	local hx, hz = (room.x2 - room.x1) / 2 - 5, (room.z2 - room.z1) / 2 - 5
	local x, z = cx + fx * hx, cz + fz * hz
	room.depth = math.max(room.depth, depth)
	table.insert(plan.chests, { room = roomId, x = x, y = room.y, z = z, depth = depth })
	table.insert(room.clear, { x1 = x - 3, z1 = z - 3, x2 = x + 3, z2 = z + 3 })
end

local function blocked(room: Room, x: number, z: number, hx: number, hz: number): boolean
	for _, r in room.clear do
		if x + hx > r.x1 and x - hx < r.x2 and z + hz > r.z1 and z - hz < r.z2 then
			return true
		end
	end
	for _, r in room.holes do
		if x + hx > r.x1 and x - hx < r.x2 and z + hz > r.z1 and z - hz < r.z2 then
			return true
		end
	end
	return false
end

-- Scatter `count` props of the given kinds inside a room (never in doorways, ramps or holes).
function Kit.scatter(
	plan: Plan,
	rng: () -> number,
	roomId: string,
	count: number,
	kinds: { PropKind }
)
	local room = plan.byId[roomId]
	local inset = WALL_T + 2.5
	for i = 1, count do
		local kind = kinds[math.floor(rng() * #kinds) + 1]
		local scale = 0.8 + rng() * 0.4
		local sx, sy, sz = kind.sx * scale, kind.sy * scale, kind.sz * scale
		for _ = 1, 10 do
			local x = room.x1 + inset + rng() * (room.x2 - room.x1 - 2 * inset)
			local z = room.z1 + inset + rng() * (room.z2 - room.z1 - 2 * inset)
			local r = math.max(sx, sz) / 2 * 1.42 -- rotated footprint
			if not blocked(room, x, z, r, r) then
				local y = if kind.hang then room.y + room.height - sy / 2 - 0.5 else room.y + sy / 2
				local b =
					box(`{kind.name}_{roomId}_{i}`, x, y, z, sx, sy, sz, kind.style, kind.collide)
				b.ry = math.floor(rng() * 4) * 22.5
				b.light = kind.light
				b.fx = kind.fx
				table.insert(plan.dressing, { room = roomId, box = b })
				break
			end
		end
	end
end

-- Dressing at an exact spot (lit lanterns, fires).
function Kit.dressAt(plan: Plan, roomId: string, b: Box)
	table.insert(plan.dressing, { room = roomId, box = b })
end

-- Emits floors, roofs, walls, carves and water for every room. Call once after all rooms/doors exist.
function Kit.finish(plan: Plan)
	for _, room in plan.rooms do
		local id = room.id
		local top = room.y + room.wallH
		if room.floor then
			local pieces: { Rect } = { { x1 = room.x1, z1 = room.z1, x2 = room.x2, z2 = room.z2 } }
			for _, hole in room.holes do
				local nextPieces: { Rect } = {}
				for _, p in pieces do
					for _, q in subtract(p, hole) do
						table.insert(nextPieces, q)
					end
				end
				pieces = nextPieces
			end
			for i, p in pieces do
				Kit.shell(
					plan,
					box(
						`Floor_{id}_{i}`,
						(p.x1 + p.x2) / 2,
						room.y - 0.5,
						(p.z1 + p.z2) / 2,
						p.x2 - p.x1,
						Kit.SLAB,
						p.z2 - p.z1,
						room.floorStyle,
						true
					)
				)
			end
		end
		if room.roof then
			Kit.shell(
				plan,
				box(
					`Roof_{id}`,
					(room.x1 + room.x2) / 2,
					room.y + room.height + 0.5,
					(room.z1 + room.z2) / 2,
					room.x2 - room.x1,
					Kit.SLAB,
					room.z2 - room.z1,
					room.roofStyle,
					true
				)
			)
		end
		-- walls
		for _, side in { "N", "S", "W", "E" } do
			local alongX = side == "N" or side == "S"
			local lo = if alongX then room.x1 else room.z1 + WALL_T
			local hi = if alongX then room.x2 else room.z2 - WALL_T
			local fixed: number
			if side == "N" then
				fixed = room.z1 + WALL_T / 2
			elseif side == "S" then
				fixed = room.z2 - WALL_T / 2
			elseif side == "W" then
				fixed = room.x1 + WALL_T / 2
			else
				fixed = room.x2 - WALL_T / 2
			end
			local doors: { Door } = {}
			for _, d in room.doors do
				if d.side == side then
					table.insert(doors, d)
				end
			end
			table.sort(doors, function(a: Door, b: Door): boolean
				return a.c < b.c
			end)
			local count = 0
			local function wallBox(a: number, b: number, y0: number, y1: number)
				if b - a < 0.4 or y1 - y0 < 0.4 then
					return
				end
				count += 1
				local mid, len, ymid = (a + b) / 2, b - a, (y0 + y1) / 2
				local wb = if alongX
					then box(
						`Wall_{id}_{side}{count}`,
						mid,
						ymid,
						fixed,
						len,
						y1 - y0,
						WALL_T,
						room.wall,
						true
					)
					else box(
						`Wall_{id}_{side}{count}`,
						fixed,
						ymid,
						mid,
						WALL_T,
						y1 - y0,
						len,
						room.wall,
						true
					)
				Kit.shell(plan, wb)
			end
			local cursor = lo
			for _, d in doors do
				wallBox(cursor, d.c - d.width / 2, room.y, top)
				wallBox(d.c - d.width / 2, d.c + d.width / 2, room.y, d.y) -- under a raised sill
				wallBox(d.c - d.width / 2, d.c + d.width / 2, d.y + DOOR_H, top) -- lintel
				cursor = d.c + d.width / 2
			end
			wallBox(cursor, hi, room.y, top)
		end
		if room.underground and not room.tower then
			table.insert(
				plan.carves,
				box(
					`Carve_{id}`,
					(room.x1 + room.x2) / 2,
					room.y + room.height / 2,
					(room.z1 + room.z2) / 2,
					room.x2 - room.x1,
					room.height + 2,
					room.z2 - room.z1,
					"Air",
					false
				)
			)
		elseif room.tower then
			local yBot = room.y - 1
			local yTop = 3
			table.insert(
				plan.carves,
				box(
					`Carve_{id}`,
					(room.x1 + room.x2) / 2,
					(yBot + yTop) / 2,
					(room.z1 + room.z2) / 2,
					room.x2 - room.x1,
					yTop - yBot,
					room.z2 - room.z1,
					"Air",
					false
				)
			)
		end
		if room.flooded then
			local wb = box(
				`Water_{id}`,
				(room.x1 + room.x2) / 2,
				room.y + 0.8,
				(room.z1 + room.z2) / 2,
				room.x2 - room.x1 - 2 * WALL_T,
				1.6,
				room.z2 - room.z1 - 2 * WALL_T,
				"Water",
				false
			)
			Kit.shell(plan, wb)
		end
	end
end

-- Analysis ------------------------------------------------------------------------------------------------

-- Hop distance from the entrance room over links (unreachable rooms are absent).
function Kit.distances(plan: Plan): { [string]: number }
	local dist: { [string]: number } = {}
	if plan.byId[plan.entrance] == nil then
		return dist
	end
	dist[plan.entrance] = 0
	local queue = { plan.entrance }
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		for _, l in plan.links do
			local other: string? = nil
			if l[1] == cur then
				other = l[2]
			elseif l[2] == cur then
				other = l[1]
			end
			if other ~= nil and dist[other] == nil then
				dist[other] = dist[cur] + 1
				table.insert(queue, other)
			end
		end
	end
	return dist
end

function Kit.summary(plan: Plan): MassiveRules.PlanSummary
	local levels: { [number]: boolean } = {}
	local minY = 0
	local minCeil = math.huge
	local minWidth = math.huge
	for _, room in plan.rooms do
		levels[math.floor(room.y + 0.5)] = true
		minY = math.min(minY, room.y)
		if room.roof or not room.rail then
			minCeil = math.min(minCeil, room.height)
		end
		if not room.tower then
			minWidth = math.min(minWidth, room.x2 - room.x1, room.z2 - room.z1)
		end
	end
	for _, w in plan.rampWidths do
		minWidth = math.min(minWidth, w)
	end
	for _, room in plan.rooms do
		for _, d in room.doors do
			minWidth = math.min(minWidth, d.width)
		end
	end
	local count = 0
	for _ in levels do
		count += 1
	end
	local lights, particles = 0, 0
	for _, b in plan.shell do
		lights += if b.light then 1 else 0
		particles += if b.fx then 1 else 0
	end
	for _, d in plan.dressing do
		lights += if d.box.light then 1 else 0
		particles += if d.box.fx then 1 else 0
	end
	return {
		id = plan.id,
		footprintX = plan.footprintX,
		footprintZ = plan.footprintZ,
		rooms = #plan.rooms,
		levels = count,
		undergroundDepth = -minY,
		minCorridorWidth = minWidth,
		minCeilingHeight = minCeil,
		parts = #plan.shell,
		dressingParts = #plan.dressing,
		lights = lights,
		particles = particles,
	}
end

-- All rule violations for a finished plan (empty = good). Used by tests and the adapter's assert.
function Kit.problems(plan: Plan): { string }
	local errs = MassiveRules.validatePlan(Kit.summary(plan))
	local function bad(msg: string)
		table.insert(errs, msg)
	end
	local dist = Kit.distances(plan)
	local maxDist = 0
	for _, room in plan.rooms do
		if dist[room.id] == nil then
			bad(`room {room.id} unreachable from entrance`)
		else
			maxDist = math.max(maxDist, dist[room.id])
		end
	end
	if plan.entrance == "" then
		bad("no exterior entrance")
	end
	local seen: { [string]: boolean } = {}
	for _, room in plan.rooms do
		if room.landmark == "" or seen[room.landmark] then
			bad(`room {room.id} landmark missing or duplicated`)
		end
		seen[room.landmark] = true
		local found = false
		for _, b in plan.shell do
			if b.name == `Landmark_{room.id}` then
				found = true
			end
		end
		if not found and not room.tower then
			bad(`room {room.id} has no landmark prop`)
		end
		if room.underground and not room.tower and room.y + room.height + 1 > -0.5 then
			bad(`room {room.id} ceiling breaks the surface`)
		end
		if not room.rail and room.height < Config.Massive.CeilingHeightMin then
			bad(`room {room.id} ceiling low`)
		end
		for _, d in room.doors do
			if d.width < Config.Massive.DoorWidthMin or DOOR_H < Config.Massive.DoorHeightMin then
				bad(`room {room.id} door too small`)
			end
		end
	end
	for _, w in plan.rampWidths do
		if w < Config.Massive.StairWidthMin then
			bad("stair too narrow")
		end
	end
	-- chests: inside their room, valid tier, and the best chest sits in a deepest room
	local bestDepth, bestRoomDist = -1, -1
	for _, c in plan.chests do
		local room = plan.byId[c.room]
		if room == nil or c.x <= room.x1 or c.x >= room.x2 or c.z <= room.z1 or c.z >= room.z2 then
			bad("chest outside its room")
		elseif math.abs(c.y - room.y) > 0.01 then
			bad("chest not on its room floor") -- floor top = room.y (ChestArt pivots at the base)
		elseif c.depth < 0 or c.depth > Config.Loot.MaxDepthTier then
			bad("chest depth out of range")
		elseif c.depth > bestDepth then
			bestDepth = c.depth
			bestRoomDist = dist[c.room] or -1
		end
	end
	if #plan.chests == 0 then
		bad("no chests")
	elseif bestRoomDist < maxDist then
		bad("deepest chest is not in a deepest room")
	end
	for _, b in plan.shell do
		if b.sx <= 0 or b.sy <= 0 or b.sz <= 0 or math.max(b.sx, b.sy, b.sz) > 2048 then
			bad(`box {b.name} bad size`)
		end
	end
	return errs
end

local WARM: Light = { color = "Warm", range = 26, brightness = 1.1 }
local COLD: Light = { color = "Cold", range = 24, brightness = 0.9 }
local RUNE: Light = { color = "Rune", range = 22, brightness = 1 }

local function prop(
	name: string,
	style: string,
	sx: number,
	sy: number,
	sz: number,
	collide: boolean,
	light: Light?,
	fx: string?,
	hang: boolean?
): PropKind
	return {
		name = name,
		style = style,
		sx = sx,
		sy = sy,
		sz = sz,
		collide = collide,
		light = light,
		fx = fx,
		hang = hang,
	}
end

-- Shared dressing props (sizes are base size; scatter jitters them 0.8..1.2).
Kit.Props = {
	Barrel = prop("Barrel", "Wall", 2.5, 3, 2.5, true, nil, nil, nil),
	Crate = prop("Crate", "WallDark", 3, 3, 3, true, nil, nil, nil),
	Table = prop("Table", "Wall", 5, 2.6, 3, true, nil, nil, nil),
	Bench = prop("Bench", "WallDark", 5, 1.6, 1.4, true, nil, nil, nil),
	Bunk = prop("Bunk", "Blanket", 7, 1.4, 3, true, nil, nil, nil),
	Shelf = prop("Shelf", "WallDark", 5, 5, 1.5, true, nil, nil, nil),
	Cannon = prop("Cannon", "MetalDark", 6, 2.5, 2.5, true, nil, nil, nil),
	Rope = prop("Rope", "Wall", 2.4, 0.6, 2.4, false, nil, nil, nil),
	Planks = prop("Planks", "WallDark", 7, 0.5, 1.2, false, nil, nil, nil),
	IceShard = prop("IceShard", "Ice", 2, 5, 2, true, nil, nil, nil),
	Rubble = prop("Rubble", "Stone", 3, 1.5, 3, true, nil, nil, nil),
	Column = prop("Column", "Stone", 2.6, 9, 2.6, true, nil, nil, nil),
	FallenColumn = prop("FallenColumn", "Stone", 9, 2, 2.6, true, nil, nil, nil),
	Urn = prop("Urn", "StoneDark", 2, 3, 2, true, nil, nil, nil),
	Sarcophagus = prop("Sarcophagus", "Stone", 8, 3, 3.6, true, nil, nil, nil),
	Statue = prop("Statue", "StoneDark", 3, 8, 3, true, nil, nil, nil),
	Pew = prop("Pew", "StoneDark", 6, 1.8, 1.6, true, nil, nil, nil),
	Rug = prop("Rug", "Blanket", 8, 0.2, 5, false, nil, nil, nil),
	Mist = prop("Mist", "Cave", 4, 1, 4, false, nil, "Mist", nil),
	HangLantern = prop("HangLantern", "Lamp", 1, 1.4, 1, false, WARM, nil, true),
	ColdHangLantern = prop("ColdHangLantern", "Lamp", 1, 1.4, 1, false, COLD, nil, true),
	LampPost = prop("LampPost", "Lamp", 1, 6, 1, true, WARM, nil, nil),
	ColdLampPost = prop("ColdLampPost", "Lamp", 1, 6, 1, true, COLD, nil, nil),
	RuneStone = prop("RuneStone", "Rune", 1.6, 5, 1.6, true, RUNE, nil, nil),
}
Kit.Lights = { Warm = WARM, Cold = COLD, Rune = RUNE }

return Kit
