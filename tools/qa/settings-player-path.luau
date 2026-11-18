--!nocheck
-- QA scenario settings-player-path (brief 21): RUN mode, local player, three MCP calls in ONE play session:
--   1. SERVER datamodel: backup the meta profile fields (MetaQA), clear the Forge hint.     -> 1 line
--   2. CLIENT datamodel: real client handlers via the client bridge: reduce-scares toggle (server mirrors
--      the saved value back as Player ReduceScares), Forge placed through the ghost + E/Act completes the
--      Forge hint, touch placement label (no "[R] Rotate" text, Rotate button shown) vs PC.     -> 4 lines
--   3. SERVER datamodel again: profile hintsSeen.Forge persisted and settings back to the original,
--      then restore the backup.                                                                 -> 2 lines
-- Total <= 10 lines `PASS settings-player-path/check` / `FAIL settings-player-path/check: reason`.
local NAME = "settings-player-path"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local PHASE_ATTR = "QASettingsPhase"

local fails, passes = {}, {}
local function chk(check, ok, why)
	if ok then
		table.insert(passes, "PASS " .. NAME .. "/" .. check)
	else
		table.insert(fails, "FAIL " .. NAME .. "/" .. check .. ": " .. tostring(why))
	end
end

local function serverPart()
	local SS = game:GetService("ServerStorage")
	local Bridge = SS:WaitForChild(Config.Debug.BridgeName, 10)
	local function QA(fn, ...)
		return Bridge:Invoke("MetaQA", fn, ...)
	end
	local P
	for _ = 1, 40 do
		P = Players:GetPlayers()[1]
		if P and P:GetAttribute(Config.ReadyAttribute) and QA("read", P) then
			break
		end
		task.wait(0.5)
	end
	if SS:GetAttribute(PHASE_ATTR) ~= "client" then
		local ok = P ~= nil and QA("backup", P) and QA("clearHint", P, "Forge")
		if ok then
			SS:SetAttribute(PHASE_ATTR, "client")
			SS:SetAttribute("QASettingsReduce", QA("read", P).settings.reduceScares)
		end
		chk("server_setup", ok, "no player/profile")
		return
	end
	local data = P and QA("read", P)
	local original = SS:GetAttribute("QASettingsReduce")
	chk("hint_persisted", data ~= nil and data.hintsSeen.Forge == true, "profile hintsSeen.Forge not set")
	chk(
		"settings_restored_and_saved",
		data ~= nil and data.settings.reduceScares == original,
		`profile {data and tostring(data.settings.reduceScares)} original {tostring(original)}`
	)
	QA("restore", P)
	Bridge:Invoke("Meta", "pushState", P)
	SS:SetAttribute(PHASE_ATTR, nil)
	SS:SetAttribute("QASettingsReduce", nil)
end

local function clientPart()
	local P = Players.LocalPlayer
	for _ = 1, 40 do
		if P:GetAttribute(Config.ReadyAttribute) and P.Character and P.Character:FindFirstChild("HumanoidRootPart") then
			break
		end
		task.wait(0.5)
	end
	local bridge = P:WaitForChild("PlayerScripts"):WaitForChild(Config.Debug.ClientBridgeName, 10)
	local debugRemote = RS:WaitForChild(Config.RemoteFolderName):FindFirstChild("DebugCommand")
	local camp = Workspace:FindFirstChild(Config.World.CampFolderName)
	local fire = camp and camp:FindFirstChild(Config.Fire.Tag)
	if not (bridge and debugRemote and fire) then
		chk("setup", false, "bridge/debug/fire missing")
		return
	end
	local function C(fn, ...)
		return bridge:Invoke(fn, ...)
	end
	local attr = Config.Settings.ReduceScaresAttribute
	local function waitAttr(value)
		for _ = 1, 30 do
			if P:GetAttribute(attr) == value then
				return true
			end
			task.wait(0.1)
		end
		return false
	end

	-- 1. reduce-scares toggle through the real handler: server saves it and mirrors the attribute back
	local before = P:GetAttribute(attr) == true
	C("settingsToggle")
	local flipped = waitAttr(not before)
	local shown = C("settingsState")
	task.wait(Config.Net.SettingsRateInterval + 0.2)
	C("settingsToggle") -- back to the original value
	local back = waitAttr(before)
	chk(
		"reduce_scares_toggle_persists",
		flipped and shown.on == not before and string.find(shown.text, if before then "Off" else "On") and back,
		`flip {flipped} back {back} text '{shown.text}'`
	)

	-- 2. Forge hint completes on a real forge placement (ghost + E/Act), not on a timer
	C("hintReset", "Forge")
	for _ = 1, 8 do
		if (C("state").counts.Forge or 0) >= 1 then
			break
		end
		debugRemote:FireServer("give", "Forge")
		task.wait(Config.Debug.CommandRateInterval + 0.35)
	end
	local hrp = P.Character.HumanoidRootPart
	local fp = fire.Position
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(fp.X - 14, fp.Y + 3, fp.Z + 10)
	task.wait(0.4)
	local seenBefore = C("hintSeen", "Forge")
	C("selectItem", "Forge")
	task.wait(0.4)
	C("ghostAim", hrp.Position + Vector3.new(0, 0, -8))
	local g = C("ghostState")

	-- 3. touch placement label: no key text, Rotate button shown; PC shows "[R] Rotate"
	C("ghostTouch", true)
	local touch = C("ghostState")
	C("ghostTouch", false)
	local pc = C("ghostState")
	C("ghostTouch", nil)
	chk(
		"touch_placement_label",
		touch.ok and touch.label == "" and touch.rotateButton and pc.rotateButton == false and string.find(pc.label, "Rotate"),
		`touch '{touch.label}' btn {tostring(touch.rotateButton)} pc '{pc.label}' btn {tostring(pc.rotateButton)}`
	)

	C("action")
	local done = false
	for _ = 1, 40 do
		task.wait(0.1)
		if C("hintSeen", "Forge") then
			done = true
			break
		end
	end
	C("ghostAim", nil)
	chk(
		"forge_hint_completes_on_place",
		not seenBefore and g.ok and done,
		`seenBefore {seenBefore} ghost {g.ok} {g.reason} done {done}`
	)
	task.wait(Config.Net.HintRateInterval + 0.5) -- let the HintSeenRequest reach the server
end

local success, err = pcall(if RunService:IsServer() then serverPart else clientPart)
if not success then
	table.insert(fails, "FAIL " .. NAME .. "/error: " .. tostring(err))
end
local lines = {}
for _, l in fails do
	table.insert(lines, l)
end
for _, l in passes do
	table.insert(lines, l)
end
return table.concat(lines, "\n")
