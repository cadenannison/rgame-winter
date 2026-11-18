--!strict
-- Ping wheel (PingRequest { kind, position }). Order: type -> kind/range sanity -> rate limit -> state (alive,
-- within Config.Ping.MaxRange, under the per-player active cap) -> act (broadcast to the pinger's party only).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Ping = require(Shared.logic.Ping)
local Guard = require(script.Parent.Parent.Net.Guard)
local PartyLink = require(script.Parent.Parent.Items.PartyLink)
local ServerUtil = require(script.Parent.Parent.Items.ServerUtil)

local PingService = {}

local expiries: { [Player]: { number } } = {}
local connections: { RBXScriptConnection } = {}
local started = false

local function onPing(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local kind = (payload :: any).kind
	local position = (payload :: any).position
	if typeof(position) ~= "Vector3" or not Ping.validKind(kind) then
		return
	end
	local pos = position :: Vector3
	if not (Guard.isNumber(pos.X) and Guard.isNumber(pos.Y) and Guard.isNumber(pos.Z)) then
		return
	end
	if not Guard.rateLimit(player, "Ping", Config.Net.PingRateInterval) then
		return
	end
	local root = ServerUtil.actingRoot(player)
	if root == nil then
		return
	end
	local ok = Ping.check(
		kind,
		{ x = pos.X, y = pos.Y, z = pos.Z },
		{ x = root.Position.X, y = root.Position.Y, z = root.Position.Z }
	)
	if not ok then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local list = expiries[player]
	if list == nil then
		list = {}
		expiries[player] = list
	end
	if not Ping.canAdd(list, now) then
		return
	end
	local expiresAt = now + Config.Ping.LifetimeSeconds
	for i = #list, 1, -1 do
		if list[i] <= now then
			table.remove(list, i)
		end
	end
	table.insert(list, expiresAt)
	local out: Remotes.PingBroadcastPayload = {
		fromUserId = player.UserId,
		kind = kind :: string,
		position = pos,
		expiresAt = expiresAt,
	}
	for _, member in PartyLink.members(player) do
		Remotes.event(Remotes.PingBroadcast):FireClient(member, out)
	end
end

PingService.handlePing = onPing

function PingService.start()
	if started then
		return
	end
	started = true
	table.insert(connections, Remotes.event(Remotes.PingRequest).OnServerEvent:Connect(onPing))
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			expiries[player] = nil
		end)
	)
end

function PingService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(expiries)
	started = false
end

return PingService
