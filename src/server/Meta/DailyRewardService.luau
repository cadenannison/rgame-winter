--!strict
-- Handles DailyClaimRequest. The server recomputes eligibility and the coin amount from the profile
-- and Config.Meta; the client sends nothing and its values are never read.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Guard = require(script.Parent.Parent.Net.Guard)
local DataService = require(script.Parent.Parent.Data.DataService)
local DailyLogic = require(script.Parent.DailyLogic)
local MetaService = require(script.Parent.MetaService)

local RATE_KEY = "DailyClaim"

local DailyRewardService = {}

local connections: { RBXScriptConnection } = {}
local started = false

local function reply(player: Player, ok: boolean, coins: number, nextClaimAt: number)
	local payload: Remotes.DailyClaimResultPayload =
		{ ok = ok, coins = coins, nextClaimAt = nextClaimAt }
	Remotes.event(Remotes.DailyClaimResult):FireClient(player, payload)
end

-- Server-side claim; returns ok, coins granted, next claim time. `now` is injectable for tests.
function DailyRewardService.claim(player: Player, now: number?): (boolean, number, number)
	local profile = DataService.get(player)
	if not profile then
		return false, 0, 0
	end
	local time = now or os.time()
	local can, nextAt = DailyLogic.check(profile.lastDailyClaim, time)
	if not can then
		return false, 0, nextAt
	end
	profile.coins = math.clamp(profile.coins + Config.Meta.DailyRewardCoins, 0, Config.MaxCoins)
	profile.lastDailyClaim = time
	local _, following = DailyLogic.check(time, time)
	MetaService.addProgress(player, "dailyClaims", 1)
	return true, Config.Meta.DailyRewardCoins, following
end

-- Handler order: type-check (no payload) -> range (none) -> rate limit -> state -> act.
local function onClaimRequest(player: Player)
	if player.Parent ~= Players then
		return
	end
	if not Guard.rateLimit(player, RATE_KEY, Config.Net.DailyClaimRateInterval) then
		return
	end
	local ok, coins, nextAt = DailyRewardService.claim(player)
	reply(player, ok, coins, nextAt)
end

function DailyRewardService.Start()
	if started then
		return
	end
	started = true
	table.insert(
		connections,
		Remotes.event(Remotes.DailyClaimRequest).OnServerEvent:Connect(function(player: Player)
			onClaimRequest(player)
		end)
	)
end

function DailyRewardService.Stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	started = false
end

return DailyRewardService
