--!strict
-- Pure helpers for client creature effects (Art/CreatureFx): telegraph ring progress, wisp light selection,
-- crow flock offsets. No Roblox APIs.

export type Candidate = { id: number, dist: number }
export type Offset = { x: number, y: number, z: number }

local CreatureFxLogic = {}

-- Ground-slam radius: Config reach (attackRange) plus the dodge leeway. The server hit test (SpeciesKit) and the
-- client telegraph ring both use it, so the ring always matches where the slam lands. Never read root size.
function CreatureFxLogic.slamRadius(attackRange: number, leeway: number): number
	return math.max(attackRange, 0) + math.max(leeway, 0)
end

-- Fraction (0..1) of a wind-up that has elapsed. total <= 0 counts as already full.
function CreatureFxLogic.telegraphProgress(total: number, elapsed: number): number
	if total <= 0 then
		return 1
	end
	return math.clamp(elapsed / total, 0, 1)
end

-- Radius of the filling disc for a ring of outer radius `maxRadius` (ease-out so the start is visible).
function CreatureFxLogic.fillRadius(progress: number, maxRadius: number): number
	local p = math.clamp(progress, 0, 1)
	return maxRadius * (1 - (1 - p) * (1 - p))
end

-- Disc transparency: faint at the start, stronger as the hit nears.
function CreatureFxLogic.fillTransparency(progress: number, from: number, to: number): number
	return from + (to - from) * math.clamp(progress, 0, 1)
end

-- Picks the ids that should hold a light: nearest first, at most maxLights, within radius. Ids already lit
-- get radius * (1 + hysteresis) so lights do not flicker at the edge.
function CreatureFxLogic.selectLights(
	cands: { Candidate },
	lit: { [number]: boolean },
	maxLights: number,
	radius: number,
	hysteresis: number
): { [number]: boolean }
	local pool: { Candidate } = {}
	for _, c in cands do
		local limit = if lit[c.id] then radius * (1 + hysteresis) else radius
		if c.dist <= limit then
			table.insert(pool, c)
		end
	end
	table.sort(pool, function(a, b)
		if a.dist == b.dist then
			return a.id < b.id
		end
		return a.dist < b.dist
	end)
	local out: { [number]: boolean } = {}
	for i = 1, math.min(#pool, math.max(maxLights, 0)) do
		out[pool[i].id] = true
	end
	return out
end

-- Moves a 0..1 scatter value toward 1 (scattering) or 0 (calm) at `rate` per second.
function CreatureFxLogic.scatterStep(
	current: number,
	scattering: boolean,
	dt: number,
	rate: number
): number
	local target = if scattering then 1 else 0
	local step = rate * math.max(dt, 0)
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

-- True for States where crows scatter instead of circling.
function CreatureFxLogic.isScatterState(state: string): boolean
	return state == "Run"
		or state == "Alert"
		or state == "Attack"
		or state == "Hurt"
		or state == "Telegraph"
end

-- Offset of follower `index` (1..count) from its crow, in world axes. scatter 0 = circling the crow; 1 = fanned out
-- ahead along (hx, hz) (flat heading; zero vector = straight up and out). Always finite and within `reach`.
function CreatureFxLogic.flockOffset(
	index: number,
	count: number,
	t: number,
	scatter: number,
	hx: number,
	hz: number,
	orbit: number,
	height: number,
	reach: number
): Offset
	local n = math.max(count, 1)
	local base = (index - 1) / n * 2 * math.pi
	local angle = base + t * (0.9 + 0.15 * index)
	local r = orbit * (0.8 + 0.4 * ((index - 1) % 2))
	local cx = math.cos(angle) * r
	local cz = math.sin(angle) * r
	local cy = height + math.sin(t * 1.7 + index) * 0.6
	local s = math.clamp(scatter, 0, 1)
	local len = math.sqrt(hx * hx + hz * hz)
	local dx, dz = 0, 0
	if len > 1e-4 then
		dx, dz = hx / len, hz / len
	end
	local fan = (index - (n + 1) / 2) * 0.35
	local fx = dx * math.cos(fan) - dz * math.sin(fan)
	local fz = dx * math.sin(fan) + dz * math.cos(fan)
	local fly = reach * s
	return {
		x = cx * (1 - s) + fx * fly,
		y = cy + s * height,
		z = cz * (1 - s) + fz * fly,
	}
end

return CreatureFxLogic
