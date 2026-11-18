--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Characters load only after the profile is loaded (SpawnService); must be off before any player can load.
Players.CharacterAutoLoads = false

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ItemCatalog = require(ReplicatedStorage.Shared.ItemCatalog)
local TeleportData = require(ReplicatedStorage.Shared.logic.TeleportData)
local Guard = require(script.Net.Guard)
local DataService = require(script.Data.DataService)
local Spawn = require(script.Spawn.SpawnService)
local DebugService = require(script.Debug.DebugService)
local StudioMode = require(script.Debug.StudioMode)
local ChunkService = require(script.World.ChunkService)
local DayNightService = require(script.Survival.DayNightService)
local SurvivalService = require(script.Survival.SurvivalService)
local FireService = require(script.Survival.FireService)
local InventoryService = require(script.Items.InventoryService)
local CraftingService = require(script.Items.CraftingService)
local FoodService = require(script.Items.FoodService)
local PlacementService = require(script.Items.PlacementService)
local MobService = require(script.Mobs.MobService)
local PartyService = require(script.Party.PartyService)
local RunSetup = require(script.Party.RunSetup)
local TeleportAdapter = require(script.Party.TeleportAdapter)
local RunLifecycleService = require(script.Run.RunLifecycleService)
local Gallery = require(script.Art.Gallery)
local LobbyService = require(script.Lobby.LobbyService)
local DailyRewardService = require(script.Meta.DailyRewardService)

local TP = Config.Teleport

-- Server mode. Live: reserved servers (PartyService reserves them) are runs, public servers are the lobby.
-- Studio: a ServerMode attribute preset on Workspace in edit mode picks the mode, else the "/debug mode"
-- override saved by the last session, else StudioDefaultMode (lobby).
local function resolveMode(): string
	if RunService:IsStudio() then
		local preset = Workspace:GetAttribute(TP.ServerModeAttribute)
		if preset == TP.ModeLobby or preset == TP.ModeRun then
			return preset :: string
		end
		local override = StudioMode.read()
		if override ~= nil then
			warn(`[init] Studio mode override from /debug mode: {override}`)
			return override
		end
		return TP.StudioDefaultMode
	end
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		return TP.ModeRun
	end
	return TP.ModeLobby
end

local mode = resolveMode()
Workspace:SetAttribute(TP.ServerModeAttribute, mode)
local isLobby = mode == TP.ModeLobby

-- Make sure the remote folder and every remote exist before clients connect.
Remotes.createAll()
Players.PlayerRemoving:Connect(Guard.cleanup)

-- Profiles start loading at once (a run server may wait for its seed below); Spawn gates characters.
DataService.start()
DebugService.start() -- no-op outside Studio
StudioMode.start(DebugService.register, DebugService.run)
-- "/debug mode run|lobby|clear" (Studio only)
DebugService.register("gallery", Gallery.handle) -- "/debug gallery <set>" art review rows

-- Studio-only QA bridge targets shared by both modes (the bridge exists only in Studio; see DebugService).
DebugService.expose("Debug", DebugService)
DebugService.expose("Teleport", TeleportAdapter)
DebugService.expose("Data", DataService)
DebugService.expose("RunLifecycle", RunLifecycleService)
DebugService.expose("MetaQA", require(script.Debug.MetaQA)) -- profile backup/restore for meta QA

-- Run server: the first arriving player's validated teleport data carries the world seed. Studio has no
-- teleport data and uses the default seed. A timeout keeps the default; RunLifecycle refuses bad data.
local function waitForRunData(): TeleportData.TeleportData?
	if RunService:IsStudio() then
		return nil
	end
	local deadline = os.clock() + Config.Run.SeedWaitSeconds
	while os.clock() < deadline do
		for _, player in Players:GetPlayers() do
			local ok, joinData = pcall(function()
				return player:GetJoinData()
			end)
			if ok and type(joinData) == "table" then
				local parsed = Guard.teleportData(player, joinData.TeleportData, TP.ModeRun)
				if parsed then
					return parsed
				end
			end
		end
		task.wait(Config.Run.PollInterval)
	end
	warn("[init] no valid run teleport data before timeout; using the default seed")
	return nil
end

local function startLobby()
	-- Players spawn on the lodge spawn built by tools/build_lobby.luau.
	Spawn.setSpawnProvider(function(): Vector3?
		local root = Workspace:FindFirstChild(Config.Lobby.RootName)
		local spawn = root and root:FindFirstChild(Config.Lobby.SpawnName)
		if spawn and spawn:IsA("BasePart") then
			return spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0)
		end
		return nil
	end)
	DebugService.expose("Party", PartyService)
	DebugService.expose("Lobby", LobbyService)
	DebugService.expose("Daily", DailyRewardService)
	-- Studio-only QA: a solo run for the caller, ended at once, so the real RunSummary reaches the lobby UI.
	DebugService.register("runSummary", function(player: Player, _arg: unknown)
		local data = TeleportData.build(TP.ModeRun, 0, { player.UserId })
		if data and RunLifecycleService.debugBegin(data) then
			RunLifecycleService.debugEnd()
		end
	end)

	PartyService.Start()
	LobbyService.Start()
	DailyRewardService.Start()
	-- Phase 4 boot hooks (each file owned by one brief; stubs until filled). See docs/INTEGRATION.md.
	require(script.Phase4.MetaBoot).start(TP.ModeLobby) -- brief 19
	require(script.Phase4.AtmosphereBoot).start(TP.ModeLobby) -- brief 20
	-- Studio-only QA bridge targets for meta (tools/qa/meta-shop.luau).
	DebugService.expose("Meta", require(script.Meta.MetaService))
	DebugService.expose("Shop", require(script.Meta.ShopService))
	DebugService.expose("Receipt", require(script.Meta.ReceiptService))
	Spawn.start()
