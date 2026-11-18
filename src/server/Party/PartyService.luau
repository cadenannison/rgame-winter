--!strict
-- Lobby pads: join/leave/mode, shared countdown, friends check, reserved-server launch.
-- Rules live in shared/logic/PadLogic; this file is the Roblox adapter. Started by init.server (lobby mode).
-- Lobby mode only: Start() does nothing unless the server mode is lobby (see isLobby).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PadLogic = require(Shared.logic.PadLogic)
local TeleportData = require(Shared.logic.TeleportData)
local Guard = require(script.Parent.Parent.Net.Guard)
local TeleportAdapter = require(script.Parent.TeleportAdapter)

local RATE_JOIN = "PadJoin"
local RATE_LEAVE = "PadLeave"
local RATE_MODE = "PadMode"
local RATE_TOUCH = "PadTouch"

local PartyService = {}

local pads: { PadLogic.Pad } = {}
local padOf: { [Player]: number } = {} -- player -> pad index
local pending: { [Player]: boolean } = {} -- async friend check in flight
local padParts: { [number]: BasePart } = {}
local touchConnections: { [BasePart]: RBXScriptConnection } = {}
local connections: { RBXScriptConnection } = {}
local launchCallbacks: { (padIndex: number, players: { Player }, data: TeleportData.TeleportData) -> () } =
	{}
local seedFn: () -> number = function()
	return Random.new():NextInteger(0, Config.Teleport.MaxSeed)
end
local started = false
local loopRunning = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function isLobby(): boolean
	local attr = Workspace:GetAttribute(Config.Teleport.ServerModeAttribute)
	return attr == nil or attr == Config.Teleport.ModeLobby
end

local function notify(player: Player, text: string)
	Remotes.event(Remotes.Notify):FireClient(player, "error", text)
end

-- Full snapshot of every pad; only sent on change, never per tick.
local function broadcast()
	local payload: Remotes.PartyStatePayload = { pads = {} }
	for _, pad in pads do
		table.insert(payload.pads, {
			index = pad.index,
			capacity = pad.capacity,
			mode = pad.mode,
			hostId = pad.hostId,
			memberIds = table.clone(pad.memberIds),
			endsAt = pad.endsAt,
			launching = pad.launching,
		})
	end
	Remotes.event(Remotes.PartyState):FireAllClients(payload)
end

local function setPlayerPad(player: Player, index: number)
	if index == 0 then
		padOf[player] = nil
	else
		padOf[player] = index
	end
	if player.Parent == Players then
		player:SetAttribute(Config.Lobby.PlayerPadAttribute, index)
	end
end

local function playersByIds(ids: { number }): { Player }
	local list: { Player } = {}
	for _, id in ids do
		local player = Players:GetPlayerByUserId(id)
		if player then
			table.insert(list, player)
		end
	end
	return list
end

local function resetPad(pad: PadLogic.Pad)
	for _, id in pad.memberIds do
		local player = Players:GetPlayerByUserId(id)
		if player then
			setPlayerPad(player, 0)
		end
	end
	PadLogic.reset(pad)
end

-- Removes a player from their pad (no broadcast). Returns true if anything changed.
local function removeFromPad(player: Player): boolean
	local index = padOf[player]
	if index == nil then
		return false
	end
	local pad = pads[index]
	local changed = PadLogic.leave(pad, player.UserId)
	if changed then
		setPlayerPad(player, 0)
	end
	return changed
end

local function launch(pad: PadLogic.Pad)
	local ids = PadLogic.members(pad)
	local players = playersByIds(ids)
	local liveIds: { number } = {}
	for _, p in players do
		table.insert(liveIds, p.UserId)
	end
	local data = TeleportData.build(Config.Teleport.ModeRun, seedFn(), liveIds)
	if data == nil or #players == 0 then
		resetPad(pad)
		broadcast()
		return
	end
	broadcast() -- launching = true
	task.spawn(function()
		local ok = TeleportAdapter.teleportParty(players, data)
		if not ok then
			-- Everyone stays in the lobby; the pad resets.
			for _, p in players do
				if p.Parent == Players then
					notify(p, "Teleport failed. You are back in the lobby.")
				end
			end
			resetPad(pad)
			broadcast()
			return
		end
		if RunService:IsStudio() then
			-- Studio cannot teleport (TeleportAdapter records the call only): say so instead of failing silently.
			warn(
				"[Party] Studio cannot teleport. To test a run: chat /debug mode run, stop, press Test."
			)
			for _, p in players do
				if p.Parent == Players then
					notify(
						p,
						"Studio can't teleport. Chat /debug mode run, then Stop and press Test."
					)
				end
			end
		end
		for _, callback in launchCallbacks do
			task.spawn(callback, pad.index, players, data)
		end
		task.delay(Config.Lobby.LaunchHoldSeconds, function()
			if pad.launching then
				resetPad(pad)
				broadcast()
			end
		end)
	end)
