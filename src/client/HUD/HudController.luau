--!strict
-- Client HUD built in code. Read-only: displays MetersUpdate / InventoryUpdate / Workspace + Player
-- Attributes; sends intent only (SelectSlotRequest, GatherRequest, AttackRequest).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudMath = require(Shared:WaitForChild("logic"):WaitForChild("HudMath"))
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))
local DebugChat = require(script.Parent:WaitForChild("DebugChat"))

local HOTBAR_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local HudController = {}

local started = false

type Bar = { fill: Frame, label: TextLabel, name: string }
type Slot = { button: TextButton, name: TextLabel, count: TextLabel, stroke: UIStroke }

local function addCleanup(list: { () -> () }, fn: () -> ())
	table.insert(list, fn)
end

local function connect(
	list: { () -> () },
	signal: RBXScriptSignal,
	fn: (...any) -> ()
): RBXScriptConnection
	local c = signal:Connect(fn)
	addCleanup(list, function()
		c:Disconnect()
	end)
	return c
end

local function make<T>(className: string, props: { [string]: any }, parent: Instance?): T
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst :: any
end

local function constrain(parent: Instance, minSize: Vector2?, maxSize: Vector2?)
	make("UISizeConstraint", {
		MinSize = minSize or Vector2.new(0, 0),
		MaxSize = maxSize or Vector2.new(math.huge, math.huge),
	}, parent)
end

local function textProps(
	size: UDim2,
	position: UDim2,
	text: string,
	maxText: number
): { [string]: any }
	return {
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		Text = text,
		TextColor3 = HudConfig.TextColor,
		TextScaled = true,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		_maxText = maxText,
	}
end

local function makeLabel(parent: Instance, props: { [string]: any }): TextLabel
	local maxText = props._maxText :: number
	props._maxText = nil
	local label = make("TextLabel", props, parent) :: TextLabel
	make("UITextSizeConstraint", { MaxTextSize = maxText, MinTextSize = 8 }, label)
	return label
end

local function panel(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	anchor: Vector2
): Frame
	local f = make("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = HudConfig.PanelColor,
		BackgroundTransparency = HudConfig.PanelTransparency,
		BorderSizePixel = 0,
	}, parent) :: Frame
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, f)
	return f
end

