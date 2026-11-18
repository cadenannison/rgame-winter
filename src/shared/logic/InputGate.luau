--!strict
-- Pure input gate rule (no Roblox APIs): an input is ignored when the engine already handled it
-- (gameProcessed) or a text box has focus (typing in chat must never fire hotkeys).

local InputGate = {}

function InputGate.blocked(gameProcessed: boolean, textBoxFocused: boolean): boolean
	return gameProcessed or textBoxFocused
end

return InputGate
