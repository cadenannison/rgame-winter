--!strict
-- Pure mob rules: activation, budget, scaling, spawn picks, hit validation (no Roblox APIs).

local Config = require("../Config")
local FireRepel = require("./FireRepel")

export type Point = { x: number, z: number }

local MobRules = {}

function MobRules.distance(a: Point, b: Point): number
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Nearest player distance, or nil when there are no players.
function MobRules.nearestDistance(from: Point, players: { Point }): number?
	local best: number? = nil
	for _, p in players do
		local d = MobRules.distance(from, p)
		if best == nil or d < best then
			best = d
		end
	end
	return best
end

-- Indices of mobs whose AI should run this step (a player within radius). No players -> none.
function MobRules.selectActive(mobs: { Point }, players: { Point }, radius: number): { number }
	local active = {}
	for i, m in mobs do
		local d = MobRules.nearestDistance(m, players)
		if d ~= nil and d <= radius then
			table.insert(active, i)
		end
	end
	return active
end

-- Mob should despawn when no player is within despawnDistance.
function MobRules.shouldDespawn(nearest: number?, despawnDistance: number): boolean
	return nearest == nil or nearest > despawnDistance
end

function MobRules.scaledStat(
	base: number,
	perDay: number,
	day: number,
	maxMultiplier: number
): number
	local mult = math.min(maxMultiplier, 1 + perDay * math.max(0, day - 1))
	return base * mult
end

function MobRules.budget(
	base: number,
	day: number,
	playerCount: number,
	isNight: boolean,
	perDay: number,
	perExtraPlayer: number,
	nightMultiplier: number,
	maxMultiplier: number
): number
	if playerCount <= 0 then
		return 0
	end
	local scale = math.min(maxMultiplier, 1 + perDay * math.max(0, day - 1))
	local party = 1 + perExtraPlayer * (playerCount - 1)
	local night = if isNight then nightMultiplier else 1
	return math.floor(base * scale * party * night)
end

-- Weighted pick; roll01 in [0,1). Returns index or nil when total weight is 0.
function MobRules.pickWeighted(weights: { number }, roll01: number): number?
	local total = 0
	for _, w in weights do
		total += math.max(0, w)
	end
	if total <= 0 then
		return nil
	end
	local target = roll01 * total
	local acc = 0
	for i, w in weights do
		acc += math.max(0, w)
		if target < acc then
			return i
		end
	end
	return #weights
end

-- Spawn point is valid when every player is at least minDist away and some player is within maxDist.
function MobRules.spawnDistanceOk(
	playerDists: { number },
	minDist: number,
	maxDist: number
): boolean
	local nearest: number? = nil
	for _, d in playerDists do
		if d < minDist then
			return false
		end
		if nearest == nil or d < nearest then
			nearest = d
		end
	end
	return nearest ~= nil and nearest <= maxDist
end

-- Hits a fixed-damage attacker needs to bring health to 0 (ceiling). nil when damage is not positive.
function MobRules.hitsToKill(health: number, damage: number): number?
	if damage <= 0 then
		return nil
	end
	return math.max(1, math.ceil(health / damage))
end

-- Server-recomputed melee check: finite distance within range plus latency slack.
function MobRules.canMelee(dist: number, range: number, lagSlack: number): boolean
	return dist == dist and dist >= 0 and dist <= range + lagSlack
end

-- Fire zone rules (Config.FireRules). Fires are { x, z, radius = WarmRadius }.

-- Categories in FireRules.SpawnExcludeCategories never spawn inside a lit fire's warm radius + SpawnMargin.
function MobRules.spawnExcluded(
	category: string,
	x: number,
	z: number,
	fires: { FireRepel.Fire }
): boolean
	local rules = Config.FireRules
	if table.find(rules.SpawnExcludeCategories, category) == nil then
		return false
	end
	return FireRepel.insideAny(x, z, fires, rules.SpawnMargin, Config.Fire.RepelRadius) ~= nil
end

-- Spawn point pushed just outside every fire exclusion circle (bosses are moved, not rejected).
function MobRules.spawnPoint(
	category: string,
	x: number,
	z: number,
	fires: { FireRepel.Fire }
): (number, number)
	local rules = Config.FireRules
	if table.find(rules.SpawnExcludeCategories, category) == nil then
		return x, z
	end
	local px, pz = x, z
	for _ = 1, 2 do
		for _, f in fires do
			local edge = FireRepel.repelRadius(f.radius, Config.Fire.RepelRadius, rules.SpawnMargin)
			px, pz = FireRepel.clampTarget(px, pz, f, edge + 0.01)
		end
	end
	return px, pz
end

-- Repelled = in FireRules.RepelCategories and not a fire-breaker. Bosses (and heavy or ranged kinds with
-- breaksFire) ignore the edge.
function MobRules.repelledByFire(category: string, breaksFire: boolean): boolean
	return not breaksFire
		and category ~= "boss"
		and table.find(Config.FireRules.RepelCategories, category) ~= nil
end

-- Server-side bite gate for repelled mobs: no damage to a target standing inside a fire's warm radius, and
-- none while the mob itself is inside a repel circle (it retreats instead).
function MobRules.biteAllowed(
	repelled: boolean,
	mob: Point,
	target: Point,
	fires: { FireRepel.Fire }
): boolean
	if not repelled then
		return true
	end
	if
		FireRepel.insideAny(mob.x, mob.z, fires, Config.Night.RepelMargin, Config.Fire.RepelRadius)
		~= nil
	then
		return false
	end
	return FireRepel.insideAny(target.x, target.z, fires, 0, Config.Fire.WarmRadius) == nil
end

return MobRules
