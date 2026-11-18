--!strict

local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local TeleportData = require(game:GetService("ReplicatedStorage").Shared.logic.TeleportData)

local Guard = {}

-- Per-player, per-key last-call timestamps. Cleared by Guard.cleanup.
local lastCall: { [Player]: { [string]: number } } = {}

-- Returns true if the call is allowed, false if the player is calling too fast.
function Guard.rateLimit(player: Player, key: string, minInterval: number?): boolean
	-- A player who left must not get a fresh entry (it would never be cleaned).
	if player.Parent ~= Players then
		return false
	end
	local interval = minInterval or Config.DefaultRateLimitInterval
	local now = os.clock()
	local perPlayer = lastCall[player]
	if not perPlayer then
		perPlayer = {}
		lastCall[player] = perPlayer
	end
	local last = perPlayer[key]
	if last ~= nil and now - last < interval then
		return false
	end
	perPlayer[key] = now
	return true
end

function Guard.cleanup(player: Player)
	lastCall[player] = nil
end

function Guard.isNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Guard.isString(value: unknown): boolean
	return type(value) == "string"
end

function Guard.inRange(value: unknown, minValue: number, maxValue: number): boolean
	return Guard.isNumber(value) and (value :: number) >= minValue and (value :: number) <= maxValue
end

-- Validates teleport data arriving on a server (Player:GetJoinData().TeleportData). Returns a clean
-- copy only if it matches the schema exactly, its mode is `expectedMode`, and `player` is in partyIds.
-- Callers refuse the player (return to lobby) on nil. Never trust the raw table.
function Guard.teleportData(
	player: Player,
	data: unknown,
	expectedMode: string
): TeleportData.TeleportData?
	local parsed = TeleportData.parse(data)
	if not parsed or parsed.mode ~= expectedMode then
		return nil
	end
	if not TeleportData.hasMember(parsed, player.UserId) then
		return nil
	end
	return parsed
end

return Guard
