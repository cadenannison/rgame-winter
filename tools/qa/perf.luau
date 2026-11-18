--!nocheck
-- QA scenario perf (runner style): run on the SERVER datamodel during Play (start_play, local player) in
-- ONE MCP call. Reads the Studio-only samples AtmosphereBoot publishes (part count, live mobs, chunks
-- loaded, Heartbeat avg ms) and asserts each stays under the Config.Perf caps via PerfBudget.check.
-- Prints <= 8 lines: `PASS perf/check` or `FAIL perf/check: reason`; FAILs first. Leaves nothing behind.
local MAX_LINES = 8
local NAME = "perf"
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local PerfBudget = require(RS.Shared.logic.PerfBudget)
local P = Config.Perf
local A = PerfBudget.Attributes

local lines = {}
local fails = {}
local function chk(check, ok, why)
	if ok then
		table.insert(lines, `PASS {NAME}/{check}`)
	else
		table.insert(fails, `FAIL {NAME}/{check}: {why}`)
	end
end

local player = Players:GetPlayers()[1]
for _ = 1, 40 do
	if player and player:GetAttribute(Config.ReadyAttribute) and player.Character then
		break
	end
	task.wait(0.5)
	player = Players:GetPlayers()[1]
end
chk("player_ready", player ~= nil and player.Character ~= nil, "no local player/character")

-- Wait for a fresh sample after the world has streamed in (2 sample periods).
task.wait(P.FpsSampleSeconds * 2 + 1)
local hb = Workspace:GetAttribute(A.HeartbeatMs)
chk(
	"sample_published",
	type(hb) == "number",
	"AtmosphereBoot published no Perf attributes (Studio only)"
)

if type(hb) == "number" then
	local playerCount = math.max(Workspace:GetAttribute(A.Players) or 1, 1)
	local sample = {
		parts = Workspace:GetAttribute(A.Parts) or 0,
		mobs = Workspace:GetAttribute(A.Mobs) or 0,
		chunks = Workspace:GetAttribute(A.Chunks) or 0,
		heartbeatMs = hb,
	}
	local caps = {
		maxParts = P.MaxLiveParts,
		maxMobs = P.MaxLiveMobs,
		maxChunks = PerfBudget.maxChunks(
			playerCount,
			Config.World.StreamOutRadius,
			Config.World.ChunkSize,
			Config.World.GridSize * Config.World.GridSize
		),
		maxHeartbeatMs = PerfBudget.frameBudgetMs(P.TargetFps),
	}
	local failures = PerfBudget.check(sample, caps)
	chk("parts", sample.parts <= caps.maxParts, `{sample.parts} > {caps.maxParts}`)
	chk("mobs", sample.mobs <= caps.maxMobs, `{sample.mobs} > {caps.maxMobs}`)
	chk("chunks", sample.chunks <= caps.maxChunks, `{sample.chunks} > {caps.maxChunks}`)
	chk(
		"heartbeat_ms",
		sample.heartbeatMs <= caps.maxHeartbeatMs,
		`{string.format("%.1f", sample.heartbeatMs)}ms > {string.format("%.1f", caps.maxHeartbeatMs)}ms`
	)
	chk("budget_check", #failures == 0, table.concat(failures, "; "))
	table.insert(
		lines,
		`INFO perf parts={sample.parts} mobs={sample.mobs} chunks={sample.chunks} hb={string.format(
			"%.1f",
			sample.heartbeatMs
		)}ms`
	)
end

local out = {}
for _, l in fails do
	table.insert(out, l)
end
for _, l in lines do
	table.insert(out, l)
end
if #out > MAX_LINES then
	local extra = #out - (MAX_LINES - 1)
	for _ = 1, extra do
		table.remove(out, #out - 1) -- keep the INFO line last
	end
	table.insert(out, #out, `PASS {NAME}/+{extra} more`)
end
print(table.concat(out, "\n"))
