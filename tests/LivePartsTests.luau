--!strict
-- Live-part estimate: parts per chunk variant (trees, rocks + ore, POIs, ground decor) times the chunks
-- loaded at once, against Config.Perf.MaxLiveParts. Worst case per variant uses the art part caps
-- (Config.Art.World.MaxPartsPer*, ChunkDecorBudget) so it can only over-estimate. Registered in tests/run.luau.

local Chunks = require("../src/shared/data/Chunks")
local Config = require("../src/shared/Config")
local ChestStyle = require("../src/shared/logic/ChestStyle")
local PerfBudget = require("../src/shared/logic/PerfBudget")
local WorldLayout = require("../src/shared/logic/WorldLayout")
local ForestPlacement = require("../src/shared/logic/ForestPlacement")
local TreeRules = require("../src/shared/logic/TreeRules")
local MassivePlacement = require("../src/shared/logic/MassivePlacement")

local MARGIN = 0.1 -- headroom kept under Perf.MaxLiveParts
local STRUCTURE_PARTS_ALLOWANCE = 400 -- campfire, builds, mobs, effects shared across the party

local function variantParts(v: any): number
	local W = Config.Art.World
	-- Trees are counted separately (forest placement below), not from the variant slot counts.
	return (v.rocks + v.ore) * W.MaxPartsPerRock
		+ v.poiSlots * W.MaxPartsPerPoi
		+ v.food
		+ W.ChunkDecorBudget
end

local TEST_SEEDS = { 1, 12345, 987654 }

-- Generates every chunk's forest for a seed. Returns per-chunk trees plus the layout.
local function forests(seed: number): ({ { ForestPlacement.Tree } }, WorldLayout.Layout)
	local layout = WorldLayout.generate(seed, Config.World :: any)
	local out: { { ForestPlacement.Tree } } = {}
	local sites = MassivePlacement.plan(layout)
	local half = layout.chunkSize / 2
	for _, c in layout.chunks do
		local pois = ForestPlacement.poiClears(
			layout,
			c,
			MassivePlacement.clears(sites, c, layout.chunkSize)
		)
		local blocked: { WorldLayout.Vec2 } = {}
		for _, list in { c.rocks, c.ore, c.food, c.spawnZones } do
			for _, p in list do
				table.insert(blocked, p)
			end
		end
		local camp = layout.camp.position
		out[c.index] = ForestPlacement.generate({
			seed = layout.seed,
			chunkIndex = c.index,
			center = c.center,
			size = layout.chunkSize,
			ring = c.ring,
			camp = camp,
			isCampChunk = math.abs(camp.x - c.center.x) <= half
				and math.abs(camp.z - c.center.z) <= half,
			pois = pois,
			blocked = blocked,
		})
	end
	return out, layout
end

-- Most trees alive at once: the biggest stream window (side x side chunks, one player) plus the camp chunk.
local function worstWindowTrees(
	trees: { { ForestPlacement.Tree } },
	layout: WorldLayout.Layout,
	side: number
): number
	local grid = layout.gridSize
	local campChunk = layout.camp.chunkIndex
	local worst = 0
	for x0 = 0, grid - side do
		for y0 = 0, grid - side do
			local sum = 0
			local hasCamp = false
			for _, c in layout.chunks do
				if c.cx >= x0 and c.cx < x0 + side and c.cy >= y0 and c.cy < y0 + side then
					sum += #trees[c.index]
					hasCamp = hasCamp or c.index == campChunk
				end
			end
			if not hasCamp then
				sum += #trees[campChunk]
			end
			worst = math.max(worst, sum)
		end
	end
	return worst
end

