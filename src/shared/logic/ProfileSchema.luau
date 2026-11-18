--!strict
-- Pure profile schema: defaults, validation and migrations keyed on schemaVersion. No Roblox APIs.
-- Saved tables use string keys only (DataStores reject sparse numeric tables): use tostring(id).

local Config = require("../Config")
local ItemCatalog = require("../ItemCatalog")

export type Profile = {
	schemaVersion: number,
	coins: number,
	-- v2 (Phase 2 meta): account-level stats. Run state is never saved.
	maxDays: number, -- best days survived in one run (feeds the leaderboard)
	runs: number, -- runs finished
	kills: number, -- mobs killed
	bossKills: number, -- bosses defeated
	crafted: number, -- items crafted
	achievements: { [string]: boolean }, -- achievement id -> true when unlocked
	lastDailyClaim: number, -- os.time() of the last daily claim; 0 = never
	-- v3 (Phase 4 meta). Every map has string keys and a Config.Meta.Max* cap; ids are <= MaxItemIdLength.
	-- Ownership of equipped ids is re-checked by the meta service on load (validate only checks shape).
	achievementProgress: { [string]: number }, -- PROGRESS_FIELDS counter -> value (clamped MaxStatValue)
	ownedCosmetics: { [string]: boolean }, -- Shop cosmetic id -> true
	equippedCosmetic: string, -- "" = none
	equippedPerk: string, -- "" = none; one perk per run (Meta.MaxEquippedPerks = 1)
	unlockedGear: { [string]: boolean }, -- Shop starter gear id -> true
	titles: { [string]: boolean }, -- Achievements title id -> true
	equippedTitle: string, -- "" = none
	settings: Settings,
	hintsSeen: { [string]: boolean }, -- Config.Hints.Ids entry -> true
	processedReceipts: { [string]: number }, -- MarketplaceService PurchaseId -> os.time() granted (capped log)
	-- v4 (Items round): worn gear, Config.Equipment.Slots entry -> item id. Unknown items/slots are dropped.
	equipment: { [string]: string },
}

export type Settings = {
	reduceScares: boolean,
}

local ProfileSchema = {}

-- Stat counter fields added in v2 (all integers in [0, Config.Meta.MaxStatValue]).
ProfileSchema.STAT_FIELDS = { "maxDays", "runs", "kills", "bossKills", "crafted" }

-- Achievement progress counters added in v3 (profile.achievementProgress keys; integers in
-- [0, Config.Meta.MaxStatValue]). Achievements reference STAT_FIELDS or these. deepestRing is a max.
ProfileSchema.PROGRESS_FIELDS = {
	"blizzardsSurvived", -- blizzards the player was alive at the end of
	"darkEventsSurvived", -- dark events the player was alive at the end of
	"revivesGiven", -- downed teammates revived
	"structuresPlaced", -- structures placed
	"mealsCooked", -- food cooked at a fire or station
	"partyRuns", -- runs finished with 2+ players
	"friendRuns", -- runs finished with at least one Roblox friend
	"deepestRing", -- deepest biome ring reached (0..3)
	"dailyClaims", -- daily rewards claimed
}

-- Every stat an achievement condition may reference.
function ProfileSchema.isStatField(name: string): boolean
	return table.find(ProfileSchema.STAT_FIELDS, name) ~= nil
		or table.find(ProfileSchema.PROGRESS_FIELDS, name) ~= nil
end

-- Reads a stat (STAT_FIELDS from the profile, PROGRESS_FIELDS from achievementProgress); 0 if absent.
function ProfileSchema.getStat(profile: Profile, name: string): number
	if table.find(ProfileSchema.STAT_FIELDS, name) then
		local value = (profile :: any)[name]
		return if type(value) == "number" then value else 0
	end
	return profile.achievementProgress[name] or 0
end

function ProfileSchema.default(): Profile
	return {
		schemaVersion = Config.SchemaVersion,
		coins = Config.StartingCoins,
		maxDays = 0,
		runs = 0,
		kills = 0,
		bossKills = 0,
		crafted = 0,
		achievements = {},
		lastDailyClaim = 0,
		achievementProgress = {},
		ownedCosmetics = {},
		equippedCosmetic = "",
		equippedPerk = "",
		unlockedGear = {},
		titles = {},
		equippedTitle = "",
		settings = { reduceScares = Config.Settings.DefaultReduceScares },
		hintsSeen = {},
		processedReceipts = {},
		equipment = {},
	}
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function sanitizeCount(value: any, default: number, max: number): number
	if not isFiniteNumber(value) then
		return default
	end
	return math.clamp(math.floor(value), 0, max)
end

local function isIdOfLength(key: any, maxLength: number): boolean
	return type(key) == "string" and #key > 0 and #key <= maxLength
end

local function isAchievementId(key: any): boolean
	return isIdOfLength(key, Config.Meta.MaxAchievementIdLength)
end

local function isItemId(key: any): boolean
	return isIdOfLength(key, Config.Meta.MaxItemIdLength)
end

