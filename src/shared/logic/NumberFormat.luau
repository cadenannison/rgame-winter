--!strict
-- Compact number formatting ("1.2K", "3.4M", "5.6B"). No Roblox APIs.

local NumberFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }
local STEP = 1000
local DECIMALS = 1

local function trim(text: string): string
	local out = string.gsub(text, "%.0$", "")
	return out
end

function NumberFormat.format(n: number): string
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "inf"
	end
	if n == -math.huge then
		return "-inf"
	end
	if n < 0 then
		return "-" .. NumberFormat.format(-n)
	end
	if n < STEP then
		return tostring(math.floor(n))
	end
	local scale = 10 ^ DECIMALS
	local index = 1
	local value = n
	while value >= STEP and index < #SUFFIXES do
		value /= STEP
		index += 1
	end
	local rounded = math.floor(value * scale + 0.5) / scale
	if rounded >= STEP and index < #SUFFIXES then
		rounded /= STEP
		index += 1
	end
	if rounded >= STEP then
		return string.format("%.2e", n)
	end
	return trim(string.format("%.1f", rounded)) .. SUFFIXES[index]
end

return NumberFormat
