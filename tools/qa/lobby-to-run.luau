--!nocheck
-- QA scenario lobby-to-run (runner style): SERVER datamodel during Play in LOBBY mode (set Workspace
-- attribute ServerMode = "lobby" in edit mode before start_play; clear it afterwards). ONE MCP call.
-- Prints <= 10 lines `PASS lobby-to-run/check` or `FAIL lobby-to-run/check: reason` (FAILs first).
-- Uses the Studio fake TeleportAdapter (records calls, moves nobody). Flow: local player on pad 2 + a
-- simulated second member (QA bridge, UserId only) -> pad timer launches (fake teleport, mode run) ->
-- RunLifecycle starts a run from that teleport data with both ids (the absent one is held) -> a kill ->
-- run ends -> stats saved on the profile -> after the summary, fake teleport back to the lobby with both.
local MAX_LINES = 10
local NAME = "lobby-to-run"
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Achievements = require(RS.Shared.data.Achievements)
local Bridge = game:GetService("ServerStorage"):WaitForChild(Config.Debug.BridgeName, 10)
local function api(name)
	return setmetatable({}, {
		__index = function(_, fn)
			return function(...)
				return Bridge:Invoke(name, fn, ...)
			end
		end,
	})
end
local Party, Run, Teleport = api("Party"), api("RunLifecycle"), api("Teleport")
local Data = api("Data")
local PAD = 2
local FAKE_ID = 999000002 -- simulated second party member (never a present Player)

local function has(list, id)
	return table.find(list or {}, id) ~= nil
end

local function scenario(chk)
	if Workspace:GetAttribute(Config.Teleport.ServerModeAttribute) ~= Config.Teleport.ModeLobby then
		chk("lobby_mode", false, "server is not in lobby mode (preset Workspace.ServerMode)")
		return
	end
	local P = Players:GetPlayers()[1]
	for _ = 1, 40 do
		if P and P:GetAttribute(Config.ReadyAttribute) and P.Character then
			break
		end
		task.wait(0.5)
		P = Players:GetPlayers()[1]
	end
	if not (P and P.Character and P.Character:FindFirstChild("HumanoidRootPart")) then
		chk("player_ready", false, "no ready local player")
		return
	end
	local padPart
	for _, part in CollectionService:GetTagged(Config.Lobby.PadTag) do
		if part:GetAttribute(Config.Lobby.PadIndexAttribute) == PAD then
			padPart = part
		end
	end
	if not padPart then
		chk("pad_built", false, "no pad " .. PAD .. " (run tools/build_lobby.luau)")
		return
	end
	Teleport.clearStudioLog()

	-- 1. queue a two-player party on pad 2 (local player stands on it; second member simulated)
	P.Character:PivotTo(padPart.CFrame + Vector3.new(0, 3, 0))
	task.wait(0.3)
	-- Standing on the pad may already have joined through Touched; else use the server join.
	local joined = #Party.getPartyIds(P) > 0 or Party.join(P, PAD)
	local simJoined = Party.debugJoinId(PAD, FAKE_ID)
	task.wait(0.5)
	local pad = Party.getPad(PAD)
	chk(
		"party_of_two",
		joined and simJoined and pad and #pad.memberIds == 2 and pad.endsAt ~= nil,
		"join "
			.. tostring(joined)
			.. " sim "
			.. tostring(simJoined)
			.. " members "
			.. tostring(pad and #pad.memberIds)
	)

	-- 2. pad timer launches the party through the fake adapter (mode run, local player teleported)
	local launch
	for _ = 1, math.ceil((Config.Lobby.PadTimerSeconds + 5) / 0.5) do
		for _, call in Teleport.getStudioLog() do
			if call.data.mode == Config.Teleport.ModeRun then
				launch = call
			end
		end
		if launch then
			break
		end
		task.wait(0.5)
	end
	chk(
		"launch_teleport",
		launch ~= nil and has(launch.userIds, P.UserId) and has(launch.data.partyIds, P.UserId),
		launch and ("partyIds " .. #launch.data.partyIds) or "no run teleport within the pad timer"
	)
	if not launch then
		return
	end

	-- 3. run server view: start from that teleport data with both members; the absent one is held
	local data = {
		version = launch.data.version,
		mode = launch.data.mode,
		seed = launch.data.seed,
		partyIds = { P.UserId, FAKE_ID },
	}
	local began = Run.debugBegin(data)
	chk(
		"run_started",
		began and Run.GetStatus(P.UserId) == "alive" and Run.GetStatus(FAKE_ID) == "held",
		"began "
			.. tostring(began)
			.. " "
			.. tostring(Run.GetStatus(P.UserId))
			.. "/"
			.. tostring(Run.GetStatus(FAKE_ID))
	)

	-- 4. a kill, then the run ends; stats land on the loaded profile (DataService saves it)
	local before = Data.get(P)
	Run.RecordKill(P, false)
	local ended = Run.debugEnd()
	local results = Run.GetResults()
	local mine
	for _, entry in (results and results.players) or {} do
		if entry.userId == P.UserId then
			mine = entry
		end
	end
	chk(
		"run_ended",
		ended and results and results.kills == 1 and mine and mine.saved and mine.coinsEarned > 0,
		"ended "
			.. tostring(ended)
			.. " kills "
			.. tostring(results and results.kills)
			.. " players "
			.. tostring(results and #results.players)
	)
	chk(
		"held_member_no_payout",
		results and #results.players == 1,
		"payout rows " .. tostring(results and #results.players)
	)
	local after = Data.get(P)
	-- Phase 4: achievements unlocked by this run (e.g. "Together" for a party run) pay their own coins.
	local achievementCoins = 0
	for id in (after and after.achievements) or {} do
		if not (before and before.achievements[id]) and Achievements.ById[id] then
			achievementCoins += Achievements.ById[id].coins
		end
	end
	chk(
		"stats_saved",
		before
			and after
			and mine
			and after.runs == before.runs + 1
			and after.kills == before.kills + 1
			and after.coins
				== math.min(before.coins + mine.coinsEarned + achievementCoins, Config.MaxCoins),
		after and ("runs " .. after.runs .. " kills " .. after.kills .. " coins " .. after.coins)
			or "no profile"
	)

	-- 5. after the summary, both are sent back to the lobby (fake adapter, mode lobby)
	local back
	for _ = 1, math.ceil((Config.Run.SummarySeconds + 5) / 0.5) do
		for _, call in Teleport.getStudioLog() do
			if call.data.mode == Config.Teleport.ModeLobby then
				back = call
			end
		end
		if back then
			break
		end
		task.wait(0.5)
	end
	chk(
		"both_returned",
		back ~= nil
			and has(back.userIds, P.UserId)
			and has(back.data.partyIds, P.UserId)
			and has(back.data.partyIds, FAKE_ID),
		back and ("partyIds " .. table.concat(back.data.partyIds, ",")) or "no lobby teleport"
	)
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
