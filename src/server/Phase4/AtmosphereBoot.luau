--!strict
-- Phase 4 server boot hook for brief 20 (atmosphere, polish, performance). init.server.luau calls
-- start(mode) once in BOTH modes, after the mode's services start and before Spawn.start(). Must not yield.
-- Studio only: one Heartbeat connection samples server load every Perf.FpsSampleSeconds and publishes
-- Workspace attributes (PerfBudget.Attributes) that tools/qa/perf.luau asserts against Config.Perf caps.
-- Production work is passive: the chunk load budget lives in ChunkService, the mob cap in MobService
-- (Scaling.MaxLiveMobs == Perf.MaxLiveMobs) and SwingRelay is called by Gather/Mob services.
-- See docs/systems/atmosphere.md.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PerfBudget = require(Shared:WaitForChild("logic"):WaitForChild("PerfBudget"))

local AtmosphereBoot = {}

local started = false

-- Studio-only measurement: counting BaseParts walks the Workspace, which is why it is never run live.
local function countParts(): number
	local n = 0
	for _, d in Workspace:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local function publish(frames: number, sumSeconds: number)
	local A = PerfBudget.Attributes
	local chunkFolder = Workspace:FindFirstChild(Config.World.ChunkFolderName)
	Workspace:SetAttribute(A.Parts, countParts())
	Workspace:SetAttribute(A.Mobs, #CollectionService:GetTagged(Config.Mobs.Tag))
	Workspace:SetAttribute(A.Chunks, if chunkFolder then #chunkFolder:GetChildren() else 0)
	Workspace:SetAttribute(A.HeartbeatMs, PerfBudget.averageMs(sumSeconds, frames))
	Workspace:SetAttribute(A.Players, #Players:GetPlayers())
end

function AtmosphereBoot.start(_mode: string)
	if started then
		return
	end
	started = true
	if not RunService:IsStudio() then
		return
	end
	local frames, sum, elapsed = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		frames += 1
		sum += dt
		elapsed += dt
		if elapsed >= Config.Perf.FpsSampleSeconds then
			publish(frames, sum)
			frames, sum, elapsed = 0, 0, 0
		end
	end)
end

return AtmosphereBoot
