--!strict
-- Pure mob rules: activation, budget, scaling, spawn picks, hit validation (no Roblox APIs).

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

-- Server-recomputed melee check: finite distance within range plus latency slack.
function MobRules.canMelee(dist: number, range: number, lagSlack: number): boolean
	return dist == dist and dist >= 0 and dist <= range + lagSlack
end

return MobRules
