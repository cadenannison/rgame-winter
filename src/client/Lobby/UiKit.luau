--!strict
-- Tiny code-built widgets shared by the lobby UI. Every instance gets its parent set last.

local LobbyConfig = require(script.Parent.LobbyConfig)

local UiKit = {}

function UiKit.corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
end

function UiKit.label(parent: Instance, name: string, text: string, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = LobbyConfig.TextColor
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 20
	limit.MinTextSize = 8
	limit.Parent = label
	label.Parent = parent
	return label
end

-- Button at least MinButton tall. Returns it; set enabled with UiKit.setEnabled.
function UiKit.button(parent: Instance, name: string, text: string, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.BackgroundColor3 = LobbyConfig.ButtonColor
	button.TextColor3 = LobbyConfig.TextColor
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Text = text
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	UiKit.corner(button)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(LobbyConfig.MinButton, LobbyConfig.MinButton)
	limit.Parent = button
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 20
	textLimit.MinTextSize = 8
	textLimit.Parent = button
	button.Parent = parent
	return button
end

-- Greyed buttons stay visible; the caller shows the reason as text.
function UiKit.setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then LobbyConfig.ButtonColor else LobbyConfig.DisabledColor
	button.TextColor3 = if enabled then LobbyConfig.TextColor else LobbyConfig.MutedColor
end

-- Centred, aspect-safe panel: scale size with a pixel cap.
function UiKit.panel(parent: Instance, name: string, maxSize: Vector2, scale: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(scale.X, scale.Y)
	frame.BackgroundColor3 = LobbyConfig.PanelColor
	frame.BackgroundTransparency = LobbyConfig.PanelTransparency
	frame.BorderSizePixel = 0
	frame.Visible = false
	UiKit.corner(frame, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize
	limit.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = frame
	frame.Parent = parent
	return frame
end

return UiKit
