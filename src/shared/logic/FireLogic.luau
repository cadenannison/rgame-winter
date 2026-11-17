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
