--!nocheck
-- QA scenario progression-player-path (brief 18): run on the CLIENT datamodel during Play (start_play,
-- local player) in ONE MCP call, fresh run, daytime. Prints <= 10 lines
-- `PASS progression-player-path/check` or `FAIL progression-player-path/check: reason` (FAILs first).
-- Drives the real client handlers through the Studio-only client bridge (HUD + storage/ping registered via
-- HudController.addQA); materials via the Studio-only DebugCommand "give".
-- Flow: place a Forge and a StorageChest through the ghost (green -> E/Act) -> open the chest with E/Act
-- (server OpenChest + panel) -> cook Raw Meat at the camp fire -> chop once, then repair the Axe at a
-- workbench -> ping through the wheel handler (marker appears).
local MAX_LINES = 10
local NAME = "progression-player-path"
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Catalog = require(RS.Shared.ItemCatalog)
local F = Config.Fire

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

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
			task.wait(Config.Debug.CommandRateInterval + 0.35)
		end
	end
	local notices = {}
	local conn = remotes:WaitForChild("Notify").OnClientEvent:Connect(function(kind, text)
		notices[tostring(kind)] = tostring(text)
	end)
	local hrp = P.Character.HumanoidRootPart
	local function tp(pos)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = CFrame.new(pos) -- facing -Z
		task.wait(0.4)
	end
	local fp = fire.Position
	local function tagged(tag)
		return #CollectionService:GetTagged(tag)
	end

	-- 1-2. place through the ghost: aim, green, then the E/Act context action
	local function placeVia(id, tag, dx, dz)
		give(id, 1)
		tp(Vector3.new(fp.X + dx, fp.Y + 3, fp.Z + dz))
		C("selectItem", id)
		task.wait(0.4)
		C("ghostAim", hrp.Position + Vector3.new(0, 0, -8))
		local g = C("ghostState")
		local n0 = tagged(tag)
		local act = C("action")
		task.wait(Config.Net.PlaceRateInterval + 0.8)
		C("ghostAim", nil)
		return g.ok and g.green and tagged(tag) == n0 + 1,
			string.format(
				"ghost ok %s reason %s action %s count %d->%d",
				tostring(g.ok),
				tostring(g.reason),
				tostring(act),
				n0,
				tagged(tag)
			)
	end
	local okForge, whyForge = placeVia("Forge", Config.Craft.Stations.forge.Tag, 12, 6)
	chk("place_forge_via_ghost", okForge, whyForge)
	-- The chest goes where no gather node is in prompt range (a tree there would take E/Act first).
	local spot, clearest = { 16, -6 }, -1
	for _, d in { { 16, -6 }, { 20, 14 }, { 0, 22 }, { -20, 14 }, { -12, 6 }, { -16, -6 } } do
		local p = Vector3.new(fp.X + d[1], 0, fp.Z + d[2] - 8)
		local near = math.huge
		for _, n in CollectionService:GetTagged(Config.Gather.NodeTag) do
			near = math.min(near, flat(n.Position, p))
		end
		if near > clearest then
			spot, clearest = d, near
		end
	end
	local okChest, whyChest = placeVia("StorageChest", Config.Build.StorageTag, spot[1], spot[2])
	chk("place_chest_via_ghost", okChest, whyChest)

	-- 3. open the chest with E/Act (empty hand)
	local chest
	for _, c in CollectionService:GetTagged(Config.Build.StorageTag) do
		chest = c
	end
	give("Wood", 4)
	if chest then
		local cp = if chest:IsA("Model") then chest:GetPivot().Position else chest.Position
		tp(Vector3.new(cp.X + 4, fp.Y + 3, cp.Z))
	end
	C("selectSlot", Config.Inventory.HotbarSize) -- empty hand (Wood would fuel the nearby fire first)
	task.wait(0.4)
	local prompt = C("state").prompt
	local act = C("action")
	local opened = false
	for _ = 1, 20 do
		task.wait(0.1)
		if P:GetAttribute(Config.Storage.OpenAttribute) and C("chestOpen") then
			opened = true
			break
		end
	end
	chk(
		"open_chest",
		chest ~= nil and opened,
		"prompt '"
			.. tostring(prompt)
			.. "' action "
			.. tostring(act)
			.. " attr "
			.. tostring(P:GetAttribute(Config.Storage.OpenAttribute))
	)

	-- 4. cook raw meat at the lit camp fire
	give("RawMeat", 1)
	tp(Vector3.new(fp.X + 3, fp.Y + 3, fp.Z))
	C("selectItem", "RawMeat")
	task.wait(0.4)
	local cookPrompt = C("state").prompt
	local cooked0 = count("CookedMeat")
	C("action")
	task.wait(Config.Net.CookRateInterval + 0.8)
	chk(
		"cook_at_fire",
		count("CookedMeat") == cooked0 + 1 and notices.cook ~= nil,
		"prompt '" .. tostring(cookPrompt) .. "' cooked " .. count("CookedMeat")
	)

	-- 5. chop once (Axe loses durability), then repair it at a workbench
	local tree, best = nil, math.huge
	for _, n in CollectionService:GetTagged(Config.Gather.NodeTag) do
		if
			n:GetAttribute(Catalog.NodeKindAttribute) == "Tree"
			and n:GetAttribute(Catalog.NodeDepletedAttribute) ~= true
		then
			local d = flat(n.Position, fp)
			if d < best then
				tree, best = n, d
			end
		end
	end
	C("selectItem", "Axe")
	if tree then
		tp(Vector3.new(tree.Position.X + 4, fp.Y + 3, tree.Position.Z))
		C("gather", tree)
		task.wait(math.max(Config.Gather.Cooldown, Config.Net.GatherRateInterval) + 0.3)
	end
	local okBench, whyBench = placeVia("Workbench", Config.Craft.Stations.workbench.Tag, 0, -14)
	give("Wood", 6)
	tp(Vector3.new(fp.X + 3, fp.Y + 3, fp.Z - 18)) -- beside the bench (placed 8 ahead of fp.Z - 14)
	C("selectItem", "Axe")
	task.wait(0.5)
	local repairPrompt = C("state").prompt
	notices.repair = nil
	C("action")
	task.wait(Config.Net.RepairRateInterval + 0.8)
	chk(
		"repair_at_bench",
		okBench and notices.repair ~= nil,
		"bench "
			.. tostring(okBench)
			.. " ("
			.. whyBench
			.. ") prompt '"
			.. tostring(repairPrompt)
			.. "'"
	)

	-- 6. ping through the wheel handler: a marker appears for the party (us)
	local function markers()
		local n = 0
		for _, g in P.PlayerGui:GetChildren() do
			if g.Name == "PingMarker" then
				n += 1
			end
		end
		return n
	end
	local m0 = markers()
	C("pingOpen", hrp.Position + Vector3.new(0, -3, -20)) -- no cursor in a script: aim like ghostAim
	C("pingSend", Config.Ping.Kinds[1])
	local pinged = false
	for _ = 1, 20 do
		task.wait(0.1)
		if markers() > m0 then
			pinged = true
			break
		end
	end
	chk("ping_marker", pinged, "markers " .. m0 .. " -> " .. markers())
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
