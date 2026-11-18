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
local SprintLogic = require(Shared.logic.SprintLogic)
local DownedLogic = require(Shared.logic.DownedLogic)
local DownedPose = require(script.Parent.DownedPose)
local Guard = require(script.Parent.Parent.Net.Guard)
local DayNightService = require(script.Parent.DayNightService)
local FireService = require(script.Parent.FireService)
local DebugService = require(script.Parent.Parent.Debug.DebugService)
local Spawn = require(script.Parent.Parent.Spawn.SpawnService)

local M = Config.Meters
local D = Config.Downed
local WARMTH_ATTRIBUTE = M.WarmthAttribute -- replicated rounded meters (health is on the Humanoid)
local HUNGER_ATTRIBUTE = M.HungerAttribute
local RATE_KEY = "Revive"
local SPRINT_KEY = "Sprint"
local SP = Config.Sprint
local HEALTH_EPSILON = 0.01 -- ignore Humanoid health differences below this

type PlayerState = {
	meters: SurvivalLogic.State,
	connections: { RBXScriptConnection },
	sentKey: string,
	revive: { target: Player, remaining: number, lastRefresh: number }?,
	jumpPower: number?, -- humanoid jump values saved while downed (restored on revive)
	jumpHeight: number?,
	sprintWanted: boolean, -- last validated SprintRequest
	sprinting: boolean, -- server-resolved sprint flag (speed applied, hunger cost charged)
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
local respawnHandler: ((Player) -> ())? = nil
local held: { [number]: { meters: SurvivalLogic.State, expires: number } } = {}

local CAUSE_COLD = "Cold"
local CAUSE_HUNGER = "Hunger"
local CAUSE_FALL = "Fall"

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
	if not downed then
		player:SetAttribute(D.BleedAttribute, nil)
	end
	player:SetAttribute(D.ReviveProgressAttribute, nil)
end

local function clearSprint(player: Player, state: PlayerState)
	state.sprintWanted = false
	if state.sprinting then
		state.sprinting = false
		player:SetAttribute(SP.Attribute, false)
	end
end

-- Lying/crawling pose with no jumping (ragdoll-free: joints stay intact).
local function applyDownedBody(state: PlayerState, humanoid: Humanoid)
	humanoid.WalkSpeed = D.DownedWalkSpeed
	if state.jumpPower == nil then
		state.jumpPower = humanoid.JumpPower
		state.jumpHeight = humanoid.JumpHeight
	end
	humanoid.JumpPower = D.DownedJumpPower
	humanoid.JumpHeight = 0
	humanoid.Health = D.DownedHealth
	local character = humanoid.Parent
	if character and character:IsA("Model") then
		DownedPose.apply(character)
	end
end

local function clearDownedBody(state: PlayerState, humanoid: Humanoid)
	humanoid.WalkSpeed = Config.WALK_SPEED
	if state.jumpPower ~= nil then
		humanoid.JumpPower = state.jumpPower
		humanoid.JumpHeight = state.jumpHeight or humanoid.JumpHeight
		state.jumpPower = nil
		state.jumpHeight = nil
	end
	local character = humanoid.Parent
	if character and character:IsA("Model") then
		DownedPose.clear(character)
	end
end

-- Final death (bled out, solo, or fell out of the world): the body lies where it fell, nothing breaks apart,
-- and the player becomes a spectator (client reads DeadAttribute).
local function kill(player: Player, state: PlayerState)
	SurvivalLogic.kill(state.meters)
	state.revive = nil
	clearSprint(player, state)
	setDownedAttribute(player, false)
	player:SetAttribute(D.DeadAttribute, true)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		humanoid.WalkSpeed = 0
		local character = humanoid.Parent
		if character and character:IsA("Model") then
			DownedPose.apply(character)
		end
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
	if DownedLogic.onZeroHealth(hasAbleTeammate(player)) == "dead" then
		kill(player, state)
		return
	end
	SurvivalLogic.down(state.meters, D)
	clearSprint(player, state)
	setDownedAttribute(player, true)
	local humanoid = getHumanoid(player)
	if humanoid then
		applyDownedBody(state, humanoid)
	end
end

local function resetState(player: Player, state: PlayerState)
	state.meters = SurvivalLogic.new(M)
	state.revive = nil
	state.sentKey = ""
	state.jumpPower = nil
	state.jumpHeight = nil
	state.sprintWanted = false
	state.sprinting = false
	player:SetAttribute(SP.Attribute, false)
	setDownedAttribute(player, false)
	player:SetAttribute(D.DeadAttribute, false)
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
		humanoid.BreakJointsOnDeath = false -- a body never scatters
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) -- we decide when a player dies
		if state.meters.downed then
			task.defer(function()
				if player.Character == character and state.meters.downed then
					applyDownedBody(state, humanoid)
				end
			end)
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
		player:SetAttribute(D.BleedAttribute, DownedLogic.bleedSeconds(m.bleed))
		if SurvivalLogic.tickDowned(m, dt) then
			kill(player, state)
		end
	elseif not m.dead then
		local root = humanoid.RootPart
		local inFire = root ~= nil and FireService.isWarm(root.Position)
		local buffSpeed: number? = nil
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
					buffSpeed = math.clamp(
						speed,
						1 - Config.Buffs.MaxSpeedBonus,
						1 + Config.Buffs.MaxSpeedBonus
					)
				end
			end
		end
		-- Sprint: server resolves the flag (gated on hunger/downed/dead) and owns WalkSpeed while it applies.
		local sprinting =
			SprintLogic.resolve(state.sprintWanted, state.sprinting, m.hunger, m.downed, m.dead, SP)
		if state.sprintWanted and not sprinting then
			state.sprintWanted = false -- gate failed (hunger): the client must request again
		end
		local wasSprinting = state.sprinting
		state.sprinting = sprinting
		if sprinting ~= wasSprinting then
			player:SetAttribute(SP.Attribute, sprinting)
		end
		if buffSpeed ~= nil or sprinting or wasSprinting then
			local walk = SprintLogic.speed(Config.WALK_SPEED * (buffSpeed or 1), sprinting, SP)
			if math.abs(humanoid.WalkSpeed - walk) > HEALTH_EPSILON then
				humanoid.WalkSpeed = walk
			end
		end
		if sprinting and root then
			local v = root.AssemblyLinearVelocity
			local cost = SprintLogic.hungerCost(true, Vector3.new(v.X, 0, v.Z).Magnitude, dt, SP)
			m.hunger = math.max(m.hunger - cost, 0)
		end
		if SurvivalLogic.step(m, env, M, dt) then
			reportCause(player, meterCause(m))
			goDown(player, state)
		end
	end
	local shownHealth = if m.downed then D.DownedHealth else m.health
	if not m.dead and math.abs(humanoid.Health - shownHealth) > HEALTH_EPSILON then
		humanoid.Health = shownHealth
	end
