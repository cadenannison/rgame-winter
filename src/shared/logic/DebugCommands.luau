--!strict
-- Pure validation for DebugService commands. No Roblox APIs.

export type Limits = {
	maxDay: number,
	maxClockSpeed: number,
	ringCount: number,
	darkEvents: { string },
	itemIds: { string }?, -- valid "give" args (ItemCatalog ids)
	mobKinds: { string }?, -- valid "spawnMob" args
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
	"give",
	"spawnMob",
	"runSummary",
	"mode",
}

-- Commands that only call registered handlers (no attribute is written by DebugService).
DebugCommands.ACTION_ONLY =
	{ give = true, spawnMob = true, runSummary = true, mode = true } :: { [string]: boolean }

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
	elseif name == "give" or name == "spawnMob" then
		local list = if name == "give" then limits.itemIds else limits.mobKinds
		if type(arg) ~= "string" or list == nil or not table.find(list, arg) then
			return false, `unknown {name} arg`
		end
		return true, arg
	elseif name == "runSummary" then
		-- QA: end a solo run for the caller so the real RunSummary path fires (lobby QA). No arg.
		return true, nil
	elseif name == "mode" then
		-- Studio-only: persists the next Test's server mode ("clear" removes the override).
		if arg == "run" or arg == "lobby" or arg == "clear" then
			return true, arg
		end
		return false, "mode must be run, lobby or clear"
	end
	return false, "unknown command"
end

return DebugCommands
