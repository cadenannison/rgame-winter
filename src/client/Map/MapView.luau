--!strict
-- Fog-of-war map panel. Press M or tap the Map button; the server sends explored cells only (needs the
-- Map item). Draws explored cells and the local player's dot. Owner: brief 13.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RightStack = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("RightStack"))
local InputGuard = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("InputGuard"))

local TOGGLE_KEY = Enum.KeyCode.M
local PANEL_SCALE = 0.7
local DOT_SIZE = 10
local DOT_INTERVAL = 0.25
local COLOR_PANEL = Color3.fromRGB(18, 24, 32)
local COLOR_CELL = Color3.fromRGB(200, 215, 230)
local COLOR_DOT = Color3.fromRGB(240, 90, 60)
local MAP_DISPLAY_ORDER = 5

local MapView = {}

local started = false

function MapView.start(): () -> ()
	if started then
		return function() end
	end
	started = true
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "MapGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = MAP_DISPLAY_ORDER

	local button = Instance.new("TextButton")
	button.Name = "MapButton"
	button.Text = "Map (M)"
	button.TextScaled = true
	button.BackgroundColor3 = COLOR_PANEL
	button.TextColor3 = COLOR_CELL
	RightStack.attach(button, "Map") -- stack (UIListLayout) in HUD/RightStack; destroyed in cleanup below

	local panel = Instance.new("Frame")
	panel.Name = "MapPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(PANEL_SCALE, PANEL_SCALE)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.Visible = false
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = panel
	local cellsFolder = Instance.new("Folder")
	cellsFolder.Name = "Cells"
	cellsFolder.Parent = panel
	local dot = Instance.new("Frame")
	dot.Name = "You"
	dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = COLOR_DOT
	dot.ZIndex = 3
	dot.Parent = panel
	panel.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	local worldSize = Config.World.GridSize * Config.World.ChunkSize
	local conns: { RBXScriptConnection } = {}
	local open = false

	local function updateDot()
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			dot.Position = UDim2.fromScale(
				math.clamp(hrp.Position.X / worldSize + 0.5, 0, 1),
				math.clamp(hrp.Position.Z / worldSize + 0.5, 0, 1)
			)
		end
	end

	local function setOpen(value: boolean)
		open = value
		panel.Visible = value
		if value then
			Remotes.event(Remotes.MapRequest):FireServer()
			task.spawn(function()
				while open and gui.Parent do
					updateDot()
					task.wait(DOT_INTERVAL)
				end
			end)
		end
	end

	table.insert(
		conns,
		Remotes.event(Remotes.MapData).OnClientEvent:Connect(function(payload: unknown)
			local data = payload :: Remotes.MapDataPayload
			if
				type(data) ~= "table"
				or type(data.cellsPerSide) ~= "number"
				or data.cellsPerSide < 1
			then
				return
			end
			cellsFolder:ClearAllChildren()
			local n = data.cellsPerSide
			for _, index in data.explored do
				local x, z = (index - 1) % n, math.floor((index - 1) / n)
				local cell = Instance.new("Frame")
				cell.BorderSizePixel = 0
				cell.BackgroundColor3 = COLOR_CELL
				cell.Position = UDim2.fromScale(x / n, z / n)
				cell.Size = UDim2.fromScale(1 / n, 1 / n)
				cell.Parent = cellsFolder
			end
			updateDot()
		end)
	)
	table.insert(
		conns,
		button.Activated:Connect(function()
			setOpen(not open)
		end)
	)
	table.insert(
		conns,
		UserInputService.InputBegan:Connect(function(input, processed)
			if not InputGuard.blocked(processed) and input.KeyCode == TOGGLE_KEY then
				setOpen(not open)
			end
		end)
	)

	return function()
		open = false
		for _, c in conns do
			c:Disconnect()
		end
		button:Destroy()
		gui:Destroy()
		started = false
	end
end

return MapView
