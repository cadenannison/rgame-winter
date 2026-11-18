--!strict
-- Terrain height field: determinism, per-biome amplitude, step cap over ALL blocks, edge/kill thresholds.
local Config = require("../src/shared/Config")
local World = require("../src/shared/logic/World")

local SEEDS = { 1, 7, 12345 }
local CAMPS = { { 0, 0 }, { 400, -300 } } -- flat-centre offsets (camp inside the start forest)

-- Worst edge-adjacent height difference over every block of the world (all blocks, not a sample).
local function worstStep(seed: number, fx: number, fz: number): (number, number, number)
	local size = Config.Terrain.BlockSize
	local n = World.halfExtent() // size
	local worst, lo, hi = 0, math.huge, -math.huge
	local prevRow: { number } = {}
	for iz = -n, n - 1 do
		local prev = 0
		for ix = -n, n - 1 do
			local h = World.blockHeight(seed, ix, iz, fx, fz)
			lo, hi = math.min(lo, h), math.max(hi, h)
			if ix > -n then
				worst = math.max(worst, math.abs(h - prev))
			end
			if iz > -n then
				worst = math.max(worst, math.abs(h - prevRow[ix + n + 1]))
			end
			prevRow[ix + n + 1] = h
			prev = h
		end
	end
	return worst, lo, hi
end

return function(check: (string, boolean) -> ())
	local T = Config.Terrain
	local deterministic = true
	for _, seed in SEEDS do
		for i = 1, 50 do
			local x, z = i * 53 - 1300, i * -37 + 900
			if World.heightAt(seed, x, z) ~= World.heightAt(seed, x, z) then
				deterministic = false
			end
		end
	end
	check("terrain heightAt deterministic", deterministic)
	check(
		"terrain seeds differ",
		World.heightAt(1, 40, 40) ~= World.heightAt(2, 40, 40)
			or World.heightAt(1, 900, 900) ~= World.heightAt(2, 900, 900)
	)
	check(
		"terrain block-constant height",
		World.heightAt(5, 801, 802) == World.heightAt(5, 803, 803)
	)

	local capOk, killOk = true, true
	for _, seed in SEEDS do
		for _, c in CAMPS do
			local worst, lo, hi = worstStep(seed, c[1], c[2])
			capOk = capOk and worst <= T.MaxStep
			-- kill height sits below the lowest reachable terrain minus the column depth margin
			killOk = killOk and lo > T.KillHeight and hi < T.KillHeight + 1000
		end
	end
	check("terrain step cap over all blocks", capOk)
	check("terrain heights above kill height", killOk)

	-- Biome relief: lake nearly flat, mountains the largest, all within amplitude.
	local maxAbs: { [string]: number } = {}
	for x = -1280, 1276, T.BlockSize * 2 do
		for z = -1280, 1276, T.BlockSize * 2 do
			local biome = World.biomeAt(x, z)
			local h = math.abs(World.heightAt(7, x, z) - T.BaseHeight)
			maxAbs[biome] = math.max(maxAbs[biome] or 0, h)
		end
	end
	local withinAmp = true
	for id, def in T.Biomes do
		withinAmp = withinAmp and (maxAbs[id] or 0) <= def.Amplitude + 1
	end
	check("terrain within biome amplitude", withinAmp)
	check("terrain lake flatter than forest", (maxAbs.FrozenLake or 0) < (maxAbs.SnowyForest or 0))
	check(
		"terrain mountains largest",
		(maxAbs.MountainsCaves or 0) > (maxAbs.DeepTundra or 0)
			and (maxAbs.MountainsCaves or 0) > (maxAbs.SnowyForest or 0)
	)
	check("terrain camp flat", World.heightAt(7, 410, -310, 400, -300) == T.BaseHeight)

	-- Edge: walkable up to the border + margin, fall threshold beyond; kill height.
	local e = World.halfExtent()
	check("terrain edge inside", not World.isPastEdge(e, 0) and not World.isPastEdge(0, -e))
	check("terrain edge margin", not World.isPastEdge(e + T.EdgeMargin, 0))
	check(
		"terrain edge past",
		World.isPastEdge(e + T.EdgeMargin + 1, 0) and World.isPastEdge(0, -e - T.EdgeMargin - 1)
	)
	check(
		"terrain shouldKill y",
		World.shouldKill(0, T.KillHeight - 1, 0) and not World.shouldKill(0, T.KillHeight + 1, 0)
	)
	check("terrain shouldKill edge", World.shouldKill(e + T.EdgeMargin + 10, 5, 0))

	-- Chunk build queue: any per-tick budget yields the identical runs (deterministic, resumable)
	local TerrainPlan = require("../src/shared/logic/TerrainPlan")
	local function collect(budget: number, yieldEvery: boolean): ({ string }, number)
		local c = TerrainPlan.newCursor(12345, 160, -96, 0, 0)
		local out: { string } = {}
		local calls = 0
		local flip = false
		repeat
			calls += 1
			local done = TerrainPlan.advance(
				c,
				budget,
				function(r)
					table.insert(out, `{r.x},{r.z},{r.n},{r.height}`)
				end,
				if yieldEvery
					then function()
						flip = not flip
						return flip
					end
					else nil
			)
			if calls > 100000 then
				break
			end
		until done
		return out, calls
	end
	local whole = collect(TerrainPlan.totalBlocks(), false)
	local perTick, calls = collect(Config.Terrain.BuildBlocksPerTick, false)
	local tiny = collect(7, true)
	local same = #whole == #perTick and #whole == #tiny and #whole > 0
	if same then
		for i, v in whole do
			if perTick[i] ~= v or tiny[i] ~= v then
				same = false
				break
			end
		end
	end
	check("terrain queue: same runs for every budget", same)
	check(
		"terrain queue: chunk spreads over >= 2 ticks at the config budget",
		calls >= 2 and calls <= TerrainPlan.totalBlocks() // Config.Terrain.BuildBlocksPerTick + 2
	)
	local covered = 0
	for _, line in whole do
		covered += tonumber(string.split(line, ",")[3]) :: number
	end
	check(
		"terrain queue: runs cover every block exactly once",
		covered == TerrainPlan.totalBlocks()
	)
	local capped = TerrainPlan.newCursor(1, 0, 0, 0, 0)
	local emitted = 0
	TerrainPlan.advance(capped, Config.Terrain.BuildBlocksPerTick, function(r)
		emitted += r.n
	end, nil)
	check(
		"terrain queue: one tick never exceeds the block budget",
		capped.blocksDone <= Config.Terrain.BuildBlocksPerTick
			and emitted <= Config.Terrain.BuildBlocksPerTick
	)
end
