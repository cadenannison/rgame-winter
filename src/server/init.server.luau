--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Characters load only after the profile is loaded (SpawnService); must be off before any player can load.
Players.CharacterAutoLoads = false

local Guard = require(script.Net.Guard)
local DataService = require(script.Data.DataService)
local Spawn = require(script.Spawn.SpawnService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Make sure the remote folder and every remote exist before clients connect.
Remotes.createAll()

-- Start systems here, each exactly once. DataService first, SpawnService last.
DataService.start()
Spawn.start()

local function onPlayerAdded(player: Player)
	-- Per-player setup goes here.
	print(`Player ready: {player.Name}`)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(Guard.cleanup)

-- PlayerAdded race: handle players who joined before this script ran.
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