end

-- Friends check with a hard timeout. Calls back once with true/false.
local function checkFriend(player: Player, hostId: number, callback: (boolean) -> ())
	local done = false
	local function finish(result: boolean)
		if done then
			return
		end
		done = true
		callback(result)
	end
	task.delay(Config.Lobby.FriendCheckTimeout, finish, false)
	task.spawn(function()
		local ok, result = pcall(function()
			return player:IsFriendsWithAsync(hostId)
		end)
		finish(ok and result == true)
	end)
end

local function finishJoin(player: Player, pad: PadLogic.Pad, isFriend: boolean)
	-- Re-validate: state may have changed while the friend check was in flight.
	if player.Parent ~= Players or padOf[player] ~= nil then
		return
	end
	local ok, reason = PadLogic.join(pad, player.UserId, now(), isFriend)
	if not ok then
		if reason == "friends_only" then
			notify(player, "This pad is friends-only.")
		elseif reason == "full" then
			notify(player, "That pad is full.")
		end
		return
	end
	setPlayerPad(player, pad.index)
	broadcast()
end

-- Server-side join (no proximity check; remote and touch handlers check that first).
function PartyService.join(player: Player, padIndex: number): boolean
	local pad = pads[padIndex]
	if pad == nil or padOf[player] ~= nil or pending[player] or player.Parent ~= Players then
		return false
	end
	if pad.launching then
		return false
	end
	if PadLogic.needsFriendCheck(pad, player.UserId) and pad.hostId then
		pending[player] = true
		checkFriend(player, pad.hostId, function(isFriend)
			pending[player] = nil
			finishJoin(player, pad, isFriend)
		end)
		return true
	end
	finishJoin(player, pad, true)
	return padOf[player] == padIndex
end

function PartyService.leave(player: Player): boolean
	if removeFromPad(player) then
		broadcast()
		return true
	end
	return false
end

function PartyService.setMode(player: Player, mode: string): boolean
	local index = padOf[player]
	if index == nil then
		return false
	end
	local ok = PadLogic.setMode(pads[index], player.UserId, mode)
	if ok then
		broadcast()
	end
	return ok
end

-- Fired after a successful teleport call: callback(padIndex, players, data).
function PartyService.onLaunch(callback: (
	padIndex: number,
	players: { Player },
	data: TeleportData.TeleportData
) -> ())
	table.insert(launchCallbacks, callback)
end

-- Studio-only QA: puts a simulated member (a UserId with no Player) on a pad, as a friend. Launch keeps
-- only members still present, exactly as for a real player who left. No-op outside Studio.
function PartyService.debugJoinId(padIndex: number, userId: number): boolean
	if not RunService:IsStudio() then
		return false
	end
	local pad = pads[padIndex]
	if pad == nil or pad.launching then
		return false
	end
	local ok = PadLogic.join(pad, userId, now(), true)
	if ok then
		broadcast()
	end
	return ok
end

-- Test/QA hook: deterministic seeds.
function PartyService.setSeedFunction(fn: (() -> number)?)
	seedFn = fn or function()
		return Random.new():NextInteger(0, Config.Teleport.MaxSeed)
	end
end

-- Snapshot of one pad (copy), or nil for a bad index.
function PartyService.getPad(index: number): PadLogic.Pad?
	local pad = pads[index]
	if pad == nil then
		return nil
	end
	local copy = table.clone(pad)
	copy.memberIds = table.clone(pad.memberIds)
	return copy
end

-- Party member list for a player's current pad (UserIds), empty if none.
function PartyService.getPartyIds(player: Player): { number }
	local index = padOf[player]
	if index == nil then
		return {}
	end
	return table.clone(pads[index].memberIds)
end

local function padPartOnTop(part: BasePart, root: BasePart, margin: number): boolean
	local localPos = part.CFrame:PointToObjectSpace(root.Position)
	local half = part.Size / 2
	return math.abs(localPos.X) <= half.X + margin
		and math.abs(localPos.Z) <= half.Z + margin
		and math.abs(localPos.Y) <= half.Y + Config.Lobby.PadHeightMargin
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- True if the player is physically at the pad. Pads without a built part never accept remote joins.
local function isAtPad(player: Player, padIndex: number, margin: number): boolean
	local part: BasePart? = padParts[padIndex]
	local root = getRoot(player)
	if part == nil or root == nil then
		return false
	end
	return padPartOnTop(part, root, margin)
end

local function registerPadPart(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local index = part:GetAttribute(Config.Lobby.PadIndexAttribute)
	if type(index) ~= "number" or pads[index] == nil then
		return
	end
	padParts[index] = part
	local existing: RBXScriptConnection? = touchConnections[part]
	if existing == nil then
		touchConnections[part] = part.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player == nil or padOf[player] ~= nil or pending[player] then
				return
			end
			if not Guard.rateLimit(player, RATE_TOUCH, Config.Net.PadRateInterval) then
				return
			end
			PartyService.join(player, index)
		end)
	end
