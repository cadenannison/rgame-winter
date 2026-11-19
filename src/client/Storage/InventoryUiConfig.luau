--!strict
-- UI-local constants for the backpack / equipment / chest panel (layout and colours). Gameplay numbers stay
-- in shared/Config (Inventory, Equipment, Storage).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UiConfig = {
	GuiName = "BackpackPanel",
	DisplayOrderOffset = 3, -- above HudConfig.DisplayOrder
	CellPx = 54, -- slot size (>= 44 so phone taps work; room for icon + name)
	MinCellPx = 44,
	GapPx = 4,
	PadPx = 10,
	HeaderPx = 22,
	TitlePx = 32,
	CloseButtonPx = 44,
	PanelWidthScale = 0.96,
	PanelMaxWidth = 1000,
	PanelMaxHeight = 760,
	PanelTopMarginPx = 8, -- gap under the Roblox top bar (the gui starts below it: ScreenInsets.TopbarSafeInsets)
	PanelBottomMarginPx = 8,
	HeaderTopPx = 4,
	HeaderGapPx = 6,
	TooltipPx = 44, -- item detail footer height
	TooltipNameMax = 16,
	TooltipInfoMax = 14,
	NameMaxPx = 12, -- slot name text: largest / smallest size NameFit will use
	NameMinPx = 8,
	NameFont = Enum.Font.SourceSansSemibold,
	IconBox = { X = 0.12, Y = 0.05, W = 0.76, H = 0.54 }, -- icon area inside a slot (fractions)
	NameBox = { X = 0.03, Y = 0.6, W = 0.94, H = 0.38 }, -- name area beneath the icon
	CountBox = { X = 0.4, Y = 0.02, W = 0.58, H = 0.26 }, -- stack count, top-right over the icon
	CaptionMaxChars = 2, -- captions longer than this (equipment labels) hide while a slot is occupied
	ViewportWidthPx = 120,
	ViewportHeightPx = 190,
	WideChestColumns = 3,
	DragThresholdPx = 8, -- pointer travel before a press becomes a drag
	GhostPx = 56,
	-- Button: right edge, under the HUD right-hand stack (Craft, Map, Settings), clear of Act and the jump button.
	ToggleButton = {
		WidthPx = 88,
		HeightPx = 44,
		TopPx = 166,
		RightScale = 0.985,
		Text = "Backpack",
	},
	ToggleKey = (Enum.KeyCode :: any)[Config.InventoryUi.ToggleKeyName] :: Enum.KeyCode, -- B only
	ChestKeyCode = Enum.KeyCode.E,
	PromptActionText = "Open",
	PromptObjectText = "Storage chest",
	FullHintY = 0.8,
	FullHintWidthPx = 200,
	FullHintHeightPx = 36,
	ShakeAmplitudePx = 7,
	ShakeFrequency = 55, -- radians per second
	ViewportFov = 30,
	ViewportCameraDistance = 9,
	ViewportCameraHeight = 0.6,
	Colors = {
		Panel = Color3.fromRGB(18, 28, 40),
		Slot = Color3.fromRGB(8, 12, 18),
		SlotSelected = Color3.fromRGB(120, 190, 230),
		Equip = Color3.fromRGB(34, 52, 70),
		Reject = Color3.fromRGB(220, 80, 70),
		Text = Color3.fromRGB(232, 242, 250),
		Dim = Color3.fromRGB(150, 170, 190),
		Hotbar = Color3.fromRGB(240, 200, 90),
	},
	SlotTransparency = 0.2,
	PanelTransparency = 0.04, -- near opaque: HUD stat bars must not show through
	Titles = {
		Backpack = "Backpack",
		Equipment = "Equipment",
		Hotbar = "Hotbar",
		Chest = "Storage chest",
	},
}

return UiConfig