-- Parts of one chunk from its REAL layout (not slot counts): rocks, ore, POIs, food, ground decor at the
-- art caps (worst case), plus trees at MaxPartsPerTree each.
local function chunkParts(c: WorldLayout.Chunk, trees: number): number
	local W = Config.Art.World
	return (#c.rocks + #c.ore) * W.MaxPartsPerRock
		+ #c.pois * W.MaxPartsPerPoi
		+ #c.food
		+ W.ChunkDecorBudget
		+ trees * Config.Forest.MaxPartsPerTree
end

-- Most parts alive at once over every stream window (side x side chunks) plus the camp chunk.
local function worstWindowParts(
	trees: { { ForestPlacement.Tree } },
	layout: WorldLayout.Layout,
	side: number
): number
	local grid = layout.gridSize
	local campChunk = layout.camp.chunkIndex
	local worst = 0
	for x0 = 0, grid - side do
		for y0 = 0, grid - side do
			local sum = 0
			local hasCamp = false
			for _, c in layout.chunks do
				if c.cx >= x0 and c.cx < x0 + side and c.cy >= y0 and c.cy < y0 + side then
					sum += chunkParts(c, #trees[c.index])
					hasCamp = hasCamp or c.index == campChunk
				end
			end
			if not hasCamp then
				sum += chunkParts(layout.chunks[campChunk], #trees[campChunk])
			end
			worst = math.max(worst, sum)
		end
	end
	return worst
end

-- Parts the live massive structures may hold: the MaxLiveStructures largest budgets plus chest art.
local function structureParts(): number
	local M = Config.Massive
	local budgets: { number } = {}
	for _, id in M.Ids do
		table.insert(
			budgets,
			M.Structures[id].Budget.Parts + M.MaxChestsPerStructure * M.ChestsPerPartAllowance
		)
	end
	table.sort(budgets, function(a, b)
		return a > b
	end)
	local sum = 0
	for i = 1, M.MaxLiveStructures do
		sum += budgets[i] or 0
	end
	return sum
end

return function(check: (string, boolean) -> ())
	local worst = 0
	local sum = 0
	for _, v in Chunks.Variants do
		local parts = variantParts(v)
		worst = math.max(worst, parts)
		sum += parts
	end
	local avg = sum / #Chunks.Variants
	local W = Config.World
	local F = Config.Forest
	-- A party playing together shares one stream window; players split apart add more windows.
	local chunksAtOnce =
		PerfBudget.maxChunks(1, W.StreamInRadius, W.ChunkSize, W.GridSize * W.GridSize)
	local side = 2 * math.ceil(W.StreamInRadius / W.ChunkSize) + 1
	local nonTree = avg * chunksAtOnce + STRUCTURE_PARTS_ALLOWANCE
	print(
		`live parts (non-tree): avg {math.floor(avg)}/chunk, worst {worst}, chunks {chunksAtOnce}, estimate {math.floor(
			nonTree
		)}`
	)
	check("liveparts: forest parts per tree <= 3", F.MaxPartsPerTree <= 3)
	check(
		"liveparts: worst variant fits chunk allowance",
		worst <= Config.Perf.MaxLiveParts / chunksAtOnce * 2
	)

	-- Tree shape: heights per class, canopy clearance, collide flags, node reachable from the ground.
	local T = Config.Trees
	local heightsOk, clearanceOk, thickOk, nodeOk, giantTall = true, true, true, true, true
	local minGiant, maxSmallTop = math.huge, 0
	for _, cls in F.Classes do
		for _, h in { cls.Height[1], (cls.Height[1] + cls.Height[2]) / 2, cls.Height[2] } do
			local s = TreeRules.shape(h)
			heightsOk = heightsOk and h >= T.MinTotalHeight
			clearanceOk = clearanceOk
				and s.lowerBottom >= T.HeadHeight + T.CanopyClearance - 1e-6
				and s.upperBottom >= s.lowerBottom
				and TreeRules.canopyOk(h, s.foliageBottom)
			thickOk = thickOk and s.lowerHeight > 0 and s.upperBottom + s.upperHeight <= h + 1e-6
			nodeOk = nodeOk and s.trunkHeight / 2 <= Config.Gather.Range * 0.85
		end
		if cls.Id == "Giant" then
			minGiant = cls.Height[1]
		else
			maxSmallTop = math.max(maxSmallTop, cls.Height[2])
		end
	end
	giantTall = minGiant >= 1.25 * maxSmallTop
		and minGiant >= T.GiantHeightMin
		and #F.Classes >= #T.SizeClasses
	check("trees: every class at least Trees.MinTotalHeight", heightsOk)
	check("trees: foliage bottom clears head + CanopyClearance", clearanceOk)
	check("trees: foliage tiers fit under the top", thickOk)
	check("trees: trunk node centre within Gather.Range", nodeOk)
	check("trees: giants much taller than other classes", giantTall)
	check(
		"trees: trunk collides, foliage never does",
		TreeRules.TRUNK_FLAGS.CanCollide
			and not TreeRules.FOLIAGE_FLAGS.CanCollide
			and not TreeRules.FOLIAGE_FLAGS.CanQuery
			and not TreeRules.FOLIAGE_FLAGS.CanTouch
	)

	local worstTrees = 0
	local placedOk = true
	local campOk, spawnClear, poiClear, giants, classesSeen, denser = true, true, true, 0, {}, true
	for _, seed in TEST_SEEDS do
		local trees, layout = forests(seed)
		worstTrees = math.max(worstTrees, worstWindowTrees(trees, layout, side))
		local camp = layout.camp.position
		local clear = ForestPlacement.campClearRadius()
		local near, nearArea, far, farArea = 0, 0, 0, 0
		local woodNear = 0
		for _, c in layout.chunks do
			for _, t in trees[c.index] do
				local d = math.sqrt((t.x - camp.x) ^ 2 + (t.z - camp.z) ^ 2)
				if d < clear then
					spawnClear = false
				end
				if d <= W.CampGuaranteeRadius then
					woodNear += 1
				end
				if d < F.CampEdgeRadius then
					near += 1
				elseif c.ring == 0 then
					far += 1
				end
				if t.classId == "Giant" then
					giants += 1
				end
				classesSeen[t.classId] = true
				for _, poi in ForestPlacement.poiClears(layout, c) do
					local r = poi.r or F.PoiClearRadius
					if (t.x - poi.x) ^ 2 + (t.z - poi.z) ^ 2 < r ^ 2 then
						poiClear = false
					end
				end
			end
		end
		nearArea = math.pi * F.CampEdgeRadius ^ 2
		farArea = 4 * W.ChunkSize ^ 2 - nearArea
		denser = denser and near / nearArea > 2 * (far / farArea)
		campOk = campOk and woodNear >= W.CampGuaranteedWoodCount
	end
	local totalParts = nonTree + worstTrees * F.MaxPartsPerTree
	print(
		`forest: worst window {worstTrees} trees / cap {Config.Perf.MaxLiveTrees}; slot-count parts estimate {math.floor(
			totalParts
		)} (no structures)`
	)
	-- Real-layout estimates (counted from the generated layouts, art caps for decor/POI/rocks): the full
	-- stream window without structures, and the immediate 3x3 core with the live massive structures and
	-- chests. ChunkService also reserves the live structures' parts (setExtraPartsProvider), so the outer ring
	-- of chunks is deferred (nearest first) while large structures are up and the cap is never exceeded.
	local coreSide = 3
	local worstFull, worstCore = 0, 0
	for _, seed in TEST_SEEDS do
		local trees, layout = forests(seed)
		worstFull = math.max(worstFull, worstWindowParts(trees, layout, side))
		worstCore = math.max(worstCore, worstWindowParts(trees, layout, coreSide))
	end
	local limit = Config.Perf.MaxLiveParts * (1 - MARGIN)
	local fullTotal = worstFull + STRUCTURE_PARTS_ALLOWANCE
	local coreTotal = worstCore + STRUCTURE_PARTS_ALLOWANCE + structureParts()
	print(
		`live parts: full {side}x{side} window {worstFull} + allowance = {fullTotal}; core {coreSide}x{coreSide} {worstCore} + allowance + structures {structureParts()} = {coreTotal}; margin limit {math.floor(
			limit
		)} / cap {Config.Perf.MaxLiveParts}`
	)
	check("liveparts: full stream window (no structures) leaves a 10% margin", fullTotal <= limit)
	check("liveparts: 3x3 core + live structures + chests leaves a 10% margin", coreTotal <= limit)
	check("liveparts: Perf.MaxLiveParts never raised", Config.Perf.MaxLiveParts == 6000)
	-- Items round: one massive structure live at a time, <= Loot.Chests Massive.Max chests (each with at most
	-- one beam part, counted in ChestStyle.partCount), so the structure estimate is small and bounded.
	local maxChestRule = 0
	for _, rule in Config.Loot.Chests do
		maxChestRule = math.max(maxChestRule, rule.Max)
	end
	local chestParts = 0
	for _, style in ChestStyle.Styles do
		chestParts = math.max(chestParts, ChestStyle.partCount(style))
	end
	check("liveparts: one massive structure live", Config.Massive.MaxLiveStructures == 1)
	check(
		"liveparts: MaxChestsPerStructure covers the Loot.Chests maximum",
		Config.Massive.MaxChestsPerStructure >= maxChestRule
	)
	check(
		"liveparts: chest allowance covers a chest's parts incl. its beam",
		2 + Config.Massive.ChestsPerPartAllowance >= chestParts
	)
	check(
		"liveparts: massive live parts (structure + chests) <= Massive.MaxLiveParts + chests",
		structureParts()
			<= Config.Massive.MaxLiveParts
				+ Config.Massive.MaxLiveStructures * Config.Massive.MaxChestsPerStructure * Config.Massive.ChestsPerPartAllowance
	)
	check("trees: placed trees tall with canopy above head clearance", placedOk)
	check("liveparts: worst window trees <= MaxLiveTrees", worstTrees <= Config.Perf.MaxLiveTrees)
	check(
		"liveparts: slot-count estimate under Perf.MaxLiveParts",
		totalParts <= Config.Perf.MaxLiveParts
	)
	check("forest: camp and spawn pad stay clear", spawnClear)
	check("forest: no trees on POIs", poiClear)
	check("forest: camp keeps guaranteed wood in reach", campOk)
	check("forest: denser around camp than the rest of the start ring", denser)
	check(
		"forest: all four size classes appear",
		classesSeen.Small and classesSeen.Medium and classesSeen.Large and classesSeen.Giant
	)
	check("forest: giants capped per chunk", giants <= F.GiantMaxPerChunk * 64 * #TEST_SEEDS)
	local a = forests(5)
	local b = forests(5)
	local same = true
	for i, list in a do
		same = same and #list == #b[i]
	end
	check("forest: deterministic per seed", same)
end
