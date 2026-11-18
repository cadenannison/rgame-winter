--!nocheck
-- Idempotent: applies the Config.Perf streaming settings to Workspace. Run once in Studio edit mode via
-- MCP execute_luau (StreamingEnabled cannot change at runtime); re-running is safe and leaves no script.
-- Values come only from Config.Perf; the chunk streamer (ChunkService) still owns world chunk load/unload.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local P = Config.Perf

Workspace.StreamingEnabled = P.StreamingEnabled
Workspace.StreamingTargetRadius = P.StreamingTargetRadius
Workspace.StreamingMinRadius = P.StreamingMinRadius

print(
	`apply_perf: StreamingEnabled={Workspace.StreamingEnabled} target={Workspace.StreamingTargetRadius} min={Workspace.StreamingMinRadius}`
)
