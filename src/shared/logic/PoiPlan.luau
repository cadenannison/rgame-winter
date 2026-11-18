--!strict
-- Pure layouts for enterable structures (no Roblox APIs). A plan is a list of axis-aligned boxes in a local
-- frame: origin = floor top at the structure centre, +Y up, +Z = the front (doorway side). The server adapter
-- (server/World/PoiStructures) turns boxes into Parts; tests check the plan against Config.Shelter.
-- Variants are picked deterministically from (seed, poi id, kind, biome).

local Config = require("../Config")

local PoiPlan = {}

export type Box = {
	name: string,
	x: number, -- centre
	y: number, -- centre
	z: number,
	sx: number,
	sy: number,
	sz: number,
	rx: number?, -- degrees (visual boxes only)
	ry: number?,
	rz: number?,
	collide: boolean,
	style: string,
	light: { range: number, brightness: number, color: string }?,
}

export type Doorway = { x: number, width: number, height: number, z: number, thickness: number }

export type Plan = {
	kind: string,
	variant: string,
	boxes: { Box },
	enterable: boolean,
	interiorWidth: number,
	interiorDepth: number,
	ceiling: number,
	doorway: Doorway?, -- front wall opening (local x centre, z = wall centre)
	crate: { x: number, y: number, z: number }, -- y = surface the crate stands on
	hearth: { x: number, z: number }?,
	entry: { x: number, z: number, dx: number, dz: number, width: number }, -- where the apron starts
	radius: number, -- footprint radius incl. FootprintMargin (tree/camp exclusion)
	doorDistance: number, -- local +Z distance from centre to the point outside the door
	legacy: string?, -- "campsite": adapter also builds the WorldProps tent
	towerHeight: number?,
	apronSteps: number,
}

local S = Config.Shelter
local MOD = 4294967296
local FOUNDATION_TOP = 0.05 -- foundation top sits this far below the floor (no coplanar z-fight)

----------------------------------------------------------------------------------------------------
-- Variants
----------------------------------------------------------------------------------------------------

local VARIANTS: { [string]: { [string]: { string } } } = {
	cabin = {
		default = { "LogCabin", "Lodge", "Trapper" },
		SnowyForest = { "LogCabin", "Lodge", "Trapper" },
		FrozenLake = { "Lodge", "LogCabin" },
		MountainsCaves = { "Trapper", "LogCabin" },
		DeepTundra = { "Trapper", "Lodge" },
	},
	plane = {
		default = { "Airliner", "Cargo" },
		MountainsCaves = { "Cargo", "Airliner" },
	},
	cave = {
		default = { "Cavern", "Grotto" },
	},
	ruin = {
		default = { "Vault", "TwinChambers" },
		DeepTundra = { "TwinChambers", "Vault" },
	},
	campsite = {
		default = { "Tent", "Watchtower" },
		SnowyForest = { "Tent", "Watchtower", "Tent" },
		DeepTundra = { "Watchtower", "Tent" },
	},
}

PoiPlan.EnterableKinds = { "cabin", "plane", "cave", "ruin", "campsite" }

function PoiPlan.variantIds(kind: string, biome: string): { string }
	local byBiome = VARIANTS[kind]
	if byBiome == nil then
		return {}
	end
	return byBiome[biome] or byBiome.default
end

-- Every variant id of a kind (union over biomes, stable order).
function PoiPlan.allVariants(kind: string): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	local byBiome = VARIANTS[kind]
	if byBiome == nil then
		return out
	end
	local names: { string } = {}
	for name in byBiome do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		for _, id in byBiome[name] do
			if not seen[id] then
				seen[id] = true
				table.insert(out, id)
			end
		end
	end
	return out
end

local function hashString(s: string): number
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % MOD
	end
	return h
end

