--!nocheck
-- QA scenario night-danger (runner style): run on the SERVER datamodel during Play (start_play, local
-- player) in ONE MCP call. Prints <= 10 lines: `PASS night-danger/check` or `FAIL night-danger/check: reason`.
-- Flow: force night -> a wolf spawned near an exposed player outside the camp fire winds up (growl attr)
-- and bites (BiteSeq + health drop) -> player shelters inside the fire; the wolf never enters the warm
-- radius -> dawn: the wolf leaves and despawns.
local MAX_LINES = 10
local NAME = "night-danger"
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
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
local Chunk, Mob, Debug = api("Chunk"), api("Mobs"), api("Debug")
local N = Config.Night

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function waitFor(cond, seconds)
	local t = 0
	while t < seconds do
		if cond() then
			return true
		end
		task.wait(0.1)
		t += 0.1
	end
	return cond()
end

local function setNight(want)
	Debug.run(Players:GetPlayers()[1], "clockSpeed", Config.Time.DayLengthSeconds)
	local ok = waitFor(function()
		return (Workspace:GetAttribute(Config.Time.IsNightAttribute) == true) == want
	end, 12)
	Debug.run(Players:GetPlayers()[1], "clockSpeed", want and 1 or 1)
	return ok
end

local function scenario(chk)
	local P = Players:GetPlayers()[1]
	for _ = 1, 40 do
		if P and P:GetAttribute(Config.ReadyAttribute) and P.Character then
			break
		end
		task.wait(0.5)
		P = Players:GetPlayers()[1]
	end
	if not (P and P.Character and P.Character:FindFirstChild("HumanoidRootPart")) then
		chk("player_ready", false, "no ready local player (server-only run?)")
		return
	end
	local hrp = P.Character.HumanoidRootPart
	local hum = P.Character:FindFirstChildOfClass("Humanoid")
	local fire = Chunk.getCampFire()
	if not fire then
		chk("camp_fire", false, "no camp fire")
		return
	end
	local fp = fire.Position
	local warm = fire:GetAttribute(N.WarmRadiusAttribute) or Config.Fire.WarmRadius

	chk("night_set", setNight(true), "IsNight never true")
	hum.Health = hum.MaxHealth
	local xPlayer = fp.X + warm + N.RepelMargin + 20
	hrp.CFrame = CFrame.new(xPlayer, fp.Y + 4, fp.Z)
	local wolf = Mob.spawn("Wolf", Vector3.new(xPlayer + 12, fp.Y, fp.Z))
	if not wolf then
		chk("wolf_spawn", false, "spawn failed")
		return
	end
	local bite0 = P:GetAttribute(N.BiteAttribute) or 0
	chk(
		"wolf_windup",
		waitFor(function()
			return wolf.Parent and wolf:GetAttribute(N.WindupAttribute) == true
		end, 6),
		"no Windup attribute within 6s"
	)
	chk("wolf_bites", waitFor(function()
		return (P:GetAttribute(N.BiteAttribute) or 0) > bite0
	end, 6) and hum.Health < hum.MaxHealth and hum.Health > 0, "hp " .. math.floor(hum.Health))

	-- shelter inside the fire; the wolf must never come within the warm radius
	hrp.CFrame = CFrame.new(fp.X + 3, fp.Y + 4, fp.Z)
	local minD = math.huge
	for _ = 1, 80 do
		task.wait(0.1)
		if wolf.Parent then
			minD = math.min(minD, flat(wolf:GetPivot().Position, fp))
		end
	end
	chk("wolf_outside_radius", minD > warm, "min dist " .. math.floor(minD) .. " <= " .. warm)

	-- dawn: the wolf runs off and despawns
	chk("dawn_set", setNight(false), "IsNight never false")
	chk(
		"wolf_leaves_at_dawn",
		waitFor(function()
			return not wolf.Parent
		end, N.DawnLeaveSeconds + 4),
		"wolf still present"
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
