--!nocheck
-- QA scenario runner: run on the SERVER datamodel during Play (start_play, local player) in one MCP call.
-- Each scenario prints <= MAX_LINES lines: `PASS scenario/check` or `FAIL scenario/check: reason`.
-- FAILs are listed first; surplus PASS lines collapse into `PASS scenario/+N more`.
local MAX_LINES = 8
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Config = require(game.ReplicatedStorage.Shared.Config)

local SCENARIOS = {}

SCENARIOS.debug = function(chk)
	-- MCP code runs in another VM: reach the live DebugService through the Studio-only QA bridge.
	local Bridge = game:GetService("ServerStorage"):WaitForChild(Config.Debug.BridgeName, 10)
	local Debug = setmetatable({}, {
		__index = function(_, fn)
			return function(...)
				return Bridge:Invoke("Debug", fn, ...)
			end
		end,
	})
	local D = Config.Debug
	local P = Players:GetPlayers()[1]
	chk("player_exists", P ~= nil, "no player")
	if not P then
		return
	end
	chk("active_in_studio", Debug.isActive(), "inactive")
	local ok = Debug.run(P, "setDay", 7)
	chk("setDay", ok and Workspace:GetAttribute(D.WorldDayAttribute) == 7, "attribute not set")
	chk("setDay_rejects_bad", select(1, Debug.run(P, "setDay", -1)) == false, "accepted -1")
	Debug.run(P, "blizzard", true)
	chk("blizzard", Workspace:GetAttribute(D.WorldBlizzardAttribute) == true, "not set")
	Debug.run(P, "stalker", true)
	chk("stalker", Workspace:GetAttribute(D.WorldStalkerAttribute) == true, "not set")
	Debug.run(P, "invincible", true)
	chk("invincible", P:GetAttribute(D.PlayerInvincibleAttribute) == true, "not set")
	Debug.run(P, "invincible", false)
	Debug.run(P, "blizzard", false)
	Debug.run(P, "stalker", false)
	Debug.run(P, "setDay", 1)
end

local function runScenario(name, fn)
	local lines, fails, passes = {}, {}, {}
	local function chk(check, ok, why)
		if ok then
			table.insert(passes, "PASS " .. name .. "/" .. check)
		else
			table.insert(fails, "FAIL " .. name .. "/" .. check .. ": " .. tostring(why))
		end
	end
	local success, err = pcall(fn, chk)
	if not success then
		table.insert(fails, "FAIL " .. name .. "/error: " .. tostring(err))
	end
	for _, l in fails do
		if #lines < MAX_LINES then
			table.insert(lines, l)
		end
	end
	local room = MAX_LINES - #lines
	if #passes <= room then
		for _, l in passes do
			table.insert(lines, l)
		end
	elseif room > 0 then
		for i = 1, room - 1 do
			table.insert(lines, passes[i])
		end
		table.insert(lines, "PASS " .. name .. "/+" .. (#passes - room + 1) .. " more")
	end
	return lines
end

local out = {}
for name, fn in SCENARIOS do
	for _, l in runScenario(name, fn) do
		table.insert(out, l)
	end
end
return table.concat(out, "\n")
