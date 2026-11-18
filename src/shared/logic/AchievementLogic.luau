--!strict
-- Pure achievement evaluation and idempotent grant. No Roblox APIs.
-- An achievement unlocks when ProfileSchema.getStat(profile, stat) >= atLeast. Granting twice pays once.

local Config = require("../Config")
local Types = require("../data/Types")
local ProfileSchema = require("./ProfileSchema")

local AchievementLogic = {}

-- True when the profile meets the condition (stat counters only; the client never reports stats).
function AchievementLogic.met(
	profile: ProfileSchema.Profile,
	condition: Types.StatCondition
): boolean
	return ProfileSchema.getStat(profile, condition.stat) >= condition.atLeast
end

-- Defs whose condition is met and that are not unlocked yet, in list order.
function AchievementLogic.evaluate(
	profile: ProfileSchema.Profile,
	defs: { Types.AchievementDef }
): { Types.AchievementDef }
	local result: { Types.AchievementDef } = {}
	for _, def in defs do
		if not profile.achievements[def.id] and AchievementLogic.met(profile, def.condition) then
			table.insert(result, def)
		end
	end
	return result
end

local function countKeys(map: { [string]: boolean }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

-- Idempotent grant: marks the achievement, pays its coins (clamped) and grants its title.
-- Returns false (changes nothing) if already unlocked or the unlock log is full.
function AchievementLogic.grant(profile: ProfileSchema.Profile, def: Types.AchievementDef): boolean
	if profile.achievements[def.id] then
		return false
	end
	if countKeys(profile.achievements) >= Config.Meta.MaxAchievements then
		return false
	end
	profile.achievements[def.id] = true
	local coins = math.clamp(math.floor(def.coins), 0, Config.Meta.MaxAchievementCoinReward)
	profile.coins = math.clamp(profile.coins + coins, 0, Config.MaxCoins)
	if
		def.title
		and (profile.titles[def.title] or countKeys(profile.titles) < Config.Meta.MaxTitles)
	then
		profile.titles[def.title] = true
	end
	return true
end

-- Adds to a progress counter (clamped, capped entry count). Returns the new value.
function AchievementLogic.addProgress(
	profile: ProfileSchema.Profile,
	field: string,
	amount: number
): number
	if not table.find(ProfileSchema.PROGRESS_FIELDS, field) or amount ~= amount or amount <= 0 then
		return profile.achievementProgress[field] or 0
	end
	local value = math.min(
		(profile.achievementProgress[field] or 0) + math.floor(amount),
		Config.Meta.MaxStatValue
	)
	profile.achievementProgress[field] = value
	return value
end

-- Raises a progress counter to value if higher (deepestRing). Returns the new value.
function AchievementLogic.raiseProgress(
	profile: ProfileSchema.Profile,
	field: string,
	value: number
): number
	if not table.find(ProfileSchema.PROGRESS_FIELDS, field) or value ~= value then
		return profile.achievementProgress[field] or 0
	end
	local clamped = math.clamp(math.floor(value), 0, Config.Meta.MaxStatValue)
	local current = profile.achievementProgress[field] or 0
	if clamped > current then
		profile.achievementProgress[field] = clamped
		return clamped
	end
	return current
end

return AchievementLogic
