--!strict
-- Settings button + panel with the Reduce scares toggle (brief 20). Works with mouse and touch; every
-- target is >= 48 px (the 44 px minimum). The client sends the key and value only (SettingsSetRequest);
-- the server writes the profile and mirrors the Player ReduceScares attribute, which is the source of truth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AtmosphereConfig = require(script.Parent:WaitForChild("AtmosphereConfig"))
local AtmosphereFx = require(script.Parent:WaitForChild("AtmosphereFx"))
local RightStack = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("RightStack"))

local C = AtmosphereConfig
local player = Players.LocalPlayer

local SettingsUi = {}

SettingsUi.toggle = function() end -- replaced in start(): the toggle's click/tap handler
SettingsUi.state = function(): { [string]: any }
	return {}
end

local started = false
local gui: ScreenGui? = nil
local openButton: TextButton? = nil -- lives in the HUD right stack, so it is destroyed here
local connections: { RBXScriptConnection } = {}

local function corner(parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = parent
end

function SettingsUi.start()
	if started then
		return
	end
	started = true
	local screen = Instance.new("ScreenGui")
	screen.Name = "AtmosphereSettings"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = C.DisplayOrder
	gui = screen

	local open = Instance.new("TextButton")
	open.Name = "SettingsButton"
	open.BackgroundColor3 = C.PanelColor
	open.BackgroundTransparency = 0.2
	open.TextColor3 = C.TextColor
	open.Font = Enum.Font.GothamBold
	open.TextSize = 14
	open.Text = C.SettingsLabel
	open.TextWrapped = true
	open.BorderSizePixel = 0
	corner(open)
	openButton = open
	RightStack.attach(open, "Settings") -- stack (UIListLayout) in HUD/RightStack; destroyed in cleanup

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(C.PanelWidth, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = C.PanelColor
	panel.BorderSizePixel = 0
	panel.Visible = false
	corner(panel)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = panel

	local toggle = Instance.new("TextButton")
	toggle.Name = "ReduceScares"
	toggle.LayoutOrder = 1
	toggle.Size = UDim2.new(1, 0, 0, C.ToggleHeight)
	toggle.TextColor3 = C.TextColor
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 16
	toggle.BorderSizePixel = 0
	corner(toggle)
	toggle.Parent = panel

	local help = Instance.new("TextLabel")
	help.Name = "Help"
	help.LayoutOrder = 2
	help.Size = UDim2.fromScale(1, 0)
	help.AutomaticSize = Enum.AutomaticSize.Y
	help.BackgroundTransparency = 1
	help.TextColor3 = C.TextColor
	help.Font = Enum.Font.Gotham
	help.TextSize = 13
	help.TextWrapped = true
	help.TextXAlignment = Enum.TextXAlignment.Left
	help.Text = C.ReduceScaresHelp
	help.Parent = panel

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.LayoutOrder = 3
	close.Size = UDim2.new(1, 0, 0, C.ToggleHeight)
	close.BackgroundColor3 = C.OffColor
	close.TextColor3 = C.TextColor
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.Text = "Close"
	close.BorderSizePixel = 0
	corner(close)
	close.Parent = panel
	panel.Parent = screen

	local function refresh()
		local on = AtmosphereFx.reduceScares()
		toggle.Text = `{C.ReduceScaresLabel}: {if on then "On" else "Off"}`
		toggle.BackgroundColor3 = if on then C.OnColor else C.OffColor
	end
	refresh()

	table.insert(
		connections,
		open.Activated:Connect(function()
			panel.Visible = not panel.Visible
			refresh()
		end)
	)
	table.insert(
		connections,
		close.Activated:Connect(function()
			panel.Visible = false
		end)
	)
	local function onToggle()
		local value = not AtmosphereFx.reduceScares()
		AtmosphereFx.setOverride(value)
		Remotes.event(Remotes.SettingsSetRequest):FireServer({
			key = Config.Settings.ReduceScares,
			value = value,
		})
		refresh()
	end
	-- Studio QA (client bridge): the same handler the toggle's click/tap calls, and what it shows.
	SettingsUi.toggle = onToggle
	SettingsUi.state = function(): { [string]: any }
		return {
			on = AtmosphereFx.reduceScares(),
			text = toggle.Text,
			attribute = player:GetAttribute(Config.Settings.ReduceScaresAttribute),
		}
	end
	table.insert(connections, toggle.Activated:Connect(onToggle))
	table.insert(
		connections,
		player:GetAttributeChangedSignal(Config.Settings.ReduceScaresAttribute):Connect(function()
			AtmosphereFx.clearOverride()
			refresh()
		end)
	)
	screen.Parent = player:WaitForChild("PlayerGui")
end

function SettingsUi.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if openButton then
		openButton:Destroy()
		openButton = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
	started = false
end

return SettingsUi