end

-- The one downed -> alive transition (real revive and respawn API): meters, attributes, body, health.
local function reviveInPlace(player: Player, state: PlayerState): boolean
	if not SurvivalLogic.revive(state.meters, M, D) then
		return false
	end
	state.revive = nil
	setDownedAttribute(player, false)
	local humanoid = getHumanoid(player)
	if humanoid then
		clearDownedBody(state, humanoid)
		humanoid.Health = state.meters.health
	end
	return true
end

local function actorOf(state: PlayerState): DownedLogic.Actor
	return { downed = state.meters.downed, dead = state.meters.dead }
end

-- Revive channel: validated every tick (reviver alive and able, target still downed, in range, still
-- holding: the client refreshes the request while it holds, a lapse cancels).
local function tickRevive(player: Player, state: PlayerState, dt: number)
	local channel = state.revive
	if not channel then
		return
	end
	local target = channel.target
	local targetState = states[target]
	local reviverRoot, targetRoot = getRoot(player), getRoot(target)
	local dist = if reviverRoot and targetRoot
		then (reviverRoot.Position - targetRoot.Position).Magnitude
		else math.huge
	local verdict, left = "cancel", channel.remaining
	if targetState then
		local since = if D.ReviveBarHoldRequired then os.clock() - channel.lastRefresh else 0
		verdict, left = DownedLogic.channelStep(
			channel.remaining,
			dt,
			dist,
			D.ReviveCancelRange,
			since,
			D.ReviveStaleSeconds,
			actorOf(state),
			actorOf(targetState)
		)
	end
	if verdict == "cancel" or not targetState then
		state.revive = nil
		target:SetAttribute(D.ReviveProgressAttribute, nil)
		return
	end
	channel.remaining = left
	if verdict == "continue" then
		target:SetAttribute(D.ReviveProgressAttribute, DownedLogic.progress(left, D.ReviveSeconds))
		return
	end
	state.revive = nil
	if reviveInPlace(target, targetState) then
		local handler = reviveHandler
		if handler then
			task.spawn(handler, player, target)
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
	local reviverRoot, targetRoot = getRoot(player), getRoot(other)
	if not reviverRoot or not targetRoot then
		return
	end
	local dist = (reviverRoot.Position - targetRoot.Position).Magnitude
	local channel = state.revive
	if channel and channel.target == other then
		channel.lastRefresh = os.clock() -- still holding
		return
	end
	if channel then
		return -- one channel at a time
	end
	if
		not DownedLogic.canStartRevive(actorOf(state), actorOf(targetState), dist, D.ReviveRange)
	then
		return
	end
	state.revive = { target = other, remaining = D.ReviveSeconds, lastRefresh = os.clock() }
