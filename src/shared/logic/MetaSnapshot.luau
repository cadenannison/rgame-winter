--!strict
-- Pure builders for what the client may see of the meta profile. No Roblox APIs. Never includes receipts.

local ProfileSchema = require("./ProfileSchema")

local MetaSnapshot = {}

export type Snapshot = {
	coins: number,
	stats: { [string]: number },
	achievements: { string },
	ownedCosmetics: { string },
	equippedCosmetic: string,
	equippedPerk: string,
	unlockedGear: { string },
	titles: { string },
	equippedTitle: string,
	settings: { reduceScares: boolean },
	hintsSeen: { string },
}

local function sortedKeys(map: { [string]: boolean }): { string }
	local keys: { string } = {}
	for key, flag in map do
		if flag then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

function MetaSnapshot.build(profile: ProfileSchema.Profile): Snapshot
	local stats: { [string]: number } = {}
	for _, name in ProfileSchema.STAT_FIELDS do
		stats[name] = ProfileSchema.getStat(profile, name)
	end
	for _, name in ProfileSchema.PROGRESS_FIELDS do
		stats[name] = ProfileSchema.getStat(profile, name)
	end
	return {
		coins = profile.coins,
		stats = stats,
		achievements = sortedKeys(profile.achievements),
		ownedCosmetics = sortedKeys(profile.ownedCosmetics),
		equippedCosmetic = profile.equippedCosmetic,
		equippedPerk = profile.equippedPerk,
		unlockedGear = sortedKeys(profile.unlockedGear),
		titles = sortedKeys(profile.titles),
		equippedTitle = profile.equippedTitle,
		settings = { reduceScares = profile.settings.reduceScares },
		hintsSeen = sortedKeys(profile.hintsSeen),
	}
end

-- "N days to your record" when the run is within `window` days below the saved best; nil otherwise.
function MetaSnapshot.recordHint(day: number, best: number, window: number): string?
	if best <= 0 or day >= best then
		return nil
	end
	local left = best - day
	if left > window then
		return nil
	end
	return if left == 1 then "1 day to your record" else `{left} days to your record`
end

return MetaSnapshot
