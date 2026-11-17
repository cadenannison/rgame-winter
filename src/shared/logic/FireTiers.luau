--!strict
-- Pure campfire tier and build-range rules. Tier rows are data in Config.Fire.Tiers. No Roblox APIs.

local Config = require("../Config")

export type Cost = Config.FireCost
export type Row = Config.FireTier
export type BuildFire = { x: number, z: number, buildRadius: number } -- a lit fire for the build check

local FireTiers = {}

function FireTiers.maxTier(): number
	return #Config.Fire.Tiers
end

-- Whole tier within [1, maxTier]; anything else (nil, NaN, text) becomes tier 1.
function FireTiers.clamp(tier: unknown): number
	if type(tier) ~= "number" or tier ~= tier then
		return 1
	end
	return math.clamp(math.floor(tier), 1, FireTiers.maxTier())
end

function FireTiers.get(tier: unknown): Row
	return Config.Fire.Tiers[FireTiers.clamp(tier)]
end

-- Cost to go from `tier` to the next one; nil at the top tier.
function FireTiers.nextCost(tier: number): Cost?
	local nextRow = Config.Fire.Tiers[FireTiers.clamp(tier) + 1]
	return if nextRow then nextRow.UpgradeCost else nil
end

function FireTiers.canAfford(counts: { [string]: number }, cost: Cost): boolean
	for _, input in cost do
		if (counts[input.id] or 0) < input.count then
			return false
		end
	end
	return true
end

-- "15 Wood, 6 Stone". nameOf maps an item id to its display name.
function FireTiers.costText(cost: Cost, nameOf: (string) -> string): string
	local parts: { string } = {}
	for _, input in cost do
		table.insert(parts, `{input.count} {nameOf(input.id)}`)
	end
	return table.concat(parts, ", ")
end

-- Horizontal (XZ) test: is the point within the build radius of any lit fire in the list?
function FireTiers.inBuildRange(fires: { BuildFire }, x: number, z: number): boolean
	for _, fire in fires do
		local dx, dz = x - fire.x, z - fire.z
		if dx * dx + dz * dz <= fire.buildRadius * fire.buildRadius then
			return true
		end
	end
	return false
end

return FireTiers