end

-- Handler order: type -> range (n/a) -> rate limit -> state -> act. The client only says what it wants;
-- the tick re-gates every frame and owns WalkSpeed and the hunger cost.
local function setSprintWanted(player: Player, wanted: boolean): boolean
	local state = states[player]
	if not state then
		return false
	end
	local m = state.meters
	if wanted and not SprintLogic.canStart(m.hunger, m.downed, m.dead, SP) then
		if not (state.sprinting and SprintLogic.canKeep(m.hunger, m.downed, m.dead, SP)) then
			state.sprintWanted = false
			if m.hunger < SP.MinHungerToStart and not m.downed and not m.dead then
				Remotes.event(Remotes.Notify):FireClient(player, "sprint", SP.NoHungerText)
			end
			return false
		end
	end
	state.sprintWanted = wanted
	return wanted
end

local function onSprintRequest(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local active = (payload :: { active: unknown }).active
	if type(active) ~= "boolean" then
		return
	end
	if not Guard.rateLimit(player, SPRINT_KEY, SP.RateInterval) then
		return
	end
	setSprintWanted(player, active)
end

local function onPlayerAdded(player: Player)
	if states[player] then
		return
	end
	local state: PlayerState = {
		meters = SurvivalLogic.new(M),
		connections = {},
		sentKey = "",
		revive = nil,
		sprintWanted = false,
		sprinting = false,
	}
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
function SurvivalService.setRespawnHandler(fn: ((Player) -> ())?)
	respawnHandler = fn
end

-- Respawn API (debug and tools): sends a downed or dead player through the same transitions as a real
-- revive/spawn. Downed -> revive in place (same path as a teammate revive). Dead -> meters and the
-- downed/dead attributes reset now and a fresh character loads (setupCharacter resets again, idempotent).
-- Alive players are left untouched (returns false). The run roster is told through the respawn handler.
function SurvivalService.respawn(player: Player): boolean
	local state = states[player]
	if not state or player.Parent ~= Players then
		return false
	end
	local wasDead = state.meters.dead
	if wasDead then
		resetState(player, state)
	elseif not reviveInPlace(player, state) then
		return false
	end
	local handler = respawnHandler
	if handler then
		pcall(handler, player)
	end
	if not wasDead then
		return true
	end
	Spawn.respawn(player) -- one load path (SpawnService guards against a double load)
	return true
end

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

-- Debug (orchestrator wires /debug sprint): same gating as the remote, no rate limit. Returns whether the
-- request was accepted; the tick still re-gates and owns speed and hunger cost.
function SurvivalService.DebugSetSprint(player: Player, on: boolean): boolean
	return setSprintWanted(player, on)
end

function SurvivalService.isSprinting(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.sprinting
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

-- Hook for the world edge / kill height (World.shouldKill, called by the terrain edge wall or any
-- fell-out check). Ends the player outright: no downed window, not revivable. Single fall path:
-- ChunkService.setFallHandler (wired in Phase3 Wiring) calls this once per fall.
function SurvivalService.killOutright(player: Player, cause: string?)
	local state = states[player]
	if state and not state.meters.dead then
		reportCause(player, cause or CAUSE_FALL)
		kill(player, state)
	end
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
		Remotes.event(Remotes.SprintRequest).OnServerEvent
			:Connect(function(player: Player, payload: unknown)
				onSprintRequest(player, payload)
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
	respawnHandler = nil
	started = false
end

return SurvivalService
