--!strict
-- Short toast for server Notify(kind, text). Display only; text is length-capped and never trusted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))

local Toast = {}

-- Builds the label under gui and listens to Notify. Returns a cleanup function.
function Toast.start(gui: ScreenGui): () -> ()
	local label = Instance.new("TextLabel")
	label.Name = "Toast"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.12)
	label.Size = UDim2.fromOffset(HudConfig.MaxWidth, 32)
	label.BackgroundColor3 = HudConfig.PanelColor
	label.BackgroundTransparency = HudConfig.PanelTransparency
	label.TextColor3 = HudConfig.TextColor
	label.TextScaled = true
	label.Font = Enum.Font.GothamMedium
	label.BorderSizePixel = 0
	label.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(HudConfig.MaxWidth, 40)
	limit.Parent = label
	label.Parent = gui

	local token = 0
	local destroyed = false
	local connection: RBXScriptConnection? = nil
	task.spawn(function()
		local ev = Remotes.event(Remotes.Notify)
		if destroyed then
			return
		end
		connection = ev.OnClientEvent:Connect(function(_kind: unknown, text: unknown)
			if type(text) ~= "string" or text == "" or Players.LocalPlayer == nil then
				return
			end
			token += 1
			local mine = token
			label.Text = string.sub(text, 1, HudConfig.ToastMaxChars)
			label.Visible = true
			task.delay(HudConfig.ToastSeconds, function()
				if token == mine and not destroyed then
					label.Visible = false
				end
			end)
		end)
	end)

	return function()
		destroyed = true
		if connection then
			connection:Disconnect()
		end
		label:Destroy()
	end
end

return Toast
