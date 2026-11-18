--!strict
-- Pure, deterministic world layout from a seed. No Roblox APIs.
-- Grid coords are 1-based (cx, cy). World coords are studs, grid centered on (0, 0), y ignored.

export type Vec2 = { x: number, z: number }

export type Params = {
	GridSize: number,
	ChunkSize: number,
	StartForestRing: number,
	CampMinRingDistance: number,
	CampGuaranteedWoodCount: number,
	CampGuaranteedFoodCount: number,
	CampGuaranteeRadius: number,
	StreamInRadius: number,
	StreamOutRadius: number,
	TreesPerChunk: number, -- legacy (Phase 1); slot counts now come from data/Chunks variants
	RocksPerChunk: number, -- legacy
	SpawnZonesPerChunk: number, -- legacy
}

-- Point of interest. kind: cabin | plane | cave | campsite | ruin (loot crate, lootTier > 0), hotspring, thinice
-- (patches). id is stable per seed: "<chunkIndex>:<slot>".
export type Poi = {
	id: string,
	kind: string,
	position: Vec2,
	lootTier: number,
	patches: { Vec2 },
}

export type Chunk = {
	index: number,
	cx: number,
	cy: number,
	ring: number,
	biome: string, -- Biomes id for the ring
	variant: number, -- index into Chunks.forBiome(biome)
	variantId: string,
	rotation: number, -- quarter turns, 0..3
	center: Vec2,
	trees: { Vec2 },
	rocks: { Vec2 },
	ore: { Vec2 },
	food: { Vec2 },
	spawnZones: { Vec2 },
	pois: { Poi },
}

export type Camp = {
	chunkIndex: number,
	position: Vec2,
	wood: { Vec2 },
	food: { Vec2 },
}

export type Layout = {
	seed: number,
	gridSize: number,
	chunkSize: number,
	chunks: { Chunk },
	camp: Camp,
}

local Config = require("../Config")
local Biomes = require("../data/Biomes")
local Chunks = require("../data/Chunks")
local Types = require("../data/Types")

local WorldLayout = {}

WorldLayout.SlotKinds = Config.World.SlotTags -- slot tag names live in Config

local LCG_MOD = 4294967296
local LCG_MUL = 1664525
local LCG_ADD = 1013904223
local SLOT_EDGE_MARGIN = 12 -- studs kept clear of chunk edges
local SLOT_MIN_SPACING = 9 -- studs between slots in one chunk
local SLOT_TRIES = 12
local CAMP_CLEAR_RADIUS = 14 -- no ordinary slots this close to camp
local CAMP_EDGE_PAD = 10 -- camp guarantee circle stays this far from chunk edge
local CAMP_NEAR_MIN = 12 -- guaranteed resources start this far from camp
local MIX_A = 73856093
local MIX_B = 19349663
local MIX_C = 83492791
local MAX_LOOT_TIER = 4
local PATCH_COUNT = 3
local PATCH_SPREAD = 16 -- studs: thin-ice patches cluster this close to their slot

-- Small LCG; fine for layout, identical on every machine (doubles stay < 2^53).
local function newRng(seed: number)
	local state = seed % LCG_MOD
	local rng = {}
	local function nextFloat(): number
		state = (state * LCG_MUL + LCG_ADD) % LCG_MOD
		return state / LCG_MOD
	end
	nextFloat()
	nextFloat()
	function rng.float(): number
		return nextFloat()
	end
	function rng.range(lo: number, hi: number): number
		return lo + nextFloat() * (hi - lo)
	end
	function rng.int(lo: number, hi: number): number
		return lo + math.floor(nextFloat() * (hi - lo + 1))
	end
	return rng
end

local function mix(seed: number, a: number, b: number): number
	return (seed * MIX_A + a * MIX_B + b * MIX_C + a * b) % LCG_MOD
end

function WorldLayout.chunkIndex(grid: number, cx: number, cy: number): number
	return (cy - 1) * grid + cx
end

function WorldLayout.chunkCenter(grid: number, size: number, cx: number, cy: number): Vec2
	local mid = (grid + 1) / 2
	return { x = (cx - mid) * size, z = (cy - mid) * size }
end

-- Ring 0 = center chunks, outward (Chebyshev distance from grid center, floored).
function WorldLayout.ringOf(grid: number, cx: number, cy: number): number
	local mid = (grid + 1) / 2
	return math.floor(math.max(math.abs(cx - mid), math.abs(cy - mid)))
end

function WorldLayout.maxRing(grid: number): number
	return math.floor((grid - 1) / 2)
end

