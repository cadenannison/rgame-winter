--!strict
-- Gated character spawning: a character loads only after the profile is loaded and per-player
-- setup is done. Handles respawns, signals Ready, and kills players who fall into the void.
-- Requires Players.CharacterAutoLoads = false (set in init.server before any player can load).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.Parent.Data.DataService)

local Spawn = {}

local charConns: { [Player]: RBXScriptConnection? } = {}
local diedConns: { [Player]: RBXScriptConnection? } = {}
local respawning: { [Player]: thread } = {}
local inFlight: { [Player]: boolean } = {}
local disconnectLoaded: (() -> ())? = nil
local playerRemovingConn: RBXScriptConnection? = nil
local voidThread: thread? = nil
local started = false
local spawnProvider: (() -> Vector3?)? = nil
local spawnPad: SpawnLocation? = nil
local autoRespawn = true

local SPAWN_PAD_SIZE =
	Vector3.new(Config.SpawnPadSize[1], Config.SpawnPadSize[2], Config.SpawnPadSize[3])

-- Lobby servers respawn dead players on a timer; run servers do not (dead = spectate until revive/new run).
function Spawn.setAutoRespawn(enabled: boolean)
	autoRespawn = enabled
end

-- Ground position players spawn at (init wires ChunkService.getCampSpawnPosition). Set before start().
function Spawn.setSpawnProvider(fn: () -> Vector3?)
	spawnProvider = fn
end

-- The shared camp spawn pad, created on first use from the provider. Nil if the world is not ready.
local function getSpawnPad(): SpawnLocation?
	local existing = spawnPad
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local provider = spawnProvider
	if provider == nil then
		return nil
	end
	local ok, pos = pcall(provider)
	if not ok or typeof(pos) ~= "Vector3" then
		return nil
	end
	local pad = Instance.new("SpawnLocation")
	pad.Name = Config.SpawnPointName
	pad.Size = SPAWN_PAD_SIZE
	pad.Position = pos + Vector3.new(0, SPAWN_PAD_SIZE.Y / 2, 0)
	pad.Anchored = true
	pad.Neutral = true
	pad.Duration = 0
	pad.Transparency = 1
	pad.Parent = Workspace
	spawnPad = pad
	return pad
end

-- Per-player setup that must finish before the character loads: spawn at camp (also on respawn).
local function prepare(player: Player): boolean
	local pad = getSpawnPad()
	if pad == nil then
		warn(`[Spawn] world not ready; no camp spawn for {player.Name}`)
		return false
	end
	player.RespawnLocation = pad
	return true
end

local function loadCharacter(player: Player)
	if inFlight[player] then
		return
	end
	if player.Parent ~= Players or DataService.get(player) == nil then
		return
	end
	inFlight[player] = true
	prepare(player) -- respawns too: re-point at the camp pad if it was rebuilt
	local loaded = false
	for attempt = 0, Config.SPAWN_LOAD_RETRIES do
		if player.Parent ~= Players or not started then
			break
		end
		local ok, err = pcall(function()
			if
				RunService:IsStudio()
				and ReplicatedStorage:GetAttribute(Config.QAForceFailureAttribute)
					== Config.QAForceSpawn
			then
				error("QA forced spawn failure")
			end
			player:LoadCharacterAsync()
		end)
		if ok then
			loaded = true
			break
		end
		if attempt < Config.SPAWN_LOAD_RETRIES and player.Parent == Players then
			task.wait(Config.SPAWN_RETRY_DELAY * (attempt + 1))
		elseif player.Parent == Players then
			warn(`[Spawn] LoadCharacterAsync failed for {player.Name}: {tostring(err)}`)
		end
	end
	inFlight[player] = nil
	if not started or player.Parent ~= Players then
		return
	end
	if not loaded then
		-- Never strand the player in limbo: LoadFailed + kick (same path as a data load failure).
		DataService.failPlayer(player, Config.LoadFailKickMessage)
		return
	end
	player:SetAttribute(Config.ReadyAttribute, true)
end

-- Explicit respawn path (SurvivalService.respawn). inFlight makes a second call during a load a no-op.
function Spawn.respawn(player: Player)
	task.spawn(loadCharacter, player)
end

local function onDied(player: Player)
	diedConns[player] = nil
	if not autoRespawn then
		return -- run server: stay dead/spectating until SurvivalService.respawn (revive) or a new run
	end
	if respawning[player] ~= nil then
		return
	end
	respawning[player] = task.delay(Players.RespawnTime, function()
		respawning[player] = nil
		loadCharacter(player)
	end)
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", Config.SPAWN_HUMANOID_WAIT)
	if humanoid == nil or not humanoid:IsA("Humanoid") or player.Parent ~= Players then
		return
	end
	-- Connect Died before anything else yields so a fast death is never missed.
	local old = diedConns[player]
	if old ~= nil then
		old:Disconnect()
	end
	diedConns[player] = humanoid.Died:Once(function()
		onDied(player)
	end)
	if humanoid.Health <= 0 then
		local conn = diedConns[player]
		if conn ~= nil then
			conn:Disconnect()
		end
		onDied(player)
	end
	humanoid.WalkSpeed = Config.WALK_SPEED
end

local function onProfileLoaded(player: Player, _profile: DataService.Profile)
	if charConns[player] == nil then
		charConns[player] = player.CharacterAdded:Connect(function(character)
			task.spawn(watchCharacter, player, character)
		end)
	end
	loadCharacter(player)
end

local function onRemoving(player: Player)
	local conn = charConns[player]
	if conn ~= nil then
		conn:Disconnect()
		charConns[player] = nil
	end
	local died = diedConns[player]
	if died ~= nil then
		died:Disconnect()
		diedConns[player] = nil
	end
	local pending = respawning[player]
	if pending ~= nil then
		respawning[player] = nil
		task.cancel(pending)
	end
	inFlight[player] = nil
end

local function voidCheck()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if
			root ~= nil
			and root:IsA("BasePart")
			and humanoid ~= nil
			and humanoid.Health > 0
			and root.Position.Y < Config.VOID_KILL_Y
		then
			humanoid.Health = 0
		end
	end
end

function Spawn.stop()
	if disconnectLoaded ~= nil then
		disconnectLoaded()
		disconnectLoaded = nil
	end
	if playerRemovingConn ~= nil then
		playerRemovingConn:Disconnect()
		playerRemovingConn = nil
	end
	for player in charConns do
		onRemoving(player)
	end
	for player in diedConns do
		onRemoving(player)
	end
	for player in respawning do
		onRemoving(player)
	end
	table.clear(inFlight)
	if voidThread ~= nil then
		task.cancel(voidThread)
		voidThread = nil
	end
	if spawnPad ~= nil then
		spawnPad:Destroy()
		spawnPad = nil
	end
	started = false -- also makes any in-progress load-retry loop exit
end

-- Requires DataService.start() (and the spawn provider's world) to have run. Fires for already-loaded players too.
function Spawn.start()
	if started then
		return
	end
	started = true
	playerRemovingConn = Players.PlayerRemoving:Connect(onRemoving)
	disconnectLoaded = DataService.onLoaded(onProfileLoaded)
	voidThread = task.spawn(function()
		while true do
			task.wait(Config.VOID_CHECK_INTERVAL)
			voidCheck()
		end
	end)
end

return Spawn
