--!nocheck
-- QA scenario lobby-player-path: CLIENT datamodel during Play in LOBBY mode (Workspace attribute
-- ServerMode = "lobby" preset in edit mode; clear it afterwards), local player, ONE MCP call.
-- Prints <= 10 lines `PASS lobby-player-path/check` or `FAIL lobby-player-path/check: reason` (FAILs first).
-- Drives the REAL lobby client handlers through the Studio-only client bridge
-- (PlayerScripts[Config.Debug.ClientBridgeName], owned by LobbyController in lobby servers): pad
-- billboard Join, Leave, Daily claim and the summary's "Queue again". The run summary itself is sent by
-- the server's real RunSummary path via the Studio-only DebugCommand "runSummary".
local MAX_LINES = 10
local NAME = "lobby-player-path"
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(RS.Shared.Config)
local COINS = require(RS.Shared.logic.LobbyLogic).ATTR.Coins

local function waitFor(fn, seconds)
	local deadline = os.clock() + seconds
	repeat
		if fn() then
			return true
		end
		task.wait(0.2)
	until os.clock() > deadline
	return fn()
end

local function scenario(chk)
	local P = Players.LocalPlayer
	if Workspace:GetAttribute(Config.Teleport.ServerModeAttribute) ~= Config.Teleport.ModeLobby then
		chk("lobby_mode", false, "not a lobby server (preset Workspace.ServerMode)")
		return
	end
	waitFor(function()
		return P:GetAttribute(Config.ReadyAttribute)
			and P.Character
			and P.Character:FindFirstChild("HumanoidRootPart")
			and P:GetAttribute(COINS) ~= nil
	end, 20)
	local bridge = P:WaitForChild("PlayerScripts"):WaitForChild(Config.Debug.ClientBridgeName, 10)
	local debugRemote = RS:WaitForChild(Config.RemoteFolderName):FindFirstChild("DebugCommand")
	local gui = P:WaitForChild("PlayerGui"):FindFirstChild("Lobby")
	if not (bridge and debugRemote and gui and P.Character) then
		chk(
			"setup",
			false,
			"bridge "
				.. tostring(bridge ~= nil)
				.. " debug "
				.. tostring(debugRemote ~= nil)
				.. " gui "
				.. tostring(gui ~= nil)
		)
		return
	end
	local function C(fn, ...)
		return bridge:Invoke(fn, ...)
	end
	local hrp = P.Character.HumanoidRootPart
	local home = hrp.CFrame
	local menu = gui:FindFirstChild("Menu")
	chk("lobby_ui", menu ~= nil and menu.Visible, "menu " .. tostring(menu and menu.Visible))

	-- 1. billboard Join from the spawn (not on the pad): server walks the player onto pad 3
	C("joinPad", 3)
	local joined = waitFor(function()
		return C("myPad") == 3
	end, 3)
	chk("join_pad", joined, "PadIndex " .. tostring(C("myPad")))
	chk(
		"pad_panel",
		joined and C("padPanelVisible") and string.find(C("padTitle"), "Pad 3") ~= nil,
		"panel " .. tostring(C("padPanelVisible")) .. " '" .. tostring(C("padTitle")) .. "'"
	)

	-- 2. Leave (Q / Leave button handler), then step off so Touched cannot rejoin
	C("leavePad")
	task.wait(0.3)
	hrp.CFrame = home
	local left = waitFor(function()
		return C("myPad") == 0
	end, 3)
	chk("leave_pad", left, "PadIndex " .. tostring(C("myPad")))

	-- 3. Daily claim (G / Daily button handler): once per UTC day, coins come from the server
	local ready = C("dailyReady")
	local coins = P:GetAttribute(COINS)
	C("claimDaily")
	if ready then
		local paid = waitFor(function()
			return P:GetAttribute(COINS) == coins + Config.Meta.DailyRewardCoins
		end, 6)
		chk(
			"daily_claim",
			paid and string.find(C("lastToast"), "Daily reward: %+") ~= nil,
			"coins "
				.. tostring(coins)
				.. "->"
				.. tostring(P:GetAttribute(COINS))
				.. " toast '"
				.. C("lastToast")
				.. "'"
		)
	else
		task.wait(1.5) -- a stale pad toast would land here
		chk(
			"daily_claim",
			string.find(C("lastToast"), "Already claimed") ~= nil and P:GetAttribute(COINS) == coins,
			"already claimed today; toast '" .. C("lastToast") .. "' coins " .. tostring(coins)
		)
	end
	waitFor(function()
		return not C("dailyReady")
	end, 4)
	C("claimDaily")
	chk(
		"daily_once",
		not C("dailyReady") and string.find(C("lastToast"), "Already claimed") ~= nil,
		"toast '" .. C("lastToast") .. "'"
	)

	-- 4. Run summary arrives (server RunSummary path) and offers Queue again in the lobby
	debugRemote:FireServer("runSummary")
	local shown = waitFor(function()
		return C("summary").visible
	end, 4)
	local summary = C("summary")
	chk(
		"summary_shown",
		shown and summary.requeueEnabled and string.find(summary.requeueText, "Queue again") ~= nil,
		"visible " .. tostring(summary.visible) .. " '" .. tostring(summary.requeueText) .. "'"
	)

	-- 5. Queue again (R / button handler): joins a free pad for real
	C("requeue")
	local queued = waitFor(function()
		return C("myPad") > 0
	end, 3)
	chk(
		"queue_again",
		queued and not C("summary").visible,
		"PadIndex " .. tostring(C("myPad")) .. " summary " .. tostring(C("summary").visible)
	)
	C("leavePad")
	task.wait(0.3)
	hrp.CFrame = home
end

local lines, fails, passes = {}, {}, {}
local function chk(check, ok, why)
	if ok then
		table.insert(passes, "PASS " .. NAME .. "/" .. check)
	else
		table.insert(fails, "FAIL " .. NAME .. "/" .. check .. ": " .. tostring(why))
	end
end
local success, err = pcall(scenario, chk)
if not success then
	table.insert(fails, "FAIL " .. NAME .. "/error: " .. tostring(err))
end
for _, l in fails do
	if #lines < MAX_LINES then
		table.insert(lines, l)
	end
end
for _, l in passes do
	if #lines < MAX_LINES then
		table.insert(lines, l)
	end
end
return table.concat(lines, "\n")
