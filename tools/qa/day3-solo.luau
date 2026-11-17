--!nocheck
-- QA scenario day3-solo (runner style): run on the SERVER datamodel during Play (start_play, local player)
-- in ONE MCP call. Prints <= 8 lines: `PASS day3-solo/check` or `FAIL day3-solo/check: reason` (FAILs first).
-- Flow: spawn at camp -> gather wood -> fuel the camp fire -> craft + place a workbench -> 3 days at
-- DebugService clockSpeed -> a wolf at the fire edge retreats. Uses the services' request handlers
-- (handleGather/handleAddFuel/handleCraft/handlePlace), so every server validation runs.
local MAX_LINES = 8
local NAME = "day3-solo"
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Catalog = require(RS.Shared.ItemCatalog)
-- MCP code runs in another VM (fresh module copies), so live services are reached through
-- DebugService's Studio-only bridge: ServerStorage[Config.Debug.BridgeName]:Invoke(service, fn, ...).
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
local Chunk, Fire, Gather = api("Chunk"), api("Fire"), api("Gather")
local Inv, Craft, Place = api("Inventory"), api("Crafting"), api("Placement")
local Mob, Debug = api("Mobs"), api("Debug")

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
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
	local spawnPos = Chunk.getCampSpawnPosition()
	local fire = Chunk.getCampFire()

	-- 1. spawn at camp
	chk(
		"spawn_at_camp",
		spawnPos ~= nil and flat(hrp.Position, spawnPos) < 8,
		spawnPos and ("dist " .. math.floor(flat(hrp.Position, spawnPos))) or "no camp"
	)

	-- 2. gather wood from the nearest tree with the starter axe
	local tree, best = nil, math.huge
	for _, n in CollectionService:GetTagged(Config.Gather.NodeTag) do
		if n:GetAttribute(Catalog.NodeKindAttribute) == "Tree" and n:GetAttribute(Catalog.NodeDepletedAttribute) ~= true then
			local d = flat(n.Position, spawnPos)
			if d < best then
				tree, best = n, d
			end
		end
	end
	local wood0 = Inv.count(P, "Wood")
	if tree then
		hrp.CFrame = CFrame.new(tree.Position.X + 3, 4, tree.Position.Z)
		task.wait(0.3)
		for _ = 1, Config.Gather.HitsToDeplete do
			Gather.handleGather(P, tree)
			task.wait(math.max(Config.Gather.Cooldown, Config.Net.GatherRateInterval) + 0.05)
		end
	end
	local gained = Inv.count(P, "Wood") - wood0
	chk("gather_wood", gained == Config.Gather.TreeYield, tree and ("gained " .. gained) or "no tree node")

	-- 3. fuel the camp fire (spends 1 wood through FireService's wood spender)
	hrp.CFrame = CFrame.new(spawnPos.X, 4, spawnPos.Z)
	task.wait(0.3)
	local fuel0 = fire and fire:GetAttribute(Config.Fire.FuelAttribute) or 0
	local woodBefore = Inv.count(P, "Wood")
	if fire then
		Fire.handleAddFuel(P, fire)
	end
	local fuel1 = fire and fire:GetAttribute(Config.Fire.FuelAttribute) or 0
	chk(
		"fuel_fire",
		fire ~= nil and Inv.count(P, "Wood") == woodBefore - 1 and fuel1 > fuel0 + Config.Fire.WoodFuelSeconds - 5,
		"fuel " .. math.floor(fuel0) .. "->" .. math.floor(fuel1) .. " wood " .. woodBefore .. "->" .. Inv.count(P, "Wood")
	)

	-- 4. craft a workbench (QA top-up of materials beyond the one gathered tree)
	Inv.add(P, "Wood", 10)
	Inv.add(P, "Stone", 4)
	Craft.handleCraft(P, "Workbench")
	chk("craft_workbench", Inv.count(P, "Workbench") == 1, "workbench count " .. Inv.count(P, "Workbench"))

	-- 5. place it (grid snap, item spent, registered as a workbench)
	local benches0 = #CollectionService:GetTagged(Catalog.WorkbenchTag)
	Place.handlePlace(P, "Workbench", hrp.Position + Vector3.new(10.7, 0, 1.3), 37)
	local benches = CollectionService:GetTagged(Catalog.WorkbenchTag)
	local placed = benches[#benches]
	local snapped = placed and placed.Position.X % Config.Build.GridStep == 0 and placed.Position.Z % Config.Build.GridStep == 0
	chk(
		"place_workbench",
		#benches == benches0 + 1 and Inv.count(P, "Workbench") == 0 and snapped and Craft.availableTier(P) >= 1,
		"benches " .. benches0 .. "->" .. #benches .. " snapped " .. tostring(snapped) .. " tier " .. Craft.availableTier(P)
	)

	-- 6. three days at clockSpeed (1 day per real second), then hold at night
	local day0 = Workspace:GetAttribute(Config.Time.DayAttribute) or 1
	Debug.run(P, "clockSpeed", Config.Time.DayLengthSeconds)
	local t = 0
	while (Workspace:GetAttribute(Config.Time.DayAttribute) or 0) < day0 + 3 and t < 10 do
		task.wait(0.1)
		t += 0.1
	end
	while Workspace:GetAttribute(Config.Time.IsNightAttribute) ~= true and t < 12 do
		task.wait(0.05)
		t += 0.05
	end
	Debug.run(P, "clockSpeed", 1)
	local day = Workspace:GetAttribute(Config.Time.DayAttribute) or 0
	chk(
		"three_days",
		day >= day0 + 3 and hum.Health > 0 and P:GetAttribute(Config.Downed.StateAttribute) ~= true and Fire.isLit(fire),
		"day " .. day0 .. "->" .. day .. " hp " .. math.floor(hum.Health) .. " lit " .. tostring(fire and Fire.isLit(fire))
	)

	-- 7. a wolf inside the fire's repel edge at night retreats (FireService lit state)
	local fp = fire.Position
	local wolf = Mob.spawn("Wolf", Vector3.new(fp.X - (Config.Fire.RepelRadius - 3), 0, fp.Z))
	local d0 = wolf and flat(wolf:GetPivot().Position, fp) or 0
	local retreated, dMax = false, d0
	for _ = 1, 20 do
		task.wait(0.1)
		if wolf and wolf.Parent then
			retreated = retreated or Mob.getLastAction(wolf) == "Retreat"
			dMax = math.max(dMax, flat(wolf:GetPivot().Position, fp))
		end
	end
	chk("wolf_repelled", retreated, "no Retreat action within 2s")
	chk("wolf_moved_away", wolf ~= nil and dMax > d0 + 1, "dist " .. math.floor(d0) .. "->max " .. math.floor(dMax))
	if wolf and wolf.Parent then
		wolf:Destroy()
	end
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