-- Keeps only valid string ids set to true, up to maxCount (sorted so the result is deterministic).
local function sanitizeIdSet(
	value: any,
	isId: (any) -> boolean,
	maxCount: number
): { [string]: boolean }
	local result: { [string]: boolean } = {}
	if type(value) ~= "table" then
		return result
	end
	local ids: { string } = {}
	for key, flag in value do
		if isId(key) and flag == true then
			table.insert(ids, key)
		end
	end
	table.sort(ids)
	for i = 1, math.min(#ids, maxCount) do
		result[ids[i]] = true
	end
	return result
end

local function sanitizeAchievements(value: any): { [string]: boolean }
	return sanitizeIdSet(value, isAchievementId, Config.Meta.MaxAchievements)
end

-- Keeps valid string keys with finite counts (clamped), up to maxCount (sorted, deterministic).
local function sanitizeCountMap(
	value: any,
	isId: (any) -> boolean,
	maxCount: number,
	maxValue: number
): { [string]: number }
	local result: { [string]: number } = {}
	if type(value) ~= "table" then
		return result
	end
	local ids: { string } = {}
	for key, count in value do
		if isId(key) and isFiniteNumber(count) then
			table.insert(ids, key)
		end
	end
	table.sort(ids)
	for i = 1, math.min(#ids, maxCount) do
		result[ids[i]] = sanitizeCount(value[ids[i]], 0, maxValue)
	end
	return result
end

local function sanitizeEquipped(value: any): string
	return if isItemId(value) then value else ""
end

local function isReceiptId(key: any): boolean
	return isIdOfLength(key, Config.Meta.MaxReceiptIdLength)
end

-- Evicts the oldest receipts (by grant time, then id) until the log fits Meta.MaxProcessedReceipts.
local function trimReceipts(receipts: { [string]: number })
	local ids: { string } = {}
	for id in receipts do
		table.insert(ids, id)
	end
	local excess = #ids - Config.Meta.MaxProcessedReceipts
	if excess <= 0 then
		return
	end
	table.sort(ids, function(a, b)
		if receipts[a] ~= receipts[b] then
			return receipts[a] < receipts[b]
		end
		return a < b
	end)
	for i = 1, excess do
		receipts[ids[i]] = nil
	end
end

local function sanitizeReceipts(value: any): { [string]: number }
	local result: { [string]: number } = {}
	if type(value) ~= "table" then
		return result
	end
	for key, at in value do
		if isReceiptId(key) and isFiniteNumber(at) then
			result[key] = math.max(math.floor(at), 0)
		end
	end
	trimReceipts(result)
	return result
end

-- Keeps only known slots holding a known item that fits that slot (so removed or renamed items never crash a load).
local function sanitizeEquipment(value: any): { [string]: string }
	local result: { [string]: string } = {}
	if type(value) ~= "table" then
		return result
	end
	for _, slot in Config.Equipment.Slots do
		local id = value[slot]
		local def = if type(id) == "string" then ItemCatalog.Items[id] else nil
		if
			def
			and def.equipSlot
			and (def.equipSlot == slot or ProfileSchema.slotAccepts(slot, def.equipSlot))
		then
			result[slot] = id
		end
	end
	return result
end

-- Accessory items are worn in either accessory slot; everything else must match exactly.
function ProfileSchema.slotAccepts(slot: string, itemSlot: string): boolean
	if slot == itemSlot then
		return true
	end
	return itemSlot == "Accessory" and (slot == "Accessory1" or slot == "Accessory2")
end

-- True if this PurchaseId was already granted (ProcessReceipt must then return PurchaseGranted, not regrant).
function ProfileSchema.hasReceipt(profile: Profile, purchaseId: string): boolean
	return profile.processedReceipts[purchaseId] ~= nil
end

-- Records a granted PurchaseId in the capped log. Returns false (records nothing) for a bad id.
function ProfileSchema.recordReceipt(profile: Profile, purchaseId: string, now: number): boolean
	if not isReceiptId(purchaseId) or not isFiniteNumber(now) then
		return false
	end
	profile.processedReceipts[purchaseId] = math.max(math.floor(now), 0)
	trimReceipts(profile.processedReceipts)
	return true
end

-- Migrates data in place to the current schema. Returns false (and leaves data alone)
-- when the data is unusable or from a newer schema, so callers refuse to overwrite it.
-- Add one `if version < N then ... end` block per schema change and bump Config.SchemaVersion.
function ProfileSchema.migrate(data: any): boolean
	if type(data) ~= "table" then
		return false
	end
	local version = data.schemaVersion
	if version == nil then
		version = 0
	end
	if type(version) ~= "number" or version > Config.SchemaVersion then
		return false
	end
	-- v0 (fresh/unversioned) -> v1: fill every field with validated values.
	if version < 1 then
		data.coins = sanitizeCount(data.coins, Config.StartingCoins, Config.MaxCoins)
		data.schemaVersion = 1
		version = 1
	end
	-- v1 -> v2: Phase 2 stats, achievements and daily claim time. Keeps coins.
	if version < 2 then
		local maxStat = Config.Meta.MaxStatValue
		for _, field in ProfileSchema.STAT_FIELDS do
			data[field] = sanitizeCount(data[field], 0, maxStat)
		end
		data.achievements = sanitizeAchievements(data.achievements)
		data.lastDailyClaim = sanitizeCount(data.lastDailyClaim, 0, math.huge)
		data.schemaVersion = 2
		version = 2
	end
	-- v2 -> v3: Phase 4 meta (progress, cosmetics, perk, gear, titles, settings, hints, receipt log).
	if version < 3 then
		local meta = Config.Meta
		data.achievementProgress = sanitizeCountMap(
			data.achievementProgress,
			isItemId,
			meta.MaxProgressEntries,
			meta.MaxStatValue
		)
		data.ownedCosmetics = sanitizeIdSet(data.ownedCosmetics, isItemId, meta.MaxOwnedCosmetics)
		data.equippedCosmetic = sanitizeEquipped(data.equippedCosmetic)
		data.equippedPerk = sanitizeEquipped(data.equippedPerk)
		data.unlockedGear = sanitizeIdSet(data.unlockedGear, isItemId, meta.MaxUnlockedGear)
		data.titles = sanitizeIdSet(data.titles, isItemId, meta.MaxTitles)
		data.equippedTitle = sanitizeEquipped(data.equippedTitle)
		local settings = if type(data.settings) == "table" then data.settings else {}
		data.settings = {
			reduceScares = if type(settings.reduceScares) == "boolean"
				then settings.reduceScares
				else Config.Settings.DefaultReduceScares,
		}
		data.hintsSeen = sanitizeIdSet(data.hintsSeen, isItemId, meta.MaxHintsSeen)
		data.processedReceipts = sanitizeReceipts(data.processedReceipts)
		data.schemaVersion = 3
		version = 3
	end
	-- v3 -> v4: equipment map (old saves have none: start empty; unknown items dropped).
	if version < 4 then
		data.equipment = sanitizeEquipment(data.equipment)
		data.schemaVersion = 4
	end
	return true
end

local function validCount(value: any, max: number): boolean
	return isFiniteNumber(value) and value >= 0 and value <= max
end

-- A table of valid ids set to true, at most maxCount entries.
local function validIdSet(value: any, isId: (any) -> boolean, maxCount: number): boolean
	if type(value) ~= "table" then
		return false
	end
	local count = 0
	for key, flag in value do
		if not isId(key) or flag ~= true then
			return false
		end
		count += 1
	end
	return count <= maxCount
end

-- A table of valid ids mapped to finite counts in [0, maxValue], at most maxCount entries.
local function validCountMap(
	value: any,
	isId: (any) -> boolean,
	maxCount: number,
	maxValue: number
): boolean
	if type(value) ~= "table" then
		return false
	end
	local count = 0
	for key, n in value do
		if not isId(key) or not validCount(n, maxValue) then
			return false
		end
		count += 1
	end
	return count <= maxCount
end

function ProfileSchema.validate(data: any): boolean
	if type(data) ~= "table" then
		return false
	end
	if data.schemaVersion ~= Config.SchemaVersion then
		return false
	end
	if not validCount(data.coins, Config.MaxCoins) then
		return false
	end
	for _, field in ProfileSchema.STAT_FIELDS do
		if not validCount(data[field], Config.Meta.MaxStatValue) then
			return false
		end
	end
	if not isFiniteNumber(data.lastDailyClaim) or data.lastDailyClaim < 0 then
		return false
	end
	local meta = Config.Meta
	if not validIdSet(data.achievements, isAchievementId, meta.MaxAchievements) then
		return false
	end
	-- v3
	if not validIdSet(data.ownedCosmetics, isItemId, meta.MaxOwnedCosmetics) then
		return false
	end
	if not validIdSet(data.unlockedGear, isItemId, meta.MaxUnlockedGear) then
		return false
	end
	if not validIdSet(data.titles, isItemId, meta.MaxTitles) then
		return false
	end
	if not validIdSet(data.hintsSeen, isItemId, meta.MaxHintsSeen) then
		return false
	end
	for _, field in { "equippedCosmetic", "equippedPerk", "equippedTitle" } do
		local value = data[field]
		if type(value) ~= "string" or (value ~= "" and not isItemId(value)) then
			return false
		end
	end
	local settings = data.settings
	if type(settings) ~= "table" or type(settings.reduceScares) ~= "boolean" then
		return false
	end
	for key in settings do
		if not table.find(Config.Settings.Keys, key) then
			return false
		end
	end
	if
		not validCountMap(
			data.achievementProgress,
			isItemId,
			meta.MaxProgressEntries,
			meta.MaxStatValue
		)
	then
		return false
	end
	if type(data.equipment) ~= "table" then
		return false
	end
	for slot, id in data.equipment do
		if
			not table.find(Config.Equipment.Slots, slot)
			or type(id) ~= "string"
			or not isItemId(id)
		then
			return false
		end
	end
	return validCountMap(data.processedReceipts, isReceiptId, meta.MaxProcessedReceipts, math.huge)
end

return ProfileSchema
