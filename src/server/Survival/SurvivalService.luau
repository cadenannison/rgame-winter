--!strict
-- Per-player health/warmth/hunger, downed and revive. One Heartbeat loop steps every player.
-- Health mirrors to Humanoid.Health; outside damage dealt to the Humanoid is absorbed here (Dead state disabled).
-- Disconnect hold: when the hold predicate (wired to RunLifecycleService.ShouldHold) says so, a leaving
-- player's meters are kept by UserId for Config.Run.RejoinWindowSeconds and restored on rejoin. The
-- character itself is not kept (Roblox removes it); a rejoining player respawns at camp.

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
	lastHit: string?, -- what last dealt outside damage ("Wolf"); the cause if that damage downs them
	restore: SurvivalLogic.State?, -- held meters to apply on the first character after a rejoin
}

-- Phase 3 environment for one player (wired in init.server): warm spots plus biome/event/buff multipliers.
export type EnvExtra = {
	warm: boolean?, -- inside a warm spot (cabin hearth, hot spring, sleeping bag)
	warmthDrain: number?, -- biome x event x buff warmth drain multiplier (1 = none)
	hungerDrain: number?, -- buff hunger drain multiplier (1 = none)
	regenBonus: number?, -- buff health regen bonus per second
	speed: number?, -- buff walk speed multiplier (1 = none; capped by Buffs.MaxSpeedBonus)
}

local SurvivalService = {}

local states: { [Player]: PlayerState } = {}
local connections: { RBXScriptConnection } = {}
local unregisters: { () -> () } = {}
local accumulator = 0
local started = false
local holdPredicate: ((Player) -> boolean)? = nil
local envProvider: ((Player, Vector3) -> EnvExtra?)? = nil
local causeHandler: ((Player, string) -> ())? = nil
local reviveHandler: ((Player, Player) -> ())? = nil
local held: { [number]: { meters: SurvivalLogic.State, expires: number } } = {}

local CAUSE_COLD = "Cold"
local CAUSE_HUNGER = "Hunger"

local function reportCause(player: Player, cause: string)
	local handler = causeHandler
	if handler then
		local ok = pcall(handler, player, cause)
		if not ok then
			warn("SurvivalService: cause handler failed")
		end
	end
end

local function meterCause(m: SurvivalLogic.State): string
	if m.warmth <= 0 then
		return CAUSE_COLD
	elseif m.hunger <= 0 then
		return CAUSE_HUNGER
	end
	return CAUSE_COLD
end

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
	local restored = state.restore
	state.restore = nil
	if restored then
		state.meters = restored
		setDownedAttribute(player, restored.downed)
	end
	local humanoid = character:WaitForChild("Humanoid", Config.SPAWN_HUMANOID_WAIT) :: Humanoid?
	if humanoid and player.Character == character then
		humanoid.MaxHealth = M.MaxHealth
		humanoid.Health = state.meters.health
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) -- we decide when a player dies
		if state.meters.downed then
			humanoid.WalkSpeed = D.DownedWalkSpeed
		end
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
			reportCause(player, state.lastHit or CAUSE_COLD)
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
		local provider = envProvider
		if provider and root then
			local ok, extra = pcall(provider, player, root.Position)
			if ok and type(extra) == "table" then
				env.inFire = inFire or extra.warm == true
				env.warmthDrainMultiplier = extra.warmthDrain
				env.hungerDrainMultiplier = extra.hungerDrain
				env.regenBonus = extra.regenBonus
				local speed = extra.speed
				if type(speed) == "number" and speed == speed then
					local walk = Config.WALK_SPEED
						* math.clamp(
							speed,
							1 - Config.Buffs.MaxSpeedBonus,
							1 + Config.Buffs.MaxSpeedBonus
						)
					if math.abs(humanoid.WalkSpeed - walk) > HEALTH_EPSILON then
						humanoid.WalkSpeed = walk
					end
				end
			end
		end
		if SurvivalLogic.step(m, env, M, dt) then
			reportCause(player, meterCause(m))
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
			local handler = reviveHandler
			if handler then
				task.spawn(handler, player, target)
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
	local hold = held[player.UserId]
	held[player.UserId] = nil
	if hold and os.clock() < hold.expires then
		state.restore = hold.meters
	end
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
	local t = os.clock()
	for userId, entry in held do
		if t >= entry.expires then
			held[userId] = nil
		end
	end
	local predicate = holdPredicate
	if predicate and not state.meters.dead then
		local ok, keep = pcall(predicate, player)
		if ok and keep == true then
			local meters = table.clone(state.meters)
			held[player.UserId] = { meters = meters, expires = t + Config.Run.RejoinWindowSeconds }
		end
	end
end

-- Wiring (init.server): whether a leaving player's meters are held for a rejoin.
function SurvivalService.setHoldPredicate(fn: ((Player) -> boolean)?)
	holdPredicate = fn
end

-- Wiring (init.server): Phase 3 environment (warm spots, biome cold, events, food buffs). Nil-safe.
function SurvivalService.setEnvProvider(fn: ((Player, Vector3) -> EnvExtra?)?)
	envProvider = fn
end

-- Wiring (Phase 4): told when a revive completes (reviver, target). Nil-safe; runs in its own thread.
function SurvivalService.setReviveHandler(fn: ((Player, Player) -> ())?)
	reviveHandler = fn
end

-- Wiring (init.server): told what downed a player ("Wolf", "Cold", "Hunger").
function SurvivalService.setCauseHandler(fn: ((Player, string) -> ())?)
	causeHandler = fn
end

-- Records what last dealt outside damage to a player (MobService bite wiring); used as the cause if it downs them.
function SurvivalService.markHit(player: Player, source: string)
	local state = states[player]
	if state then
		state.lastHit = source
	end
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

function SurvivalService.damage(player: Player, amount: number, cause: string?)
	local state = states[player]
	if state and SurvivalLogic.damage(state.meters, amount, M, isInvincible(player)) then
		reportCause(player, cause or state.lastHit or CAUSE_COLD)
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
	table.clear(held)
	started = false
end

return SurvivalService
