--!strict
-- Pure biome math (no Roblox APIs): ring lookup, cold drain, loot tiers and rolls, node memory,
-- hearth fuel, thin ice. Owner: brief 13. Tuning lives in Config.Biome.Tuning (aliased here).

local Config = require("../Config")
local Biomes = require("../data/Biomes")
local WorldLayout = require("./WorldLayout")

export type NodeMemo = { depletedAt: number?, hits: number? }

local BiomeLogic = {}

BiomeLogic.Tuning = Config.Biome.Tuning -- values live in Config.Biome.Tuning

-- Ring (0 = centre) of a world position: Chebyshev distance in chunks, clamped to the outer ring.
function BiomeLogic.ringAt(x: number, z: number): number
	local world = Config.World
	local ring = math.floor(math.max(math.abs(x), math.abs(z)) / world.ChunkSize)
	return math.clamp(ring, 0, WorldLayout.maxRing(world.GridSize))
end

-- Warmth drain multiplier for a ring and clothing cold resistance. All inputs capped by Config.Biome.
function BiomeLogic.drainMultiplier(ring: number, resistance: number): number
	local b = Config.Biome
	local def = Biomes.forRing(ring)
	local severity = math.min(def.coldSeverity, b.MaxColdSeverity)
	local required = math.min(def.requiredColdResistance, b.MaxRequiredColdResistance)
	local res = math.clamp(resistance, 0, Config.Clothing.MaxColdResistance)
	local covered = math.max(b.MinDrainFraction, 1 - b.ResistanceDrainReductionPerPoint * res)
	local shortfall = math.max(0, required - res)
	local underdressed =
		math.min(b.MaxUnderdressedMultiplier, 1 + shortfall * b.UnderdressedDrainPerPoint)
	return severity * covered * underdressed
end

-- Loot tier from distance to camp: never decreases as distance grows.
function BiomeLogic.lootTier(distanceFromCamp: number): number
	local step = Config.World.ChunkSize
	local tier = 1 + math.floor(math.max(0, distanceFromCamp) / step)
	return math.clamp(tier, 1, BiomeLogic.Tuning.MaxLootTier)
end

-- Expected worth of one crate of a tier (tests + tuning).
function BiomeLogic.expectedLootValue(tier: number): number
	local table_ = Biomes.Loot[math.clamp(tier, 1, #Biomes.Loot)]
	local total, sum = 0, 0
	for _, e in table_.entries do
		total += e.weight
		sum += e.weight * (e.min + e.max) / 2 * e.value
	end
	return table_.rolls * sum / total
end

-- Deterministic loot for a tier. nextFloat yields numbers in [0, 1).
function BiomeLogic.rollLoot(
	tier: number,
	nextFloat: () -> number
): { { id: string, count: number } }
	local table_ = Biomes.Loot[math.clamp(tier, 1, #Biomes.Loot)]
	local total = 0
	for _, e in table_.entries do
		total += e.weight
	end
	local out: { { id: string, count: number } } = {}
	for _ = 1, table_.rolls do
		local pick = nextFloat() * total
		for _, e in table_.entries do
			pick -= e.weight
			if pick < 0 then
				local count = e.min + math.floor(nextFloat() * (e.max - e.min + 1))
				table.insert(out, { id = e.id, count = math.min(count, e.max) })
				break
			end
		end
	end
	return out
end

-- State of a node being rebuilt after its chunk reloaded. Wall-clock based, so the respawn timer
-- keeps running while the chunk is unloaded. Returns state and seconds until respawn (depleted only).
function BiomeLogic.nodeState(
	memo: NodeMemo?,
	now: number,
	respawnSeconds: number,
	maxHits: number
): (string, number)
	if memo == nil then
		return "full", 0
	end
	local at = memo.depletedAt
	if at ~= nil then
		local remaining = at + respawnSeconds - now
		if remaining > 0 then
			return "depleted", remaining
		end
		return "full", 0
	end
	local hits = memo.hits
	if hits ~= nil and hits < maxHits then
		return "partial", 0
	end
	return "full", 0
end

-- Hearth fuel: add one wood's burn time, never beyond the cap. Returns the new litUntil.
function BiomeLogic.hearthAfterWood(litUntil: number, now: number): number
	local t = BiomeLogic.Tuning
	local base = math.max(litUntil, now)
	return math.min(base + t.HearthBurnSeconds, now + t.HearthMaxSeconds)
end

-- Thin ice: accumulated standing seconds -> (newSeconds, broke). Leaving the patch resets.
function BiomeLogic.iceStep(standSeconds: number, onPatch: boolean, dt: number): (number, boolean)
	if not onPatch then
		return 0, false
	end
	local s = standSeconds + dt
	if s >= BiomeLogic.Tuning.ThinIceCrackSeconds then
		return 0, true
	end
	return s, false
end

return BiomeLogic
