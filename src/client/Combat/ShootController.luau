--!strict
-- Bow input and tracers. Sends only an aim direction (ShootRequest); the server owns origin, ammo, damage
-- and hits. PC: left click while a ranged weapon is selected. Mobile: an on-screen Shoot button that fires
-- along the camera look. Tracers come from ProjectileFired (visual only).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local MobData = require(Shared:WaitForChild("data"):WaitForChild("Mobs"))

local player = Players.LocalPlayer

local TRACER_LENGTH = 4
local TRACER_WIDTH = 0.2
local TRACER_COLOR = Color3.fromRGB(230, 220, 190)
local BUTTON_SIZE = UDim2.fromOffset(96, 96)
local BUTTON_POSITION = UDim2.new(1, -150, 1, -260)
local BUTTON_COLOR = Color3.fromRGB(40, 60, 90)
local AIM_DISTANCE = 300

local ShootController = {}

local started = false

local function held(): boolean
	return player:GetAttribute(MobData.HeldRangedAttribute) == true
end

local function aimDirection(useMouse: boolean): Vector3?
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root or not root:IsA("BasePart") then
		return nil
	end
	local lookDirection = camera.CFrame.LookVector
	if useMouse then
		local location = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(location.X, location.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
		local point = if hit then hit.Position else ray.Origin + ray.Direction * AIM_DISTANCE
		lookDirection = point - root.Position
	end
	if lookDirection.Magnitude < 0.01 then
		return nil
	end
	return lookDirection.Unit
end

local function shoot(useMouse: boolean)
	if not held() then
		return
	end
	local direction = aimDirection(useMouse)
	if direction then
		Remotes.event(Remotes.ShootRequest):FireServer({ direction = direction })
	end
end

local function drawTracer(payload: Remotes.ProjectileFiredPayload)
	local part = Instance.new("Part")
	part.Name = "Arrow"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = TRACER_COLOR
	part.Size = Vector3.new(TRACER_WIDTH, TRACER_WIDTH, TRACER_LENGTH)
	local start = CFrame.lookAt(payload.origin, payload.origin + payload.direction)
	part.CFrame = start
	part.Parent = Workspace
	local travelled = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt)
		travelled += payload.speed * dt
		if travelled >= Config.Projectile.MaxRange then
			if conn then
				conn:Disconnect()
			end
			part:Destroy()
			return
		end
		part.CFrame = start + payload.direction * travelled
	end)
	part.Destroying:Once(function()
		if conn then
			conn:Disconnect()
		end
	end)
	Debris:AddItem(part, Config.Projectile.MaxLifetime)
end

local function buildMobileButton()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShootGui"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local button = Instance.new("TextButton")
	button.Name = "Shoot"
	button.Size = BUTTON_SIZE
	button.Position = BUTTON_POSITION
	button.BackgroundColor3 = BUTTON_COLOR
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Text = "Shoot"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	button.Parent = gui
	button.Activated:Connect(function()
		shoot(false)
	end)
	gui.Parent = playerGui
	local function refresh()
		gui.Enabled = UserInputService.TouchEnabled and held()
	end
	player:GetAttributeChangedSignal(MobData.HeldRangedAttribute):Connect(refresh)
	refresh()
end

function ShootController.start()
	if started then
		return
	end
	started = true
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			shoot(true)
		end
	end)
	Remotes.event(Remotes.ProjectileFired).OnClientEvent:Connect(drawTracer)
	task.spawn(buildMobileButton)
end

return ShootController
