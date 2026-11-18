--!nocheck
-- QA scenario placement-preview: run on the CLIENT datamodel during Play (start_play, local player) in ONE
-- MCP call. Prints <= 10 lines `PASS placement-preview/check` or `FAIL placement-preview/check: reason`.
-- Drives the real HUD handlers through the Studio-only client bridge (ghostAim / ghostState / ghostRotate
-- are the QA hooks of the placement ghost; select / fuel are the real input handlers). Needs a lit camp
-- fire and daytime. Flow: select Workbench -> ghost up (no collision/query/scripts) -> green in range, red
-- out of range with readable reason, red "Too far from the fire" outside the build radius, R rotates ->
-- deselect removes it -> fire meter (FuelFraction + world bar) tracks fuel -> ring dots visible by day.
local MAX_LINES = 10
local NAME = "placement-preview"
local Players = game:GetService("Players")
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
	local function give(id, need)
		for _ = 1, 8 do
			if (C("state").counts[id] or 0) >= need then
				return
			end
			debugRemote:FireServer("give", id)
			task.wait(Config.Debug.CommandRateInterval + 0.35)
		end
	end
	local hrp = P.Character.HumanoidRootPart
	local function tp(pos)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = CFrame.new(pos) -- facing -Z
		task.wait(0.4)
	end
	local fp = fire.Position
	local row1 = F.Tiers[1]
	local ghostCfg = Config.Build.Ghost

	-- 1-2. ghost on select (green near the fire), harmless
	give("Workbench", 1)
	tp(Vector3.new(fp.X + 6, fp.Y + 3, fp.Z))
	C("ghostAim", hrp.Position + Vector3.new(0, 0, -8))
	local before = C("ghostState")
	C("selectItem", "Workbench")
	task.wait(0.4)
	local g = C("ghostState")
	chk(
		"ghost_on_select",
		before.exists == false and g.exists and g.visible,
		"before " .. tostring(before.exists) .. " after " .. tostring(g.exists)
	)
	chk(
		"ghost_inert",
		g.exists and g.collide == false and g.query == false and g.scripts == false,
		"collide "
			.. tostring(g.collide)
			.. " query "
			.. tostring(g.query)
			.. " scripts "
			.. tostring(g.scripts)
	)

	-- 3. green in range
	g = C("ghostState")
	chk(
		"green_in_range",
		g.ok and g.green and not g.red,
		"ok " .. tostring(g.ok) .. " reason " .. tostring(g.reason)
	)

	-- 4. red out of range with a readable reason (beyond reach)
	C("ghostAim", hrp.Position + Vector3.new(Config.Build.PlaceRange + 40, 0, 0))
	g = C("ghostState")
	chk(
		"red_out_of_range",
		(not g.ok) and g.red and g.text ~= "" and g.text ~= g.reason,
		"ok " .. tostring(g.ok) .. " text '" .. tostring(g.text) .. "'"
	)

	-- 5. within reach but outside the lit fire's build radius -> "Too far from the fire"
	tp(Vector3.new(fp.X + row1.BuildRadius + 30, fp.Y + 3, fp.Z))
	C("ghostAim", hrp.Position + Vector3.new(0, 0, -8))
	g = C("ghostState")
	chk(
		"red_reason_text",
		g.red and g.text == ghostCfg.ReasonText.OutOfBuildRange,
		"text '" .. tostring(g.text) .. "' reason " .. tostring(g.reason)
	)

	-- 6. rotate (R / button handler) steps by RotationStep
	local r0 = g.rotation
	C("ghostRotate")
	local r1 = C("ghostState").rotation
	chk(
		"rotate_steps",
		(r1 - r0) % 360 == Config.Build.RotationStep % 360,
		"rot " .. tostring(r0) .. " -> " .. tostring(r1)
	)

	-- 7. deselect destroys the ghost
	C("ghostAim", nil)
	C("selectItem", "Axe")
	task.wait(0.4)
	g = C("ghostState")
	chk("ghost_gone_on_deselect", g.exists == false, "exists " .. tostring(g.exists))

	-- 8. fire meter tracks fuel (attribute + world bar)
	tp(Vector3.new(fp.X + 4, fp.Y + 3, fp.Z))
	give("Wood", 1)
	local f0 = fire:GetAttribute(F.FuelFractionAttribute) or -1
	C("fuel", fire)
	task.wait(F.Meter.UpdateInterval + Config.Meters.TickInterval + 0.8)
	local f1 = fire:GetAttribute(F.FuelFractionAttribute) or -1
	local fuel = fire:GetAttribute(F.FuelAttribute) or 0
	local maxFuel = F.Tiers[fire:GetAttribute(F.TierAttribute) or 1].MaxFuelSeconds
	local bar
	for _, gui in P.PlayerGui:GetChildren() do
		if gui.Name == F.Meter.GuiName and gui:IsA("BillboardGui") and gui.Adornee == fire then
			bar = gui
		end
	end
	local fill = bar and bar:FindFirstChild("Fill", true)
	local fillX = fill and fill.Size.X.Scale or -1
	chk(
		"fire_meter_tracks_fuel",
		f1 > f0
			and math.abs(f1 - fuel / maxFuel) <= 0.03
			and bar ~= nil
			and bar.Enabled
			and math.abs(fillX - f1) <= 0.03,
		"f0 "
			.. f0
			.. " f1 "
			.. f1
			.. " fuel/max "
			.. fuel / maxFuel
			.. " bar "
			.. tostring(bar ~= nil)
			.. " fill "
			.. fillX
	)

	-- 9. ring dots stay under the day-visibility threshold at midday
	tp(Vector3.new(fp.X + row1.WarmRadius, fp.Y + 3, fp.Z))
	task.wait(1.3)
	local night = Workspace:GetAttribute(Config.Time.IsNightAttribute) == true
	local folder = Workspace:FindFirstChild(F.Ring.FolderName)
	local best = 2
	if folder then
		for _, dot in folder:GetChildren() do
			best = math.min(best, dot.Transparency)
		end
	end
	chk(
		"ring_visible_by_day",
		(not night) and best <= F.Ring.DayVisibilityMaxTransparency,
		"night "
			.. tostring(night)
			.. " min dot transparency "
			.. best
			.. " max "
			.. F.Ring.DayVisibilityMaxTransparency
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
