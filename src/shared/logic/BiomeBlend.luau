--!strict
-- Pure biome blend (no Roblox APIs): how much of each ring's look applies at a world position. Rings
-- are Chebyshev bands of `chunkSize` studs (same as BiomeLogic.ringAt). Within `blendStuds` of a border
-- the two neighbouring rings mix, reaching 50/50 exactly on the border so the look is continuous.

local BiomeBlend = {}

export type Weight = { ring: number, weight: number }

function BiomeBlend.weights(
	x: number,
	z: number,
	chunkSize: number,
	maxRing: number,
	blendStuds: number
): { Weight }
	local d = math.max(math.abs(x), math.abs(z))
	local raw = math.floor(d / chunkSize)
	local ring = math.clamp(raw, 0, maxRing)
	local into = d - raw * chunkSize -- studs past this band's inner border
	local other: number? = nil
	local wOther = 0
	if blendStuds > 0 and raw <= maxRing then
		if raw > 0 and into < blendStuds then
			other = raw - 1
			wOther = 0.5 * (1 - into / blendStuds)
		elseif raw < maxRing and chunkSize - into < blendStuds then
			other = raw + 1
			wOther = 0.5 * (1 - (chunkSize - into) / blendStuds)
		end
	end
	if other == nil then
		return { { ring = ring, weight = 1 } }
	end
	return {
		{ ring = ring, weight = 1 - wOther },
		{ ring = math.clamp(other, 0, maxRing), weight = wOther },
	}
end

return BiomeBlend
