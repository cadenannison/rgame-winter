--!strict
-- Word-safe item-name sizing: picks the largest TextSize (maxSize down to minSize) at which every word fits the
-- label width and the wrapped text fits its height, so names wrap only between words ("Winterberry" is never
-- split). When even minSize cannot fit, the label goes single line with an end ellipsis instead of breaking a
-- word (the tooltip shows the full name). Re-fits on Text and AbsoluteSize changes; cleans up with the label.

local TextService = game:GetService("TextService")

local NameFit = {}

local UNBOUNDED = 10000

type Fit = { size: number, wrapped: boolean }

local cache: { [string]: Fit } = {}

local function measure(text: string, size: number, font: Enum.Font, width: number): Vector2
	local ok, bounds =
		pcall(TextService.GetTextSize, TextService, text, size, font, Vector2.new(width, UNBOUNDED))
	if ok then
		return bounds
	end
	return Vector2.new(0, 0)
end

local function solve(
	text: string,
	font: Enum.Font,
	width: number,
	height: number,
	maxSize: number,
	minSize: number
): Fit
	for size = maxSize, minSize, -1 do
		local wordsFit = true
		for word in string.gmatch(text, "%S+") do
			if measure(word, size, font, UNBOUNDED).X > width then
				wordsFit = false
				break
			end
		end
		if wordsFit and measure(text, size, font, width).Y <= height then
			return { size = size, wrapped = true }
		end
	end
	return { size = minSize, wrapped = false }
end

-- Fits `label` now (no-op while it has no size or text).
function NameFit.fit(label: TextLabel, maxSize: number, minSize: number)
	local width, height = label.AbsoluteSize.X, label.AbsoluteSize.Y
	local text = label.Text
	if width <= 0 or height <= 0 or text == "" then
		return
	end
	local key =
		`{text}|{math.floor(width)}|{math.floor(height)}|{label.Font.Value}|{maxSize}|{minSize}`
	local fit = cache[key]
	if fit == nil then
		fit = solve(text, label.Font, width, height, maxSize, minSize)
		cache[key] = fit
	end
	label.TextSize = fit.size
	label.TextWrapped = fit.wrapped
	label.TextTruncate = if fit.wrapped then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd
end

-- Keeps `label` fitted as its text or size changes. Returns a disconnect function.
function NameFit.bind(label: TextLabel, maxSize: number, minSize: number): () -> ()
	local connections: { RBXScriptConnection } = {}
	local function refit()
		NameFit.fit(label, maxSize, minSize)
	end
	table.insert(connections, label:GetPropertyChangedSignal("Text"):Connect(refit))
	table.insert(connections, label:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit))
	refit()
	return function()
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
	end
end

return NameFit
