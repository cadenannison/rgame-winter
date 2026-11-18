--!strict
-- Pure projectile rules (no Roblox APIs): direction validation, aim assist, friendly-fire damage.

export type V3 = { x: number, y: number, z: number }

local Projectile = {}

local MIN_LENGTH = 0.5
local MAX_LENGTH = 2

local function length(v: V3): number
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- Client direction must be finite and roughly unit length; returns the normalized vector or nil.
function Projectile.cleanDirection(v: V3): V3?
	if not (finite(v.x) and finite(v.y) and finite(v.z)) then
		return nil
	end
	local len = length(v)
	if len < MIN_LENGTH or len > MAX_LENGTH then
		return nil
	end
	return { x = v.x / len, y = v.y / len, z = v.z / len }
end

-- Angle in degrees between two unit vectors.
function Projectile.angleDegrees(a: V3, b: V3): number
	local dot = math.clamp(a.x * b.x + a.y * b.y + a.z * b.z, -1, 1)
	return math.deg(math.acos(dot))
end

-- Nudges a unit aim direction toward the target closest (by angle) to it, only inside maxDegrees.
function Projectile.aimAssist(origin: V3, dir: V3, targets: { V3 }, maxDegrees: number): V3
	local best: V3? = nil
	local bestAngle = maxDegrees
	for _, t in targets do
		local to = { x = t.x - origin.x, y = t.y - origin.y, z = t.z - origin.z }
		local len = length(to)
		if len > 0.001 then
			local unit = { x = to.x / len, y = to.y / len, z = to.z / len }
			local angle = Projectile.angleDegrees(dir, unit)
			if angle <= bestAngle then
				bestAngle = angle
				best = unit
			end
		end
	end
	return best or dir
end

-- Damage a stray projectile deals to a player (melee never hurts players).
function Projectile.playerDamage(damage: number, friendlyFireMultiplier: number): number
	return math.max(0, damage) * math.clamp(friendlyFireMultiplier, 0, 1)
end

-- Per-player active projectile cap.
function Projectile.canFire(active: number, maxActive: number): boolean
	return active < maxActive
end

return Projectile
