--!strict
-- Lobby client entry. Start() builds the lobby ScreenGui (pads, side menu, summary) and returns a stop
-- function. init.client starts it in both modes: the pad and menu views show only in the lobby; in a run
-- server only the run summary appears. In a lobby server it also owns the Studio-only client QA bridge.
-- Read-only: renders PartyState / RunSummary / DailyClaimResult and server-published attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local LobbyLogic = require(Shared:WaitForChild("logic"):WaitForChild("LobbyLogic"))
local LobbyConfig = require(script.Parent.LobbyConfig)
local LobbyState = require(script.Parent.LobbyState)
local PadHud = require(script.Parent.PadHud)
local MenuPanels = require(script.Parent.MenuPanels)
local SummaryScreen = require(script.Parent.SummaryScreen)
local QABridge = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("QABridge"))

local LobbyController = {}

local stopFn: (() -> ())? = nil

function LobbyController.Start(): () -> ()
	if stopFn then
		return stopFn
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = LobbyConfig.GuiName
	gui.ResetOnSpawn = false
	gui.DisplayOrder = LobbyConfig.DisplayOrder
	gui.IgnoreGuiInset = false
	gui.Parent = playerGui

	local state = LobbyState.new(gui)
	local cleanups: { () -> () } = {}
	local qa: { [string]: any } = {}
	table.insert(cleanups, PadHud.start(gui, state, qa))
	table.insert(cleanups, MenuPanels.start(gui, state, qa))
	table.insert(cleanups, SummaryScreen.start(gui, state, qa))
	qa.lastToast = function(): string
		return state.lastToast
	end
	-- Run servers keep the HUD's bridge; only one client bridge exists at a time.
	if state.isLobby() then
		table.insert(cleanups, QABridge.start(qa))
	end

	local partyConn = Remotes.event(Remotes.PartyState).OnClientEvent
		:Connect(function(payload: unknown)
			state.setPads(LobbyLogic.parsePads(payload, Config.Lobby.PadCount))
		end)
	table.insert(cleanups, function()
		partyConn:Disconnect()
	end)

	local function stop()
		for _, fn in cleanups do
			fn()
		end
		table.clear(cleanups)
		state.destroy()
		gui:Destroy()
		stopFn = nil
	end
	gui.Destroying:Connect(function()
		stopFn = nil
	end)
	stopFn = stop
	return stop
end

return LobbyController
