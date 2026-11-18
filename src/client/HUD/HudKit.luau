--!strict
-- HUD helpers shared by HudController and its widget modules: cleanup lists, signal connect, Instance
-- factory, size constraint, text/label/panel builders, world position of an Instance. No state.

local HudConfig = require(script.Parent:WaitForChild("HudConfig"))

local HudKit = {}

function HudKit.addCleanup(list: { () -> () }, fn: () -> ())
	table.insert(list, fn)
end

function HudKit.connect(
	list: { () -> () },
	signal: RBXScriptSignal,
	fn: (...any) -> ()
): RBXScriptConnection
	local c = signal:Connect(fn)
	HudKit.addCleanup(list, function()
		c:Disconnect()
	end)
	return c
end

function HudKit.make<T>(className: string, props: { [string]: any }, parent: Instance?): T
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst :: any
end

function HudKit.constrain(parent: Instance, minSize: Vector2?, maxSize: Vector2?)
	HudKit.make("UISizeConstraint", {
		MinSize = minSize or Vector2.new(0, 0),
		MaxSize = maxSize or Vector2.new(math.huge, math.huge),
	}, parent)
end

function HudKit.textProps(
	size: UDim2,
	position: UDim2,
	text: string,
	maxText: number
): { [string]: any }
	return {
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		Text = text,
		TextColor3 = HudConfig.TextColor,
		TextScaled = true,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		_maxText = maxText,
	}
end

function HudKit.makeLabel(parent: Instance, props: { [string]: any }): TextLabel
	local maxText = props._maxText :: number
	props._maxText = nil
	local label = HudKit.make("TextLabel", props, parent) :: TextLabel
	HudKit.make("UITextSizeConstraint", { MaxTextSize = maxText, MinTextSize = 8 }, label)
	return label
end

function HudKit.panel(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	anchor: Vector2
): Frame
	local f = HudKit.make("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = HudConfig.PanelColor,
		BackgroundTransparency = HudConfig.PanelTransparency,
		BorderSizePixel = 0,
	}, parent) :: Frame
	HudKit.make("UICorner", { CornerRadius = UDim.new(0, 8) }, f)
	return f
end

function HudKit.positionOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

return HudKit
