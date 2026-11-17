--!strict
-- One world prompt above the current target ("Chop [Click/E]", "Chop: needs Axe", "Hunt Hare") with a
-- progress bar (node hits left / mob health). Display only; rebuilt never, re-adorned per target.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))

export type Prompt = {
	set: (target: Instance?, text: string, progress: number?, warn: boolean) -> (),
	destroy: () -> (),
}

local TargetPrompt = {}

function TargetPrompt.new(parent: Instance): Prompt
	local bb = Instance.new("BillboardGui")
	bb.Name = "TargetPrompt"
	bb.Size = UDim2.fromOffset(180, 46)
	bb.StudsOffsetWorldSpace = Vector3.new(0, Config.Feedback.PromptOffsetY, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Enabled = false

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.new(1, 0, 0, 28)
	text.BackgroundColor3 = HudConfig.PanelColor
	text.BackgroundTransparency = HudConfig.PanelTransparency
	text.TextColor3 = HudConfig.TextColor
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = text
	local tpad = Instance.new("UIPadding")
	tpad.PaddingLeft = UDim.new(0, 6)
	tpad.PaddingRight = UDim.new(0, 6)
	tpad.PaddingTop = UDim.new(0, 3)
	tpad.PaddingBottom = UDim.new(0, 3)
	tpad.Parent = text
	text.Parent = bb

	local bar = Instance.new("Frame")
	bar.Name = "Progress"
	bar.Position = UDim2.fromOffset(10, 34)
	bar.Size = UDim2.new(1, -20, 0, 8)
	bar.BackgroundColor3 = Color3.new(0, 0, 0)
	bar.BackgroundTransparency = 0.4
	bar.BorderSizePixel = 0
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = HudConfig.AccentColor
	fill.BorderSizePixel = 0
	fill.Parent = bar
	bar.Parent = bb
	bb.Parent = parent

	return {
		set = function(target: Instance?, msg: string, progress: number?, warn: boolean)
			if target == nil then
				local untyped: any = bb -- Adornee is nil-able at runtime; the type defs say Instance
				untyped.Adornee = nil
				bb.Enabled = false
				return
			end
			bb.Adornee = target
			bb.Enabled = true
			text.Text = msg
			text.TextColor3 = if warn then HudConfig.BarColors.health else HudConfig.TextColor
			bar.Visible = progress ~= nil
			if progress then
				fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
			end
		end,
		destroy = function()
			bb:Destroy()
		end,
	}
end

return TargetPrompt
