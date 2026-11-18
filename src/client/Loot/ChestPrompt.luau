--!strict
-- Custom "Open" prompt for loot chests: a rarity-coloured label plus a tappable button (>= 44 px) so PC
-- (E / click), mobile (tap) and gamepad (X) all work. Triggering sends Remotes.LootOpenRequest {chest}; the
-- server re-checks range, rate and state. Display and intent only.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Rarity = require(Shared:WaitForChild("data"):WaitForChild("Rarity"))
local ChestStyle = require(Shared:WaitForChild("logic"):WaitForChild("ChestStyle"))

local L = Config.Loot

local PROMPT_ATTRIBUTE = "ChestPrompt"
local GUI_SIZE = UDim2.fromOffset(230, 96)
local GUI_OFFSET = Vector3.new(0, 3.5, 0)
local BUTTON_HEIGHT = 48 -- >= 44 px touch target
local TITLE_HEIGHT = 30
local TITLE_TEXT_SIZE = 20
local BUTTON_TEXT_SIZE = 22
local BG_COLOR = Color3.fromRGB(18, 22, 30)
local BG_TRANSPARENCY = 0.25
local TEXT_COLOR = Color3.fromRGB(240, 244, 250)
local FILL_TRANSPARENCY = 0.55
local FILL_RESET_SECONDS = 0.1
local CORNER = UDim.new(0, 8)
local STROKE_THICKNESS = 2

local ChestPrompt = {}

local localPlayer = Players.LocalPlayer
local connections: { RBXScriptConnection } = {}
local shown: { [ProximityPrompt]: { gui: BillboardGui, conns: { RBXScriptConnection }, button: TextButton } } =
	{}
local lastRequest = 0
local started = false

local function rarityColor(rarity: string): Color3
	local c = Rarity.Colors[rarity] or Rarity.Colors.common
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function actionText(inputType: Enum.ProximityPromptInputType, holdSeconds: number): string
	local verb = if holdSeconds > 0 then "Hold to open" else "Open"
	if inputType == Enum.ProximityPromptInputType.Touch then
		return if holdSeconds > 0 then "Hold to open" else "Tap to open"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return `{verb} [X]`
	end
	return `{verb} [E]`
end

local function hide(prompt: ProximityPrompt)
	local entry = shown[prompt]
	if not entry then
		return
	end
	shown[prompt] = nil
	for _, c in entry.conns do
		c:Disconnect()
	end
	entry.gui:Destroy()
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt:GetAttribute(PROMPT_ATTRIBUTE) ~= true or shown[prompt] then
		return
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local model = prompt:FindFirstAncestorOfClass("Model")
	if not playerGui or not model then
		return
	end
	local rarityAttr = model:GetAttribute(L.ChestRarityAttribute)
	local rarity = if type(rarityAttr) == "string" then rarityAttr else "common"
	local color = rarityColor(rarity)
	local style = ChestStyle.get(rarity)

	local gui = Instance.new("BillboardGui")
	gui.Name = "ChestPromptGui"
	gui.Size = GUI_SIZE
	gui.StudsOffsetWorldSpace = GUI_OFFSET
	gui.AlwaysOnTop = true
	gui.ResetOnSpawn = false
	gui.Adornee = prompt.Parent :: Instance

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
	title.BackgroundTransparency = 1
	title.Text = style.label
	title.TextColor3 = color
	title.TextSize = TITLE_TEXT_SIZE
	title.Font = Enum.Font.GothamBold
	title.TextStrokeTransparency = 0.4
	title.Parent = gui

	local button = Instance.new("TextButton")
	button.Name = "Open"
	button.Position = UDim2.fromOffset(0, TITLE_HEIGHT + 4)
	button.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	button.BackgroundColor3 = BG_COLOR
	button.BackgroundTransparency = BG_TRANSPARENCY
	button.AutoButtonColor = true
	button.Text = actionText(inputType, prompt.HoldDuration)
	button.TextColor3 = TEXT_COLOR
	button.TextSize = BUTTON_TEXT_SIZE
	button.Font = Enum.Font.GothamBold
	button.ClipsDescendants = true
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = STROKE_THICKNESS
	stroke.Parent = button
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.BackgroundTransparency = FILL_TRANSPARENCY
	fill.BorderSizePixel = 0
	fill.ZIndex = 0
	fill.Parent = button

	local conns: { RBXScriptConnection } = {}
	table.insert(
		conns,
		button.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				prompt:InputHoldBegin()
			end
		end)
	)
	table.insert(
		conns,
		button.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				prompt:InputHoldEnd()
			end
		end)
	)
	table.insert(
		conns,
		prompt.PromptButtonHoldBegan:Connect(function()
			if prompt.HoldDuration > 0 then
				TweenService:Create(
					fill,
					TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
					{ Size = UDim2.fromScale(1, 1) }
				):Play()
			end
		end)
	)
	table.insert(
		conns,
		prompt.PromptButtonHoldEnded:Connect(function()
			TweenService
				:Create(fill, TweenInfo.new(FILL_RESET_SECONDS), { Size = UDim2.fromScale(0, 1) })
				:Play()
		end)
	)
	-- Confirm feedback: the button reads "Opening..." until the server opens the chest and the prompt hides.
	table.insert(
		conns,
		prompt.Triggered:Connect(function()
			button.Text = "Opening..."
		end)
	)
	-- Prompt text follows the active input device (keyboard <-> touch) while shown.
	table.insert(
		conns,
		UserInputService.LastInputTypeChanged:Connect(function()
			if button.Text ~= "Opening..." then
				local t = UserInputService:GetLastInputType()
				local mapped = if t == Enum.UserInputType.Touch
					then Enum.ProximityPromptInputType.Touch
					elseif
						t == Enum.UserInputType.Gamepad1
					then Enum.ProximityPromptInputType.Gamepad
					else Enum.ProximityPromptInputType.Keyboard
				button.Text = actionText(mapped, prompt.HoldDuration)
			end
		end)
	)
	gui.Parent = playerGui
	shown[prompt] = { gui = gui, conns = conns, button = button }
end

local function onTriggered(prompt: ProximityPrompt, player: Player)
	if player ~= localPlayer or prompt:GetAttribute(PROMPT_ATTRIBUTE) ~= true then
		return
	end
	local model = prompt:FindFirstAncestorOfClass("Model")
	if not model or model:GetAttribute(L.ChestOpenedAttribute) == true then
		return
	end
	local now = os.clock()
	if now - lastRequest < L.OpenRateInterval then
		return
	end
	lastRequest = now
	Remotes.event(Remotes.LootOpenRequest):FireServer({ chest = model })
end

function ChestPrompt.start()
	if started then
		return
	end
	started = true
	table.insert(connections, ProximityPromptService.PromptShown:Connect(show))
	table.insert(connections, ProximityPromptService.PromptHidden:Connect(hide))
	table.insert(connections, ProximityPromptService.PromptTriggered:Connect(onTriggered))
end

function ChestPrompt.destroy()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for prompt in shown do
		hide(prompt)
	end
	started = false
end

return ChestPrompt
