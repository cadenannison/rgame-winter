--!strict
-- Lobby server side: publishes each player's shown stats as Player attributes (read by the stat board,
-- shop and daily button) and feeds the max-days leaderboard. Pads/teleport live in src/server/Party,
-- daily claim in src/server/Meta. Started by init.server (lobby mode only).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LobbyLogic = require(ReplicatedStorage.Shared.logic.LobbyLogic)
local DataService = require(script.Parent.Parent.Data.DataService)
local LobbyLeaderboard = require(script.Parent.LobbyLeaderboard)

local LobbyService = {}

local started = false
local stopped = false
local connections: { RBXScriptConnection } = {}
local unsubscribe: (() -> ())? = nil

local function publish(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local attr = LobbyLogic.ATTR
	player:SetAttribute(attr.Coins, profile.coins)
	player:SetAttribute(attr.MaxDays, profile.maxDays)
	player:SetAttribute(attr.Runs, profile.runs)
	player:SetAttribute(attr.Kills, profile.kills)
	player:SetAttribute(attr.BossKills, profile.bossKills)
	player:SetAttribute(attr.Crafted, profile.crafted)
	player:SetAttribute(attr.LastDailyClaim, profile.lastDailyClaim)
	local ids: { string } = {}
	for id, unlocked in profile.achievements do
		if unlocked then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	player:SetAttribute(attr.Achievements, table.concat(ids, ","))
	LobbyLeaderboard.submit(player.UserId, profile.maxDays)
end

function LobbyService.Start()
	if started then
		return
	end
	started = true
	LobbyLeaderboard.start()

	unsubscribe = DataService.onLoaded(function(player: Player, _profile)
		publish(player)
	end)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			LobbyLeaderboard.forget(player.UserId)
		end)
	)

	-- One loop for every player (profile values change from run end and daily claim).
	task.spawn(function()
		while not stopped do
			task.wait(Config.Lobby.StatPublishSeconds)
			for _, player in Players:GetPlayers() do
				publish(player)
			end
		end
	end)
end

function LobbyService.Stop()
	stopped = true
	LobbyLeaderboard.stop()
	if unsubscribe then
		unsubscribe()
		unsubscribe = nil
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	started = false
end

return LobbyService
