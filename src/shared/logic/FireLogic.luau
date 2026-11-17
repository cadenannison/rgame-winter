--!strict
-- Pure campfire fuel math. Fuel is stored burn time in seconds. No Roblox APIs.

export type Fire = { fuel: number }

local FireLogic = {}

function FireLogic.new(fuelSeconds: number): Fire
	return { fuel = math.max(fuelSeconds, 0) }
end

function FireLogic.isLit(fire: Fire): boolean
	return fire.fuel > 0
end

-- Burns for dt seconds. Returns true if the fire just went out.
function FireLogic.burn(fire: Fire, dt: number): boolean
	if fire.fuel <= 0 then
		return false
	end
	fire.fuel = math.max(fire.fuel - dt, 0)
	return fire.fuel <= 0
end

-- Adds burn time up to maxFuel. Returns the seconds actually added.
function FireLogic.addFuel(fire: Fire, seconds: number, maxFuel: number): number
	local room = math.max(maxFuel - fire.fuel, 0)
	local added = math.min(math.max(seconds, 0), room)
	fire.fuel += added
	return added
end

-- Remaining burn as a 0-1 fraction of the cap, rounded to FRACTION_STEPS so the replicated attribute
-- changes only when the bar visibly moves.
local FRACTION_STEPS = 100
function FireLogic.fraction(fuel: number, maxFuel: number): number
	if maxFuel <= 0 then
		return 0
	end
	local f = math.clamp(fuel / maxFuel, 0, 1)
	return math.floor(f * FRACTION_STEPS + 0.5) / FRACTION_STEPS
end

-- Horizontal (XZ) distance test against the warm radius.
function FireLogic.inRadius(fx: number, fz: number, px: number, pz: number, radius: number): boolean
	local dx, dz = px - fx, pz - fz
	return dx * dx + dz * dz <= radius * radius
end

-- True if a lit fire at (fx, fz) warms the point.
function FireLogic.warms(
	fire: Fire,
	fx: number,
	fz: number,
	px: number,
	pz: number,
	radius: number
): boolean
	return FireLogic.isLit(fire) and FireLogic.inRadius(fx, fz, px, pz, radius)
end

return FireLogic
