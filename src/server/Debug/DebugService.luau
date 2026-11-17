--!strict
-- Studio-only debug commands. Inert (start() is a no-op, run() rejects) on published servers.
-- Each command writes state to attributes (Config.Debug.*) and notifies plug-in handlers from the registry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local DebugCommands = require(Shared.logic.DebugCommands)
local Guard = require(script.Parent.Parent.Net.Guard)

export type Handler = (player: Player, arg: unknown) -> ()

local DebugService = {}

local D = Config.Debug
local registry: { [string]: { Handler } } = {}
local connections: { RBXScriptConnection } = {}
local ownedForceFields: { [Player]: ForceField } = {}
local playerConnections: { [Player]: RBXScriptConnection } = {}
local started = false

local limits: DebugCommands.Limits = {
	maxDay = D.MaxDay,
	maxClockSpeed = D.MaxClockSpeed,
	ringCount = D.RingCount,
	darkEvents = D.DarkEvents,
}

function DebugService.isActive(): boolean
	return RunService:IsStudio()
end

-- Other systems plug in here. Returns an unregister function.
function DebugService.register(command: string, handler: Handler): () -> ()
	local list = registry[command]
	if not list then
		list = {}
		registry[command] = list
	end
	table.insert(list, handler)
	return function()
		local l = registry[command]
		local i = l and table.find(l, handler)
		if l and i then
			table.remove(l, i)
		end
	end
end

local function setInvincible(player: Player, on: boolean)
	local existing = ownedForceFields[player]
	if existing then
		existing:Destroy()
		ownedForceFields[player] = nil
	end
	if on and player.Character then
		local ff = Instance.new("ForceField")
		ff.Visible = false
		ff.Parent = player.Character
		ownedForceFields[player] = ff
	end
end

local function worldAttribute(name: string): string
	local map: { [string]: string } = {
		setDay = D.WorldDayAttribute,
		clockSpeed = D.WorldClockSpeedAttribute,
		blizzard = D.WorldBlizzardAttribute,
		darkEvent = D.WorldDarkEventAttribute,
		stalker = D.WorldStalkerAttribute,
	}
	return map[name] or ""
end

-- Validates and applies one command. Returns ok, message. Safe to call from server code too.
function DebugService.run(player: Player, name: unknown, arg: unknown): (boolean, string)
	if not DebugService.isActive() then
		return false, "inactive"
	end
	local ok, value = DebugCommands.validate(name, arg, limits)
	if not ok then
		return false, tostring(value)
	end
	local command = name :: string
	if command == "invincible" then
		player:SetAttribute(D.PlayerInvincibleAttribute, value :: boolean)
		setInvincible(player, value :: boolean)
	elseif command == "teleportRing" then
		player:SetAttribute(D.PlayerRingAttribute, value :: number)
	else
		Workspace:SetAttribute(worldAttribute(command), value :: any)
	end
	local handlers: { Handler } = table.clone(registry[command] or {})
	for _, handler in handlers do
		local success, err = pcall(handler :: any, player, value)
		if not success then
			warn(`[Debug] handler for {command} failed: {err}`)
		end
	end
	return true, "ok"
end

local function onCharacterAdded(player: Player)
	if player:GetAttribute(D.PlayerInvincibleAttribute) == true then
		setInvincible(player, true)
	end
end

local function onPlayerAdded(player: Player)
	if playerConnections[player] then
		return
	end
	playerConnections[player] = player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
end

local function clearPlayerState(player: Player)
	setInvincible(player, false)
	player:SetAttribute(D.PlayerInvincibleAttribute, nil)
	player:SetAttribute(D.PlayerRingAttribute, nil)
end

local function onPlayerRemoving(player: Player)
	local conn = playerConnections[player]
	if conn then
		conn:Disconnect()
		playerConnections[player] = nil
	end
	clearPlayerState(player)
end

local function clearWorldState()
	for _, attr in
		{
			D.WorldDayAttribute,
			D.WorldClockSpeedAttribute,
			D.WorldBlizzardAttribute,
			D.WorldDarkEventAttribute,
			D.WorldStalkerAttribute,
		}
	do
		Workspace:SetAttribute(attr, nil)
	end
end

function DebugService.start()
	if started or not DebugService.isActive() then
		return
	end
	started = true
	local remote = Remotes.event(Remotes.DebugCommand)
	table.insert(
		connections,
		remote.OnServerEvent:Connect(function(player: Player, name: unknown, arg: unknown)
			-- type-check and range-check happen in run (DebugCommands.validate) before any state change;
			-- rate limit comes first for cheap rejection of spam.
			if
				type(name) ~= "string"
				or not Guard.rateLimit(player, "DebugCommand", D.CommandRateInterval)
			then
				return
			end
			local ok, msg = DebugService.run(player, name, arg)
			if not ok then
				warn(`[Debug] {player.Name} {name}: {msg}`)
			end
		end)
	)
	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function DebugService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for player, conn in playerConnections do
		conn:Disconnect()
		playerConnections[player] = nil
	end
	for _, player in Players:GetPlayers() do
		clearPlayerState(player)
	end
	for player in ownedForceFields do
		setInvincible(player, false)
	end
	clearWorldState()
	started = false
end

return DebugService
