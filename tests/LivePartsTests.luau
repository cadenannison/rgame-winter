--!strict
-- Live-part estimate: parts per chunk variant (trees, rocks + ore, POIs, ground decor) times the chunks
-- loaded at once, against Config.Perf.MaxLiveParts. Worst case per variant uses the art part caps
-- (Config.Art.World.MaxPartsPer*, ChunkDecorBudget) so it can only over-estimate. Registered in tests/run.luau.

local Chunks = require("../src/shared/data/Chunks")
local Config = require("../src/shared/Config")
local PerfBudget = require("../src/shared/logic/PerfBudget")

local STRUCTURE_PARTS_ALLOWANCE = 400 -- campfire, builds, mobs, effects shared across the party

local function variantParts(v: any): number
	local W = Config.Art.World
	return v.trees * W.MaxPartsPerTree
		+ (v.rocks + v.ore) * W.MaxPartsPerRock
		+ v.poiSlots * W.MaxPartsPerPoi
		+ v.food
		+ W.ChunkDecorBudget
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
	-- A party playing together shares one stream window; players split apart add more windows.
	local chunksAtOnce =
		PerfBudget.maxChunks(1, W.StreamInRadius, W.ChunkSize, W.GridSize * W.GridSize)
	local estimate = avg * chunksAtOnce + STRUCTURE_PARTS_ALLOWANCE
	print(
		`live parts: avg {math.floor(avg)}/chunk, worst {worst}, chunks {chunksAtOnce}, estimate {math.floor(
			estimate
		)} / cap {Config.Perf.MaxLiveParts}`
	)
	check("liveparts: estimate under Perf.MaxLiveParts", estimate <= Config.Perf.MaxLiveParts)
	check(
		"liveparts: worst variant fits chunk allowance",
		worst <= Config.Perf.MaxLiveParts / chunksAtOnce * 2
	)
end
