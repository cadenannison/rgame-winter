--!strict
-- First-run hint chain UI. HudController reports real actions via complete(stepId); the panel shows
-- the first step not done (shared/logic/Onboarding) and hides for good once every step is done.
-- Per session for now (see docs/KNOWN_ISSUES.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Onboarding = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("logic"):WaitForChild("Onboarding")
)
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))

export type Hints = {
	complete: (string) -> (),
	current: () -> string?,
	destroy: () -> (),
}

local OnboardingHints = {}

function OnboardingHints.new(gui: ScreenGui): Hints
	local done: Onboarding.Done = {}
	local destroyed = false

	local frame = Instance.new("Frame")
	frame.Name = "Onboarding"
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.fromScale(0.015, 0.42)
	frame.Size = UDim2.fromScale(0.3, 0.12)
	frame.BackgroundColor3 = HudConfig.PanelColor
	frame.BackgroundTransparency = HudConfig.PanelTransparency
	frame.BorderSizePixel = 0
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(180, 60)
	limit.MaxSize = Vector2.new(340, 90)
	limit.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local step = Instance.new("TextLabel")
	step.Name = "Step"
	step.BackgroundTransparency = 1
	step.Position = UDim2.fromOffset(10, 4)
	step.Size = UDim2.new(1, -20, 0, 16)
	step.TextColor3 = HudConfig.AccentColor
	step.Font = Enum.Font.GothamBold
	step.TextScaled = true
	step.TextXAlignment = Enum.TextXAlignment.Left
	step.Parent = frame
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(10, 22)
	text.Size = UDim2.new(1, -20, 1, -26)
	text.TextColor3 = HudConfig.TextColor
	text.Font = Enum.Font.GothamMedium
	text.TextScaled = true
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = 16
	tc.MinTextSize = 8
	tc.Parent = text
	text.Parent = frame
	frame.Parent = gui

	local function render()
		local id = Onboarding.current(done)
		if id == nil then
			step.Text = "Tutorial complete"
			text.Text = HudConfig.OnboardingDoneText
			task.delay(HudConfig.OnboardingDoneSeconds, function()
				if not destroyed then
					frame.Visible = false
				end
			end)
			return
		end
		local index = table.find(Onboarding.STEPS, id) or 0
		step.Text = `Tip {index}/{#Onboarding.STEPS}`
		text.Text = HudConfig.OnboardingText[id] or id
	end
	render()

	return {
		complete = function(id: string)
			if Onboarding.complete(done, id) and not destroyed then
				render()
			end
		end,
		current = function(): string?
			return Onboarding.current(done)
		end,
		destroy = function()
			destroyed = true
			frame:Destroy()
		end,
	}
end

return OnboardingHints
