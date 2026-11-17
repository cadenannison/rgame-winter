--!strict
-- Per-player health/warmth/hunger, downed and revive. One Heartbeat loop steps every player.
-- Health mirrors to Humanoid.Health; outside damage dealt to the Humanoid is absorbed here (Dead state disabled).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local SurvivalLogic = require(Shared.logic.SurvivalLogic)
local Guard = require(script.Parent.Parent.Net.Guard)
local DayNightService = require(script.Parent.DayNightService)
local FireService = require(script.Parent.FireService)
local DebugService = require(script.Parent.Parent.Debug.DebugService)

local M = Config.Meters
local D = Config.Downed
local WARMTH_ATTRIBUTE = M.WarmthAttribute -- replicated rounded meters (health is on the Humanoid)
local HUNGER_ATTRIBUTE = M.HungerAttribute
local RATE_KEY = "Revive"
local HEALTH_EPSILON = 0.01 -- ignore Humanoid health differences below this

type PlayerState = {
	meters: SurvivalLogic.State,
	connections: { RBXScriptConnection },
	sentKey: string,
	revive: { target: Player, remaining: number }?,
}

local SurvivalService = {}

local states: { [Player]: PlayerState } = {}
local connections: { RBXScriptConnection } = {}
local unregisters: { () -> () } = {}
local accumulator = 0
local started = false

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(player: Player): BasePart?
	local humanoid = getHumanoid(player)
	return humanoid and humanoid.RootPart
end

local function isInvincible(player: Player): boolean
	return player:GetAttribute(Config.Debug.PlayerInvincibleAttribute) == true
end

local function setDownedAttribute(player: Player, downed: boolean)
	player:SetAttribute(D.StateAttribute, downed)
end

local function kill(player: Player, state: PlayerState)
	SurvivalLogic.kill(state.meters)
	state.revive = nil
	setDownedAttribute(player, false)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
		humanoid.Health = 0
	end
end

-- A player who falls is downed only if a teammate can still act; otherwise they die (solo = immediate death).
local function hasAbleTeammate(except: Player): boolean
	for other, otherState in states do
		if other ~= except and not otherState.meters.downed and not otherState.meters.dead then
			local humanoid = getHumanoid(other)
			if humanoid and humanoid.Health > 0 then
				return true
			end
		end
	end
	return false
end

local function goDown(player: Player, state: PlayerState)
	if not hasAbleTeammate(player) then
		kill(player, state)
		return
	end
	SurvivalLogic.down(state.meters, D)
	setDownedAttribute(player, true)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = D.DownedWalkSpeed
	end
end

local function resetState(player: Player, state: PlayerState)
	state.meters = SurvivalLogic.new(M)
	state.revive = nil
	state.sentKey = ""
	setDownedAttribute(player, false)
end

local function setupCharacter(player: Player, state: PlayerState, character: Model)
	resetState(player, state)
	local humanoid = character:WaitForChild("Humanoid", Config.SPAWN_HUMANOID_WAIT) :: Humanoid?
	if humanoid and player.Character == character then
		humanoid.MaxHealth = M.MaxHealth
		humanoid.Health = M.MaxHealth
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) -- we decide when a player dies
	end
end

local function pushMeters(player: Player, state: PlayerState)
	local m = state.meters
	local info = {
		health = math.floor(m.health + 0.5),
		warmth = math.floor(m.warmth + 0.5),
		hunger = math.floor(m.hunger + 0.5),
		day = DayNightService.getDay(),
		isNight = DayNightService.isNight(),
	}
	player:SetAttribute(WARMTH_ATTRIBUTE, info.warmth)
	player:SetAttribute(HUNGER_ATTRIBUTE, info.hunger)
	local key = `{info.health}|{info.warmth}|{info.hunger}|{info.day}|{info.isNight}`
	if key == state.sentKey then
		return
	end
	state.sentKey = key
	Remotes.event(Remotes.MetersUpdate):FireClient(player, info :: Remotes.MetersPayload)
end

-- Reads outside damage dealt straight to the Humanoid since the last write-back.
local function absorbExternalDamage(player: Player, state: PlayerState, humanoid: Humanoid)
	local m = state.meters
	local lost = m.health - humanoid.Health
	if lost > HEALTH_EPSILON and not m.downed and not m.dead then
		if SurvivalLogic.damage(m, lost, M, isInvincible(player)) then
			goDown(player, state)
		end
	end
end

local function tickPlayer(player: Player, state: PlayerState, dt: number, isNight: boolean)
	local humanoid = getHumanoid(player)
	local m = state.meters
	if not humanoid or m.dead then
		return
	end
	absorbExternalDamage(player, state, humanoid)
	if m.downed then
		if SurvivalLogic.tickDowned(m, dt) then
			kill(player, state)
		end
	elseif not m.dead then
		local root = humanoid.RootPart
		local inFire = root ~= nil and FireService.isWarm(root.Position)
		local env: SurvivalLogic.Env =
			{ inFire = inFire, isNight = isNight, invincible = isInvincible(player) }
		if SurvivalLogic.step(m, env, M, dt) then
			goDown(player, state)
		end
	end
	if not m.dead and math.abs(humanoid.Health - m.health) > HEALTH_EPSILON then
		humanoid.Health = m.health
	end