end

local function startRun()
	local runData = waitForRunData()
	if runData then
		RunSetup.applyRunData(runData) -- world seed; must precede ChunkService.start
	end
	-- The lodge is not part of a run.
	local lodge = Workspace:FindFirstChild(Config.Lobby.RootName)
	if lodge then
		lodge:Destroy()
	end

	-- Cross-system wiring (set before start so no request can arrive unwired).
	FireService.setWoodSpender(function(player: Player, amount: number): boolean
		return InventoryService.remove(player, "Wood", amount)
	end)
	FoodService.install()
	Spawn.setSpawnProvider(ChunkService.getCampSpawnPosition)
	local function shouldHold(player: Player): boolean
		return RunLifecycleService.ShouldHold(player.UserId)
	end
	SurvivalService.setHoldPredicate(shouldHold)
	InventoryService.setHoldPredicate(shouldHold)
	SurvivalService.setCauseHandler(function(_player: Player, cause: string)
		RunLifecycleService.SetCause(cause)
	end)
	MobService.setHitHandler(function(player: Player, kind: string)
		SurvivalService.markHit(player, kind)
	end)
	MobService.setKillHandler(function(player: Player, _kind: string, isBoss: boolean)
		RunLifecycleService.RecordKill(player, isBoss)
	end)

	DebugService.expose("Chunk", ChunkService)
	DebugService.expose("Fire", FireService)
	DebugService.expose("Survival", SurvivalService)
	DebugService.expose("Gather", require(script.Items.GatherService))
	DebugService.expose("Inventory", InventoryService)
	DebugService.expose("Crafting", CraftingService)
	DebugService.expose("Placement", PlacementService)
	DebugService.expose("Mobs", MobService)
	-- Phase 3 services for tools/qa (Studio-only bridge).
	DebugService.expose("Events", require(script.Events.EventService))
	DebugService.expose("Dread", require(script.Horror.DreadService))
	DebugService.expose("Stalker", require(script.Horror.StalkerService))
	DebugService.expose("Biome", require(script.World.BiomeService))
	DebugService.expose("Buffs", require(script.Items.BuffService))
	DebugService.expose("DayNight", DayNightService)

	-- Studio-only QA commands (DebugService validates the arg against ItemCatalog / Config.Debug.MobKinds).
	local DebugConfig = Config.Debug
	DebugService.register("give", function(player: Player, itemId: unknown)
		-- At most one stack: placeables stack to 1, so a bigger grant would flood the hotbar.
		local def = ItemCatalog.Items[itemId :: string]
		local count = if def then math.min(DebugConfig.GiveCount, def.maxStack) else 0
		InventoryService.add(player, itemId :: string, count)
	end)
	DebugService.register("spawnMob", function(player: Player, kind: unknown)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local at = root.Position + root.CFrame.LookVector * DebugConfig.SpawnMobDistance
			MobService.spawn(kind :: string, at - Vector3.new(0, DebugConfig.SpawnMobDrop, 0))
		end
	end)

	-- Start systems here, each exactly once. ChunkService before Spawn so the camp exists before any
	-- LoadCharacter; Spawn starts after every gameplay system so characters never load unwired.
	ChunkService.start() -- builds the camp chunk, camp fire, and registers tree/rock gather nodes
	require(script.Phase3.Wiring).apply() -- brief 18: Phase 3 cross-system setters (needs the run seed)
	DayNightService.start()
	SurvivalService.start()
	FireService.start()
	InventoryService.start()
	CraftingService.start() -- also starts GatherService
	PlacementService.start()
	MobService.start()
	-- Phase 3 boot hooks (each file owned by one brief; stubs until filled). See docs/INTEGRATION.md.
	require(script.Phase3.WorldGenBoot).start() -- brief 13
	require(script.Phase3.EventsBoot).start() -- brief 14
	require(script.Phase3.HorrorBoot).start() -- brief 15
	require(script.Phase3.MobsBoot).start() -- brief 16
	require(script.Phase3.ProgressionBoot).start() -- brief 17
	RunLifecycleService.Start()
	-- Phase 4 boot hooks (each file owned by one brief; stubs until filled). See docs/INTEGRATION.md.
	require(script.Phase4.MetaBoot).start(TP.ModeRun) -- brief 19
	require(script.Phase4.AtmosphereBoot).start(TP.ModeRun) -- brief 20
	-- brief 21: meta progress sources + run perk capture (needs MetaService started; before any spawn).
	require(script.Phase4.Wiring).apply(TP.ModeRun)
	DebugService.expose("Meta", require(script.Meta.MetaService))
	Spawn.start()
end

if isLobby then
	startLobby()
else
	startRun()
end

local function onPlayerAdded(player: Player)
	-- Per-player setup goes here.
	print(`Player ready: {player.Name} ({mode})`)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- PlayerAdded race: handle players who joined before this script ran.
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
