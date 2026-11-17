--!strict

local Clamp = {}

function Clamp.clamp(value: number, minValue: number, maxValue: number): number
	return math.max(minValue, math.min(maxValue, value))
end

return Clamp
