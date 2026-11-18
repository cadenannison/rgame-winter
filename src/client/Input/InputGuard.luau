--!strict
-- Shared client input gate. Every client input handler must call InputGuard.blocked(gameProcessed)
-- first and return when it is true (typing in chat/text boxes, or the engine already handled it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputGate = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("logic"):WaitForChild("InputGate")
)

local InputGuard = {}

function InputGuard.blocked(gameProcessed: boolean): boolean
	return InputGate.blocked(gameProcessed, UserInputService:GetFocusedTextBox() ~= nil)
end

return InputGuard
