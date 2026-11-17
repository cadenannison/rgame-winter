--!nocheck
-- QA spawn: run on the SERVER datamodel during Play (start_play, local player). Returns PASS/FAIL lines.
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.Config)
local out = {}
local function chk(name, ok, why)
	table.insert(out, ok and ("PASS " .. name) or ("FAIL " .. name .. ": " .. tostring(why)))
end
local P = Players:GetPlayers()[1]
for _ = 1, 40 do
	if P and P:GetAttribute(Config.ReadyAttribute) then
		break
	end
	task.wait(0.5)
	P = Players:GetPlayers()[1]
end
chk("player_exists", P ~= nil, "no player (server-only run?)")
if P then
	chk("autoload_off", Players.CharacterAutoLoads == false, "CharacterAutoLoads true")
	chk("ready", P:GetAttribute(Config.ReadyAttribute) == true, "Ready not true")
	local c = P.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	chk("char_exists", r ~= nil, "no character")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	chk("walkspeed", h ~= nil and h.WalkSpeed == Config.WALK_SPEED, h and h.WalkSpeed)
	chk("not_load_failed", P:GetAttribute(Config.LoadFailedAttribute) ~= true, "LoadFailed set")
	if h then
		h.Health = 0
		local t = 0
		repeat
			task.wait(0.5)
			t += 0.5
		until (P.Character ~= c and P.Character ~= nil) or t > Players.RespawnTime + 10
		chk("respawn", P.Character ~= nil and P.Character ~= c, "no new character after death")
	end
end
return table.concat(out, "\n")
