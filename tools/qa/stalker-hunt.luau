--!nocheck
-- QA scenario stalker-hunt (brief 18). Two parts, one MCP call each during Play (start_play, local player),
-- fresh run: SERVER datamodel first (~60 s), then the CLIENT datamodel. <= 6 lines per part,
-- `PASS stalker-hunt/check` / `FAIL stalker-hunt/check: reason` (FAILs first).
-- Server: isolation weighting (a lone player outweighs a grouped one; live solo weight = SoloBaseline) ->
-- forced hunt on a full-health player in the open strikes once and never kills -> after it retreats, a new
-- hunt whose target shelters in the camp fire never brings the Stalker inside the fire's warm radius.
-- Client: no Dread/hunt/timer value on Workspace, the player or the Stalker model.
local MAX_LINES = 6
local NAME = "stalker-hunt"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local S = Config.Stalker
local HIDDEN =
	{ "dread", "hunt", "timer", "countdown", "endsat", "isolation", "chance", "weight", "phase" }

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

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
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

local function stalkerModel()
	for _, m in CollectionService:GetTagged(S.Tag) do
		if m:IsA("Model") and m:IsDescendantOf(Workspace) then
			return m
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
	local Chunk, Survival, Stalker, Dread =
		api("Chunk"), api("Survival"), api("Stalker"), api("Dread")
	local Isolation = require(RS.Shared.logic.Isolation)
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

	-- 1. weighting: lone vs grouped (pure) and the live solo weight (server snapshot)
	local w = Isolation.weights({ { x = 0, z = 0 }, { x = 500, z = 0 }, { x = 505, z = 0 } }, 3)
	local live = Dread.snapshot().weights[1]
	chk(
		"lone_weighted_over_group",
		w[1] > w[2] and w[2] == w[3] and live == Config.Isolation.SoloBaseline,
		string.format("lone %.2f pair %.2f live %s", w[1], w[2], tostring(live))
	)

	-- 2. strike from full health is never lethal
	hrp.CFrame = CFrame.new(fp.X + warmR + 40, fp.Y + 4, fp.Z)
	Survival.heal(P, Config.Meters.MaxHealth)
	task.wait(Config.Dread.TickInterval + 0.3) -- fresh snapshot: player outside warmth
	Stalker.forceHunt()
	local started = waitFor(function()
		return Stalker.isHunting() and stalkerModel() ~= nil
	end, 3)
	local struck = waitFor(function()
		local m = Survival.getMeters(P)
		return m.health < Config.Meters.MaxHealth - 1
	end, S.TelegraphSeconds + 14)
	local m = Survival.getMeters(P)
	chk(
		"strike_not_lethal_from_full",
		started and struck and m.health > 0 and not m.downed and not m.dead,
		string.format("started %s struck %s hp %.0f", tostring(started), tostring(struck), m.health)
	)
	local ended = waitFor(function()
		return not Stalker.isHunting()
	end, S.RetreatSeconds + 6)
	chk("hunt_ends_after_strike", ended, "still hunting after retreat")

	-- 3. a sheltering target: the Stalker never enters the fire's warm radius
	hrp.CFrame = CFrame.new(fp.X + warmR + 10, fp.Y + 4, fp.Z)
	task.wait(Config.Dread.TickInterval + 0.3)
	Stalker.forceHunt()
	local again = waitFor(function()
		return Stalker.isHunting() and stalkerModel() ~= nil
	end, 3)
	hrp.CFrame = CFrame.new(fp.X + 3, fp.Y + 4, fp.Z)
	local h0 = Survival.getMeters(P).health
	local minD = math.huge
	for _ = 1, 160 do -- telegraph + a few seconds of chase
		task.wait(0.1)
		local model = stalkerModel()
		if model then
			minD = math.min(minD, flat(model:GetPivot().Position, fp))
		end
	end
	local h1 = Survival.getMeters(P).health
	chk(
		"stalker_stops_at_fire",
		again and minD > warmR and h1 >= h0 - 0.5,
		string.format(
			"hunt %s min dist %.1f warm %d hp %.0f->%.0f",
			tostring(again),
			minD,
			warmR,
			h0,
			h1
		)
	)
end

local function clientPart(chk)
	local P = Players.LocalPlayer
	local model = stalkerModel()
	local bad = hiddenAttr(Workspace) or hiddenAttr(P) or (model and hiddenAttr(model))
	chk("client_no_hidden_values", bad == nil, "attribute " .. tostring(bad))
	local remotes = RS:FindFirstChild(Config.RemoteFolderName)
	local leaky = nil
	for _, r in (remotes and remotes:GetChildren() or {}) do
		local lower = string.lower(r.Name)
		if string.find(lower, "dread", 1, true) or string.find(lower, "hunt", 1, true) then
			leaky = r.Name
		end
	end
	chk("no_hidden_remotes", leaky == nil, "remote " .. tostring(leaky))
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
