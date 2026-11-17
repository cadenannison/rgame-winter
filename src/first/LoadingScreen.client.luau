--!strict
-- Loading screen. Shown until the server marks the player Ready and the character exists, then
-- fades out for good (respawns never re-show it). Shows a rejoin message if the server reports a
-- failed load. Display only; all values are local constants here (move to a shared UiConfig as UI grows).

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Config = require(ReplicatedStorage.Shared.Config)

local TITLE = "Arctic Survival"
local SUBTITLE = "Loading..."
local FAILED_TITLE = "Could not load"
local FAILED_SUFFIX = "Rejoin from the Roblox app."
local BACKGROUND = Color3.fromRGB(20, 28, 38)
local TEXT = Color3.fromRGB(235, 244, 250)
local ACCENT = Color3.fromRGB(120, 190, 230)
local DISPLAY_ORDER = 100
local MIN_SECONDS = 1.5
local MAX_SECONDS = 30
local FADE_SECONDS = 0.5
local BAR_CYCLE_SECONDS = 1.2
local BAR_SEGMENT = 0.3

local player = Players.LocalPlayer
local connections: { RBXScriptConnection } = {}
local barTween: Tween? = nil
local finished = false
local failed = false
local shownAt = os.clock()

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.DisplayOrder = DISPLAY_ORDER
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false

local root = Instance.new("CanvasGroup")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = BACKGROUND
root.BorderSizePixel = 0
root.Parent = gui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.4)
title.Size = UDim2.fromScale(0.8, 0.12)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = TEXT
title.TextScaled = true
title.Text = TITLE
local titleLimit = Instance.new("UITextSizeConstraint")
titleLimit.MaxTextSize = 56
titleLimit.MinTextSize = 14
titleLimit.Parent = title
title.Parent = root

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
subtitle.Position = UDim2.fromScale(0.5, 0.5)
subtitle.Size = UDim2.fromScale(0.7, 0.06)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextColor3 = TEXT
subtitle.TextScaled = true
subtitle.TextWrapped = true
subtitle.Text = SUBTITLE
local subtitleLimit = Instance.new("UITextSizeConstraint")
subtitleLimit.MaxTextSize = 28
subtitleLimit.MinTextSize = 12
subtitleLimit.Parent = subtitle
subtitle.Parent = root

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.fromScale(0.5, 0.6)
track.Size = UDim2.new(0.5, 0, 0, 8)
track.BackgroundColor3 = Color3.fromRGB(40, 54, 68)
track.BorderSizePixel = 0
track.ClipsDescendants = true
local trackLimit = Instance.new("UISizeConstraint")
trackLimit.MaxSize = Vector2.new(420, math.huge)
trackLimit.Parent = track
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0, 4)
trackCorner.Parent = track
track.Parent = root

local segment = Instance.new("Frame")
segment.Name = "Segment"
segment.Size = UDim2.fromScale(BAR_SEGMENT, 1)
segment.Position = UDim2.fromScale(-BAR_SEGMENT, 0)
segment.BackgroundColor3 = ACCENT
segment.BorderSizePixel = 0
local segmentCorner = Instance.new("UICorner")
segmentCorner.CornerRadius = UDim.new(0, 4)
segmentCorner.Parent = segment
segment.Parent = track

local function startBar()
	local tween = TweenService:Create(
		segment,
		TweenInfo.new(BAR_CYCLE_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		{ Position = UDim2.fromScale(1, 0) }
	)
	barTween = tween
	tween:Play()
end

local function stopBar()
	if barTween ~= nil then
		barTween:Cancel()
		barTween:Destroy()
		barTween = nil
	end
end

local function cleanup()
	finished = true
	stopBar()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function hide()
	if finished or failed then
		return
	end
	cleanup()
	local fade = TweenService:Create(
		root,
		TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 1 }
	)
	fade.Completed:Once(function()
		fade:Destroy()
		gui:Destroy()
	end)
	fade:Play()
end

local function tryHide()
	if finished or failed then
		return
	end
	if player:GetAttribute(Config.ReadyAttribute) ~= true or player.Character == nil then
		return
	end
	local remaining = MIN_SECONDS - (os.clock() - shownAt)
	if remaining > 0 then
		task.delay(remaining, tryHide)
	else
		hide()
	end
end

-- LoadFailed arrived after the loading screen already faded: show a standalone message.
local function showStandaloneFailure()
	if failed then
		return
	end
	failed = true
	local msgGui = Instance.new("ScreenGui")
	msgGui.Name = "LoadFailedMessage"
	msgGui.DisplayOrder = DISPLAY_ORDER
	msgGui.IgnoreGuiInset = true
	msgGui.ResetOnSpawn = false
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = BACKGROUND
	backdrop.BorderSizePixel = 0
	backdrop.Parent = msgGui
	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.4)
	label.Size = UDim2.fromScale(0.7, 0.2)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextColor3 = TEXT
	label.TextScaled = true
	label.Text = `{FAILED_TITLE}\n{Config.LoadFailKickMessage} {FAILED_SUFFIX}`
	label.Parent = backdrop
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 40
	limit.Parent = label
	msgGui.Parent = player:WaitForChild("PlayerGui")
end

local function showFailure()
	if failed then
		return
	end
	if finished then
		showStandaloneFailure()
		return
	end
	failed = true
	stopBar()
	track.Visible = false
	title.Text = FAILED_TITLE
	subtitle.Text = `{Config.LoadFailKickMessage} {FAILED_SUFFIX}`
	subtitle.Size = UDim2.fromScale(0.7, 0.12)
end

-- Not in `connections`: must survive cleanup() so a late LoadFailed still shows (player leaves = script ends).
player:GetAttributeChangedSignal(Config.LoadFailedAttribute):Connect(function()
	if player:GetAttribute(Config.LoadFailedAttribute) == true then
		showFailure()
	end
end)
table.insert(connections, player:GetAttributeChangedSignal(Config.ReadyAttribute):Connect(tryHide))
table.insert(connections, player.CharacterAdded:Connect(tryHide))
table.insert(connections, gui.Destroying:Connect(cleanup))

startBar()
gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

if player:GetAttribute(Config.LoadFailedAttribute) == true then
	showFailure()
end
tryHide()
task.delay(MAX_SECONDS, hide)
