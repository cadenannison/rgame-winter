--!strict
-- Pure wolf-vs-fire geometry (no Roblox APIs). Radii are studs on the XZ plane.

export type Fire = { x: number, z: number, radius: number } -- radius = the fire's WarmRadius

local FireRepel = {}

-- Repel edge for a fire: its WarmRadius (attribute, or fallback) plus the margin.
function FireRepel.repelRadius(warmRadius: number?, fallbackRepel: number, margin: number): number
	if warmRadius ~= nil and warmRadius > 0 then
		return warmRadius + margin
	end
	return fallbackRepel
end

-- First fire whose repel edge contains (x, z); returns its index or nil.
function FireRepel.insideAny(
	x: number,
	z: number,
	fires: { Fire },
	margin: number,
	fallbackRepel: number
): number?
	for i, f in fires do
		local r = FireRepel.repelRadius(f.radius, fallbackRepel, margin)
		local dx, dz = x - f.x, z - f.z
		if dx * dx + dz * dz <= r * r then
			return i
		end
	end
	return nil
end

-- A chase target inside a fire's repel circle is pushed to just outside it (radial projection), so a
-- wolf never paths into the warm area to reach a sheltered player.
function FireRepel.clampTarget(tx: number, tz: number, fire: Fire, repel: number): (number, number)
	local dx, dz = tx - fire.x, tz - fire.z
	local d = math.sqrt(dx * dx + dz * dz)
	if d >= repel then
		return tx, tz
	end
	if d < 1e-6 then
		return fire.x + repel, fire.z
	end
	return fire.x + dx / d * repel, fire.z + dz / d * repel
end

return FireRepel
