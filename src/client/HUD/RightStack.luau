--!strict
-- Right-hand HUD button column (Craft, Map, Settings). One ScreenGui with a UIListLayout: each owner
-- attaches its button, the layout spaces them, so they never overlap on desktop or phone.

local Players = game:GetService("Players")

local HudConfig = require(script.Parent:WaitForChild("HudConfig"))

local R = HudConfig.RightStack

local RightStack = {}

local function getStack(): Frame?
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = playerGui:FindFirstChild(R.GuiName)
	if gui and gui:IsA("ScreenGui") then
		local existing = gui:FindFirstChild("Stack")
		return if existing and existing:IsA("Frame") then existing else nil
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = R.GuiName
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = HudConfig.DisplayOrder
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local frame = Instance.new("Frame")
	frame.Name = "Stack"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(R.RightScale, 0, 0, R.TopOffset)
	frame.Size = UDim2.fromOffset(R.Width, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Active = false
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, R.Gap)
	layout.Parent = frame
	frame.Parent = screen
	screen.Parent = playerGui
	return frame
end

-- Puts the button into the stack at its named slot (HudConfig.RightStack.Order). The caller keeps
-- ownership: destroy the button on cleanup (the stack frame outlives any single owner).
function RightStack.attach(button: GuiButton, slot: string)
	local stack = getStack()
	if not stack then
		return
	end
	button.AnchorPoint = Vector2.zero
	button.Position = UDim2.new()
	button.Size = UDim2.new(1, 0, 0, R.ButtonHeight)
	button.LayoutOrder = R.Order[slot] or 99
	button.Parent = stack
end

return RightStack
