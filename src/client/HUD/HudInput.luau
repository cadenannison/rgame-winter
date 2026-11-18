--!strict
-- HUD hotbar input helpers: number-key map and the mouse-wheel cycle binding. HudController supplies the
-- select callbacks; this module owns only the binding and its cleanup.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HudMath =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("logic"):WaitForChild("HudMath"))

local HOTBAR_KEYS: { Enum.KeyCode } = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}
local WHEEL_ACTION = "ArcticHotbarWheel"

local HudInput = {}

-- Slot index for a hotbar key (1-9), or nil.
function HudInput.slotForKey(keyCode: Enum.KeyCode): number?
	return table.find(HOTBAR_KEYS, keyCode)
end

-- Mouse wheel cycles the hotbar. Bound above the camera's zoom binding and sunk so it does not
-- also zoom; hold Shift to zoom with the wheel instead. Returns the unbind function.
function HudInput.bindWheel(
	shownSlot: () -> number,
	requestSelect: (slot: number) -> (),
	slotCount: number
): () -> ()
	ContextActionService:BindActionAtPriority(
		WHEEL_ACTION,
		function(
			_name: string,
			state: Enum.UserInputState,
			input: InputObject
		): Enum.ContextActionResult
			if
				state ~= Enum.UserInputState.Change
				or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			then
				return Enum.ContextActionResult.Pass
			end
			local dz = input.Position.Z
			if dz == 0 then
				return Enum.ContextActionResult.Pass
			end
			requestSelect(HudMath.cycleSlot(shownSlot(), if dz < 0 then 1 else -1, slotCount))
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.UserInputType.MouseWheel
	)
	return function()
		ContextActionService:UnbindAction(WHEEL_ACTION)
	end
end

return HudInput
