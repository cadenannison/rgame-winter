--!strict
-- Global max-days leaderboard over an OrderedDataStore. Every call is pcall'd and rate limited:
-- one queue drains at most one write per interval, one read per refresh. The top list is published
-- as a Workspace attribute (encoded text) so the read-only client never calls DataStores.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LobbyLogic = require(ReplicatedStorage.Shared.logic.LobbyLogic)

local LobbyLeaderboard = {}

local store: OrderedDataStore? = nil
local pending: { [number]: number } = {} -- userId -> best score waiting to be written
local pendingOrder: { number } = {}
local submitted: { [number]: number } = {} -- best score this session already queued/written
local names: { [number]: string } = {}
local nameCount = 0
local started = false
local stopped = false
local warned = false

local function warnOnce(message: string)
	if not warned then
		warned = true
		warn(`[Lobby] leaderboard unavailable: {message}`)
	end
end

local function nameFor(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	local name = if player then player.Name else nil
	if name == nil then
		local ok, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = if ok and type(result) == "string" then result else "Player"
	end
	if nameCount >= Config.Lobby.NameCacheMax then
		names = {}
		nameCount = 0
	end
	names[userId] = name :: string
	nameCount += 1
	return name :: string
end

-- Queues a score for the player (ignored unless it beats what this session already queued).
function LobbyLeaderboard.submit(userId: number, days: number)
	if stopped or days <= 0 then
		return
	end
	local score = math.min(math.floor(days), Config.Meta.MaxStatValue)
	if score <= (submitted[userId] or 0) then
		return
	end
	submitted[userId] = score
	if pending[userId] == nil then
		if #pendingOrder >= Config.Lobby.LeaderboardMaxPending then
			return
		end
		table.insert(pendingOrder, userId)
	end
	pending[userId] = score
end

-- Forget per-player session state (PlayerRemoving).
function LobbyLeaderboard.forget(userId: number)
	submitted[userId] = nil
end

local function writeOne(): boolean
	local ds = store
	local userId = table.remove(pendingOrder, 1)
	if ds == nil or userId == nil then
		return true
	end
	local score = pending[userId]
	pending[userId] = nil
	if score == nil then
		return true
	end
	local ok, err = pcall(function()
		ds:UpdateAsync(tostring(userId), function(old: any): any
			if type(old) == "number" and old >= score then
				return nil -- keep the better stored value
			end
			return score
		end)
	end)
	if not ok then
		-- Requeue once so a transient failure does not lose the score.
		submitted[userId] = nil
		warnOnce(tostring(err))
		return false
	end
	return true
end

local function refresh(): boolean
	local ds = store
	if ds == nil then
		return false
	end
	local ok, result = pcall(function()
		local page = ds:GetSortedAsync(false, Config.Lobby.LeaderboardTopCount)
		return page:GetCurrentPage()
	end)
	if not ok then
		warnOnce(tostring(result))
		return false
	end
	local entries: { LobbyLogic.BoardEntry } = {}
	for _, row in result :: { { key: string, value: number } } do
		local userId = tonumber(row.key)
		if userId and type(row.value) == "number" then
			table.insert(entries, { name = nameFor(userId), score = row.value })
		end
	end
	Workspace:SetAttribute(
		LobbyLogic.ATTR.Board,
		LobbyLogic.encodeBoard(entries, Config.Lobby.LeaderboardTopCount)
	)
	return true
end

-- Starts the single background loop. Safe to call once; Stop ends it.
function LobbyLeaderboard.start()
	if started then
		return
	end
	started = true
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Lobby.LeaderboardStoreName)
	end)
	if ok then
		store = result :: OrderedDataStore
	else
		warnOnce(tostring(result))
	end
	task.spawn(function()
		local sinceRefresh = Config.Lobby.LeaderboardRefreshSeconds -- refresh immediately
		while not stopped do
			local step = Config.Lobby.LeaderboardWriteIntervalSeconds
			task.wait(step)
			sinceRefresh += step
			local failed = false
			if #pendingOrder > 0 and not writeOne() then
				failed = true
			end
			if not failed and sinceRefresh >= Config.Lobby.LeaderboardRefreshSeconds then
				sinceRefresh = 0
				failed = not refresh()
			end
			if failed then
				task.wait(Config.Lobby.LeaderboardRetryAfterFailSeconds)
			end
		end
	end)
end

function LobbyLeaderboard.stop()
	stopped = true
end

return LobbyLeaderboard