local function scatter(
	rng: { range: (number, number) -> number },
	center: Vec2,
	size: number,
	count: number,
	avoid: Vec2?,
	taken: { Vec2 }
): { Vec2 }
	local out: { Vec2 } = {}
	local half = size / 2 - SLOT_EDGE_MARGIN
	for _ = 1, count do
		for _ = 1, SLOT_TRIES do
			local p: Vec2 =
				{ x = center.x + rng.range(-half, half), z = center.z + rng.range(-half, half) }
			local ok = true
			if
				avoid
				and math.sqrt((p.x - avoid.x) ^ 2 + (p.z - avoid.z) ^ 2) < CAMP_CLEAR_RADIUS
			then
				ok = false
			end
			if ok then
				for _, q in taken do
					if (p.x - q.x) ^ 2 + (p.z - q.z) ^ 2 < SLOT_MIN_SPACING ^ 2 then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(out, p)
				table.insert(taken, p)
				break
			end
		end
	end
	return out
end

-- Weighted pick: roll in [0, 1) -> index into variants.
local function pickVariant(roll: number, variants: { Types.ChunkVariant }): number
	local total = 0
	for _, v in variants do
		total += v.weight
	end
	local pick = roll * total
	for i, v in variants do
		pick -= v.weight
		if pick < 0 then
			return i
		end
	end
	return #variants
end

local function ringPoints(
	rng: { range: (number, number) -> number },
	around: Vec2,
	count: number,
	radius: number
): { Vec2 }
	local out: { Vec2 } = {}
	for _ = 1, count do
		local angle = rng.range(0, 2 * math.pi)
		local dist = rng.range(CAMP_NEAR_MIN, radius)
		table.insert(
			out,
			{ x = around.x + math.cos(angle) * dist, z = around.z + math.sin(angle) * dist }
		)
	end
	return out
end

