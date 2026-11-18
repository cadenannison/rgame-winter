--!strict
-- Pure, seeded placement of massive structures (no Roblox APIs). Sites come from the world seed + layout:
-- count and rings from Config.Massive, ground from World.heightAt (never from carved Terrain), radius from
-- MassiveRules.footprintRadius. A site never overlaps the camp / spawn pad, a POI, or another structure
-- (centres at least Config.Massive.MinSeparation apart). Trees, rocks, ore, food and spawn slots are
-- excluded through clears()/blocks().

local Config = require("../Config")
local MassiveRules = require("./MassiveRules")
local PoiPlan = require("./PoiPlan")
local SiteGround = require("./SiteGround")
local World = require("./World")
local WorldLayout = require("./WorldLayout")

local MassivePlacement = {}

export type Site = {
	key: string, -- "<id>#<n>", stable per seed
	id: string,
	x: number,
	z: number,
	y: number, -- median World.heightAt over the footprint (builders re-sample; informational)
	radius: number,
	ring: number,
	chunks: { number }, -- chunk indices whose square the footprint (plus margin) touches
}
export type Clear = { x: number, z: number, r: number }

local MOD = 2147483646
local MULT = 48271

local function newRng(seed: number): () -> number
	local state = (math.floor(seed) % MOD) + 1
	return function(): number
		state = (state * MULT) % 2147483647
		return state / 2147483647
	end
end

local function poiRadius(kind: string): number
	local r = PoiPlan.PropFootprints[kind] or PoiPlan.kindFootprint(kind)
	return if r > 0 then r else Config.Forest.PoiClearRadius
end

-- Distance from a point to an axis-aligned square (centre, side); 0 inside.
local function distToSquare(px: number, pz: number, cx: number, cz: number, side: number): number
	local half = side / 2
	local dx = math.max(math.abs(px - cx) - half, 0)
	local dz = math.max(math.abs(pz - cz) - half, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- Highest-lowest and median of World.heightAt over a grid across the footprint circle.
function MassivePlacement.relief(
	seed: number,
	x: number,
	z: number,
	radius: number
): (number, number, number)
	local M = Config.Massive
	local lo, hi = math.huge, -math.huge
	local samples: { number } = {}
	local step = M.SiteSampleStep
	local r2 = radius * radius
	local ox = -radius
	while ox <= radius do
		local oz = -radius
		while oz <= radius do
			if ox * ox + oz * oz <= r2 then
				local h = World.heightAt(seed, x + ox, z + oz)
				lo, hi = math.min(lo, h), math.max(hi, h)
				table.insert(samples, h)
			end
			oz += step
		end
		ox += step
	end
	table.sort(samples)
	local median = samples[math.max(1, math.ceil(#samples / 2))] or Config.Terrain.BaseHeight
	return lo, hi, median
end

function MassivePlacement.chunksCovering(
	layout: WorldLayout.Layout,
	x: number,
	z: number,
	radius: number
): { number }
	local out: { number } = {}
	for _, c in layout.chunks do
		if distToSquare(x, z, c.center.x, c.center.z, layout.chunkSize) <= radius then
			table.insert(out, c.index)
		end
	end
	return out
end

local function acceptable(
	layout: WorldLayout.Layout,
	sites: { Site },
	id: string,
	x: number,
	z: number,
	radius: number
): boolean
	local M = Config.Massive
	local half = World.halfExtent() - radius - M.EdgeMargin
	if math.abs(x) > half or math.abs(z) > half then
		return false
	end
	if not MassiveRules.ringAllowed(id, World.ringAt(x, z)) then
		return false
	end
	local camp = layout.camp.position
	if math.sqrt((x - camp.x) ^ 2 + (z - camp.z) ^ 2) < M.MinSeparation then
		return false
	end
	for _, s in sites do
		local need = math.max(M.MinSeparation, s.radius + radius + M.FootprintMargin)
		if (x - s.x) ^ 2 + (z - s.z) ^ 2 < need * need then
			return false
		end
	end
	for _, c in layout.chunks do
		-- Cheap reject: a chunk this far away cannot hold a POI inside the footprint.
		if distToSquare(x, z, c.center.x, c.center.z, layout.chunkSize) <= radius + 200 then
			for _, poi in c.pois do
				local need = radius + poiRadius(poi.kind) + M.PoiMargin
				if (x - poi.position.x) ^ 2 + (z - poi.position.z) ^ 2 < need * need then
					return false
				end
			end
		end
	end
	return true
end

-- All sites for a layout. Deterministic per (layout seed, layout). A structure that cannot be placed is
-- skipped (tests check CountMin is met for many seeds).
function MassivePlacement.plan(layout: WorldLayout.Layout): { Site }
	local M = Config.Massive
	local rng = newRng(layout.seed * 7919 + 104729)
	local sites: { Site } = {}
	for _, id in M.Ids do
		local def = M.Structures[id]
		local radius = MassiveRules.footprintRadius(id)
		local count = def.CountMin + math.floor(rng() * (def.CountMax - def.CountMin + 1))
		count = math.min(count, def.CountMax)
		local depthY = def.UndergroundDepth
		for n = 1, count do
			for _ = 1, M.PlacementAttempts do
				local span = World.halfExtent() - radius - M.EdgeMargin
				local x = (rng() * 2 - 1) * span
				local z = (rng() * 2 - 1) * span
				if acceptable(layout, sites, id, x, z, radius) then
					local lo, hi, median = MassivePlacement.relief(layout.seed, x, z, radius)
					local function heightFn(sx: number, sz: number): number
						return World.heightAt(layout.seed, sx, sz)
					end
					-- The builder yaws by quarter turns: the site must work in either orientation.
					local hx, hz = def.MinFootprintX / 2, def.MinFootprintZ / 2
					local ground = SiteGround.plan(heightFn, x, z, hx, hz)
					local groundTurned = SiteGround.plan(heightFn, x, z, hz, hx)
					-- SiteGround rejects steep, cliffy and watery sites; the placement loop relocates.
					if
						ground.ok
						and groundTurned.ok
						and hi - lo <= M.MaxSiteRelief
						and lo - depthY - M.KillMargin >= Config.Terrain.KillHeight
					then
						table.insert(sites, {
							key = `{id}#{n}`,
							id = id,
							x = x,
							z = z,
							y = median,
							radius = radius,
							ring = World.ringAt(x, z),
							chunks = MassivePlacement.chunksCovering(layout, x, z, radius),
						})
						break
					end
				end
			end
		end
	end
	return sites
end

-- Exclusion circles (for ForestPlacement tree clearing) of sites that can touch `chunk`.
function MassivePlacement.clears(
	sites: { Site },
	chunk: WorldLayout.Chunk,
	chunkSize: number
): { Clear }
	local out: { Clear } = {}
	for _, s in sites do
		if
			distToSquare(s.x, s.z, chunk.center.x, chunk.center.z, chunkSize)
			<= s.radius + Config.Forest.PoiClearRadius
		then
			table.insert(out, { x = s.x, z = s.z, r = s.radius })
		end
	end
	return out
end

-- True when (x, z) is inside any site footprint.
function MassivePlacement.blocks(sites: { Site }, x: number, z: number): boolean
	for _, s in sites do
		if (x - s.x) ^ 2 + (z - s.z) ^ 2 <= s.radius * s.radius then
			return true
		end
	end
	return false
end

return MassivePlacement
