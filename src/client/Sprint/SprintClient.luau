--!strict
-- Sprint input + HUD. PC: hold Config.Sprint.Key. Touch: toggle button. The client only requests; the server
-- gates and applies speed/hunger. The indicator and button highlight read the server's Sprinting attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local InputGuard = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("InputGuard"))

local SP = Config.Sprint
local GUI_NAME = "SprintGui"
local INDICATOR_COLOR = Color3.fromRGB(255, 220, 120)
local BUTTON_IDLE = Color3.fromRGB(40, 48, 60)
local BUTTON_ACTIVE = Color3.fromRGB(230, 170, 60)
local INDICATOR_SIZE = UDim2.fromOffset(120, 22)
local INDICATOR_POS = UDim2.new(0.5, 0, 1, -150) -- above the hotbar, centred
local LABEL_TEXT_SIZE = 14
local BUTTON_TEXT_SIZE = 13
local BUTTON_CORNER = 12

local SprintClient = {}

local started = false

function SprintClient.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local request = Remotes.event(Remotes.SprintRequest)
	local keyCode = (Enum.KeyCode :: any)[SP.Key] :: Enum.KeyCode
	local sent = false
	local conns: { RBXScriptConnection } = {}

	local function send(active: boolean)
		if sent == active then
			return
		end
		sent = active
		request:FireServer({ active = active })
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	local indicator = Instance.new("TextLabel")
	indicator.Name = "Indicator"
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	indicator.Position = INDICATOR_POS
	indicator.Size = INDICATOR_SIZE
	indicator.BackgroundTransparency = 1
	indicator.Text = SP.IndicatorText
	indicator.TextColor3 = INDICATOR_COLOR
	indicator.Font = Enum.Font.GothamBold
	indicator.TextSize = LABEL_TEXT_SIZE
	indicator.TextStrokeTransparency = 0.5
	indicator.Visible = false
	indicator.Parent = gui

	local button: TextButton? = nil
	if UserInputService.TouchEnabled then
		local b = Instance.new("TextButton")
		b.Name = "SprintButton"
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, -SP.ButtonOffsetPx[1], 1, -SP.ButtonOffsetPx[2])
		b.Size = UDim2.fromOffset(SP.ButtonSizePx, SP.ButtonSizePx)
		b.BackgroundColor3 = BUTTON_IDLE
		b.BackgroundTransparency = 0.25
		b.Text = "Sprint"
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.GothamBold
		b.TextSize = BUTTON_TEXT_SIZE
		b.AutoButtonColor = true
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, BUTTON_CORNER)
		corner.Parent = b
		table.insert(
			conns,
			b.Activated:Connect(function()
				send(not sent) -- toggle
			end)
		)
		b.Parent = gui
		button = b
	end

	local function refresh()
		local on = player:GetAttribute(SP.Attribute) == true
		indicator.Visible = on
		if sent and not on then
			sent = false -- the server ended or refused it (hunger/downed): the next request goes out again
		end
		local b = button
		if b then
			b.BackgroundColor3 = if on then BUTTON_ACTIVE else BUTTON_IDLE
		end
	end

	table.insert(
		conns,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if input.KeyCode ~= keyCode or InputGuard.blocked(gameProcessed) then
				return
			end
			send(true)
		end)
	)
	table.insert(
		conns,
		UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
			if input.KeyCode == keyCode then
				send(false) -- release always counts, even if focus moved to a text box
			end
		end)
	)
	table.insert(
		conns,
		UserInputService.WindowFocusReleased:Connect(function()
			send(false)
		end)
	)
	table.insert(conns, player:GetAttributeChangedSignal(SP.Attribute):Connect(refresh))
	gui.Destroying:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	refresh()
end

return SprintClient
