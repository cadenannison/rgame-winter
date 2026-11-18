--!strict
-- Phase 3 client boot hook for brief 17 (Progression). init.client.luau calls start() once in run mode after
-- HudController.start() and must not yield. Starts: structure interactions (chest, door, cook, repair) on the
-- HUD's click / E / Act, the shared-chest panel, the ping wheel, the status strip (cold resistance, buffs,
-- underdressed warning) and the first-run hints for the new mechanics.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudConfig = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("HudConfig"))
local HudController =
	require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("HudController"))
local ProgressionHints =
	require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("ProgressionHints"))
local StatusHud = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("StatusHud"))
local StructureInteract =
	require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("StructureInteract"))
local Toast = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("Toast"))
local InventoryMirror =
	require(script.Parent.Parent:WaitForChild("Storage"):WaitForChild("InventoryMirror"))
local StorageController =
	require(script.Parent.Parent:WaitForChild("Storage"):WaitForChild("StorageController"))
local PingController =
	require(script.Parent.Parent:WaitForChild("Ping"):WaitForChild("PingController"))

local ProgressionClient = {}

local started = false
local cleanups: { () -> () } = {}

-- Server Notify kinds that confirm a hinted action.
local CONFIRM_KINDS: { [string]: string } = { cook = "cooked", repair = "repaired" }

function ProgressionClient.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "ProgressionHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = HudConfig.DisplayOrder + 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local mirror = InventoryMirror.start()
	local hints = ProgressionHints.start(gui, mirror)
	local interact = StructureInteract.new(mirror, Toast.show, hints.report)
	HudController.setInteractHook(interact)
	local storage = StorageController.start(mirror, hints.report)
	local ping = PingController.start(hints.report)
	local statusCleanup = StatusHud.start(gui)
	-- Studio-only QA: the same handlers the Q key / Ping button / wheel buttons and the chest panel use.
	HudController.addQA("pingOpen", ping.openWheelAt)
	HudController.addQA("pingSend", ping.send)
	HudController.addQA("chestOpen", storage.isOpen)
	table.insert(cleanups, statusCleanup)

	local connections: { RBXScriptConnection } = {}

	-- Real-action confirmations from the server: cooked and repaired.
	task.spawn(function()
		local ev = Remotes.event(Remotes.Notify)
		table.insert(
			connections,
			ev.OnClientEvent:Connect(function(kind: unknown)
				local event = if type(kind) == "string" then CONFIRM_KINDS[kind] else nil
				if event then
					hints.report(event)
				end
			end)
		)
	end)

	-- Placing any new structure completes its hint ("placed:<StructureId>") and confirms with a sound/toast
	-- from the server state (the part appears in Workspace.Structures with our OwnerUserId).
	task.spawn(function()
		local folder = Workspace:WaitForChild(Config.Build.FolderName, 30)
		if folder == nil then
			return
		end
		local function onChild(child: Instance)
			local id = child:GetAttribute(Config.Build.StructureAttribute)
			if
				type(id) == "string"
				and child:GetAttribute(Config.Build.OwnerAttribute) == player.UserId
			then
				hints.report(`placed:{id}`)
			end
		end
		table.insert(connections, folder.ChildAdded:Connect(onChild))
	end)

	table.insert(
		connections,
		gui.Destroying:Connect(function()
			started = false
		end)
	)
	table.insert(cleanups, function()
		HudController.setInteractHook(nil)
		interact.destroy()
		storage.destroy()
		ping.destroy()
		hints.destroy()
		mirror.destroy()
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
		gui:Destroy()
	end)
	gui.Parent = playerGui
end

function ProgressionClient.stop()
	for _, fn in cleanups do
		pcall(fn)
	end
	table.clear(cleanups)
	started = false
end

return ProgressionClient
