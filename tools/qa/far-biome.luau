--!nocheck
-- QA scenario far-biome (brief 18, runner style): run on the SERVER datamodel during Play (start_play,
-- local player) in ONE MCP call, fresh run, daytime. Prints <= 6 lines `PASS far-biome/check` or
-- `FAIL far-biome/check: reason` (FAILs first).
-- Flow: warmth drain in the open start forest (ring 0) -> debug teleportRing to the deep tundra (ring 3):
-- BiomeRing attribute follows, an underdressed player drains much faster -> carry tier-3 clothing:
-- ColdResistance rises to the ring's requirement and the drain drops to a survivable rate.
local MAX_LINES = 6
local NAME = "far-biome"
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Clothing = require(RS.Shared.data.Clothing)
local Biomes = require(RS.Shared.data.Biomes)
local SURVIVABLE_SECONDS = 120 -- full warmth must last at least this long dressed for the ring

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

local function scenario(chk)
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
	local Chunk, Debug, Survival, Inventory =
		api("Chunk"), api("Debug"), api("Survival"), api("Inventory")
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
	local function rate(seconds)
		Survival.warm(P, Config.Meters.MaxWarmth)
		task.wait(0.6)
		local w0, t0 = Survival.getMeters(P).warmth, os.clock()
		task.wait(seconds)
		return (w0 - Survival.getMeters(P).warmth) / (os.clock() - t0)
	end

	-- ring 0 baseline in the open
	hrp.CFrame = CFrame.new(fp.X + warmR + 25, fp.Y + 4, fp.Z)
	local base = rate(3)

	-- deep tundra, underdressed
	local outer = #Biomes.List - 1
	Debug.run(P, "teleportRing", outer + 1) -- debug rings are 1-based
	local arrived = waitFor(function()
		return P:GetAttribute(Config.Biome.RingAttribute) == outer
	end, 6)
	task.wait(1) -- land
	local res0 = P:GetAttribute(Config.Biome.ColdResistanceAttribute) or 0
	local under = rate(3)
	chk(
		"underdressed_drains_faster",
		arrived and res0 == 0 and under > base * 2,
		string.format(
			"ring %s res %s base %.2f/s outer %.2f/s",
			tostring(P:GetAttribute(Config.Biome.RingAttribute)),
			tostring(res0),
			base,
			under
		)
	)

	-- tier clothing: one piece per slot of the top tier
	local pieces = Clothing.Pieces[#Clothing.Pieces]
	for _, slot in Config.Clothing.Slots do
		Inventory.add(P, pieces[slot], 1)
	end
	local need = Biomes.List[outer + 1].requiredColdResistance
	local dressed = waitFor(function()
		return (P:GetAttribute(Config.Biome.ColdResistanceAttribute) or 0) >= need
	end, Config.Biome.UpdateInterval + 3)
	chk(
		"clothing_sets_resistance",
		dressed,
		"ColdResistance "
			.. tostring(P:GetAttribute(Config.Biome.ColdResistanceAttribute))
			.. " need "
			.. need
	)
	local dressedRate = rate(3)
	local lasts = if dressedRate > 0 then Config.Meters.MaxWarmth / dressedRate else math.huge
	chk(
		"dressed_survivable",
		dressedRate < under * 0.6 and lasts >= SURVIVABLE_SECONDS,
		string.format("dressed %.2f/s (warmth lasts %.0fs) vs %.2f/s", dressedRate, lasts, under)
	)
	local m = Survival.getMeters(P)
	chk("alive", m.health > 0 and not m.dead, "hp " .. m.health)
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
