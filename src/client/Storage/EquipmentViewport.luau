--!strict
-- ViewportFrame showing a slowly rotating clone of the local character (Config.Equipment.ViewportRotateSpeed
-- degrees per second). Visual only: scripts, tools and sounds are stripped from the clone; failures leave an
-- empty frame. Rotation runs on RenderStepped only while the frame is visible.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UiConfig = require(script.Parent:WaitForChild("InventoryUiConfig"))

local EquipmentViewport = {}

export type Viewport = {
	frame: ViewportFrame,
	refresh: () -> (), -- rebuild the clone from the current character (call when the panel opens)
	destroy: () -> (),
}

function EquipmentViewport.new(parent: Instance): Viewport
	local frame = Instance.new("ViewportFrame")
	frame.Name = "Character"
	frame.BackgroundColor3 = UiConfig.Colors.Equip
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(UiConfig.ViewportWidthPx, UiConfig.ViewportHeightPx)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local camera = Instance.new("Camera")
	camera.FieldOfView = UiConfig.ViewportFov
	camera.Parent = frame
	frame.CurrentCamera = camera
	frame.Parent = parent

	local localPlayer = Players.LocalPlayer
	local clone: Model? = nil
	local angle = 0
	local connection: RBXScriptConnection? = nil

	local function clear()
		if clone then
			clone:Destroy()
			clone = nil
		end
	end

	local function refresh()
		clear()
		local character = localPlayer.Character
		if character == nil then
			return
		end
		local ok, copy = pcall(function()
			local wasArchivable = character.Archivable
			character.Archivable = true
			local c = character:Clone()
			character.Archivable = wasArchivable
			return c
		end)
		if not ok or copy == nil then
			return
		end
		for _, d in copy:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("Tool") or d:IsA("Sound") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local root = copy:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			copy:Destroy()
			return
		end
		copy:PivotTo(CFrame.new(0, 0, 0))
		copy.Parent = frame
		clone = copy
		angle = 0
	end

	connection = RunService.RenderStepped:Connect(function(dt: number)
		local model = clone
		if model == nil or not frame.Visible or not frame:IsDescendantOf(game) then
			return
		end
		angle = (angle + Config.Equipment.ViewportRotateSpeed * dt) % 360
		model:PivotTo(CFrame.Angles(0, math.rad(angle), 0))
		local _, size = model:GetBoundingBox()
		local focus = Vector3.new(0, size.Y * 0.05, 0)
		local eye = focus
			+ Vector3.new(
				0,
				size.Y * UiConfig.ViewportCameraHeight * 0.1,
				UiConfig.ViewportCameraDistance + size.Y
			)
		camera.CFrame = CFrame.lookAt(eye, focus)
	end)

	return {
		frame = frame,
		refresh = refresh,
		destroy = function()
			if connection then
				connection:Disconnect()
				connection = nil
			end
			clear()
			frame:Destroy()
		end,
	}
end

return EquipmentViewport
