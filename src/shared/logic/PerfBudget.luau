--!strict
-- Pure performance budget math (brief 20): chunk load allowance per tick, particle/sound caps, and the
-- pass/fail check tools/qa/perf.luau applies to a server sample. Caps come from Config.Perf; nothing here
-- touches Roblox APIs.

local PerfBudget = {}

-- Studio-only Workspace attributes the server samples publish (AtmosphereBoot); read by tools/qa/perf.luau.
PerfBudget.Attributes = {
	Parts = "PerfParts",
	Mobs = "PerfMobs",
	Chunks = "PerfChunks",
	HeartbeatMs = "PerfHeartbeatMs",
	Players = "PerfPlayers",
}

export type Caps = {
	maxParts: number,
	maxMobs: number,
	maxChunks: number,
	maxHeartbeatMs: number,
}

export type Sample = {
	parts: number,
	mobs: number,
	chunks: number,
	heartbeatMs: number,
}

-- Frame budget in ms for a target FPS (a Heartbeat average above this means the server misses the target).
function PerfBudget.frameBudgetMs(targetFps: number): number
	return 1000 / math.max(targetFps, 1)
end

-- Most chunks that can be loaded at once: each player's stream-in square plus the always-kept camp chunk,
-- never more than the world has.
function PerfBudget.maxChunks(
	players: number,
	streamInRadius: number,
	chunkSize: number,
	totalChunks: number
): number
	local side = 2 * math.ceil(streamInRadius / chunkSize) + 1
	local perPlayer = side * side
	return math.min(totalChunks, math.max(players, 1) * perPlayer + 1)
end

-- How many chunks the streamer may build this tick: the per-tick budget, further limited by headroom under
-- the live part cap (avgChunkParts = a typical chunk's part count). Always >= 0.
function PerfBudget.chunkAllowance(
	budgetPerTick: number,
	liveParts: number,
	partCap: number,
	avgChunkParts: number
): number
	local headroom = partCap - liveParts
	if headroom <= 0 then
		return 0
	end
	local byParts = math.floor(headroom / math.max(avgChunkParts, 1))
	return math.max(0, math.min(budgetPerTick, byParts))
end

-- First `allowance` entries of an already priority-sorted list.
function PerfBudget.take(list: { number }, allowance: number): { number }
	local out: { number } = {}
	for i = 1, math.min(#list, math.max(allowance, 0)) do
		out[i] = list[i]
	end
	return out
end

-- Whether one more emitter / sound may start under a cap.
function PerfBudget.canAdd(active: number, cap: number): boolean
	return active < cap
end

-- Particle emission rate clamped to the cap and scaled (reduce-scares multiplier etc.).
function PerfBudget.clampRate(rate: number, cap: number, scale: number?): number
	return math.clamp(rate * (scale or 1), 0, cap)
end

-- Average frame time in ms from a summed dt and frame count.
function PerfBudget.averageMs(sumSeconds: number, frames: number): number
	if frames <= 0 then
		return 0
	end
	return sumSeconds / frames * 1000
end

-- Failure strings (empty = within every cap).
function PerfBudget.check(sample: Sample, caps: Caps): { string }
	local fails: { string } = {}
	if sample.parts > caps.maxParts then
		table.insert(fails, `parts {sample.parts} > {caps.maxParts}`)
	end
	if sample.mobs > caps.maxMobs then
		table.insert(fails, `mobs {sample.mobs} > {caps.maxMobs}`)
	end
	if sample.chunks > caps.maxChunks then
		table.insert(fails, `chunks {sample.chunks} > {caps.maxChunks}`)
	end
	if sample.heartbeatMs > caps.maxHeartbeatMs then
		table.insert(fails, `heartbeat {sample.heartbeatMs}ms > {caps.maxHeartbeatMs}ms`)
	end
	return fails
end

return PerfBudget