function HudController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local cleanups: { () -> () } = {}
	local destroyed = false

	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = make("ScreenGui", {
		Name = HudConfig.GuiName,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = HudConfig.DisplayOrder,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	-- Stats (top-left): health, warmth, hunger.
	local stats =
		panel(gui, "Stats", UDim2.fromScale(0.3, 0.13), UDim2.fromScale(0.015, 0.02), Vector2.zero)
	constrain(stats, Vector2.new(150, 66), Vector2.new(300, 110))
	make("UIPadding", {
		PaddingTop = UDim.new(0.08, 0),
		PaddingBottom = UDim.new(0.08, 0),
		PaddingLeft = UDim.new(0.04, 0),
		PaddingRight = UDim.new(0.04, 0),
	}, stats)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0.04, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, stats)

	local bars: { [string]: Bar } = {}
	for i, key in { "health", "warmth", "hunger" } do
		local row = make("Frame", {
			Name = key,
			LayoutOrder = i,
			Size = UDim2.fromScale(1, 0.29),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, stats) :: Frame
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, row)
		local fill = make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = (HudConfig.BarColors :: { [string]: Color3 })[key],
			BorderSizePixel = 0,
		}, row) :: Frame
		local label = makeLabel(row, textProps(UDim2.fromScale(1, 1), UDim2.new(), key, 14))
		label.Name = "Label"
		label.ZIndex = 2
		bars[key] = { fill = fill, label = label, name = key }
	end

	-- Day counter (top-center).
	local dayPanel = panel(
		gui,
		"Day",
		UDim2.fromScale(0.2, 0.06),
		UDim2.fromScale(0.5, 0.02),
		Vector2.new(0.5, 0)
	)
	constrain(dayPanel, Vector2.new(80, 26), Vector2.new(180, 44))
	local dayLabel = makeLabel(
		dayPanel,
		textProps(UDim2.fromScale(1, 0.8), UDim2.fromScale(0, 0.1), "Day 1", 22)
	)

	-- Compass to camp (below the day counter).
	local compass = panel(
		gui,
		"Compass",
		UDim2.fromScale(0.1, 0.1),
		UDim2.fromScale(0.5, 0.09),
		Vector2.new(0.5, 0)
	)
	constrain(compass, Vector2.new(48, 48), Vector2.new(84, 84))
	make("UIAspectRatio", { AspectRatio = 1 }, compass)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, compass)
	local arrowHolder = make("Frame", {
		Name = "ArrowHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundTransparency = 1,
	}, compass) :: Frame
	local arrow = makeLabel(arrowHolder, textProps(UDim2.fromScale(1, 1), UDim2.new(), "^", 36))
	arrow.TextColor3 = HudConfig.AccentColor
	arrow.Font = Enum.Font.GothamBold
	local distLabel = makeLabel(
		compass,
		textProps(UDim2.fromScale(1, 0.26), UDim2.fromScale(0, 0.72), "camp", 12)
	)

	-- Hotbar (bottom-center), hint floats above it.
	local slotCount = Config.Inventory.HotbarSize
	local hotbar = make("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.98),
		Size = UDim2.fromScale(0.62, 0.1),
		BackgroundTransparency = 1,
	}, gui) :: Frame
	constrain(
		hotbar,
		Vector2.new(HudConfig.MinWidth, 0),
		Vector2.new(HudConfig.MaxWidth, math.huge)
	)
	make(
		"UIAspectRatio",
		{ AspectRatio = slotCount * 1.0, DominantAxis = Enum.DominantAxis.Width },
		hotbar
	)

	local slots: { [number]: Slot } = {}
	for i = 1, slotCount do
		local button = make("TextButton", {
			Name = `Slot{i}`,
			AutoButtonColor = true,
			Text = "",
			AnchorPoint = Vector2.zero,
			Position = UDim2.new((i - 1) / slotCount, 2, 0, 0),
			Size = UDim2.new(1 / slotCount, -4, 1, 0),
			BackgroundColor3 = HudConfig.PanelColor,
			BackgroundTransparency = HudConfig.PanelTransparency,
			BorderSizePixel = 0,
		}, hotbar) :: TextButton
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
		local stroke = make("UIStroke", {
			Color = HudConfig.SelectedColor,
			Thickness = 2,
			Enabled = false,
		}, button) :: UIStroke
		local keyLabel = makeLabel(
			button,
			textProps(UDim2.fromScale(0.35, 0.3), UDim2.fromScale(0.04, 0.03), tostring(i), 12)
		)
		keyLabel.TextTransparency = 0.4
		local nameLabel = makeLabel(
			button,
			textProps(UDim2.fromScale(0.9, 0.35), UDim2.fromScale(0.05, 0.3), "", 14)
		)
		local countLabel = makeLabel(
			button,
			textProps(UDim2.fromScale(0.6, 0.28), UDim2.fromScale(0.37, 0.68), "", 12)
		)
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		slots[i] = { button = button, name = nameLabel, count = countLabel, stroke = stroke }
		connect(cleanups, button.Activated, function()
			Remotes.event(Remotes.SelectSlotRequest):FireServer(i)
		end)
	end

	local hintLabel =
		makeLabel(hotbar, textProps(UDim2.fromScale(1, 0.55), UDim2.fromOffset(0, -6), "", 18))
	hintLabel.AnchorPoint = Vector2.new(0, 1)
	hintLabel.BackgroundTransparency = HudConfig.PanelTransparency
	hintLabel.BackgroundColor3 = HudConfig.PanelColor
	hintLabel.Visible = false
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, hintLabel)

	-- Mobile context action button (bottom-right): picks gather or attack from the nearest tagged target.
	local actionButton: TextButton? = nil
	if UserInputService.TouchEnabled then
		local b = make("TextButton", {
			Name = "Action",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(0.97, 0.9),
			Size = UDim2.fromScale(0.16, 0.16),
			BackgroundColor3 = HudConfig.AccentColor,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Text = "Act",
			TextColor3 = HudConfig.PanelColor,
			TextScaled = true,
			Font = Enum.Font.GothamBold,
		}, gui) :: TextButton
		constrain(
			b,
			Vector2.new(72, 72),
			Vector2.new(HudConfig.ActionButtonSize + 24, HudConfig.ActionButtonSize + 24)
		)
		make("UIAspectRatio", { AspectRatio = 1 }, b)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
		make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 10 }, b)
		actionButton = b
	end

	-- State mirrored from the server (display only).
	local meters = { health = 0, warmth = 0, hunger = 0, day = 1, isNight = false }
	local hasItems = false
	local shownHints: { [string]: boolean } = {}
	local hintUntil = 0.0
	local lastDist = -1
	local targetKind = "none"
	local targetInstance: Instance? = nil

	local function setSelected(selected: number)
		for i, slot in slots do
			slot.stroke.Enabled = i == selected
		end
	end

	local function applyMeters()
		local values = {
			health = Config.Meters.MaxHealth,
			warmth = Config.Meters.MaxWarmth,
			hunger = Config.Meters.MaxHunger,
		}
		for key, bar in bars do
			local v = (meters :: any)[key] :: number
			local frac = HudMath.fraction(v, (values :: any)[key])
			bar.fill.Size = UDim2.fromScale(frac, 1)
			bar.label.Text = `{bar.name} {math.floor(v + 0.5)}`
		end
		dayLabel.Text = if meters.isNight then `Day {meters.day} (night)` else `Day {meters.day}`
	end

	local function nodePosition(inst: Instance): Vector3?
		if inst:IsA("BasePart") then
			return inst.Position
		elseif inst:IsA("Model") then
			return inst:GetPivot().Position
		end
		return nil
	end

	local function pickTarget()
		targetKind, targetInstance = "none", nil
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local best = HudConfig.ActionRange
		local function scan(tag: string, kind: string)
			for _, inst in CollectionService:GetTagged(tag) do
				if inst ~= character then
					local pos = nodePosition(inst)
					if pos then
						local d = (pos - root.Position).Magnitude
						if d <= best then
							best, targetKind, targetInstance = d, kind, inst
						end
					end
				end
			end
		end
		scan(Config.Gather.NodeTag, "gather")
		scan(Config.Mobs.Tag, "attack")
	end

	if actionButton then
		local b = actionButton
		connect(cleanups, b.Activated, function()
			pickTarget()
			if targetKind == "gather" and targetInstance then
				Remotes.event(Remotes.GatherRequest):FireServer(targetInstance)
			elseif targetKind == "attack" and targetInstance then
				Remotes.event(Remotes.AttackRequest):FireServer(targetInstance)
			end
		end)
	end

	-- Server -> client updates. Remotes.event may yield, so connect from a spawned thread.
	task.spawn(function()
		local ev = Remotes.event(Remotes.MetersUpdate)
		if destroyed then
			return
		end
		connect(cleanups, ev.OnClientEvent, function(p: any)
			if
				type(p) ~= "table"
				or type(p.health) ~= "number"
				or type(p.warmth) ~= "number"
				or type(p.hunger) ~= "number"
			then
				return
			end
			meters.health, meters.warmth, meters.hunger = p.health, p.warmth, p.hunger
			meters.day = if type(p.day) == "number" then p.day else meters.day
			meters.isNight = p.isNight == true
			applyMeters()
		end)
	end)
	task.spawn(function()
		local ev = Remotes.event(Remotes.InventoryUpdate)
		if destroyed then
			return
		end
		connect(cleanups, ev.OnClientEvent, function(p: any)
			if type(p) ~= "table" or type(p.slots) ~= "table" then
				return
			end
			hasItems = false
			for i, slot in slots do
				local stack = p.slots[i]
				if type(stack) == "table" and type(stack.id) == "string" then
					slot.name.Text = stack.id
					slot.count.Text = if type(stack.count) == "number" and stack.count > 1
						then `x{stack.count}`
						else ""
					hasItems = true
				else
					slot.name.Text = ""
					slot.count.Text = ""
				end
			end
			if type(p.selected) == "number" then
				setSelected(p.selected)
			end
		end)
	end)

	connect(cleanups, player:GetAttributeChangedSignal(Config.Inventory.SlotAttribute), function()
		local v = player:GetAttribute(Config.Inventory.SlotAttribute)
		if type(v) == "number" then
			setSelected(v)
		end
	end)
	connect(cleanups, UserInputService.InputBegan, function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local idx = table.find(HOTBAR_KEYS, input.KeyCode)
		if idx and idx <= slotCount then
			Remotes.event(Remotes.SelectSlotRequest):FireServer(idx)
		end
	end)

	-- One visual loop: compass every frame, hints/action label at a low rate.
	local accumulator = 0.0
	connect(cleanups, RunService.RenderStepped, function(dt: number)
		local camera = Workspace.CurrentCamera
		local camp = Workspace:GetAttribute(HudConfig.CampAttribute)
		if camera and typeof(camp) == "Vector3" then
			local look = camera.CFrame.LookVector
			local offset = camp - camera.CFrame.Position
			arrowHolder.Rotation = HudMath.compassAngle(look.X, look.Z, offset.X, offset.Z)
			arrow.Visible = true
			local dist = math.floor(Vector3.new(offset.X, 0, offset.Z).Magnitude + 0.5)
			if dist ~= lastDist then
				lastDist = dist
				distLabel.Text = `{dist}`
			end
		else
			arrow.Visible = false
			distLabel.Text = "camp ?"
			lastDist = -1
		end

		accumulator += dt
		if accumulator < HudConfig.HintCheckInterval then
			return
		end
		accumulator = 0
		local now = os.clock()
		if hintLabel.Visible and now >= hintUntil then
			hintLabel.Visible = false
		end
		if not hintLabel.Visible then
			local id = HudMath.nextHint(HudConfig.Hints, shownHints, {
				warmth = meters.warmth,
				hunger = meters.hunger,
				health = meters.health,
				isNight = meters.isNight,
				hasItems = hasItems,
			})
			if id then
				shownHints[id] = true
				for _, hint in HudConfig.Hints do
					if hint.id == id then
						hintLabel.Text = hint.text
						hintLabel.Visible = true
						hintUntil = now + HudConfig.HintSeconds
					end
				end
			end
		end
		if actionButton then
			pickTarget()
			actionButton.Text = if targetKind == "gather"
				then "Gather"
				elseif targetKind == "attack" then "Attack"
				else "Act"
		end
	end)

	addCleanup(cleanups, DebugChat.start())

	local function teardown()
		if destroyed then
			return
		end
		destroyed = true
		for _, fn in cleanups do
			pcall(fn)
		end
		table.clear(cleanups)
		started = false
	end
	connect(cleanups, gui.Destroying, teardown)
	addCleanup(cleanups, function()
		gui:Destroy()
	end)

	applyMeters()
	gui.Parent = playerGui
end

return HudController
