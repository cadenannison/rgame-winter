--!strict
-- Phase 4 client boot hook for brief 19 (shop panel, cosmetics, perks, titles, achievement toasts).
-- init.client.luau calls start(mode) once in BOTH modes (Config.Teleport.ModeLobby or ModeRun).
-- Read-only: renders MetaState / PurchaseResult / AchievementUnlocked. Must not yield: waiting work runs
-- in its own thread.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Achievements = require(Shared:WaitForChild("data"):WaitForChild("Achievements"))
local LobbyConfig = require(script.Parent.Parent:WaitForChild("Lobby"):WaitForChild("LobbyConfig"))
local MetaPanel = require(script.Parent.Parent:WaitForChild("Meta"):WaitForChild("MetaPanel"))
local MetaUiConfig = require(script.Parent.Parent:WaitForChild("Meta"):WaitForChild("MetaUiConfig"))

local MetaClient = {}

local started = false

-- Optional cue through brief 20's AtmosphereFx (nil-safe: absent or failing means silence).
local function playCue(key: string)
	local folder = script.Parent.Parent:FindFirstChild("Atmosphere")
	local module = folder and folder:FindFirstChild("AtmosphereFx")
	if module and module:IsA("ModuleScript") then
		pcall(function()
			(require(module) :: any).play(key)
		end)
	end
end

local function run(mode: string)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = MetaUiConfig.GuiName
	gui.ResetOnSpawn = false
	gui.DisplayOrder = MetaUiConfig.DisplayOrder
	gui.Parent = playerGui

	-- Toast queue: one label, shown one at a time.
	local label = Instance.new("TextLabel")
	label.Name = "MetaToast"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.2)
	label.Size = UDim2.fromOffset(380, 44)
	label.BackgroundColor3 = LobbyConfig.PanelColor
	label.BackgroundTransparency = 0.15
	label.TextColor3 = LobbyConfig.TextColor
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.BorderSizePixel = 0
	label.Visible = false
	label.ZIndex = 30
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(380, 48)
	limit.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	label.Parent = gui

	local queue: { { text: string, seconds: number } } = {}
	local showing = false
	local function pump()
		if showing then
			return
		end
		showing = true
		task.spawn(function()
			while #queue > 0 and gui.Parent ~= nil do
				local item = table.remove(queue, 1) :: { text: string, seconds: number }
				label.Text = item.text
				label.Visible = true
				task.wait(item.seconds)
			end
			label.Visible = false
			showing = false
		end)
	end
	local function toast(text: string, seconds: number?)
		if text == "" or #queue >= MetaUiConfig.MaxToastQueue then
			return
		end
		table.insert(queue, { text = text, seconds = seconds or MetaUiConfig.ToastSeconds })
		pump()
	end

	local connections: { RBXScriptConnection } = {}
	table.insert(
		connections,
		Remotes.event(Remotes.AchievementUnlocked).OnClientEvent:Connect(function(payload: unknown)
			if type(payload) ~= "table" then
				return
			end
			local data = payload :: { id: unknown, coins: unknown, title: unknown }
			local def = if type(data.id) == "string" then Achievements.ById[data.id] else nil
			if not def then
				return
			end
			local coins = if type(data.coins) == "number" then math.floor(data.coins) else 0
			playCue("AchievementUnlocked")
			toast(`Achievement: {def.name}  +{coins} coins`, MetaUiConfig.AchievementToastSeconds)
			if type(data.title) == "string" then
				local title = Achievements.TitleById[data.title]
				if title then
					toast(`New title: {title.name}`, MetaUiConfig.AchievementToastSeconds)
				end
			end
		end)
	)

	if mode == Config.Teleport.ModeLobby then
		MetaPanel.start(gui, toast, playCue)
		table.insert(
			connections,
			Remotes.event(Remotes.MetaState).OnClientEvent:Connect(MetaPanel.onState)
		)
		table.insert(
			connections,
			Remotes.event(Remotes.PurchaseResult).OnClientEvent:Connect(MetaPanel.onPurchase)
		)
	end
	gui.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end)
end

function MetaClient.start(mode: string)
	if started then
		return
	end
	started = true
	task.spawn(run, mode)
end

return MetaClient
