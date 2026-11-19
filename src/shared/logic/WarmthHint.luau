--!strict
-- General cold hint (no numbers): compares the player's cold resistance with a zone's requirement and picks a
-- Config.WarmthHints band (comfortable / chilly / dangerous / deadly). No Roblox APIs.

local Config = require("../Config")

local WarmthHint = {}

export type Band = { MinRatio: number, Id: string, Text: string }

-- Resistance / requirement. A zone needing nothing is always comfortable.
function WarmthHint.ratio(resistance: number, required: number): number
	local need = math.min(required, Config.Biome.MaxRequiredColdResistance)
	if need <= 0 then
		return math.huge
	end
	return math.max(0, resistance) / need
end

-- Highest band (bands are sorted by MinRatio descending) whose MinRatio <= ratio.
function WarmthHint.band(resistance: number, required: number): Band
	local r = WarmthHint.ratio(resistance, required)
	local bands = Config.WarmthHints.Bands
	for _, band in bands do
		if r >= band.MinRatio then
			return band
		end
	end
	return bands[#bands]
end

-- Player-facing sentence for the zone, or nil when comfortable. Never contains numbers.
function WarmthHint.message(resistance: number, required: number, zoneName: string): string?
	local band = WarmthHint.band(resistance, required)
	if WarmthHint.ratio(resistance, required) >= 1 then
		return nil
	end
	local text = string.gsub(band.Text, "%.$", "")
	return `{zoneName}: {text}`
end

return WarmthHint
