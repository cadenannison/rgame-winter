--!nocheck
-- QA scenario studio-test-boot (runner style): run on the SERVER datamodel during a PLAIN Studio Test
-- (start_play, local player, NO Workspace.ServerMode preset, no /debug mode override) in ONE MCP call (~35 s).
-- Prints <= 8 lines: `PASS studio-test-boot/check` or `FAIL studio-test-boot/check: reason` (FAILs first).
-- Checks: lobby mode by default, profile loaded from the real Studio store (not the in-memory fallback),
-- Studio-scoped store name, player ready, and still connected after 30 s.
local NAME = "studio-test-boot"
local STAY_SECONDS = 30
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Bridge = game:GetService("ServerStorage"):WaitForChild(Config.Debug.BridgeName, 10)

local fails, passes = {}, {}
local function chk(check, ok, why)
	if ok then
		table.insert(passes, "PASS " .. NAME .. "/" .. check)
	else
		table.insert(fails, "FAIL " .. NAME .. "/" .. check .. ": " .. tostring(why))
	end
end

local function scenario()
	local P = Players:GetPlayers()[1]
	for _ = 1, 60 do
		if P and (P:GetAttribute(Config.ReadyAttribute) or P:GetAttribute(Config.LoadFailedAttribute)) then
			break
		end
		task.wait(0.5)
		P = Players:GetPlayers()[1]
	end
	if not P then
		chk("player_exists", false, "no local player (server-only run?)")
		return
	end
	local mode = Workspace:GetAttribute(Config.Teleport.ServerModeAttribute)
	chk("lobby_mode", mode == Config.Teleport.ModeLobby, "mode is " .. tostring(mode))
	local profile = Bridge:Invoke("Data", "get", P)
	chk("data_loaded", type(profile) == "table", "no profile in DataService")
	chk(
		"real_store_not_fallback",
		P:GetAttribute(Config.DataFallbackAttribute) ~= true,
		"in-memory fallback in use (see [Data] load failed line)"
	)
	chk("studio_store", Config.StudioStoreSuffix ~= "", "Studio store suffix is empty")
	chk("ready", P:GetAttribute(Config.ReadyAttribute) == true, "player never became Ready")
	local deadline = os.clock() + STAY_SECONDS
	local stayed = true
	while os.clock() < deadline do
		if P.Parent ~= Players or P:GetAttribute(Config.LoadFailedAttribute) then
			stayed = false
			break
		end
		task.wait(1)
	end
	chk("stays_connected_" .. STAY_SECONDS .. "s", stayed, "player removed or LoadFailed before 30 s")
end

local ok, err = pcall(scenario)
if not ok then
	table.insert(fails, "FAIL " .. NAME .. "/error: " .. tostring(err))
end
local lines = {}
for _, l in fails do
	table.insert(lines, l)
end
if #fails == 0 then
	table.insert(lines, "PASS " .. NAME .. " (" .. #passes .. "/" .. #passes .. ")")
end
print(table.concat(lines, "\n"))
