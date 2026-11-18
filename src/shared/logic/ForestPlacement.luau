--!strict
-- Pure, deterministic tree placement for one chunk (no Roblox APIs). Trees are packed by rejection
-- sampling: thick around the camp (Config.Forest bands), a small clearing at the fire and spawn pad,
-- none on POIs or other slots, mixed size classes (some giants), Y from World.heightAt.

local Config = require("../Config")
local PoiPlan = require("./PoiPlan")
local TreeRules = require("./TreeRules")
local World = require("./World")
local WorldLayout = require("./WorldLayout")

local ForestPlacement = {}

export type Vec2 = { x: number, z: number }
export type Clear = { x: number, z: number, r: number? } -- exclusion circle (r nil = Forest.PoiClearRadius)

export type Params = {
	seed: number, -- world seed (heightAt) mixed into the placement rng
	chunkIndex: number,
	center: Vec2,
	size: number, -- chunk side in studs
	ring: number, -- 0-based biome ring
	camp: Vec2?, -- camp fire position (clearing, density bands, terrain flat centre)
	isCampChunk: boolean,
	pois: { Clear }, -- POI / fire centres to keep clear (r = PoiPlan.kindFootprint for enterable POIs)
	blocked: { Vec2 }, -- other slot positions (rocks, ore, food, spawn zones)
}

export type Tree = {
	x: number,
	y: number, -- ground height at (x, z)
	z: number,
	classIndex: number,
	classId: string,
	height: number,
	foliageBottom: number, -- lowest foliage Y above ground (>= TreeRules.minCanopyBottom())
	trunkRadius: number,
	canopyRadius: number,
	yaw: number,
}

local CELL = 20 -- spatial hash cell (neighbour search spans max MinSpacing)

