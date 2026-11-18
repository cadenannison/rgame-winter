--!strict
-- Isolation weights (pure, no Roblox APIs). Server-only values: never replicate a weight.
-- A player alone weighs most, a pair less, a group (3+) much less; a one-player party uses the
-- reduced solo baseline. A full group (every living member in one cluster within Range) blocks big events.

local Config = require("../Config")

export type Point = { x: number, z: number }

local Isolation = {}

local function within(a: Point, b: Point, range: number): boolean
	local dx, dz = a.x - b.x, a.z - b.z
	return dx * dx + dz * dz <= range * range
end

-- Teammates within Range of points[i].
function Isolation.neighbors(points: { Point }, i: number, range: number?): number
	local r = range or Config.Isolation.Range
	local count = 0
	for j, p in points do
		if j ~= i and within(points[i], p, r) then
			count += 1
		end
	end
	return count
end

-- Weight per point. partySize is the run's party size (1 = solo baseline).
function Isolation.weights(
	points: { Point },
	partySize: number,
	cfg: Config.IsolationConfig?
): { number }
	local c = cfg or Config.Isolation
	local out: { number } = {}
	for i in points do
		if partySize <= 1 then
			out[i] = c.SoloBaseline
		else
			local n = Isolation.neighbors(points, i, c.Range)
			if n == 0 then
				out[i] = c.WeightAlone
			elseif n == 1 then
				out[i] = c.WeightPair
			else
				out[i] = c.WeightGroup
			end
		end
	end
	return out
end

-- True when 2+ points form one connected cluster (each link within Range) and the setting is on.
function Isolation.fullGroup(points: { Point }, cfg: Config.IsolationConfig?): boolean
	local c = cfg or Config.Isolation
	if not c.FullGroupBlocksBigEvents or #points < 2 then
		return false
	end
	local seen: { [number]: boolean } = { [1] = true }
	local stack = { 1 }
	local reached = 1
	while #stack > 0 do
		local i = table.remove(stack) :: number
		for j, p in points do
			if not seen[j] and within(points[i], p, c.Range) then
				seen[j] = true
				reached += 1
				table.insert(stack, j)
			end
		end
	end
	return reached == #points
end

-- Weighted pick: roll in [0, 1). Returns nil when every weight is zero.
function Isolation.pick(weights: { number }, roll: number): number?
	local total = 0
	for _, w in weights do
		total += math.max(w, 0)
	end
	if total <= 0 then
		return nil
	end
	local target = math.clamp(roll, 0, 1) * total
	local last: number? = nil
	for i, w in weights do
		if w > 0 then
			last = i
			target -= w
			if target < 0 then
				return i
			end
		end
	end
	return last
end

-- Index of the highest weight (ties: lowest index). Nil for an empty list.
function Isolation.mostIsolated(weights: { number }): number?
	local best: number? = nil
	for i, w in weights do
		if best == nil or w > weights[best] then
			best = i
		end
	end
	return best
end

-- Highest weight in the party (0 when empty).
function Isolation.maxWeight(weights: { number }): number
	local m = 0
	for _, w in weights do
		m = math.max(m, w)
	end
	return m
end

return Isolation
