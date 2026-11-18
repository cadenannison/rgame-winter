--!strict
-- Pure species rules (no Roblox APIs): ring spawn weights, outer-ring meanness, caps, drops, grounding checks.
-- Data lives in Config.Mobs.Species; Scaling caps are reused (Scaling.MaxRingBudgetMultiplier /
-- MaxRingDamageMultiplier) so nothing here can grow past an existing cap.

local Config = require("../Config")

export type Species = typeof(Config.Mobs.Species.SnowGrouse)
export type Drop = { id: string, count: number }
export type DropRow = { id: string, min: number, max: number, chance: number }

local MobSpecies = {}

function MobSpecies.get(id: string): Species?
	return Config.Mobs.Species[id]
end

function MobSpecies.ids(): { string }
	return Config.Mobs.SpeciesIds
end

-- Ring is clamped to the 4 biome rings; weights are indexed ring + 1.
function MobSpecies.ringWeight(def: Species, ring: number): number
	local index = math.clamp(math.floor(ring), 0, #def.ringWeights - 1) + 1
	return math.max(0, def.ringWeights[index] or 0)
end

-- Hostile weight multiplier: grows per ring, capped by the existing ring budget cap.
function MobSpecies.hostileFactor(def: Species, ring: number): number
	if def.role ~= "hostile" then
		return 1
	end
	local per = def.hostileWeightPerRing or 0
	return math.min(Config.Scaling.MaxRingBudgetMultiplier, 1 + per * math.max(0, ring))
end

-- Spawn weight at a ring (0 = cannot spawn here/now). danger = night or blizzard.
function MobSpecies.spawnWeight(def: Species, ring: number, day: number, danger: boolean): number
	if day < def.minDay or (def.nightOnly and not danger) then
		return 0
	end
	return MobSpecies.ringWeight(def, ring) * MobSpecies.hostileFactor(def, ring)
end

-- Outer rings are meaner: hostile aggro range grows per ring, capped by Scaling.MaxRingDamageMultiplier.
function MobSpecies.aggroScale(def: Species, ring: number): number
	if def.role ~= "hostile" then
		return 1
	end
	return math.min(
		Config.Scaling.MaxRingDamageMultiplier,
		1 + Config.Mobs.RingAggroPerRing * math.max(0, ring)
	)
end

-- Hits a damage-per-hit attacker needs at base health (day 1, ring 0, solo).
function MobSpecies.hitsToKill(def: Species, damage: number): number
	if damage <= 0 then
		return math.huge
	end
	return math.ceil(def.health / damage)
end

-- Another mob of this species may spawn (live count under its cap).
function MobSpecies.underCap(def: Species, live: number): boolean
	return live < def.spawnCap
end

-- Members to spawn together (herd / pack), never past the cap.
function MobSpecies.groupSize(def: Species, live: number): number
	return math.max(0, math.min(def.packSize or 1, def.spawnCap - live))
end

-- Mob parts live + new stay under the mob part cap, and chunk + mob parts under the world cap.
function MobSpecies.partsOk(mobParts: number, add: number, otherParts: number?): boolean
	local S = Config.Mobs.Spawning
	if mobParts + add > S.MaxMobParts then
		return false
	end
	if otherParts ~= nil then
		return otherParts + mobParts + add <= Config.Perf.MaxLiveParts - S.PartHeadroom
	end
	return true
end

-- The ground the spawn ray hit is the real terrain surface (within tolerance): rejects ungrounded sites
-- (unbuilt chunk, a roof, a tree top). terrainY nil = no terrain under the point.
function MobSpecies.groundedOk(terrainY: number?, hitY: number): boolean
	if terrainY == nil then
		return false
	end
	return math.abs(hitY - terrainY) <= Config.Mobs.Spawning.GroundTolerance
end

-- Drop rolls. roll() returns a number in [0, 1).
function MobSpecies.rollDrops(drops: { DropRow }, roll: () -> number): { Drop }
	local out: { Drop } = {}
	for _, row in drops do
		if roll() < row.chance then
			local span = row.max - row.min
			local count = row.min + math.floor(roll() * (span + 1))
			count = math.clamp(count, row.min, row.max)
			if count > 0 then
				table.insert(out, { id = row.id, count = count })
			end
		end
	end
	return out
end

return MobSpecies
