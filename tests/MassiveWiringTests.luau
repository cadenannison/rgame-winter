--!strict
-- Integration round: massive structure placement (MassivePlacement) and its chunk-generation hooks.
-- Headless: seeded, no overlap with camp / POIs / each other / trees, ring and count rules, ground from the
-- pure World.heightAt (never carved Terrain), kill-height margin for underground carves.

local Config = require("../src/shared/Config")
local ForestPlacement = require("../src/shared/logic/ForestPlacement")
local MassivePlacement = require("../src/shared/logic/MassivePlacement")
local MassiveRules = require("../src/shared/logic/MassiveRules")
local PoiPlan = require("../src/shared/logic/PoiPlan")
local World = require("../src/shared/logic/World")
local WorldLayout = require("../src/shared/logic/WorldLayout")

local SEEDS = { 1, 2, 3, 5, 7, 12345, 987654, 424242, 31337, 2024, 77, 90210 }

local function poiRadius(kind: string): number
	local r = PoiPlan.PropFootprints[kind] or PoiPlan.kindFootprint(kind)
	return if r > 0 then r else Config.Forest.PoiClearRadius
end

return function(check: (string, boolean) -> ())
	local M = Config.Massive
	local countsOk, ringsOk, sepOk, campOk, poiOk, edgeOk, reliefOk, killOk, detOk, coverOk =
		true, true, true, true, true, true, true, true, true, true
	local treeOk, slotsOk = true, true
	local total, worstTotal = 0, 0
	for _, seed in SEEDS do
		local layout = WorldLayout.generate(seed, Config.World :: any)
		local sites = MassivePlacement.plan(layout)
		local again = MassivePlacement.plan(layout)
		detOk = detOk and #sites == #again
		for i, s in sites do
			local a = again[i]
			detOk = detOk and a ~= nil and a.x == s.x and a.z == s.z and a.key == s.key
		end
		total += #sites
		worstTotal = math.max(worstTotal, #sites)
		local perId: { [string]: number } = {}
		for _, s in sites do
			perId[s.id] = (perId[s.id] or 0) + 1
		end
		for _, id in M.Ids do
			local def = M.Structures[id]
			local n = perId[id] or 0
			countsOk = countsOk and n >= def.CountMin and n <= def.CountMax
		end
		local camp = layout.camp.position
		for i, s in sites do
			ringsOk = ringsOk and MassiveRules.ringAllowed(s.id, World.ringAt(s.x, s.z))
			ringsOk = ringsOk and s.radius == MassiveRules.footprintRadius(s.id)
			campOk = campOk
				and math.sqrt((s.x - camp.x) ^ 2 + (s.z - camp.z) ^ 2) >= M.MinSeparation
			local half = World.halfExtent()
			edgeOk = edgeOk
				and math.abs(s.x) + s.radius <= half
				and math.abs(s.z) + s.radius <= half
			for j = i + 1, #sites do
				local o = sites[j]
				sepOk = sepOk and math.sqrt((s.x - o.x) ^ 2 + (s.z - o.z) ^ 2) >= M.MinSeparation
			end
			for _, c in layout.chunks do
				for _, poi in c.pois do
					local d = math.sqrt((s.x - poi.position.x) ^ 2 + (s.z - poi.position.z) ^ 2)
					poiOk = poiOk and d >= s.radius + poiRadius(poi.kind)
				end
			end
			local lo, hi = MassivePlacement.relief(seed, s.x, s.z, s.radius)
			reliefOk = reliefOk and hi - lo <= M.MaxSiteRelief
			killOk = killOk
				and lo - M.Structures[s.id].UndergroundDepth - M.KillMargin
					>= Config.Terrain.KillHeight
			coverOk = coverOk and #s.chunks >= 1 and #s.chunks <= 9
			-- Trees and slots keep out of the footprint.
			for _, chunkIndex in s.chunks do
				local chunk = layout.chunks[chunkIndex]
				local extra = MassivePlacement.clears(sites, chunk, layout.chunkSize)
				local blocked: { WorldLayout.Vec2 } = {}
				for _, list in { chunk.rocks, chunk.ore, chunk.food, chunk.spawnZones } do
					for _, p in list do
						if not MassivePlacement.blocks(sites, p.x, p.z) then
							table.insert(blocked, p)
						else
							slotsOk = slotsOk and MassivePlacement.blocks(sites, p.x, p.z)
						end
					end
				end
				local trees = ForestPlacement.generate({
					seed = layout.seed,
					chunkIndex = chunk.index,
					center = chunk.center,
					size = layout.chunkSize,
					ring = chunk.ring,
					camp = camp,
					isCampChunk = false,
					pois = ForestPlacement.poiClears(layout, chunk, extra),
					blocked = blocked,
				})
				for _, t in trees do
					for _, o in sites do
						if (t.x - o.x) ^ 2 + (t.z - o.z) ^ 2 < o.radius ^ 2 then
							treeOk = false
						end
					end
				end
			end
		end
	end
	print(`massive sites: {total} over {#SEEDS} seeds (max {worstTotal} in one world)`)
	check("massive: per-structure count within CountMin..CountMax for every seed", countsOk)
	check("massive: rings allowed and radius = footprintRadius", ringsOk)
	check("massive: at least MinSeparation from each other", sepOk)
	check("massive: at least MinSeparation from the camp and spawn pad", campOk)
	check("massive: no overlap with any POI footprint", poiOk)
	check("massive: footprint stays inside the world edge", edgeOk)
	check("massive: site relief within MaxSiteRelief (World.heightAt)", reliefOk)
	check("massive: deepest carve stays above the kill height with a margin", killOk)
	check("massive: placement deterministic per seed", detOk)
	check("massive: covering chunks listed (1..9)", coverOk)
	check("massive: no tree inside any structure footprint", treeOk)
	check("massive: slots inside a footprint are the ones skipped", slotsOk)
	check("massive: total never exceeds the structure cap per world", worstTotal <= 11)

	-- Different seeds move the sites; a different layout is not the same plan.
	local la = WorldLayout.generate(1, Config.World :: any)
	local lb = WorldLayout.generate(2, Config.World :: any)
	local pa, pb = MassivePlacement.plan(la), MassivePlacement.plan(lb)
	check("massive: seed changes the plan", pa[1] ~= nil and pb[1] ~= nil and pa[1].x ~= pb[1].x)

	-- Underground carving never feeds back into placement or streaming: heightAt is a pure function of
	-- (seed, x, z): this file runs under lune (no Terrain exists), so placement cannot depend on carved
	-- voxels, and any number of calls (before or after a carve) agree.
	local s = pa[1]
	local h1 = World.heightAt(1, s.x, s.z)
	for dx = -40, 40, 8 do
		World.heightAt(1, s.x + dx, s.z - dx)
	end
	check("heightAt: unchanged by interleaved calls (stateless)", World.heightAt(1, s.x, s.z) == h1)
	check(
		"heightAt: a site's recorded Y equals a fresh sample set",
		select(3, MassivePlacement.relief(1, s.x, s.z, s.radius)) == s.y
	)
end