function WorldLayout.generate(seed: number, p: Params): Layout
	local grid, size = p.GridSize, p.ChunkSize
	local chunks: { Chunk } = {}

	-- Camp: pick a start-forest chunk, then a spot with room for the guarantee circle.
	local eligible: { number } = {}
	local maxRing = WorldLayout.maxRing(grid)
	for cy = 1, grid do
		for cx = 1, grid do
			local ring = WorldLayout.ringOf(grid, cx, cy)
			if ring == p.StartForestRing and maxRing - ring >= p.CampMinRingDistance then
				table.insert(eligible, WorldLayout.chunkIndex(grid, cx, cy))
			end
		end
	end
	assert(#eligible > 0, "no eligible camp chunk")
	local campRng = newRng(mix(seed, 7, 11))
	local campIndex = eligible[campRng.int(1, #eligible)]
	local campCx = (campIndex - 1) % grid + 1
	local campCy = math.floor((campIndex - 1) / grid) + 1
	local campCenter = WorldLayout.chunkCenter(grid, size, campCx, campCy)
	local campHalf = math.max(0, size / 2 - p.CampGuaranteeRadius - CAMP_EDGE_PAD)
	local campPos: Vec2 = {
		x = campCenter.x + campRng.range(-campHalf, campHalf),
		z = campCenter.z + campRng.range(-campHalf, campHalf),
	}
	local campWood = ringPoints(campRng, campPos, p.CampGuaranteedWoodCount, p.CampGuaranteeRadius)
	local campFood = ringPoints(campRng, campPos, p.CampGuaranteedFoodCount, p.CampGuaranteeRadius)

	for cy = 1, grid do
		for cx = 1, grid do
			local index = WorldLayout.chunkIndex(grid, cx, cy)
			local rng = newRng(mix(seed, cx, cy))
			local center = WorldLayout.chunkCenter(grid, size, cx, cy)
			local isCamp = index == campIndex
			local avoid = if isCamp then campPos else nil
			local taken: { Vec2 } = {}
			if isCamp then
				for _, v in campWood do
					table.insert(taken, v)
				end
				for _, v in campFood do
					table.insert(taken, v)
				end
			end
			local ring = WorldLayout.ringOf(grid, cx, cy)
			local biome = Biomes.forRing(ring)
			local variants = Chunks.forBiome(biome.id)
			assert(#variants > 0, "no chunk variants for biome " .. biome.id)
			local variant = pickVariant(rng.float(), variants)
			local def = variants[variant]
			local chunk: Chunk = {
				index = index,
				cx = cx,
				cy = cy,
				ring = ring,
				biome = biome.id,
				variant = variant,
				variantId = def.id,
				rotation = rng.int(0, 3),
				center = center,
				trees = scatter(rng, center, size, def.trees, avoid, taken),
				rocks = scatter(rng, center, size, def.rocks, avoid, taken),
				ore = scatter(rng, center, size, def.ore, avoid, taken),
				food = scatter(rng, center, size, def.food, avoid, taken),
				spawnZones = scatter(rng, center, size, def.spawnZones, avoid, taken),
				pois = {},
			}
			local slots = scatter(rng, center, size, def.poiSlots, avoid, taken)
			for slot, pos in slots do
				local kind = def.poiKinds[rng.int(1, #def.poiKinds)]
				local hasLoot = kind ~= "hotspring" and kind ~= "thinice"
				local dist = math.sqrt((pos.x - campPos.x) ^ 2 + (pos.z - campPos.z) ^ 2)
				local tier = if hasLoot
					then math.clamp(1 + math.floor(dist / size), 1, MAX_LOOT_TIER)
					else 0
				local patches: { Vec2 } = {}
				if kind == "thinice" then
					for _ = 1, PATCH_COUNT do
						table.insert(patches, {
							x = pos.x + rng.range(-PATCH_SPREAD, PATCH_SPREAD),
							z = pos.z + rng.range(-PATCH_SPREAD, PATCH_SPREAD),
						})
					end
				end
				table.insert(chunk.pois, {
					id = `{index}:{slot}`,
					kind = kind,
					position = pos,
					lootTier = tier,
					patches = patches,
				})
			end
			if isCamp then
				for _, v in campWood do
					table.insert(chunk.trees, v)
				end
				for _, v in campFood do
					table.insert(chunk.food, v)
				end
			end
			chunks[index] = chunk
		end
	end

	return {
		seed = seed,
		gridSize = grid,
		chunkSize = size,
		chunks = chunks,
		camp = { chunkIndex = campIndex, position = campPos, wood = campWood, food = campFood },
	}
end

-- Stable text form; equal strings mean equal layouts.
function WorldLayout.serialize(layout: Layout): string
	local parts: { string } = {
		`{layout.seed}|{layout.camp.chunkIndex}|{layout.camp.position.x},{layout.camp.position.z}`,
	}
	local function pts(list: { Vec2 }): string
		local s: { string } = {}
		for _, v in list do
			table.insert(s, string.format("%.3f,%.3f", v.x, v.z))
		end
		return table.concat(s, ";")
	end
	local function poiText(list: { Poi }, fmt: ({ Vec2 }) -> string): string
		local s: { string } = {}
		for _, poi in list do
			table.insert(
				s,
				`{poi.id}/{poi.kind}/{poi.lootTier}/{fmt({ poi.position })}/{fmt(poi.patches)}`
			)
		end
		return table.concat(s, ";")
	end
	for _, c in layout.chunks do
		table.insert(
			parts,
			`{c.index}:{c.variantId}:{c.rotation}:{pts(c.trees)}:{pts(c.rocks)}:{pts(c.ore)}:{pts(
				c.food
			)}:{pts(c.spawnZones)}:{poiText(c.pois, pts)}`
		)
	end
	return table.concat(parts, "\n")
end

-- Distance from a point to a chunk's square footprint (0 when inside).
function WorldLayout.distanceToChunk(layout: Layout, chunk: Chunk, point: Vec2): number
	local half = layout.chunkSize / 2
	local dx = math.max(math.abs(point.x - chunk.center.x) - half, 0)
	local dz = math.max(math.abs(point.z - chunk.center.z) - half, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- Which chunks to load / unload given player positions and the currently loaded set.
-- Load within StreamInRadius of any player; unload only when beyond StreamOutRadius of all.
-- keep: chunk indices never unloaded (e.g. camp chunk).
function WorldLayout.streamDiff(
	layout: Layout,
	p: Params,
	positions: { Vec2 },
	loaded: { [number]: boolean },
	keep: { [number]: boolean }
): ({ number }, { number })
	local toLoad: { number } = {}
	local toUnload: { number } = {}
	for index, chunk in layout.chunks do
		local nearest = math.huge
		for _, pos in positions do
			nearest = math.min(nearest, WorldLayout.distanceToChunk(layout, chunk, pos))
		end
		if loaded[index] then
			if nearest > p.StreamOutRadius and not keep[index] then
				table.insert(toUnload, index)
			end
		elseif nearest <= p.StreamInRadius then
			table.insert(toLoad, index)
		end
	end
	return toLoad, toUnload
end

-- Spawn point inside a chunk of the given ring (deterministic, chunk center).
function WorldLayout.ringPosition(layout: Layout, ring: number): Vec2
	local best: Chunk? = nil
	for _, chunk in layout.chunks do
		if chunk.ring == ring and (best == nil or chunk.index == layout.camp.chunkIndex) then
			best = chunk
			if chunk.index == layout.camp.chunkIndex then
				return layout.camp.position
			end
		end
	end
	assert(best, "no chunk in ring")
	return best.center
end

return WorldLayout