-- Deterministic: same (seed, id, kind, biome) always gives the same variant.
function PoiPlan.pickVariant(seed: number, poiId: string, kind: string, biome: string): string
	local list = PoiPlan.variantIds(kind, biome)
	if #list == 0 then
		return ""
	end
	local h = (hashString(poiId) * 1664525 + seed * 40503 + hashString(kind)) % MOD
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = (h * 69069 + 12345) % MOD
	h = bit32.bxor(h, bit32.rshift(h, 13))
	return list[h % #list + 1]
end

----------------------------------------------------------------------------------------------------
-- Box helpers (y0 = bottom of the box)
----------------------------------------------------------------------------------------------------

local function add(
	out: { Box },
	name: string,
	x: number,
	y0: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	style: string,
	collide: boolean,
	extra: {
		rx: number?,
		ry: number?,
		rz: number?,
		light: { range: number, brightness: number, color: string }?,
	}?
): Box
	local b: Box = {
		name = name,
		x = x,
		y = y0 + sy / 2,
		z = z,
		sx = sx,
		sy = sy,
		sz = sz,
		collide = collide,
		style = style,
	}
	if extra then
		b.rx, b.ry, b.rz, b.light = extra.rx, extra.ry, extra.rz, extra.light
	end
	table.insert(out, b)
	return b
end

local function warmLight(): { range: number, brightness: number, color: string }
	return { range = S.InteriorLightRange, brightness = S.InteriorLightBrightness, color = "Warm" }
end

type RoomOpts = {
	iw: number,
	id: number,
	h: number,
	t: number,
	dw: number,
	dh: number,
	doorX: number?,
	wall: string,
	floor: string,
	roof: string,
	partitionZ: number?, -- interior z of an internal wall with a doorway
	snow: boolean?,
}

-- Walled room with a floor, a roof, and an open doorway in the +Z wall.
local function room(out: { Box }, o: RoomOpts)
	local iw, id, h, t = o.iw, o.id, o.h, o.t
	local ow, od = iw + 2 * t, id + 2 * t
	local doorX = o.doorX or 0
	add(out, "Floor", 0, -0.5, 0, ow, 0.5, od, o.floor, true)
	add(out, "WallBack", 0, 0, -(id / 2 + t / 2), ow, h, t, o.wall, true)
	add(out, "WallLeft", -(iw / 2 + t / 2), 0, 0, t, h, id, o.wall, true)
	add(out, "WallRight", iw / 2 + t / 2, 0, 0, t, h, id, o.wall, true)
	local fz = id / 2 + t / 2
	local leftEdge, rightEdge = doorX - o.dw / 2, doorX + o.dw / 2
	local lw = leftEdge - (-ow / 2)
	local rw = ow / 2 - rightEdge
	if lw > 0.01 then
		add(out, "FrontLeft", -ow / 2 + lw / 2, 0, fz, lw, h, t, o.wall, true)
	end
	if rw > 0.01 then
		add(out, "FrontRight", ow / 2 - rw / 2, 0, fz, rw, h, t, o.wall, true)
	end
	if h - o.dh > 0.01 then
		add(out, "Lintel", doorX, o.dh, fz, o.dw, h - o.dh, t, o.wall, true)
	end
	add(out, "Roof", 0, h, 0, ow + 1.2, 0.8, od + 1.2, o.roof, true)
	if o.snow ~= false then
		add(out, "RoofSnow", 0, h + 0.8, 0, ow + 0.6, 0.6, od + 0.6, "Snow", false)
	end
	local pz = o.partitionZ
	if pz then
		local pw = (iw - 5) / 2
		add(out, "PartitionL", -(iw / 2 - pw / 2), 0, pz, pw, h, 1, o.wall, true)
		add(out, "PartitionR", iw / 2 - pw / 2, 0, pz, pw, h, 1, o.wall, true)
		add(out, "PartitionLintel", 0, o.dh, pz, 5, h - o.dh, 1, o.wall, true)
	end
end

-- Door leaf swung open against the inside of the front wall (visual only: no scripted doors).
local function openDoorLeaf(out: { Box }, o: RoomOpts)
	local doorX = o.doorX or 0
	add(
		out,
		"DoorLeaf",
		doorX + o.dw / 2 + 1.1,
		0,
		o.id / 2 - 0.2,
		2.2,
		o.dh - 0.4,
		0.3,
		"WallDark",
		false
	)
end

local function windowPane(
	out: { Box },
	name: string,
	x: number,
	y0: number,
	z: number,
	onX: boolean
)
	if onX then
		add(out, name, x, y0, z, 0.3, 1.8, 1.8, "Window", false)
	else
		add(out, name, x, y0, z, 1.8, 1.8, 0.3, "Window", false)
	end
end

----------------------------------------------------------------------------------------------------
-- Per-kind builders. Each returns the partial plan fields.
----------------------------------------------------------------------------------------------------

type Partial = {
	boxes: { Box },
	iw: number,
	id: number,
	h: number,
	doorway: Doorway?,
	crate: { x: number, y: number, z: number },
	hearth: { x: number, z: number }?,
	outerW: number,
	outerD: number,
	entry: { x: number, z: number, dx: number, dz: number, width: number },
	legacy: string?,
	towerHeight: number?,
}

local function roomPartial(o: RoomOpts, boxes: { Box }): Partial
	local ow, od = o.iw + 2 * o.t, o.id + 2 * o.t
	return {
		boxes = boxes,
		iw = o.iw,
		id = o.id,
		h = o.h,
		doorway = {
			x = o.doorX or 0,
			width = o.dw,
			height = o.dh,
			z = o.id / 2 + o.t / 2,
			thickness = o.t,
		},
		crate = { x = 0, y = 0, z = 0 },
		outerW = ow,
		outerD = od,
		entry = {
			x = o.doorX or 0,
			z = od / 2,
			dx = 0,
			dz = 1,
			width = math.max(o.dw + 2, S.StairWidth),
		},
	}
end

local function cabin(variant: string): Partial
	local out: { Box } = {}
	local o: RoomOpts = {
		iw = S.InteriorWidth,
		id = S.InteriorDepth,
		h = S.CeilingHeight,
		t = S.WallThickness,
		dw = S.DoorWidth,
		dh = S.DoorHeight,
		wall = "Wall",
		floor = "Floor",
		roof = "Roof",
	}
	if variant == "Lodge" then
		o.iw = S.InteriorWidth + 4
	elseif variant == "Trapper" then
		o.id = S.InteriorDepth + 2
		o.h = S.CeilingHeight + 1
	end
	room(out, o)
	openDoorLeaf(out, o)
	local iw, id = o.iw, o.id
	local backZ = -id / 2
	-- bed (frame collides, blanket does not) in the back-left corner
	add(out, "BedFrame", -iw / 2 + 2.6, 0, backZ + 4, 4, 1, 7, "WallDark", true)
	add(out, "Blanket", -iw / 2 + 2.6, 1, backZ + 4.6, 3.6, 0.3, 5, "Blanket", false)
	add(out, "Pillow", -iw / 2 + 2.6, 1, backZ + 1.3, 3, 0.4, 1.2, "Pillow", false)
	if variant == "Lodge" then
		add(out, "BedFrame2", -iw / 2 + 2.6, 0, backZ + 12, 4, 1, 7, "WallDark", true)
		add(out, "Blanket2", -iw / 2 + 2.6, 1, backZ + 12.6, 3.6, 0.3, 5, "Blanket", false)
		add(out, "TableTop", iw / 2 - 3, 2.4, 0, 4, 0.4, 4, "Wall", true)
		add(out, "TableLegA", iw / 2 - 4.6, 0, -1.6, 0.5, 2.4, 0.5, "WallDark", true)
		add(out, "TableLegB", iw / 2 - 1.4, 0, 1.6, 0.5, 2.4, 0.5, "WallDark", true)
	end
	-- lit interior: warm lamp under the ridge
	add(out, "Lamp", 0, o.h - 1, 0, 0.8, 0.8, 0.8, "Lamp", false, { light = warmLight() })
	-- windows (visual panes on the outer faces) and chimney
	windowPane(out, "WindowL", -(iw / 2 - 2.5), 3.4, id / 2 + 0.65, false)
	windowPane(out, "WindowR", iw / 2 - 2.5, 3.4, id / 2 + 0.65, false)
	windowPane(out, "WindowSide", iw / 2 + 0.65, 3.4, 1, true)
	add(out, "Chimney", 0, o.h, backZ - 0.2, 3, 5, 2, "StoneDark", false)
	add(out, "Firewood", -(iw / 2 - 1), 0, id / 2 + 2.2, 3.2, 1.6, 1.4, "Wall", true)
	if variant == "Trapper" then
		-- covered porch (posts clear of the doorway)
		add(out, "PorchPostL", -3.8, 0, id / 2 + 3.5, 0.8, 8.5, 0.8, "WallDark", true)
		add(out, "PorchPostR", 3.8, 0, id / 2 + 3.5, 0.8, 8.5, 0.8, "WallDark", true)
		add(out, "PorchRoof", 0, 8.5, id / 2 + 2.6, 9, 0.6, 4.6, "Roof", true)
	end
	local p = roomPartial(o, out)
	p.crate = { x = iw / 2 - 2.2, y = 0, z = backZ + 2.4 }
	p.hearth = { x = 0, z = backZ + 2.6 }
	return p
end

local function plane(variant: string): Partial
	local out: { Box } = {}
	local cargo = variant == "Cargo"
	local o: RoomOpts = {
		iw = if cargo then 10 else S.NarrowInteriorWidth,
		id = if cargo then 22 else 26,
		h = if cargo then 9 else S.NarrowCeilingHeight,
		t = 0.6,
		dw = if cargo then 10 else S.NarrowInteriorWidth,
		dh = if cargo then 8 else S.NarrowCeilingHeight - 1,
		wall = "Metal",
		floor = "MetalDark",
		roof = "Metal",
		snow = true,
	}
	room(out, o)
	local iw, id = o.iw, o.id
	local backZ = -id / 2
	-- cockpit glass on the nose wall, torn wing stubs, scorch at the tail break
	add(out, "Cockpit", 0, 3, backZ + 0.1, iw - 2, 2, 0.2, "Glass", false)
	add(out, "WingL", -(iw / 2 + 5), 1.4, 1, 10, 0.6, 4.4, "MetalDark", false, { rz = 6 })
	add(out, "WingR", iw / 2 + 3.2, 1.6, 1, 6, 0.6, 4.4, "MetalDark", false, { rz = -22 })
	add(out, "Scorch", 0, 0, id / 2 + 9, 12, 0.1, 18, "Scorch", false)
	add(out, "Engine", -(iw / 2 + 7), 0, id / 2 - 2, 2.4, 2.4, 3, "MetalDark", true, { ry = 20 })
	add(out, "TailFin", iw / 2 + 5, 0, id / 2 + 4, 0.6, 5, 3.6, "Tent", false, { rz = 80 })
	if cargo then
		add(out, "CargoA", -iw / 2 + 1.6, 0, backZ + 2.5, 3, 3, 3, "Wall", true)
		add(out, "CargoB", -iw / 2 + 1.6, 0, backZ + 6, 3, 3, 3, "WallDark", true)
		add(out, "CargoC", -iw / 2 + 1.6, 3, backZ + 2.5, 2.6, 2.6, 2.6, "Wall", true)
		add(out, "CargoD", iw / 2 - 1.6, 0, 0, 3, 3, 3, "WallDark", true)
	else
		for i = 0, 3 do
			local z = backZ + 3 + i * 4
			add(out, `SeatL{i}`, -iw / 2 + 0.9, 0, z, 1.4, 1.2, 1.4, "TentAlt", true)
			add(out, `SeatR{i}`, iw / 2 - 0.9, 0, z, 1.4, 1.2, 1.4, "TentAlt", true)
		end
	end
	add(out, "Lamp", 0, o.h - 0.8, backZ + 5, 0.7, 0.4, 0.7, "Lamp", false, {
		light = {
			range = S.InteriorLightRange - 4,
			brightness = S.InteriorLightBrightness * 0.7,
			color = "Cold",
		},
	})
	local p = roomPartial(o, out)
	p.crate = { x = 0, y = 0, z = backZ + 2 }
	return p
end

local function cave(variant: string): Partial
	local out: { Box } = {}
	local grotto = variant == "Grotto"
	local o: RoomOpts = {
		iw = if grotto then 16 else S.InteriorWidth,
		id = if grotto then 16 else 22,
		h = if grotto then 11 else 10,
		t = 3,
		dw = 8,
		dh = 8,
		wall = "Rock",
		floor = "CaveFloor",
		roof = "RockDark",
		snow = true,
	}
	room(out, o)
	local iw, id = o.iw, o.id
	local backZ = -id / 2
	-- crags and boulders (visual) so the shell reads as a cave mouth
	add(out, "CragA", -3, o.h + 1.4, -1, 7, 4, 6, "RockDark", false, { ry = 25, rz = 6 })
	add(out, "CragB", 4, o.h + 1.4, 2, 5, 3.4, 5, "Rock", false, { ry = -30, rz = -8 })
	add(out, "BoulderL", -(iw / 2 + 5), 0, id / 2 + 3, 4, 3, 4, "Rock", true)
	add(out, "BoulderR", iw / 2 + 5, 0, id / 2 + 3, 3.4, 2.4, 3.4, "RockDark", true)
	if grotto then
		add(out, "Pillar", 0, 0, -1, 3, o.h, 3, "Rock", true)
	end
	-- dim crystal glow keeps the depth readable but dark
	add(out, "CrystalA", -iw / 2 + 1.4, 0, backZ + 2, 1.2, 3.4, 1.2, "Crystal", false, {
		rz = 8,
		light = { range = 16, brightness = 0.9, color = "Rune" },
	})
	add(out, "CrystalB", iw / 2 - 1.4, 0, backZ + 5, 1, 2.6, 1, "Crystal", false, { rz = -10 })
	add(out, "CrystalC", -iw / 2 + 1.2, 0, id / 2 - 2, 1, 2.2, 1, "Crystal", false, { rz = 12 })
	local p = roomPartial(o, out)
	p.crate = { x = 0, y = 0, z = backZ + 2.4 }
	return p
end

local function ruin(variant: string): Partial
	local out: { Box } = {}
	local twin = variant == "TwinChambers"
	local o: RoomOpts = {
		iw = S.InteriorWidth,
		id = if twin then 29 else S.InteriorDepth,
		h = S.CeilingHeight,
		t = 1.5,
		dw = S.DoorWidth,
		dh = S.DoorHeight,
		wall = "Stone",
		floor = "StoneDark",
		roof = "StoneDark",
		snow = true,
		partitionZ = if twin then 0 else nil,
	}
	room(out, o)
	local iw, id = o.iw, o.id
	local backZ = -id / 2
	-- pillars flank the back of each chamber; rune tile glows faintly (no lamps: ruins are dark)
	add(out, "PillarA", -iw / 2 + 2, 0, backZ + 2, 2, o.h, 2, "StoneDark", true)
	add(out, "PillarB", iw / 2 - 2, 0, backZ + 2, 2, o.h, 2, "StoneDark", true)
	add(out, "RuneTile", 0, 0, backZ + 7, 5, 0.12, 3, "StoneDark", false)
	add(out, "RuneGlow", 0, 0.12, backZ + 7, 4, 0.1, 0.4, "Rune", false)
	add(out, "Fallen", -iw / 2 - 5, 0, id / 2 + 2, 9, 2.4, 2.4, "Stone", true, { ry = 25 })
	add(out, "RubbleA", iw / 2 + 4, 0, id / 2 + 1, 2.4, 1.4, 2, "Stone", true, { ry = 40 })
	local p = roomPartial(o, out)
	p.crate = { x = 0, y = 0, z = backZ + 2.4 }
	return p
end

-- Watchtower: four stair flights spiral round a square deck; climb with no jumping. The deck, rails, roof
-- and posts sit on a foundation; the loot crate stands on the deck.
local function watchtower(): Partial
	local out: { Box } = {}
	local flights = 4
	local sw = S.StairWidth
	local run = S.StairRun
	local total = math.ceil(S.WatchtowerHeight / S.StairRise)
	local n = math.ceil(total / flights) -- steps per flight
	local rise = S.WatchtowerHeight / (n * flights)
	local height = n * flights * rise
	local c = math.max(S.WatchtowerPlatformSize, n * run) / 2 -- deck half size
	local mid = c + sw / 2
	local tread = 0.6
	-- deck
	add(out, "Deck", 0, height - 1, 0, 2 * c, 1, 2 * c, "Floor", true)
	-- tread positions per side (S: +z, W: -x, N: -z, E: +x), each flight runs round the deck
	local function stepPos(flight: number, i: number): (number, number, number, number)
		local along = c - (i - 0.5) * run
		if flight == 1 then
			return along, mid, run, sw
		elseif flight == 2 then
			return -mid, along, sw, run
		elseif flight == 3 then
			return -along, -mid, run, sw
		end
		return mid, -along, sw, run
	end
	for f = 1, flights do
		for i = 1, n do
			local x, z, sx, sz = stepPos(f, i)
			local top = ((f - 1) * n + i) * rise
			add(out, `Step{f}_{i}`, x, top - tread, z, sx, tread, sz, "Wall", true)
		end
	end
	for f = 1, 3 do
		local top = f * n * rise
		local x = if f == 1 or f == 2 then -mid else mid -- SW, NW, NE corners
		local z = if f == 1 then mid else -mid
		add(out, `Landing{f}`, x, top - tread, z, sw, tread, sw, "Floor", true)
		add(
			out,
			`LandingPost{f}`,
			x + (if x < 0 then -sw / 2 + 0.5 else sw / 2 - 0.5),
			0,
			z + (if z < 0 then -sw / 2 + 0.5 else sw / 2 - 0.5),
			1,
			top - tread,
			1,
			"WallDark",
			true
		)
	end
	-- stringers (visual): one inclined beam under each flight
	local theta = math.deg(math.atan2(rise, run))
	local flen = math.sqrt((n * run) ^ 2 + (n * rise) ^ 2)
	for f = 1, flights do
		local x, z = stepPos(f, (n + 1) / 2)
		local top = ((f - 1) * n + (n + 1) / 2) * rise - tread - 0.5
		local sx, sz =
			if f == 1 or f == 3 then flen else 0.5, if f == 1 or f == 3 then 0.5 else flen
		local extra = if f == 1
			then { rz = -theta }
			elseif f == 2 then { rx = theta }
			elseif f == 3 then { rz = theta }
			else { rx = -theta }
		add(out, `Stringer{f}`, x, top, z, sx, 0.5, sz, "WallDark", false, extra)
	end
	-- legs, rails (east rail leaves the top step open), roof
	for _, sxn in { -1, 1 } do
		for _, szn in { -1, 1 } do
			add(out, "Leg", sxn * (c - 0.5), 0, szn * (c - 0.5), 1, height - 1, 1, "WallDark", true)
		end
	end
	local railH = S.WatchtowerRailHeight
	add(out, "RailN", 0, height, -c + 0.2, 2 * c, railH, 0.4, "Wall", true)
	add(out, "RailS", 0, height, c - 0.2, 2 * c, railH, 0.4, "Wall", true)
	add(out, "RailW", -c + 0.2, height, 0, 0.4, railH, 2 * c, "Wall", true)
	local eastLen = 2 * c - 3
	add(out, "RailE", c - 0.2, height, -c + eastLen / 2, 0.4, railH, eastLen, "Wall", true)
	local roofY = height + S.CeilingHeight
	add(
		out,
		"RoofPostA",
		-(c - 0.5),
		height,
		-(c - 0.5),
		0.8,
		S.CeilingHeight,
		0.8,
		"WallDark",
		true
	)
	add(out, "RoofPostB", c - 0.5, height, -(c - 0.5), 0.8, S.CeilingHeight, 0.8, "WallDark", true)
	add(out, "RoofPostC", -(c - 0.5), height, c - 0.5, 0.8, S.CeilingHeight, 0.8, "WallDark", true)
	add(out, "Roof", 0, roofY, 0, 2 * c + 2, 0.8, 2 * c + 2, "Roof", true)
	add(out, "RoofSnow", 0, roofY + 0.8, 0, 2 * c + 1, 0.6, 2 * c + 1, "Snow", false)
	add(out, "Lamp", 0, roofY - 1, 0, 0.8, 0.8, 0.8, "Lamp", false, { light = warmLight() })
	local outer = 2 * (c + sw)
	return {
		boxes = out,
		iw = 2 * c,
		id = 2 * c,
		h = S.CeilingHeight,
		doorway = nil,
		crate = { x = -c / 2, y = height, z = -c / 2 },
		hearth = nil,
		outerW = outer,
		outerD = outer,
		entry = { x = mid, z = c + sw, dx = 0, dz = 1, width = sw },
		towerHeight = height,
	}
end

local function tent(): Partial
	return {
		boxes = {},
		iw = 0,
		id = 0,
		h = 0,
		doorway = nil,
		crate = { x = 5, y = 0, z = 3 },
		outerW = 18,
		outerD = 18,
		entry = { x = 0, z = 9, dx = 0, dz = 1, width = S.StairWidth },
		legacy = "campsite",
	}
end

local function partialFor(kind: string, variant: string): Partial?
	if kind == "cabin" then
		return cabin(variant)
	elseif kind == "plane" then
		return plane(variant)
	elseif kind == "cave" then
		return cave(variant)
	elseif kind == "ruin" then
		return ruin(variant)
	elseif kind == "campsite" then
		if variant == "Watchtower" then
			return watchtower()
		end
		return tent()
	end
	return nil
end

-- Plan for a structure. drop = how far the floor sits above the terrain at the entry (studs, >= 0):
-- entry steps bridge it. depth = how far the foundation reaches below the floor (covers terrain variation).
function PoiPlan.build(kind: string, variant: string, drop: number, depth: number): Plan?
	local p = partialFor(kind, variant)
	if p == nil then
		return nil
	end
	local boxes = p.boxes
	local m = S.FoundationMargin
	local porch = if p.doorway then 3 else 0
	local fdepth = math.max(depth, 2)
	add(
		boxes,
		"Foundation",
		0,
		-fdepth - FOUNDATION_TOP,
		porch / 2,
		p.outerW + 2 * m,
		fdepth,
		p.outerD + 2 * m + porch,
		"Foundation",
		true
	)
	-- entry steps descending from the foundation edge to the terrain
	local steps = 0
	if drop > 0.5 then
		steps = math.min(S.MaxApronSteps, math.ceil(drop / S.StairRise))
		local rise = drop / steps
		local z0 = p.outerD / 2 + m + porch
		if p.towerHeight then
			z0 = p.entry.z + m
		end
		for i = 1, steps do
			add(
				boxes,
				`Entry{i}`,
				p.entry.x,
				-i * rise - 2,
				z0 + (i - 0.5) * S.StairRun,
				p.entry.width,
				2,
				S.StairRun,
				"Foundation",
				true
			)
		end
	end
	local radius = 0
	for _, b in boxes do
		if b.name ~= "Foundation" and not string.find(b.name, "^Entry") then
			local rx = math.abs(b.x) + b.sx / 2
			local rz = math.abs(b.z) + b.sz / 2
			radius = math.max(radius, math.sqrt(rx * rx + rz * rz))
		end
	end
	radius = math.max(radius, math.sqrt((p.outerW / 2 + m) ^ 2 + (p.outerD / 2 + m + porch) ^ 2))
	local frontEdge = p.outerD / 2 + m + porch
	if p.towerHeight then
		frontEdge = p.entry.z + m
	end
	return {
		kind = kind,
		variant = variant,
		boxes = boxes,
		enterable = p.doorway ~= nil or p.towerHeight ~= nil,
		interiorWidth = p.iw,
		interiorDepth = p.id,
		ceiling = p.h,
		doorway = p.doorway,
		crate = p.crate,
		hearth = p.hearth,
		entry = p.entry,
		radius = math.ceil(radius) + S.FootprintMargin,
		doorDistance = frontEdge + 3,
		legacy = p.legacy,
		towerHeight = p.towerHeight,
		apronSteps = steps,
	}
end

-- Largest footprint radius over all variants of a kind (what tree/camp exclusion should use).
function PoiPlan.kindFootprint(kind: string): number
	local worst = 0
	for _, variant in PoiPlan.allVariants(kind) do
		local plan = PoiPlan.build(kind, variant, 0, 0)
		if plan then
			worst = math.max(worst, plan.radius)
		end
	end
	return worst
end

-- Footprint radius for kinds that are not enterable (props): fixed small circles.
PoiPlan.PropFootprints = { hotspring = 14, thinice = 0 } :: { [string]: number }

----------------------------------------------------------------------------------------------------
-- Site: height sampling and orientation (heightFn = World.heightAt closure)
----------------------------------------------------------------------------------------------------

-- Highest and lowest terrain Y over a square of half-size `radius` (sampled every Terrain.BlockSize).
-- The floor goes at the highest so terrain never rises through the interior; the foundation fills the rest.
function PoiPlan.siteFloor(
	heightFn: (number, number) -> number,
	cx: number,
	cz: number,
	radius: number
): (number, number)
	local step = Config.Terrain.BlockSize
	local hi, lo = -math.huge, math.huge
	local n = math.ceil(radius / step)
	for i = -n, n do
		for j = -n, n do
			local x, z = cx + i * step, cz + j * step
			if (x - cx) ^ 2 + (z - cz) ^ 2 <= (radius + step) ^ 2 then
				local h = heightFn(x, z)
				hi = math.max(hi, h)
				lo = math.min(lo, h)
			end
		end
	end
	return hi, lo
end

-- Door direction of yaw index k (0..3): local +Z in world XZ.
function PoiPlan.doorDirection(k: number): (number, number)
	local a = (k % 4) * math.pi / 2
	return math.floor(math.sin(a) + 0.5), math.floor(math.cos(a) + 0.5)
end

-- Picks the cardinal yaw whose door faces the lowest ground (shortest entry stair); ties go to `pref`.
function PoiPlan.chooseYaw(
	heightFn: (number, number) -> number,
	cx: number,
	cz: number,
	doorDistance: number,
	pref: number
): number
	local best, bestH = pref % 4, math.huge
	for off = 0, 3 do
		local k = (pref + off) % 4
		local dx, dz = PoiPlan.doorDirection(k)
		local h = heightFn(cx + dx * doorDistance, cz + dz * doorDistance)
		if h < bestH then
			best, bestH = k, h
		end
	end
	return best
end

return PoiPlan
