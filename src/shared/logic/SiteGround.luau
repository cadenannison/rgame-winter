--!strict
-- Pure terrain grounding for structures, POIs, camp and placeables (no Roblox APIs). Samples the FULL footprint
-- (grid incl. corners, edge midpoints and centre) from a height function (World.heightAt closure), decides
-- whether the site is usable (slope / range / cliff / water), picks one base height, and describes the blended
-- skirt so the server adapter can flatten terrain without a hard-edged pad. Also the shared "ground snap" used by
-- the server placement handler and the client ghost so a placed model never sits partly buried.

local Config = require("../Config")

export type HeightFn = (x: number, z: number) -> number
export type Offset = { x: number, z: number }
export type Sample = {
	cx: number,
	cz: number,
	halfX: number,
	halfZ: number,
	nx: number, -- grid points along X (odd, so the centre line is sampled)
	nz: number,
	heights: { number }, -- row-major: index = (iz - 1) * nx + ix
	min: number,
	max: number,
	median: number,
	range: number,
	slope: number, -- range / footprint diagonal
	maxJump: number, -- largest height difference between adjacent grid samples (cliff detector)
	waterFraction: number,
}
export type Plan = {
	ok: boolean,
	reason: string, -- "Ok" | "Water" | "Cliff" | "Range" | "Slope"
	mode: string, -- "level" (cut + fill at the median) | "foundation" (fill up to the highest) | "reject"
	baseY: number,
	cx: number,
	cz: number,
	halfX: number,
	halfZ: number,
	sample: Sample,
}

local SiteGround = {}

local function cfg(): Config.SiteGroundConfig
	return Config.SiteGround
end

-- Grid point count along one axis: step spacing, odd so corners, edges and the centre are all sampled.
local function axisCount(half: number, step: number): number
	local n = math.max(2, math.ceil(2 * half / step))
	if n % 2 == 1 then
		n += 1
	end
	return n + 1
end