end

local function unregisterPadPart(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local connection = touchConnections[part]
	if connection then
		connection:Disconnect()
		touchConnections[part] = nil
	end
	for index, registered in padParts do
		if registered == part then
			padParts[index] = nil
		end
	end
end

local function onJoinRequest(player: Player, payload: unknown)
	-- type-check
	if type(payload) ~= "table" then
		return
	end
	local index = (payload :: any).padIndex
	if not Guard.isNumber(index) or (index :: number) % 1 ~= 0 then
		return
	end
	-- range
	if not Guard.inRange(index, 1, Config.Lobby.PadCount) then
		return
	end
	-- rate limit
	if not Guard.rateLimit(player, RATE_JOIN, Config.Net.PadRateInterval) then
		return
	end
	-- permission/state: not already queued, the pad is built and the player has a character.
	if padOf[player] ~= nil or pending[player] then
		return
	end
	local part: BasePart? = padParts[index :: number]
	local root = getRoot(player)
	if part == nil or root == nil then
		return
	end
	-- Remote joins (billboard Join, summary "Queue again") walk the player onto the pad first, so the
	-- off-pad check keeps them only while they stay on it.
	if not isAtPad(player, index :: number, Config.Lobby.PadEdgeMargin) then
		local character = player.Character
		if character == nil then
			return
		end
		character:PivotTo(
			part.CFrame + Vector3.new(0, part.Size.Y / 2 + Config.Lobby.PadJoinLift, 0)
		)
	end
	PartyService.join(player, index :: number)
end

local function onLeaveRequest(player: Player)
	if not Guard.rateLimit(player, RATE_LEAVE, Config.Net.PadRateInterval) then
		return
	end
	PartyService.leave(player)
end

local function onModeRequest(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local mode = (payload :: any).mode
	if not Guard.isString(mode) or #(mode :: string) > 16 then
		return
	end
	if not Guard.rateLimit(player, RATE_MODE, Config.Net.PadModeRateInterval) then
		return
	end
	PartyService.setMode(player, mode :: string) -- host-only and mode validity enforced in PadLogic
end

-- One loop for every pad: launches finished timers and drops members who walked off.
local function step()
	local changed = false
	for player, index in padOf do
		local pad = pads[index]
		if
			not pad.launching
			and not isAtPad(player, index, Config.Lobby.PadEdgeMargin)
			and padParts[index]
		then
			if removeFromPad(player) then
				changed = true
			end
		end
	end
	if changed then
		broadcast()
	end
	local t = now()
	for _, pad in pads do
		if PadLogic.tick(pad, t) then
			launch(pad)
		end
	end
end

local function onPlayerRemoving(player: Player)
	pending[player] = nil
	if removeFromPad(player) then
		broadcast()
	end
	padOf[player] = nil
	Guard.cleanup(player)
end

function PartyService.Start()
	if started then
		return
	end
	started = true
	if not isLobby() then
		return
	end
	for i = 1, Config.Lobby.PadCount do
		pads[i] = PadLogic.new(i, i)
	end

	local tag = Config.Lobby.PadTag
	for _, part in CollectionService:GetTagged(tag) do
		registerPadPart(part)
	end
	table.insert(
		connections,
		CollectionService:GetInstanceAddedSignal(tag):Connect(registerPadPart)
	)
	table.insert(
		connections,
		CollectionService:GetInstanceRemovedSignal(tag):Connect(unregisterPadPart)
	)

	table.insert(
		connections,
		Remotes.event(Remotes.PadJoinRequest).OnServerEvent:Connect(onJoinRequest)
	)
	table.insert(
		connections,
		Remotes.event(Remotes.PadLeaveRequest).OnServerEvent:Connect(onLeaveRequest)
	)
	table.insert(
		connections,
		Remotes.event(Remotes.PadModeRequest).OnServerEvent:Connect(onModeRequest)
	)
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
	-- Players already present: give them the pad attribute and the first snapshot on arrival.
	for _, player in Players:GetPlayers() do
		player:SetAttribute(Config.Lobby.PlayerPadAttribute, 0)
	end
	table.insert(
		connections,
		Players.PlayerAdded:Connect(function(player)
			player:SetAttribute(Config.Lobby.PlayerPadAttribute, 0)
			Remotes.event(Remotes.PartyState) -- ensure exists
			broadcast()
		end)
	)

	loopRunning = true
	task.spawn(function()
		while loopRunning do
			step()
			task.wait(Config.Lobby.PollInterval)
		end
	end)
	broadcast()
end

function PartyService.Stop()
	loopRunning = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for part, connection in touchConnections do
		connection:Disconnect()
		touchConnections[part] = nil
	end
	table.clear(padParts)
	table.clear(padOf)
	table.clear(pending)
	table.clear(pads)
	started = false
end

return PartyService
