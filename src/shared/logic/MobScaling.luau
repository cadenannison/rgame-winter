--!strict
-- Pure mob scaling and spawn tables (no Roblox APIs). Every multiplier is clamped to its Config.Scaling /
-- Config.Bosses cap, then the live total is clamped to Scaling.MaxLiveMobs.

local Config = require("../Config")

export type Mult = { budget: number, health: number, damage: number }
export type Entry = {
	kind: string,
	category: string,
	biomes: { string },
	minDay: number,
	nightOnly: boolean,
	weight: number,
}
export type Row = { kind: string, weight: number }

local S = Config.Scaling
local B = Config.Bosses

local MobScaling = {}

local function capped(base: number, perStep: number, steps: number, cap: number): number
	return math.min(cap, base + perStep * math.max(0, steps))
end

-- Extra wolf-only difficulty past Config.WolfScaling.StartDay; multiply onto multipliers() results.
function MobScaling.wolfDamageFactor(day: number): number
	local W = Config.WolfScaling
	return capped(1, W.DamagePerDay, day - W.StartDay, W.MaxDamageMultiplier)
end

function MobScaling.wolfSpawnFactor(day: number): number
	local W = Config.WolfScaling
	return capped(1, W.SpawnRatePerDay, day - W.StartDay, W.MaxSpawnRateMultiplier)
end

-- Health and damage for a spawned mob. The Wolf's health never scales (the starting Axe always kills it in
-- Config.Combat.WolfHitsMin..Max hits); its difficulty rises through damage (wolfDamageFactor) and spawn
-- rate (wolfSpawnFactor). Other kinds scale health as before.
function MobScaling.mobStats(
	kind: string,
	baseHealth: number,
	baseDamage: number,
	day: number,
	ring: number,
	partySize: number
): (number, number)
	local mult = MobScaling.multipliers(day, ring, partySize)
	if kind == "Wolf" then
		return baseHealth, baseDamage * mult.damage * MobScaling.wolfDamageFactor(day)
	end
	return baseHealth * mult.health, baseDamage * mult.damage
end

-- Spawn-table weight multiplier for a kind (wolves get more frequent with days; others unchanged).
function MobScaling.weightFactor(kind: string, day: number): number
	return if kind == "Wolf" then MobScaling.wolfSpawnFactor(day) else 1
end

-- Day, ring (distance from the start forest) and party size, each capped separately.
function MobScaling.multipliers(day: number, ring: number, partySize: number): Mult
	local d = day - 1
	local extra = partySize - 1
	return {
		budget = capped(1, S.MobBudgetPerDay, d, S.MaxMobBudgetMultiplier)
			* capped(1, S.MobBudgetPerRing, ring, S.MaxRingBudgetMultiplier)
			* capped(1, S.MobBudgetPerExtraPlayer, extra, S.MaxPartyBudgetMultiplier),
		health = capped(1, S.MobHealthPerDay, d, S.MaxMobHealthMultiplier)
			* capped(1, S.MobHealthPerRing, ring, S.MaxRingHealthMultiplier)
			* capped(1, S.MobHealthPerExtraPlayer, extra, S.MaxPartyHealthMultiplier),
		damage = capped(1, S.MobDamagePerDay, d, S.MaxMobDamageMultiplier)
			* capped(1, S.MobDamagePerRing, ring, S.MaxRingDamageMultiplier),
	}
end

-- Budget slots for normal mobs (bosses are separate). No players -> 0. Hard cap: Scaling.MaxLiveMobs.
function MobScaling.liveBudget(
	base: number,
	mult: Mult,
	partySize: number,
	danger: boolean,
	nightMultiplier: number
): number
	if partySize <= 0 then
		return 0
	end
	local scaled = math.floor(base * mult.budget * (if danger then nightMultiplier else 1))
	return math.clamp(scaled, 0, S.MaxLiveMobs)
end

-- Boss stats: health grows only with party size, damage only with day; both capped.
function MobScaling.bossHealth(base: number, partySize: number): number
	return base * capped(1, B.HealthPerExtraPlayer, partySize - 1, B.MaxHealthMultiplier)
end

function MobScaling.bossDamage(base: number, day: number): number
	return base * capped(1, B.DamagePerDay, day - 1, B.MaxDamageMultiplier)
end

-- Chance that a blizzard brings the boss (0 before BlizzardBossFirstDay, capped after).
function MobScaling.blizzardBossChance(day: number): number
	if day < B.BlizzardBossFirstDay then
		return 0
	end
	return math.clamp(
		B.BlizzardBossChance + B.BlizzardBossChancePerDay * (day - B.BlizzardBossFirstDay),
		0,
		B.MaxBlizzardBossChance
	)
end

-- A mini-boss may spawn: late enough, room under the alive cap, and its respawn cooldown over.
function MobScaling.miniBossDue(
	minDay: number,
	day: number,
	aliveCount: number,
	lastKilledDay: number?
): boolean
	if day < math.max(B.MiniBossFirstDay, minDay) or aliveCount >= B.MiniBossMaxAlive then
		return false
	end
	return lastKilledDay == nil or day - lastKilledDay >= B.MiniBossRespawnDays
end

-- Deterministic spawn table for a biome: animals and hostiles only, entry order preserved.
-- danger = night or blizzard (night-only hostiles join the table).
function MobScaling.spawnTable(
	entries: { Entry },
	biomeId: string,
	day: number,
	danger: boolean
): { Row }
	local out: { Row } = {}
	for _, e in entries do
		if
			(e.category == "animal" or e.category == "hostile")
			and e.weight > 0
			and e.minDay <= day
			and table.find(e.biomes, biomeId) ~= nil
			and (danger or not e.nightOnly)
		then
			table.insert(out, { kind = e.kind, weight = e.weight })
		end
	end
	return out
end

return MobScaling
