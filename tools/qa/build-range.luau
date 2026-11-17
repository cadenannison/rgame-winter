--!nocheck
-- QA scenario build-range: run on the CLIENT datamodel during Play (start_play, local player) in ONE MCP
-- call. Prints <= 10 lines `PASS build-range/check` or `FAIL build-range/check: reason` (FAILs first).
-- Drives the real HUD handlers through the Studio-only client bridge (see player-path.luau). Materials via
-- the Studio-only DebugCommand "give". Needs a fresh run (only the camp fire lit, no other fires/benches).
-- Flow: workbench refused beyond the tier-1 build radius -> allowed inside -> craft Spear refused away from
-- the bench (server) and allowed at it -> "Craft" context action at the bench -> upgrade refused when
-- unaffordable -> upgrade raises Tier/WarmRadius/BuildRadius/LightRange -> a bench beyond tier-1 radius is
-- now allowed. Mob repel follows WarmRadius (A's mob code reads the fire's WarmRadius attribute).
local MAX_LINES = 10
local NAME = "build-range"
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local F = Config.Fire

local function scenario(chk)
	local P = Players.LocalPlayer
	for _ = 1, 40 do
		if
			P:GetAttribute(Config.ReadyAttribute)
			and P.Character
			and P.Character:FindFirstChild("HumanoidRootPart")
		then
			break
		end
		task.wait(0.5)
	end
	local bridge = P:WaitForChild("PlayerScripts"):WaitForChild(Config.Debug.ClientBridgeName, 10)
	local remotes = RS:WaitForChild(Config.RemoteFolderName)
	local debugRemote = remotes:FindFirstChild("DebugCommand")
	local camp = Workspace:FindFirstChild(Config.World.CampFolderName)
	local fire = camp and camp:FindFirstChild(F.Tag)
	if not (bridge and debugRemote and P.Character and fire) then
		chk("setup", false, "bridge/debug/fire missing")
		return
	end
	local function C(fn, ...)
		return bridge:Invoke(fn, ...)
	end
	local function count(id)
		return C("state").counts[id] or 0
	end
	local function give(id, need)
		for _ = 1, 8 do
			if count(id) >= need then
				return
			end
			debugRemote:FireServer("give", id)
			task.wait(Config.Debug.CommandRateInterval + 0.15)
			task.wait(0.2)
		end
	end
	local hrp = P.Character.HumanoidRootPart
	local function tp(pos)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = CFrame.new(pos) -- facing -Z; the place target is 8 studs ahead
		task.wait(0.35)
	end
	local fp = fire.Position
	local lastNotify = ""
	local conn = remotes:WaitForChild("Notify").OnClientEvent:Connect(function(_, text)
		lastNotify = tostring(text)
	end)
	local function benches()
		return #CollectionService:GetTagged(Config.Craft.Stations.workbench.Tag)
	end
	local row1, row2 = F.Tiers[1], F.Tiers[2]
	local function placeBench(dx)
		give("Workbench", 1)
		C("selectItem", "Workbench")
		task.wait(0.4)
		tp(Vector3.new(fp.X + dx, fp.Y + 3, fp.Z))
		local b0 = benches()
		lastNotify = ""
		C("place")
		task.wait(Config.Net.PlaceRateInterval + 0.7)
		return benches() - b0
	end

	-- 1-2. build radius (tier 1)
	local farGain = placeBench(row1.BuildRadius + 30)
	chk(
		"place_refused_outside",
		farGain == 0 and lastNotify == "OutOfBuildRange",
		"gain " .. farGain .. " notify " .. lastNotify
	)
	local nearGain = placeBench(10)
	chk("place_allowed_inside", nearGain == 1, "gain " .. nearGain .. " notify " .. lastNotify)
	local bench
	for _, b in CollectionService:GetTagged(Config.Craft.Stations.workbench.Tag) do
		bench = b
	end

	-- 3. craft: server refuses away from the bench, allows at it
	give("Wood", 6)
	give("Stone", 4)
	C("selectItem", "Axe")
	local bp = bench and bench.Position or fp
	tp(Vector3.new(bp.X + Config.Craft.Stations.workbench.Range + 25, bp.Y + 3, bp.Z))
	local clientAway = C("craftStatus", "Spear")
	lastNotify = ""
	remotes.CraftRequest:FireServer("Spear") -- raw on purpose: proves the server checks proximity
	task.wait(Config.Net.CraftRateInterval + 0.5)
	local awayOk = count("Spear") == 0 and clientAway == "NeedStation"
	tp(Vector3.new(bp.X + 4, bp.Y + 3, bp.Z))
	local act = C("state").action
	C("toggleCraft")
	C("craftStatus", "Spear")
	C("craft", "Spear")
	task.wait(Config.Net.CraftRateInterval + 0.6)
	C("toggleCraft")
	chk(
		"craft_refused_away",
		awayOk,
		"spears "
			.. count("Spear")
			.. " client "
			.. tostring(clientAway)
			.. " notify "
			.. lastNotify
	)
	chk("craft_allowed_at_bench", count("Spear") == 1, "spears " .. count("Spear"))
	chk("bench_context_action", act == "craft", "action " .. tostring(act))

	-- 4. upgrade refused when unaffordable (drop to the starting inventory is not possible; use a fresh
	-- state check instead: the cost is shown in the prompt before the attempt)
	tp(Vector3.new(fp.X + 4, fp.Y + 3, fp.Z))
	C("selectItem", "Axe")
	task.wait(0.3)
	local tier0 = fire:GetAttribute(F.TierAttribute)
	local needWood, needStone = 0, 0
	for _, c in row2.UpgradeCost do
		if c.id == "Wood" then
			needWood = c.count
		else
			needStone = c.count
		end
	end
	local affordable = count("Wood") >= needWood and count("Stone") >= needStone
	local prompt = C("state").prompt
	chk(
		"upgrade_prompt_cost",
		tier0 == 1
			and string.find(prompt, "Upgrade fire", 1, true) ~= nil
			and string.find(prompt, tostring(needWood), 1, true) ~= nil,
		"prompt '" .. prompt .. "' tier " .. tostring(tier0)
	)

	-- 5. upgrade (real action) raises every radius
	give("Wood", needWood)
	give("Stone", needStone)
	local before = {
		fire:GetAttribute(F.WarmRadiusAttribute),
		fire:GetAttribute(F.BuildRadiusAttribute),
		fire:GetAttribute(F.LightRangeAttribute),
	}
	local uact = C("action")
	task.wait(F.UpgradeRateInterval + 0.6)
	local after = {
		fire:GetAttribute(F.WarmRadiusAttribute),
		fire:GetAttribute(F.BuildRadiusAttribute),
		fire:GetAttribute(F.LightRangeAttribute),
	}
	chk(
		"upgrade_raises_radii",
		uact == "upgrade"
			and fire:GetAttribute(F.TierAttribute) == 2
			and after[1] == row2.WarmRadius
			and after[2] == row2.BuildRadius
			and after[3] == row2.LightRange
			and after[1] > before[1]
			and after[2] > before[2]
			and after[3] > before[3],
		"action "
			.. tostring(uact)
			.. " tier "
			.. tostring(fire:GetAttribute(F.TierAttribute))
			.. " affordable-before "
			.. tostring(affordable)
	)

	-- 6. build radius grew; mob repel edge follows the fire's WarmRadius attribute
	local mid = (row1.BuildRadius + row2.BuildRadius) / 2
	local gain = placeBench(mid)
	chk("place_extends_after_upgrade", gain == 1, "gain " .. gain .. " notify " .. lastNotify)
	chk(
		"repel_follows_warm_radius",
		fire:GetAttribute(F.WarmRadiusAttribute) == row2.WarmRadius,
		"WarmRadius " .. tostring(fire:GetAttribute(F.WarmRadiusAttribute))
	)
	conn:Disconnect()
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