-- Trees this chunk should hold (before rejection); the camp chunk gets the bonus.
function ForestPlacement.targetCount(ring: number, isCampChunk: boolean): number
	local F = Config.Forest
	local density = F.RingDensity[math.clamp(ring + 1, 1, #F.RingDensity)] or 1
	local n = math.floor(F.TreesPerChunk * density + 0.5)
	if isCampChunk then
		n += F.CampBonusTrees
	end
	return n
end

-- Radius around the camp fire that stays tree free (fire clearing plus the spawn pad beside it).
function ForestPlacement.campClearRadius(): number
	local F = Config.Forest
	return math.max(F.FireClearRadius, Config.World.CampSpawnOffset + F.SpawnClearRadius)
end

-- Relative density at a distance from camp (1 = base).
function ForestPlacement.densityAt(distFromCamp: number): number
	local F = Config.Forest
	if distFromCamp < ForestPlacement.campClearRadius() then
		return 0
	elseif distFromCamp < F.NearCampRadius then
		return F.NearCampDensity
	elseif distFromCamp < F.CampEdgeRadius then
		return F.CampEdgeDensity
	end
	return 1
end

local NEIGHBOUR_REACH = 1.01 -- chunk sizes: the chunk itself plus its 8 neighbours
local footprints: { [string]: number } = {}

-- Exclusion radius for a POI kind: structure footprint (cached) or the prop footprint; 0 = none known.
local function footprint(kind: string): number
	local cached = footprints[kind]
	if cached == nil then
		cached = PoiPlan.PropFootprints[kind] or PoiPlan.kindFootprint(kind)
		footprints[kind] = cached
	end
	return cached
end

-- POIs of `chunk` and its neighbours (a plane or ruin footprint can cross a chunk border), each cleared
-- by its structure footprint (PoiPlan.kindFootprint) instead of the flat Forest.PoiClearRadius default
-- (still used for kinds with no footprint, e.g. thin ice).
function ForestPlacement.poiClears(
	layout: WorldLayout.Layout,
	chunk: WorldLayout.Chunk,
	extra: { Clear }? -- massive structure footprints (MassivePlacement.clears)
): { Clear }
	local out: { Clear } = {}
	if extra then
		for _, c in extra do
			table.insert(out, c)
		end
	end
	local reach = layout.chunkSize * NEIGHBOUR_REACH
	for _, other in layout.chunks do
		if
			math.abs(other.center.x - chunk.center.x) <= reach
			and math.abs(other.center.z - chunk.center.z) <= reach
		then
			for _, poi in other.pois do
				local r = footprint(poi.kind)
				table.insert(
					out,
					{ x = poi.position.x, z = poi.position.z, r = if r > 0 then r else nil }
				)
			end
		end
	end
	return out
end

-- MINSTD LCG (pure Luau; identical everywhere). Products stay below 2^53.
type Rng = { NextNumber: (Rng) -> number, state: number }

local function newRng(seed: number): Rng
	local rng: Rng = {
		state = (math.floor(seed) % 2147483646) + 1,
		NextNumber = function(self: Rng): number
			self.state = (self.state * 48271) % 2147483647
			return self.state / 2147483647
		end,
	}
	rng:NextNumber()
	rng:NextNumber()
	return rng
end

local function pickClass(rng: Rng, allowGiant: boolean): number
	local classes = Config.Forest.Classes
	local total = 0
	for _, c in classes do
		if allowGiant or c.Id ~= "Giant" then
			total += c.Weight
		end
	end
	local roll = rng:NextNumber() * total
	for i, c in classes do
		if allowGiant or c.Id ~= "Giant" then
			roll -= c.Weight
			if roll <= 0 then
				return i
			end
		end
	end
	return 1
end

local function range(rng: Rng, r: { number }): number
	return r[1] + (r[2] - r[1]) * rng:NextNumber()
end

function ForestPlacement.generate(p: Params): { Tree }
	local F = Config.Forest
	local rng = newRng(p.seed * 31 + p.chunkIndex * 7919 + 17)
	local want = ForestPlacement.targetCount(p.ring, p.isCampChunk)
	local out: { Tree } = {}
	local grid: { [number]: { Tree } } = {}
	local camp = p.camp
	local maxMult = math.max(1, F.NearCampDensity, F.CampEdgeDensity)
	local half = p.size / 2
	local giants = 0
	local poiClear2 = F.PoiClearRadius * F.PoiClearRadius
	local slotClear2 = F.SlotClearRadius * F.SlotClearRadius
	local reach = math.ceil(16 / CELL) + 1
	local attempts = want * F.PlacementAttempts * 3

	for _ = 1, attempts do
		if #out >= want then
			break
		end
		local ci = pickClass(rng, giants < F.GiantMaxPerChunk)
		local cls = F.Classes[ci]
		-- Keep centres MinSpacing/2 inside the chunk edge so neighbours never crowd across the border.
		local margin = cls.MinSpacing / 2
		local x = p.center.x + (rng:NextNumber() * 2 - 1) * (half - margin)
		local z = p.center.z + (rng:NextNumber() * 2 - 1) * (half - margin)
		local accept = 1.0
		if camp then
			local d = math.sqrt((x - camp.x) ^ 2 + (z - camp.z) ^ 2)
			accept = ForestPlacement.densityAt(d) / maxMult
		end
		local ok = accept > 0 and rng:NextNumber() <= accept
		if ok then
			for _, q in p.pois do
				local r2 = if q.r then q.r * q.r else poiClear2
				if (x - q.x) ^ 2 + (z - q.z) ^ 2 < r2 then
					ok = false
					break
				end
			end
		end
		if ok then
			for _, q in p.blocked do
				if (x - q.x) ^ 2 + (z - q.z) ^ 2 < slotClear2 then
					ok = false
					break
				end
			end
		end
		local gx, gz = math.floor(x / CELL), math.floor(z / CELL)
		if ok then
			for dx = -reach, reach do
				for dz = -reach, reach do
					local cell = grid[(gx + dx) * 100003 + (gz + dz)]
					if cell then
						for _, o in cell do
							local need = (cls.MinSpacing + F.Classes[o.classIndex].MinSpacing) / 2
							if (x - o.x) ^ 2 + (z - o.z) ^ 2 < need * need then
								ok = false
								break
							end
						end
					end
					if not ok then
						break
					end
				end
				if not ok then
					break
				end
			end
		end
		if ok then
			local height = range(rng, cls.Height)
			local tree: Tree = {
				x = x,
				y = World.heightAt(
					p.seed,
					x,
					z,
					if camp then camp.x else nil,
					if camp then camp.z else nil
				),
				z = z,
				classIndex = ci,
				classId = cls.Id,
				height = height,
				foliageBottom = TreeRules.shape(height).foliageBottom,
				trunkRadius = range(rng, cls.TrunkRadius),
				canopyRadius = range(rng, cls.CanopyRadius),
				yaw = rng:NextNumber() * math.pi * 2,
			}
			local key = gx * 100003 + gz
			local cell = grid[key]
			if cell == nil then
				cell = {}
				grid[key] = cell
			end
			table.insert(cell, tree)
			table.insert(out, tree)
			if cls.Id == "Giant" then
				giants += 1
			end
		end
	end
	return out
end

return ForestPlacement
