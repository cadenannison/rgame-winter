--!strict
-- Lobby-client constants (layout, colours, keys, copy). Gameplay numbers stay in shared/Config.

return {
	GuiName = "Lobby",
	DisplayOrder = 6,
	MinButton = 44, -- px; phone-safe touch target
	PanelColor = Color3.fromRGB(18, 28, 40),
	PanelTransparency = 0.15,
	TextColor = Color3.fromRGB(232, 242, 250),
	MutedColor = Color3.fromRGB(140, 158, 174),
	AccentColor = Color3.fromRGB(120, 190, 230),
	GoodColor = Color3.fromRGB(110, 190, 120),
	DisabledColor = Color3.fromRGB(52, 62, 74),
	ButtonColor = Color3.fromRGB(44, 74, 104),
	PanelMaxSize = Vector2.new(420, 380),
	PadPanelMaxSize = Vector2.new(340, 230),
	MenuWidth = 96,
	PadTimerColor = Color3.fromRGB(255, 205, 110),
	BillboardSize = Vector2.new(170, 130),
	BillboardOffset = Vector3.new(0, 7, 0),
	BillboardMaxDistance = 150,
	BoardRefreshSeconds = 1, -- hub boards redraw only when their content changed
	BoardRows = 10,
	BoardPixelsPerStud = 40,
	TimerStepSeconds = 0.25, -- UI refresh loop (timer text, daily button)
	TickSeconds = 5, -- last N seconds play the tick sound
	ToastSeconds = 3,
	JoinConfirmSeconds = 1.2, -- no PartyState change by then -> "could not join" toast
	SoundLifetime = 5,
	MaxAchievementsShown = 64,
	Keys = {
		Leave = Enum.KeyCode.Q,
		Mode = Enum.KeyCode.F,
		Stats = Enum.KeyCode.T,
		Leaderboard = Enum.KeyCode.L,
		Shop = Enum.KeyCode.B,
		Daily = Enum.KeyCode.G,
		Requeue = Enum.KeyCode.R,
		Close = Enum.KeyCode.X,
	},
	Tips = {
		Daily = "Daily reward ready. Press G or tap Daily.",
	},
}
