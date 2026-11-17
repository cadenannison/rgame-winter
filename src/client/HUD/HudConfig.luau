--!strict
-- HUD-local constants (visual layout, hints). Gameplay numbers stay in shared/Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Hint = { id: string, kind: string, threshold: number?, text: string }

local HudConfig = {
	-- Workspace attribute (Vector3) the server publishes for the camp position.
	CampAttribute = Config.World.CampAttribute,
	GuiName = "Hud",
	DisplayOrder = 5,
	-- Phone-safe: bars/hotbar scale with an aspect-locked, size-capped container.
	MinWidth = 280,
	MaxWidth = 520,
	BarColors = {
		health = Color3.fromRGB(214, 76, 76),
		warmth = Color3.fromRGB(240, 160, 70),
		hunger = Color3.fromRGB(120, 190, 110),
	},
	PanelColor = Color3.fromRGB(18, 28, 40),
	TextColor = Color3.fromRGB(232, 242, 250),
	AccentColor = Color3.fromRGB(120, 190, 230),
	SelectedColor = Color3.fromRGB(120, 190, 230),
	PanelTransparency = 0.35,
	ActionButtonSize = 96,
	ActionRange = 12, -- studs; client target pick only, server re-validates
	HintSeconds = 6,
	HintCheckInterval = 1,
	Hints = {
		{ id = "welcome", kind = "start", text = "Stay near the compass arrow to find camp." },
		{ id = "items", kind = "firstItem", text = "Pick a hotbar slot to equip it." },
		{
			id = "cold",
			kind = "warmthLow",
			threshold = 40,
			text = "You are freezing. Stand near a fire.",
		},
		{
			id = "hungry",
			kind = "hungerLow",
			threshold = 40,
			text = "Hungry. Eat food from your hotbar.",
		},
		{
			id = "night",
			kind = "night",
			text = "Night falls. Wolves hunt in the dark; stay by the fire.",
		},
		{
			id = "hurt",
			kind = "healthLow",
			threshold = 30,
			text = "Health is low. Warm up and eat to recover.",
		},
	} :: { Hint },
}

return HudConfig
