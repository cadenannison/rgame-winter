--!strict
-- Pure wildlife rules (no Roblox APIs): day density, per-ring creature targets near a player, fire-free day
-- spawns and the day-counter replacement schedule for killed animals. All numbers: Config.Wildlife.

local Config = require("../Config")
local FireRepel = require("./FireRepel")
local MobRules = require("./MobRules")

export type Target = { min: number, max: number }
export type Pending = { kind: string, dueDay: number }

local MobWildlife = {}

-- Spawn density: full while danger (night / blizzard), DayDensityMultiplier by day.
function MobWildlife.density(danger: boolean): number
	return if danger then 1 else Config.Wildlife.DayDensityMultiplier
end

local function ringIndex(ring: number): number
	return math.clamp(math.floor(ring), 0, #Config.Wildlife.TargetMax - 1) + 1
end

-- Creatures wanted within NearRadius of a player in this ring. Day density does not shrink the target: it
-- scales the per-kind caps (scaledCap), which is what thins the day crowd.
function MobWildlife.target(ring: number): Target
	local W = Config.Wildlife
	local i = ringIndex(ring)
	local lo = math.max(1, W.TargetMin[i])
	return { min = lo, max = math.max(lo, W.TargetMax[i]) }
end

-- Per-kind cap after day density (never below 1).
function MobWildlife.scaledCap(cap: number, danger: boolean): number
	return math.max(1, math.ceil(cap * MobWildlife.density(danger) - 1e-9))
end

-- Natural-spawn attempts this tick: 0 at/above the target max, UrgentAttempts under the min, else 1.
function MobWildlife.attempts(near: number, ring: number): number
	local t = MobWildlife.target(ring)
	if near >= t.max then
		return 0
	end
	return if near < t.min then math.max(1, Config.Wildlife.UrgentAttempts) else 1
end

-- Live budget with the ring-target floor (so costly kinds cannot starve the targets). MaxLiveMobs caps it.
function MobWildlife.budget(liveBudget: number, ring: number, players: number): number
	local b = liveBudget
	if Config.Wildlife.BudgetFloorFromTargets and players > 0 then
		b = math.max(b, MobWildlife.target(ring).max * players)
	end
	return math.clamp(b, 0, Config.Scaling.MaxLiveMobs)
end

-- Day wildlife never spawns inside a lit fire's radius (plus the spawn margin).
function MobWildlife.dayBlocked(
	danger: boolean,
	x: number,
	z: number,
	fires: { FireRepel.Fire }
): boolean
	if danger or not Config.Wildlife.OutsideFireOnly then
		return false
	end
	return FireRepel.insideAny(x, z, fires, Config.FireRules.SpawnMargin, Config.Fire.RepelRadius)
		~= nil
end

-- Killed animals (not ambient crows/wisps, not hostiles or bosses) are replaced later.
function MobWildlife.replaces(role: string, category: string): boolean
	return category == "animal" and role ~= "ambient"
end

-- Queues a replacement RespawnDays {min, max} days after `day` (roll01 in [0, 1)).
function MobWildlife.schedule(queue: { Pending }, kind: string, day: number, roll01: number)
	if #queue >= Config.Scaling.MaxLiveMobs then
		return
	end
	local range = Config.Wildlife.RespawnDays
	local lo = math.max(1, math.floor(range[1]))
	local hi = math.max(lo, math.floor(range[2]))
	local delay = math.clamp(lo + math.floor(roll01 * (hi - lo + 1)), lo, hi)
	table.insert(queue, { kind = kind, dueDay = day + delay })
end

-- First queued replacement due by `day` (oldest first), or nil.
function MobWildlife.nextDue(queue: { Pending }, day: number): Pending?
	for _, entry in queue do
		if entry.dueDay <= day then
			return entry
		end
	end
	return nil
end

function MobWildlife.remove(queue: { Pending }, entry: Pending)
	local index = table.find(queue, entry)
	if index then
		table.remove(queue, index)
	end
end

-- Replacement spawn point: at least RespawnMinPlayerDistance from every player, within spawn range of one.
function MobWildlife.respawnPointOk(playerDists: { number }): boolean
	return MobRules.spawnDistanceOk(
		playerDists,
		math.max(Config.Wildlife.RespawnMinPlayerDistance, Config.Mobs.SpawnMinDistance),
		Config.Mobs.SpawnMaxDistance
	)
end

return MobWildlife
