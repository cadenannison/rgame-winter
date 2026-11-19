--!strict
-- Pure HUD helpers (no Roblox APIs): bar fractions, compass angle, hint choice, /debug parsing.

export type HintState = {
	warmth: number,
	hunger: number,
	health: number,
	isNight: boolean,
	hasItems: boolean,
}

export type HintRule = { id: string, kind: string, threshold: number?, text: string? }

local HudMath = {}

-- Fraction 0..1 of value/maxValue; safe for nan, negative and zero max.
function HudMath.fraction(value: number, maxValue: number): number
	if maxValue <= 0 or value ~= value then
		return 0
	end
	return math.max(0, math.min(1, value / maxValue))
end

-- Signed clockwise angle in degrees from the (flat) look vector to the target direction.
function HudMath.compassAngle(lookX: number, lookZ: number, toX: number, toZ: number): number
	local cross = lookX * toZ - lookZ * toX
	local dot = lookX * toX + lookZ * toZ
	if cross == 0 and dot == 0 then
		return 0
	end
	return math.deg(math.atan2(cross, dot))
end

-- First rule not yet shown whose condition holds, or nil.
function HudMath.nextHint(
	rules: { HintRule },
	shown: { [string]: boolean },
	state: HintState
): string?
	for _, rule in rules do
		if not shown[rule.id] then
			local threshold = rule.threshold or 0
			local hit = false
			if rule.kind == "start" then
				hit = true
			elseif rule.kind == "warmthLow" then
				hit = state.warmth <= threshold
			elseif rule.kind == "hungerLow" then
				hit = state.hunger <= threshold
			elseif rule.kind == "healthLow" then
				hit = state.health <= threshold
			elseif rule.kind == "night" then
				hit = state.isNight
			elseif rule.kind == "firstItem" then
				hit = state.hasItems
			end
			if hit then
				return rule.id
			end
		end
	end
	return nil
end

-- Next hotbar slot for a wheel step (delta > 0 forward), wrapping within 1..count.
function HudMath.cycleSlot(current: number, delta: number, count: number): number
	if count <= 0 then
		return 1
	end
	local step = if delta > 0 then 1 elseif delta < 0 then -1 else 0
	return ((current - 1 + step) % count) + 1
end

local TRUE_WORDS: { [string]: boolean } =
	{ ["true"] = true, ["on"] = true, ["1"] = true, ["yes"] = true }
local FALSE_WORDS: { [string]: boolean } =
	{ ["false"] = false, ["off"] = false, ["0"] = false, ["no"] = false }

local NUMBER_COMMANDS: { [string]: boolean } =
	{ setDay = true, clockSpeed = true, teleportRing = true }

-- Parse "<command> [arg]" (text after "/debug") against known command names.
-- Arg typing follows DebugCommands: bool for blizzard/stalker/invincible, string for darkEvent, else number.
-- Returns ok, name-or-error, arg.
function HudMath.parseDebug(text: string, names: { string }): (boolean, string, unknown)
	local name, rest = string.match(text, "^%s*(%S+)%s*(.-)%s*$")
	if not name then
		return false, "usage: /debug <command> [arg]", nil
	end
	if not table.find(names, name) then
		return false, "unknown command; try: " .. table.concat(names, ", "), nil
	end
	if name == "blizzard" then
		-- bool (legacy toggle) or the BlizzardService words: start | stop | intensity <n>
		local word = string.lower(rest or "")
		if TRUE_WORDS[word] then
			return true, name, true
		elseif FALSE_WORDS[word] == false then
			return true, name, false
		end
		return true, name, rest or ""
	elseif name == "stalker" or name == "invincible" then
		local word = string.lower(rest or "")
		if TRUE_WORDS[word] then
			return true, name, true
		elseif FALSE_WORDS[word] == false then
			return true, name, false
		end
		return false, name .. " needs true/false", nil
	elseif not NUMBER_COMMANDS[name] then
		-- every other command takes a string arg (or none); DebugCommands.validate normalizes it
		return true, name, rest or ""
	end
	local n = tonumber(rest or "")
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return false, name .. " needs a number", nil
	end
	return true, name, n
end

return HudMath
