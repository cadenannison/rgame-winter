--!strict
-- UI-local constants for the backpack / equipment / chest panel (layout and colours). Gameplay numbers stay
-- in shared/Config (Inventory, Equipment, Storage).

local UiConfig = {
	GuiName = "BackpackPanel",
	DisplayOrderOffset = 3, -- above HudConfig.DisplayOrder
	CellPx = 50, -- slot size (>= 44 so phone taps work)
	MinCellPx = 44,
	GapPx = 4,
	PadPx = 10,
	HeaderPx = 22,
	TitlePx = 32,
	CloseButtonPx = 44,
	PanelWidthScale = 0.96,
	PanelMaxWidth = 1000,
	PanelHeightScale = 0.8,
	PanelCenterY = 0.44,
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
	Keys = { Enum.KeyCode.B, Enum.KeyCode.Tab },
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
	SlotTransparency = 0.25,
	PanelTransparency = 0.08,
	Titles = {
		Backpack = "Backpack",
		Equipment = "Equipment",
		Hotbar = "Hotbar",
		Chest = "Storage chest",
	},
}

return UiConfig
