--!nocheck
-- QA scenario blizzard-survival (brief 18). Two parts, one MCP call each during Play (start_play, local
-- player), fresh run: run this file on the SERVER datamodel first, then on the CLIENT datamodel. Each part
-- prints <= 6 lines `PASS blizzard-survival/check` or `FAIL blizzard-survival/check: reason` (FAILs first).
-- Server: baseline warmth drain in the open -> force a blizzard (debug "blizzard", warning skipped with
-- clockSpeed) -> Blizzard flag on, warmth drains faster, mob budget multiplier > 1 and capped, live mobs
-- within Scaling.MaxLiveMobs -> shelter at the camp fire: warmth recovers, alive.
-- Client: the Blizzard flag replicated and the visibility cue (EventAtmosphere density) is up; no
-- countdown/schedule/hidden attribute visible on Workspace or the player.
local MAX_LINES = 6
local NAME = "blizzard-survival"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local HIDDEN = {
	"dread",
	"hunt",
	"timer",
	"countdown",
	"endsat",
	"nextevent",
	"isolation",
	"chance",
	"schedule",
}

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

local function hiddenAttr(inst)
	for name in inst:GetAttributes() do
		local lower = string.lower(name)
		for _, word in HIDDEN do
			if string.find(lower, word, 1, true) then
				return name
			end
		end
	end
	return nil
end

local function serverPart(chk)
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
	local Chunk, Mob, Debug, Survival, Events =
		api("Chunk"), api("Mobs"), api("Debug"), api("Survival"), api("Events")
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
	local hrp = P.Character.HumanoidRootPart
	local fire = Chunk.getCampFire()
	local fp = fire.Position
	local warmR = fire:GetAttribute(Config.Fire.WarmRadiusAttribute) or Config.Fire.WarmRadius
	local open = Vector3.new(fp.X + warmR + 25, fp.Y + 4, fp.Z)
	local function warmth()
		return Survival.getMeters(P).warmth
	end
	local function drainRate(seconds)
		hrp.CFrame = CFrame.new(open)
		task.wait(0.6)
		local w0, t0 = warmth(), os.clock()
		task.wait(seconds)
		return (w0 - warmth()) / (os.clock() - t0)
	end
	local nightBefore = Workspace:GetAttribute(Config.Time.IsNightAttribute)
	local base = drainRate(4)

	Debug.run(P, "blizzard", true)
	Debug.run(P, "clockSpeed", 20) -- skip the 45 s warning
	local on = waitFor(function()
		return Workspace:GetAttribute(Config.Blizzard.ActiveAttribute) == true
	end, 10)
	Debug.run(P, "clockSpeed", 1)
	chk("blizzard_active", on and Events.isBlizzard(), "Blizzard attribute never true")
	task.wait(2) -- let the intensity ramp
	local mods = Events.getModifiers()
	local storm = drainRate(4)
	local sameNight = Workspace:GetAttribute(Config.Time.IsNightAttribute) == nightBefore
	chk(
		"warmth_drain_up",
		mods.warmthDrain > 1 and storm > base * 1.05 and sameNight,
		string.format(
			"base %.2f/s storm %.2f/s mod %.2f night-same %s",
			base,
			storm,
			mods.warmthDrain,
			tostring(sameNight)
		)
	)
	local mult = Mob.getBudgetMultiplier()
	local live = #Mob.getLive()
	chk(
		"extra_mobs_capped",
		mult > 1
			and mult <= Config.Scaling.MaxSpawnMultiplier
			and live <= Config.Scaling.MaxLiveMobs,
		string.format("budget x%.2f live %d", mult, live)
	)
	hrp.CFrame = CFrame.new(fp.X + 4, fp.Y + 4, fp.Z)
	task.wait(0.6)
	local w0 = warmth()
	task.wait(4)
	local m = Survival.getMeters(P)
	chk(
		"survive_at_fire",
		m.warmth > w0 and m.health > 0 and not m.downed and not m.dead,
		string.format("warmth %.1f -> %.1f hp %.0f", w0, m.warmth, m.health)
	)
end

local function clientPart(chk)
	local P = Players.LocalPlayer
	local flag = waitFor(function()
		return Workspace:GetAttribute(Config.Blizzard.ActiveAttribute) == true
	end, 5)
	local atmo
	local up = waitFor(function()
		atmo = Lighting:FindFirstChild("EventAtmosphere")
		return atmo ~= nil and atmo.Density > 0.2
	end, 8)
	chk(
		"client_visibility_cue",
		flag and up,
		"flag "
			.. tostring(flag)
			.. " density "
			.. (atmo and string.format("%.2f", atmo.Density) or "none")
	)
	local bad = hiddenAttr(Workspace) or hiddenAttr(P)
	chk("client_no_hidden_values", bad == nil, "attribute " .. tostring(bad))
end

local lines, fails, passes = {}, {}, {}
local function chk(check, ok, why)
	if ok then
		table.insert(passes, "PASS " .. NAME .. "/" .. check)
	else
		table.insert(fails, "FAIL " .. NAME .. "/" .. check .. ": " .. tostring(why))
	end
end
local success, err = pcall(if RunService:IsServer() then serverPart else clientPart, chk)
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
