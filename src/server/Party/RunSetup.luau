--!strict
-- Run-mode seed and party hand-off. Brief 9 (RunLifecycleService) validates join data with
-- Guard.teleportData, then calls RunSetup.applyRunData before ChunkService.start().
-- ChunkService already reads the Workspace world-seed attribute at start, so this is the "setter".

local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local TeleportData = require(game:GetService("ReplicatedStorage").Shared.logic.TeleportData)

local RunSetup = {}

local mode: string = Config.Teleport.ModeLobby
local partyIds: { number } = {}

-- Call once at boot with already-validated data (Guard.teleportData). Sets the world seed and party.
function RunSetup.applyRunData(data: TeleportData.TeleportData)
	mode = data.mode
	partyIds = table.clone(data.partyIds)
	Workspace:SetAttribute(Config.World.SeedAttribute, data.seed)
end

function RunSetup.getMode(): string
	return mode
end

function RunSetup.getPartyIds(): { number }
	return table.clone(partyIds)
end

return RunSetup
