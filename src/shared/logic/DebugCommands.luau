--!strict
-- Pure validation for DebugService commands. No Roblox APIs.

local Rarity = require("../data/Rarity")

export type Limits = {
	maxDay: number,
	maxClockSpeed: number,
	maxSeed: number?, -- "seed" argument upper bound (default 2147483646)
	ringCount: number,
	darkEvents: { string },
	itemIds: { string }?, -- valid "give" args (ItemCatalog ids)
	mobKinds: { string }?, -- valid "spawnMob" args
	gallerySets: { string }?, -- valid "gallery" args (art review sets, plus "clear")
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
	"gallery",
	"structures",
	"tp",
	"chest",
	"seed",
	"respawn",
}

-- Commands that only call registered handlers (no attribute is written by DebugService).
DebugCommands.ACTION_ONLY = {
	give = true,
	spawnMob = true,
	runSummary = true,
	mode = true,
	gallery = true,
	structures = true, -- nearest massive structures with distance and ring
	tp = true, -- teleport next to a structure / ring / player, grounded
	chest = true, -- spawn a loot chest of a rarity in front of the player
	seed = true, -- print or set the run seed
	respawn = true, -- the real revive/respawn transition (SurvivalService.respawn)
} :: { [string]: boolean }

export type TpTarget = { kind: string, index: number?, id: string?, ring: number?, name: string? }

-- "/debug tp structure [n|Id]" | "ring <n>" | "<player name>" -> normalized target (nil = unusable).
function DebugCommands.parseTp(arg: unknown, ringCount: number): TpTarget?
	if type(arg) ~= "string" then
		return nil
	end
	local text = string.match(arg, "^%s*(.-)%s*$") or ""
	if text == "" or #text > 40 then
		return nil
	end
	local word, rest = string.match(text, "^(%S+)%s*(.-)$")
	local lower = string.lower(word or "")
	if lower == "structure" then
		if rest == "" then
			return { kind = "structure", index = 1 }
		end
		local n = tonumber(rest)
		if n ~= nil then
			if n % 1 ~= 0 or n < 1 or n > 64 then
				return nil
			end
			return { kind = "structure", index = n }
		end
		return { kind = "structure", index = 1, id = rest }
	elseif lower == "ring" then
		local n = tonumber(rest)
		if n == nil or n % 1 ~= 0 or n < 1 or n > ringCount then
			return nil
		end
		return { kind = "ring", ring = n }
	end
	return { kind = "player", name = text }
end

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
	elseif name == "gallery" then
		-- Studio-only art review: spawns a labelled row of an art pass's assets ("clear" removes it).
		if type(arg) == "string" and limits.gallerySets and table.find(limits.gallerySets, arg) then
			return true, arg
		end
		return false, "unknown gallery set"
	elseif name == "structures" or name == "respawn" then
		return true, nil
	elseif name == "tp" then
		local target = DebugCommands.parseTp(arg, limits.ringCount)
		if target == nil then
			return false, "tp needs structure [n|Id], ring <n> or a player name"
		end
		return true, target
	elseif name == "chest" then
		local r = if type(arg) == "string" then string.lower(arg) else ""
		if not Rarity.isRarity(r) then
			return false, "chest needs a rarity: " .. table.concat(Rarity.List, ", ")
		end
		return true, r
	elseif name == "seed" then
		if arg == nil or arg == "" then
			return true, nil -- print
		end
		local n = if type(arg) == "string" then tonumber(arg) else arg
		if not isInt(n, 0, limits.maxSeed or 2147483646) then
			return false, "seed must be a whole number"
		end
		return true, n
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
