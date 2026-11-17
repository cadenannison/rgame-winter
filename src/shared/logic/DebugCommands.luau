--!strict
-- Pure validation for DebugService commands. No Roblox APIs.

export type Limits = {
	maxDay: number,
	maxClockSpeed: number,
	ringCount: number,
	darkEvents: { string },
}

local DebugCommands = {}

DebugCommands.NAMES = {
	"setDay",
	"clockSpeed",
	"blizzard",
	"darkEvent",
	"stalker",
	"invincible",
	"teleportRing",
}

local function isNumber(v: unknown): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function isInt(v: unknown, lo: number, hi: number): boolean
	return isNumber(v) and (v :: number) % 1 == 0 and (v :: number) >= lo and (v :: number) <= hi
end

-- Returns ok, normalized arg (or an error string when not ok).
function DebugCommands.validate(name: unknown, arg: unknown, limits: Limits): (boolean, unknown)
	if type(name) ~= "string" then
		return false, "name must be a string"
	end
	if name == "setDay" then
		if not isInt(arg, 1, limits.maxDay) then
			return false, "day out of range"
		end
		return true, arg
	elseif name == "clockSpeed" then
		if not isNumber(arg) or (arg :: number) < 0 or (arg :: number) > limits.maxClockSpeed then
			return false, "speed out of range"
		end
		return true, arg
	elseif name == "blizzard" or name == "stalker" or name == "invincible" then
		if type(arg) ~= "boolean" then
			return false, "arg must be boolean"
		end
		return true, arg
	elseif name == "darkEvent" then
		if arg == nil or arg == "" then
			return true, "" -- clear
		end
		if type(arg) == "string" and table.find(limits.darkEvents, arg) then
			return true, arg
		end
		return false, "unknown dark event"
	elseif name == "teleportRing" then
		if not isInt(arg, 1, limits.ringCount) then
			return false, "ring out of range"
		end
		return true, arg
	end
	return false, "unknown command"
end

return DebugCommands
