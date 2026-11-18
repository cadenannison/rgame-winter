--!strict
-- Pure dread weighting for ambient mobs (no Roblox APIs). Reads Isolation weights: lone players attract
-- ambient crows and wisps, groups suppress them, a full group suppresses them further. Server-only values;
-- nothing here is ever shown as a meter. Also picks the crow scatter direction and the wisp hazard point.

local Config = require("../Config")
local Isolation = require("./Isolation")

export type Point = { x: number, z: number }

local MobDread = {}

-- Spawn weight multiplier for the anchor player (index into points). 1 = neutral (solo baseline).
function MobDread.factor(points: { Point }, index: number, partySize: number): number
	local D = Config.Mobs.Dread
	local weights = Isolation.weights(points, partySize)
	local w = weights[index]
	if w == nil then
		return 1
	end
	local f = w / Config.Isolation.SoloBaseline
	if Isolation.fullGroup(points) then
		f *= D.FullGroupFactor
	end
	return math.clamp(f, D.MinFactor, D.MaxFactor)
end

-- Ambient species weight under dread; non-ambient species pass through untouched.
function MobDread.weight(role: string, base: number, factor: number): number
	return if role == "ambient" then base * factor else base
end

local function unit(dx: number, dz: number): Point
	local m = math.sqrt(dx * dx + dz * dz)
	if m < 1e-6 then
		return { x = 1, z = 0 }
	end
	return { x = dx / m, z = dz / m }
end

-- Crows scatter toward the Stalker's hunting position; with no hunt, straight away from the player.
function MobDread.scatterDir(self: Point, player: Point?, stalker: Point?): Point
	if stalker then
		return unit(stalker.x - self.x, stalker.z - self.z)
	end
	if player then
		return unit(self.x - player.x, self.z - player.z)
	end
	return { x = 1, z = 0 }
end

-- Where a wisp drifts: the Stalker when it hunts, else a point on the far side of the player from the
-- nearest lit fire (off the safe path). nil when there is nothing to drift toward.
function MobDread.hazardPoint(player: Point, fire: Point?, stalker: Point?, lead: number): Point?
	if stalker then
		return stalker
	end
	if fire then
		local dir = unit(player.x - fire.x, player.z - fire.z)
		return { x = player.x + dir.x * lead * 2, z = player.z + dir.z * lead * 2 }
	end
	return nil
end

return MobDread
