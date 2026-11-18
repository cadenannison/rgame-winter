--!strict
-- Pure ping rules: kind, range and the per-player active cap. No Roblox APIs (positions are plain tables).

local Config = require("../Config")

export type Vec = { x: number, y: number, z: number }

local Ping = {}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function Ping.validKind(kind: unknown): boolean
	return type(kind) == "string" and table.find(Config.Ping.Kinds, kind) ~= nil
end

-- (ok, reason): BadKind | BadPosition | TooFar | Ok. origin = the pinger's position.
function Ping.check(kind: unknown, position: Vec, origin: Vec): (boolean, string)
	if not Ping.validKind(kind) then
		return false, "BadKind"
	end
	if not (finite(position.x) and finite(position.y) and finite(position.z)) then
		return false, "BadPosition"
	end
	local dx, dy, dz = position.x - origin.x, position.y - origin.y, position.z - origin.z
	if math.sqrt(dx * dx + dy * dy + dz * dz) > Config.Ping.MaxRange then
		return false, "TooFar"
	end
	return true, "Ok"
end

-- Drops expired entries (expiresAt <= now) and reports whether another ping is allowed.
function Ping.canAdd(expiries: { number }, now: number): boolean
	local live = 0
	for _, expiresAt in expiries do
		if expiresAt > now then
			live += 1
		end
	end
	return live < Config.Ping.MaxActivePerPlayer
end

return Ping
