--!nocheck
-- QA scenario player-path: run on the CLIENT datamodel during Play (start_play, local player) in ONE
-- MCP call. Prints <= 10 lines `PASS player-path/check` or `FAIL player-path/check: reason` (FAILs first).
-- Drives the REAL client input handlers through the Studio-only client bridge
-- (PlayerScripts[Config.Debug.ClientBridgeName]:Invoke(fn, ...); see src/client/HUD/QABridge.luau),
-- so prediction, prompts, feedback and remotes run exactly as for keys/clicks/taps. Material top-up
-- and the hare spawn use the Studio-only DebugCommand remote (give / spawnMob).
-- Flow: select axe -> prompt says needs Axe on an empty hand -> chop a tree -> open crafting, craft a
-- campfire -> place it -> add wood -> catch a hare -> eat -> onboarding chain complete.
local MAX_LINES = 10
local NAME = "player-path"
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Catalog = require(RS.Shared.ItemCatalog)

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
	if not (bridge and debugRemote and P.Character) then
		chk(
			"setup",
			false,
			"bridge " .. tostring(bridge ~= nil) .. " debug " .. tostring(debugRemote ~= nil)
		)
		return
	end
	local function C(fn, ...)
		return bridge:Invoke(fn, ...)
	end
	local function dbg(name, arg)
		debugRemote:FireServer(name, arg)
		task.wait(Config.Debug.CommandRateInterval + 0.1)
	end
	local hrp = P.Character.HumanoidRootPart
	local function tp(pos)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = CFrame.new(pos)
		task.wait(0.25)
	end
	local function count(id)
		return C("state").counts[id] or 0
	end

	-- 1. select the axe (hotbar), wheel round-trip, held Tool in hand
	C("wheel", 1)
	task.wait(0.3)
	local wheeled = C("state").selected
	local axeSlot = C("selectItem", "Axe")
	task.wait(0.4)
	local st = C("state")
	chk(
		"select_axe",
		axeSlot ~= nil
			and wheeled ~= axeSlot
			and st.selected == axeSlot
			and st.held == "Axe"
			and st.itemName ~= "",
		"slot "
			.. tostring(axeSlot)
			.. " wheel "
			.. tostring(wheeled)
			.. " sel "
			.. tostring(st.selected)
			.. " held "
			.. tostring(st.held)
	)

	-- 2. go to the nearest live tree; empty hand shows "needs Axe", axe shows Chop
	local tree, best = nil, math.huge
	for _, n in CollectionService:GetTagged(Config.Gather.NodeTag) do
		if
			n:GetAttribute(Catalog.NodeKindAttribute) == "Tree"
			and n:GetAttribute(Catalog.NodeDepletedAttribute) ~= true
		then
			local d = flat(n.Position, hrp.Position)
			if d < best then
				tree, best = n, d
			end
		end
	end
	if not tree then
		chk("chop", false, "no tree node")
		return
	end
	tp(Vector3.new(tree.Position.X + 4, hrp.Position.Y, tree.Position.Z))
	C("selectSlot", Config.Inventory.HotbarSize) -- empty slot
	task.wait(0.4)
	local needs = C("state").prompt
	C("gather", tree) -- refused: server toast "Chop: needs Axe"
	task.wait(0.3)
	C("selectItem", "Axe")
	task.wait(0.4)
	local okPrompt = C("state").prompt
	chk(
		"prompt_tool",
		string.find(needs, "needs Axe", 1, true) ~= nil
			and string.find(okPrompt, "Chop", 1, true) ~= nil,
		"empty '" .. tostring(needs) .. "' axe '" .. tostring(okPrompt) .. "'"
	)

	-- 3. chop it down through the context action (click/E path)
	local wood0 = count("Wood")
	local actions = {}
	for _ = 1, Config.Gather.HitsToDeplete do
		table.insert(actions, C("action"))
		task.wait(math.max(Config.Gather.Cooldown, Config.Net.GatherRateInterval) + 0.1)
	end
	task.wait(0.3)
	local gained = count("Wood") - wood0
	chk(
		"chop",
		gained == Config.Gather.TreeYield,
		"gained " .. gained .. " actions " .. table.concat(actions, ",")
	)

	-- 4. open crafting (C path), craft a campfire (row click path)
	dbg("give", "Wood")
	dbg("give", "Stone")
	task.wait(0.3)
	C("toggleCraft")
	local open = C("state").craftOpen
	C("craft", "Campfire")
	task.wait(0.6)
	chk(
		"craft_campfire",
		open and count("Campfire") == 1,
		"open " .. tostring(open) .. " campfires " .. count("Campfire")
	)
	C("toggleCraft")

	-- 5. place it (selected placeable -> context action = place)
	C("selectItem", "Campfire")
	task.wait(0.4)
	local act = C("action")
	task.wait(0.8)
	local mine = nil
	for _, f in CollectionService:GetTagged(Config.Fire.Tag) do
		if f:GetAttribute(Config.Build.OwnerAttribute) == P.UserId then
			mine = f
		end
	end
	chk(
		"place_campfire",
		act == "place" and mine ~= nil and count("Campfire") == 0,
		"action " .. tostring(act) .. " fire " .. tostring(mine ~= nil)
	)

	-- 6. add wood to it (wood in hand next to the fire)
	if mine then
		tp(Vector3.new(mine.Position.X + 3, hrp.Position.Y, mine.Position.Z))
		C("selectItem", "Wood")
		task.wait(0.4)
		local fuel0 = mine:GetAttribute(Config.Fire.FuelAttribute) or 0
		local fact = C("action")
		task.wait(0.6)
		local fuel1 = mine:GetAttribute(Config.Fire.FuelAttribute) or 0
		chk(
			"add_wood",
			fact == "fuel" and fuel1 > fuel0 + Config.Fire.WoodFuelSeconds / 2,
			"action "
				.. tostring(fact)
				.. " fuel "
				.. math.floor(fuel0)
				.. "->"
				.. math.floor(fuel1)
		)
	end

	-- 7. catch a hare with the axe (attack handler; server recomputes reach and damage)
	C("selectItem", "Axe")
	task.wait(0.3)
	local meat0 = count("RawMeat")
	dbg("spawnMob", "ArcticHare")
	task.wait(0.5)
	local hare, hb = nil, math.huge
	for _, m in CollectionService:GetTagged(Config.Mobs.Tag) do
		if m:GetAttribute(Config.Mobs.KindAttribute) == "ArcticHare" then
			local d = flat(m:GetPivot().Position, hrp.Position)
			if d < hb then
				hare, hb = m, d
			end
		end
	end
	local swings = 0
	while
		hare
		and hare.Parent
		and CollectionService:HasTag(hare, Config.Mobs.Tag)
		and swings < 10
	do
		local hp = hare:GetPivot().Position
		tp(Vector3.new(hp.X + 4, hrp.Position.Y, hp.Z))
		C("attack", hare)
		swings += 1
		task.wait(Config.Combat.MeleeCooldown + 0.15)
	end
	task.wait(0.4)
	chk(
		"catch_hare",
		count("RawMeat") >= meat0 + Config.Mobs.Hare.DropCount,
		"hare " .. tostring(hare ~= nil) .. " swings " .. swings .. " meat " .. count("RawMeat")
	)

	-- 8. eat it (food in hand -> context action = eat)
	C("selectItem", "RawMeat")
	task.wait(0.4)
	local meatBefore = count("RawMeat")
	local eact = C("action")
	task.wait(0.6)
	chk(
		"eat",
		eact == "eat" and count("RawMeat") == meatBefore - 1,
		"action "
			.. tostring(eact)
			.. " meat "
			.. meatBefore
			.. "->"
			.. count("RawMeat")
			.. " hunger "
			.. tostring(C("state").hunger)
	)

	-- 9. onboarding chain finished by the real actions above
	local ob = C("state").onboarding
	chk("onboarding_done", ob == nil, "stuck at " .. tostring(ob))
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
