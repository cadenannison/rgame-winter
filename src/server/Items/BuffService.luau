--!strict
-- Server food buffs: per-player list (shared/logic/Buffs), pruned in one loop. Visible state only
-- (Attributes Config.Buffs.ActiveAttribute and Food.TimesAttribute). getModifiers feeds Survival (brief 18).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Buffs = require(Shared.logic.Buffs)
local Food = require(Shared.data.Food)

local BuffService = {}

local PRUNE_INTERVAL = 1 -- seconds between expiry sweeps (one loop for all players)

local active: { [Player]: { Buffs.Active } } = {}
local connections: { RBXScriptConnection } = {}
local started = false
local accumulator = 0.0

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish(player: Player)
	local list: { Buffs.Active } = active[player] or {}
	local times: { string } = {}
	for _, entry in list do
		table.insert(times, `{entry.id}:{math.floor(entry.expires * 10) / 10}`)
	end
	local ids = Buffs.ids(list)
	local stamp = table.concat(times, ",")
	if player:GetAttribute(Config.Buffs.ActiveAttribute) ~= ids then
		player:SetAttribute(Config.Buffs.ActiveAttribute, ids)
	end
	if player:GetAttribute(Food.TimesAttribute) ~= stamp then
		player:SetAttribute(Food.TimesAttribute, stamp)
	end
end

-- Grants (or refreshes) a buff. False for an unknown id or a player who left.
function BuffService.grant(player: Player, buffId: string, durationSeconds: number): boolean
	if player.Parent ~= Players then
		return false
	end
	local list = active[player]
	if list == nil then
		list = Buffs.new()
		active[player] = list
	end
	local ok = Buffs.add(list, buffId, durationSeconds, now())
	if ok then
		publish(player)
	end
	return ok
end

-- { warmthDrain, hungerDrain, regenBonus, speed }, all capped (neutral when no buff is active).
function BuffService.getModifiers(player: Player): Buffs.Mods
	return Buffs.modifiers(active[player] or {}, now())
end

function BuffService.clear(player: Player)
	active[player] = nil
	if player.Parent == Players then
		publish(player)
	end
end

local function sweep()
	local t = now()
	for player, list in active do
		if Buffs.prune(list, t) then
			publish(player)
		end
	end
end

function BuffService.start()
	if started then
		return
	end
	started = true
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			active[player] = nil
		end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator >= PRUNE_INTERVAL then
				accumulator = 0
				sweep()
			end
		end)
	)
end

function BuffService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(active)
	started = false
end

return BuffService