function SiteGround.stats(heights: { number }): (number, number, number)
	local lo, hi = math.huge, -math.huge
	local sorted = table.clone(heights)
	table.sort(sorted)
	for _, h in heights do
		lo, hi = math.min(lo, h), math.max(hi, h)
	end
	local median = sorted[math.max(1, math.ceil(#sorted / 2))] or 0
	return lo, hi, median
end

-- Samples the axis-aligned footprint (centre cx, cz; half sizes) every Config.SiteGround.SampleStep.
function SiteGround.sample(
	heightFn: HeightFn,
	cx: number,
	cz: number,
	halfX: number,
	halfZ: number
): Sample
	local c = cfg()
	local nx, nz = axisCount(halfX, c.SampleStep), axisCount(halfZ, c.SampleStep)
	local heights: { number } = table.create(nx * nz, 0)
	for iz = 1, nz do
		local z = cz - halfZ + (iz - 1) / (nz - 1) * 2 * halfZ
		for ix = 1, nx do
			local x = cx - halfX + (ix - 1) / (nx - 1) * 2 * halfX
			heights[(iz - 1) * nx + ix] = heightFn(x, z)
		end
	end
	local lo, hi, median = SiteGround.stats(heights)
	local jump, water = 0, 0
	for iz = 1, nz do
		for ix = 1, nx do
			local h = heights[(iz - 1) * nx + ix]
			if h <= c.WaterHeight then
				water += 1
			end
			if ix < nx then
				jump = math.max(jump, math.abs(h - heights[(iz - 1) * nx + ix + 1]))
			end
			if iz < nz then
				jump = math.max(jump, math.abs(h - heights[iz * nx + ix]))
			end
		end
	end
	local diag = math.sqrt((2 * halfX) ^ 2 + (2 * halfZ) ^ 2)
	return {
		cx = cx,
		cz = cz,
		halfX = halfX,
		halfZ = halfZ,
		nx = nx,
		nz = nz,
		heights = heights,
		min = lo,
		max = hi,
		median = median,
		range = hi - lo,
		slope = if diag > 0 then (hi - lo) / diag else 0,
		maxJump = jump,
		waterFraction = water / (nx * nz),
	}
end

-- Decides what to do with a sampled site. Rejections: water, cliff edge, range above MaxRange, slope above
-- MaxSlope. Up to FillRange the terrain is levelled at the median; above that a foundation raises the low
-- side to the highest sample (the floor never sits under terrain).
function SiteGround.evaluate(s: Sample): Plan
	local c = cfg()
	local reason = "Ok"
	if s.waterFraction > c.MaxWaterFraction then
		reason = "Water"
	elseif s.maxJump > c.CliffStep then
		reason = "Cliff"
	elseif s.range > c.MaxRange then
		reason = "Range"
	elseif s.slope > c.MaxSlope then
		reason = "Slope"
	end
	local ok = reason == "Ok"
	local mode = if not ok then "reject" elseif s.range <= c.FillRange then "level" else "foundation"
	local baseY = if mode == "foundation" then s.max else s.median
	return {
		ok = ok,
		reason = reason,
		mode = mode,
		baseY = baseY,
		cx = s.cx,
		cz = s.cz,
		halfX = s.halfX,
		halfZ = s.halfZ,
		sample = s,
	}
end

function SiteGround.plan(
	heightFn: HeightFn,
	cx: number,
	cz: number,
	halfX: number,
	halfZ: number
): Plan
	return SiteGround.evaluate(SiteGround.sample(heightFn, cx, cz, halfX, halfZ))
end

-- Looks for a usable site at (cx, cz) and then on expanding rings (deterministic order, at most
-- RelocateAttempts candidates, within RelocateRadius). `accept` can veto a candidate (exclusion zones).
-- Returns the first ok plan, or nil.
function SiteGround.relocate(
	heightFn: HeightFn,
	cx: number,
	cz: number,
	halfX: number,
	halfZ: number,
	accept: ((x: number, z: number) -> boolean)?
): Plan?
	local c = cfg()
	local first = SiteGround.plan(heightFn, cx, cz, halfX, halfZ)
	if first.ok and (accept == nil or accept(cx, cz)) then
		return first
	end
	local rings = 3
	local perRing = math.max(1, math.ceil(c.RelocateAttempts / rings))
	local tried = 0
	for r = 1, rings do
		local radius = c.RelocateRadius * r / rings
		for k = 0, perRing - 1 do
			if tried >= c.RelocateAttempts then
				return nil
			end
			tried += 1
			local a = (k / perRing + (r - 1) * 0.5 / perRing) * 2 * math.pi
			local x, z = cx + math.cos(a) * radius, cz + math.sin(a) * radius
			if accept == nil or accept(x, z) then
				local p = SiteGround.plan(heightFn, x, z, halfX, halfZ)
				if p.ok then
					return p
				end
			end
		end
	end
	return nil
end

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Distance (studs) from a point to the plan's footprint rectangle; 0 inside.
function SiteGround.distanceOutside(plan: Plan, x: number, z: number): number
	local dx = math.max(math.abs(x - plan.cx) - plan.halfX, 0)
	local dz = math.max(math.abs(z - plan.cz) - plan.halfZ, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- Target terrain top at (x, z) given the original ground height there: the base height inside the footprint,
-- blending smoothly back to the original ground across SkirtWidth outside it (no hard edge).
function SiteGround.targetHeight(plan: Plan, ground: number, x: number, z: number): number
	local d = SiteGround.distanceOutside(plan, x, z)
	if d <= 0 then
		return plan.baseY
	end
	local skirt = cfg().SkirtWidth
	if d >= skirt then
		return ground
	end
	local t = smoothstep(d / skirt)
	return math.floor(plan.baseY + (ground - plan.baseY) * t + 0.5)
end

-- Local-space offsets (corners, edge midpoints, centre) of an XZ footprint rotated by rotRad: the ray origins
-- for grounding placeables. Deduplicated for zero-size footprints.
function SiteGround.footprintOffsets(sizeX: number, sizeZ: number, rotRad: number): { Offset }
	local hx, hz = sizeX / 2, sizeZ / 2
	local raw: { Offset } = {
		{ x = 0, z = 0 },
		{ x = -hx, z = -hz },
		{ x = hx, z = -hz },
		{ x = -hx, z = hz },
		{ x = hx, z = hz },
		{ x = 0, z = -hz },
		{ x = 0, z = hz },
		{ x = -hx, z = 0 },
		{ x = hx, z = 0 },
	}
	local cosA, sinA = math.cos(rotRad), math.sin(rotRad)
	local out: { Offset } = {}
	local seen: { [string]: boolean } = {}
	for _, o in raw do
		local x = o.x * cosA + o.z * sinA
		local z = -o.x * sinA + o.z * cosA
		local key = `{math.floor(x * 100 + 0.5)}:{math.floor(z * 100 + 0.5)}`
		if not seen[key] then
			seen[key] = true
			table.insert(out, { x = x, z = z })
		end
	end
	return out
end

-- Base Y of a placed model from the surface heights under its footprint: the highest hit plus SinkMargin,
-- so no corner is buried. nil when there is no hit.
function SiteGround.snapY(hits: { number }): number?
	if #hits == 0 then
		return nil
	end
	local top = -math.huge
	for _, h in hits do
		top = math.max(top, h)
	end
	return top + cfg().SinkMargin
end

-- Ground Y for a placeable centred at (x, z) with a footprint sizeX x sizeZ rotated rotationDeg: casts at every
-- footprint offset through `cast(x, z) -> surface Y?` (server and client ghost each pass their own raycast, so
-- both snap identically) and returns the highest surface + SinkMargin. nil when nothing is hit.
function SiteGround.snapGround(
	cast: (x: number, z: number) -> number?,
	x: number,
	z: number,
	sizeX: number,
	sizeZ: number,
	rotationDeg: number
): number?
	local hits: { number } = {}
	for _, o in SiteGround.footprintOffsets(sizeX, sizeZ, math.rad(rotationDeg)) do
		local y = cast(x + o.x, z + o.z)
		if y ~= nil then
			table.insert(hits, y)
		end
	end
	return SiteGround.snapY(hits)
end

return SiteGround