end

-- Revive channel: validated every tick (reviver alive and able, target still downed, in range).
local function tickRevive(player: Player, state: PlayerState, dt: number)
	local channel = state.revive
	if not channel then
		return
	end
	local target = channel.target
	local targetState = states[target]
	local reviverRoot, targetRoot = getRoot(player), getRoot(target)
	if
		not targetState
		or not targetState.meters.downed
		or state.meters.downed
		or state.meters.dead
		or not reviverRoot
		or not targetRoot
		or (reviverRoot.Position - targetRoot.Position).Magnitude > D.ReviveRange
	then
		state.revive = nil
		return
	end
	channel.remaining -= dt
	if channel.remaining <= 0 then
		state.revive = nil
		if SurvivalLogic.revive(targetState.meters, M, D) then
			setDownedAttribute(target, false)
			local humanoid = getHumanoid(target)
			if humanoid then
				humanoid.WalkSpeed = Config.WALK_SPEED
				humanoid.Health = targetState.meters.health
			end
		end
	end
end

local function tick(dt: number)
	local isNight = DayNightService.isNight()
	for player, state in states do
		tickPlayer(player, state, dt, isNight)
	end
	for player, state in states do
		tickRevive(player, state, dt)
		pushMeters(player, state)
	end
end

-- Handler order: type -> range -> rate limit -> state -> act.
local function onReviveRequest(player: Player, target: unknown)
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Player") then
		return
	end
	local other = target :: Player
	if other == player or other.Parent ~= Players then
		return
	end
	if not Guard.rateLimit(player, RATE_KEY, Config.Net.UseRateInterval) then
		return
	end
	local state, targetState = states[player], states[other]
	if not state or not targetState then
		return
	end
	if
		state.meters.downed
		or state.meters.dead
		or not targetState.meters.downed
		or state.revive
	then
		return
	end
	local reviverRoot, targetRoot = getRoot(player), getRoot(other)
	if not reviverRoot or not targetRoot then
		return
	end
	if (reviverRoot.Position - targetRoot.Position).Magnitude > D.ReviveRange then
		return
	end
	state.revive = { target = other, remaining = D.ReviveSeconds }
end

local function onPlayerAdded(player: Player)
	if states[player] then
		return
	end
	local state: PlayerState =
		{ meters = SurvivalLogic.new(M), connections = {}, sentKey = "", revive = nil }
	states[player] = state
	table.insert(
		state.connections,
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, state, character)
		end)
	)
	if player.Character then
		task.spawn(setupCharacter, player, state, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local state = states[player]
	if not state then
		return
	end
	for _, connection in state.connections do
		connection:Disconnect()
	end
	states[player] = nil
end

-- Public API for other systems (food, mobs, items). All server-side.
function SurvivalService.getMeters(player: Player): SurvivalLogic.State?
	local state = states[player]
	return state and table.clone(state.meters)
end

function SurvivalService.isDowned(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.meters.downed
end

function SurvivalService.damage(player: Player, amount: number)
	local state = states[player]
	if state and SurvivalLogic.damage(state.meters, amount, M, isInvincible(player)) then
		goDown(player, state)
	end
end

function SurvivalService.heal(player: Player, amount: number)
	local state = states[player]
	if state then
		SurvivalLogic.heal(state.meters, amount, M)
	end
end

function SurvivalService.feed(player: Player, amount: number)
	local state = states[player]
	if state then
		SurvivalLogic.feed(state.meters, amount, M)
	end
end

function SurvivalService.warm(player: Player, amount: number)
	local state = states[player]
	if state then
		SurvivalLogic.warm(state.meters, amount, M)
	end
end

function SurvivalService.start()
	if started then
		return
	end
	started = true
	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	table.insert(
		connections,
		Remotes.event(Remotes.ReviveRequest).OnServerEvent
			:Connect(function(player: Player, target: unknown)
				onReviveRequest(player, target)
			end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator >= M.TickInterval then
				local step = accumulator
				accumulator = 0
				tick(step)
			end
		end)
	)
	-- DebugService already sets the attribute and ForceField; resync so the client sees it at once.
	table.insert(
		unregisters,
		DebugService.register("invincible", function(player, _arg)
			local state = states[player]
			if state then
				state.sentKey = ""
			end
		end)
	)
end

function SurvivalService.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, unregister in unregisters do
		unregister()
	end
	table.clear(unregisters)
	for player in states do
		onPlayerRemoving(player)
	end
	started = false
end

return SurvivalService
