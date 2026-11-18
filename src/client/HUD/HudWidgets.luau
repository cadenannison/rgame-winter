--!strict
-- HUD widget construction: stats bars (top-left), day counter, compass to camp, hotbar with item-name and
-- hint labels, and the mobile Act button. Builds Instances only; HudController owns all state and logic.

local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))
local HudKit = require(script.Parent:WaitForChild("HudKit"))

local make = HudKit.make
local constrain = HudKit.constrain
local textProps = HudKit.textProps
local makeLabel = HudKit.makeLabel
local panel = HudKit.panel

export type Slot = { button: TextButton, name: TextLabel, count: TextLabel, stroke: UIStroke }
export type Bar = { fill: Frame, label: TextLabel, name: string }
export type Widgets = {
	bars: { [string]: Bar },
	dayLabel: TextLabel,
	arrowHolder: Frame,
	arrow: TextLabel,
	distLabel: TextLabel,
	slotCount: number,
	slots: { [number]: Slot },
	itemLabel: TextLabel,
	hintLabel: TextLabel,
	actionButton: TextButton?,
}

local HudWidgets = {}

function HudWidgets.build(gui: ScreenGui): Widgets
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
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, compass)
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

	-- Hotbar (bottom-center); the selected item name floats above it, the reactive hint above that.
	local slotCount = Config.Inventory.HotbarSize
	local hotbar = make("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.98),
		Size = UDim2.fromScale(0.7, 0.1),
		BackgroundTransparency = 1,
	}, gui) :: Frame
	constrain(
		hotbar,
		Vector2.new(HudConfig.MinWidth, 0),
		Vector2.new(HudConfig.MaxWidth, math.huge)
	)
	make(
		"UIAspectRatioConstraint",
		{ AspectRatio = slotCount * 1.0, DominantAxis = Enum.DominantAxis.Width },
		hotbar
	)

	local slots: { [number]: Slot } = {}
	for i = 1, slotCount do
		local button = make("TextButton", {
			Name = `Slot{i}`,
			AutoButtonColor = true,
			Text = "",
			Position = UDim2.new((i - 1) / slotCount, 2, 0, 0),
			Size = UDim2.new(1 / slotCount, -4, 1, 0),
			BackgroundColor3 = HudConfig.PanelColor,
			BackgroundTransparency = HudConfig.PanelTransparency,
			BorderSizePixel = 0,
		}, hotbar) :: TextButton
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
		local stroke = make("UIStroke", {
			Color = HudConfig.SelectedColor,
			Thickness = 3,
			Enabled = false,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
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
	end

	local itemLabel =
		makeLabel(hotbar, textProps(UDim2.fromScale(0.6, 0.38), UDim2.new(0.2, 0, 0, -6), "", 18))
	itemLabel.Name = "ItemName"
	itemLabel.AnchorPoint = Vector2.new(0, 1)
	itemLabel.BackgroundTransparency = HudConfig.PanelTransparency
	itemLabel.BackgroundColor3 = HudConfig.PanelColor
	itemLabel.Font = Enum.Font.GothamBold
	itemLabel.Visible = false
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, itemLabel)

	local hintLabel =
		makeLabel(hotbar, textProps(UDim2.fromScale(1, 0.45), UDim2.new(0, 0, -0.45, -12), "", 18))
	hintLabel.AnchorPoint = Vector2.new(0, 1)
	hintLabel.BackgroundTransparency = HudConfig.PanelTransparency
	hintLabel.BackgroundColor3 = HudConfig.PanelColor
	hintLabel.Visible = false
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, hintLabel)

	-- Mobile context action button (bottom-right).
	local actionButton: TextButton? = nil
	if UserInputService.TouchEnabled then
		local b = make("TextButton", {
			Name = "Action",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(0.97, 0.78),
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
		make("UIAspectRatioConstraint", { AspectRatio = 1 }, b)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
		make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 10 }, b)
		actionButton = b
	end

	return {
		bars = bars,
		dayLabel = dayLabel,
		arrowHolder = arrowHolder,
		arrow = arrow,
		distLabel = distLabel,
		slotCount = slotCount,
		slots = slots,
		itemLabel = itemLabel,
		hintLabel = hintLabel,
		actionButton = actionButton,
	}
end

return HudWidgets
