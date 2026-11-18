--!strict
-- Drag and drop for the HUD hotbar (same single move path as the Backpack: Remotes.InventoryMove). A drag that
-- ends on another hotbar slot or a Backpack grid slot sends one move request; any other end (no slot, same slot,
-- window focus lost) cancels and sends nothing, so the item stays in its origin slot. Intent only: the server
-- validates and the hotbar redraws from InventoryUpdate. Highlights: origin = held, other slots = valid targets,
-- slot under the pointer = hover (Config.InventoryUi).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudWidgets = require(script.Parent:WaitForChild("HudWidgets"))

local HudHotbarDrag = {}

export type Style = { Stroke: { number }, Tint: { number }, Thickness: number }
export type Drag = {
	-- Highlight to draw on hotbar slot i right now (nil = normal rendering).
	style: (i: number) -> Style?,
	-- True once after a drag ended on the slot (so the Activated that follows does not also select).
	consumeClick: () -> boolean,
	destroy: () -> (),
}

local PANEL_SLOT_PATTERN = "^Slot_inv:(%d+)$"

function HudHotbarDrag.attach(
	gui: ScreenGui,
	slots: { [number]: HudWidgets.Slot },
	stackAt: (i: number) -> { id: string, count: number }?,
	onChange: () -> ()
): Drag
	local HL = Config.InventoryUi
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local connections: { RBXScriptConnection } = {}
	local press: { index: number, input: InputObject, start: Vector2, touch: boolean }? = nil
	local origin: number? = nil
	local hover: number? = nil
	local ghost: TextLabel? = nil
	local suppress = false

	local function slotAt(pos: Vector2): number?
		for _, object in playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) do
			for i, slot in slots do
				if slot.button == object then
					return i
				end
			end
			local n = string.match(object.Name, PANEL_SLOT_PATTERN)
			if n ~= nil and object:IsA("GuiButton") then
				return tonumber(n)
			end
		end
		return nil
	end

	local function cancel()
		press = nil
		origin = nil
		hover = nil
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
		onChange()
	end

	for i, slot in slots do
		table.insert(
			connections,
			slot.button.InputBegan:Connect(function(input: InputObject)
				local kind = input.UserInputType
				local touch = kind == Enum.UserInputType.Touch
				if kind ~= Enum.UserInputType.MouseButton1 and not touch then
					return
				end
				press = {
					index = i,
					input = input,
					start = Vector2.new(input.Position.X, input.Position.Y),
					touch = touch,
				}
			end)
		)
	end

	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			local p = press
			if p == nil then
				return
			end
			if
				not (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or (p.touch and input == p.input)
				)
			then
				return
			end
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if origin == nil then
				if (pos - p.start).Magnitude < HL.DragThresholdPx or stackAt(p.index) == nil then
					return
				end
				origin = p.index
				local g = Instance.new("TextLabel")
				g.Name = "HotbarDragGhost"
				g.AnchorPoint = Vector2.new(0.5, 0.5)
				g.Size = UDim2.fromOffset(56, 56)
				g.BackgroundColor3 =
					Color3.fromRGB(HL.Held.Tint[1], HL.Held.Tint[2], HL.Held.Tint[3])
				g.BackgroundTransparency = 0.3
				g.BorderSizePixel = 0
				g.Text = slots[p.index].name.Text
				g.TextColor3 = Color3.new(1, 1, 1)
				g.Font = Enum.Font.GothamBold
				g.TextSize = 12
				g.TextWrapped = true
				g.ZIndex = 20
				g.Parent = gui
				ghost = g
				onChange()
			end
			if ghost then
				ghost.Position = UDim2.fromOffset(pos.X, pos.Y)
			end
			local under = slotAt(pos)
			if under ~= hover then
				hover = under
				onChange()
			end
		end)
	)

	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			local p = press
			if
				p == nil or not (input == p.input or input.UserInputType == p.input.UserInputType)
			then
				return
			end
			local from = origin
			if from == nil then
				press = nil
				return
			end
			local to = slotAt(Vector2.new(input.Position.X, input.Position.Y))
			local stack = stackAt(from)
			cancel()
			suppress = true
			task.defer(function()
				suppress = false
			end)
			if to ~= nil and to ~= from and stack ~= nil then
				local payload: Remotes.InventoryMovePayload = {
					from = { kind = "inv", slot = from },
					to = { kind = "inv", slot = to },
					count = stack.count, -- whole stack (merge or swap); the server re-validates
					expect = stack.id,
				}
				Remotes.event(Remotes.InventoryMove):FireServer(payload)
			end
		end)
	)
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(cancel))

	return {
		style = function(i: number): Style?
			if origin == nil then
				return nil
			end
			if i == origin then
				return HL.Held
			elseif i == hover then
				return HL.Hover
			end
			return HL.Target
		end,
		consumeClick = function(): boolean
			return suppress
		end,
		destroy = function()
			for _, c in connections do
				c:Disconnect()
			end
			table.clear(connections)
			if ghost then
				ghost:Destroy()
				ghost = nil
			end
		end,
	}
end

return HudHotbarDrag
