--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local HudController = require(script.HUD.HudController)
local NightFeedback = require(script.HUD.NightFeedback)
local LobbyController = require(script.Lobby.LobbyController)

local player = Players.LocalPlayer
local MODE_ATTRIBUTE = Config.Teleport.ServerModeAttribute

-- Client entry point. Build UI in code from Attributes; never trust or invent server state here.
print(`Client ready: {player.Name}`)

-- The server sets the mode at boot (before any character loads); wait briefly if it has not replicated.
local mode = Workspace:GetAttribute(MODE_ATTRIBUTE)
if mode == nil then
	local changed = Workspace:GetAttributeChangedSignal(MODE_ATTRIBUTE)
	local waiting = coroutine.running()
	local done = false
	local conn = changed:Connect(function()
		if not done then
			done = true
			task.spawn(waiting)
		end
	end)
	task.delay(Config.Teleport.ModeWaitSeconds, function()
		if not done then
			done = true
			task.spawn(waiting)
		end
	end)
	coroutine.yield()
	conn:Disconnect()
	mode = Workspace:GetAttribute(MODE_ATTRIBUTE)
end

if mode == Config.Teleport.ModeLobby then
	LobbyController.Start()
	-- Phase 4 boot hooks (each file owned by one brief; stubs until filled). See docs/INTEGRATION.md.
	require(script.Phase4.MetaClient).start(Config.Teleport.ModeLobby) -- brief 19
	require(script.Phase4.AtmosphereClient).start(Config.Teleport.ModeLobby) -- brief 20
else
	HudController.start()
	NightFeedback.start()
	require(script.HUD.DownedUi).start() -- downed banner, revive prompt, spectate + return to lobby
	-- Phase 3 boot hooks (each file owned by one brief; stubs until filled). See docs/INTEGRATION.md.
	require(script.Phase3.WorldGenClient).start() -- brief 13
	require(script.Phase3.EventsClient).start() -- brief 14
	require(script.Phase3.HorrorClient).start() -- brief 15
	require(script.Phase3.MobsClient).start() -- brief 16
	require(script.Phase3.ProgressionClient).start() -- brief 17
	LobbyController.Start() -- run summary screen (pad/menu views stay hidden outside the lobby)
	require(script.Phase4.MetaClient).start(Config.Teleport.ModeRun) -- brief 19
	require(script.Phase4.AtmosphereClient).start(Config.Teleport.ModeRun) -- brief 20
	require(script.Art.BiomeFx).start() -- art pass 2: per-biome atmosphere, grade, snow/wind
	require(script.Loot.ChestClient).start() -- loot chest glow/light/particles and the Open prompt
end
