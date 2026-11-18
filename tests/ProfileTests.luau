--!strict
-- Tests for ProfileSchema (default, validate, migrate).

local Config = require("../src/shared/Config")
local ProfileSchema = require("../src/shared/logic/ProfileSchema")

return function(check: (string, boolean) -> ())
	check("profile default validates", ProfileSchema.validate(ProfileSchema.default()))
	check("profile negative coins invalid", not ProfileSchema.validate({
		schemaVersion = Config.SchemaVersion,
		coins = -1,
	}))
	check("profile nan coins invalid", not ProfileSchema.validate({
		schemaVersion = Config.SchemaVersion,
		coins = 0 / 0,
	}))
	check("profile non-table invalid", not ProfileSchema.validate(nil))

	local fresh: any = {}
	check("migrate empty ok", ProfileSchema.migrate(fresh))
	check("migrate empty validates", ProfileSchema.validate(fresh))

	local dirty: any = { coins = 1e99 }
	check("migrate clamps coins", ProfileSchema.migrate(dirty) and dirty.coins == Config.MaxCoins)

	local newer: any = { schemaVersion = Config.SchemaVersion + 1, coins = 5 }
	check("migrate refuses newer schema", not ProfileSchema.migrate(newer) and newer.coins == 5)
	check("migrate refuses non-table", not ProfileSchema.migrate("x"))

	-- v1 -> v2 migration (Phase 2 meta fields).
	check("schema version is 3", Config.SchemaVersion == 3)
	local v1: any = { schemaVersion = 1, coins = 42 }
	local v1ok = ProfileSchema.migrate(v1)
	check("migrate v1 ok", v1ok and v1.schemaVersion == 3)
	check("migrate v1 keeps coins", v1.coins == 42)
	check(
		"migrate v1 fills stats",
		v1.maxDays == 0 and v1.runs == 0 and v1.kills == 0 and v1.bossKills == 0 and v1.crafted == 0
	)
	check(
		"migrate v1 fills achievements",
		type(v1.achievements) == "table" and next(v1.achievements) == nil
	)
	check("migrate v1 fills lastDailyClaim", v1.lastDailyClaim == 0)
	check("migrate v1 validates", ProfileSchema.validate(v1))

	local v1dirty: any = {
		schemaVersion = 1,
		coins = 3,
		maxDays = -4,
		kills = 1e99,
		runs = 0 / 0,
		crafted = 2.7,
		achievements = { FirstNight = true, [5] = true, Bad = "yes" },
		lastDailyClaim = "never",
	}
	ProfileSchema.migrate(v1dirty)
	check("migrate v1 clamps negative stat", v1dirty.maxDays == 0)
	check("migrate v1 clamps huge stat", v1dirty.kills == Config.Meta.MaxStatValue)
	check("migrate v1 nan stat", v1dirty.runs == 0 and v1dirty.crafted == 2)
	check(
		"migrate v1 cleans achievements",
		v1dirty.achievements.FirstNight == true
			and v1dirty.achievements.Bad == nil
			and v1dirty.achievements[5] == nil
	)
	check("migrate v1 bad daily claim", v1dirty.lastDailyClaim == 0)
	check("migrate v1 dirty validates", ProfileSchema.validate(v1dirty))

	local current = ProfileSchema.default()
	current.kills = 7
	check("migrate current is no-op", ProfileSchema.migrate(current) and current.kills == 7)

	local badAch: any = ProfileSchema.default()
	badAch.achievements = { [1] = true }
	check("validate rejects numeric achievement key", not ProfileSchema.validate(badAch))
	local missing: any = ProfileSchema.default()
	missing.bossKills = nil
	check("validate rejects missing stat", not ProfileSchema.validate(missing))
	local stale: any = { schemaVersion = 1, coins = 0 }
	check("validate rejects v1", not ProfileSchema.validate(stale))

	-- v2 -> v3 migration (Phase 4 meta fields).
	local Meta = Config.Meta
	local v2: any = {
		schemaVersion = 2,
		coins = 90,
		maxDays = 5,
		runs = 3,
		kills = 11,
		bossKills = 1,
		crafted = 4,
		achievements = { FirstDawn = true },
		lastDailyClaim = 1000,
	}
	check("migrate v2 ok", ProfileSchema.migrate(v2) and v2.schemaVersion == 3)
	check(
		"migrate v2 keeps v2 data",
		v2.coins == 90 and v2.maxDays == 5 and v2.kills == 11 and v2.achievements.FirstDawn == true
	)
	check(
		"migrate v2 fills v3 defaults",
		next(v2.achievementProgress) == nil
			and next(v2.ownedCosmetics) == nil
			and v2.equippedCosmetic == ""
			and v2.equippedPerk == ""
			and next(v2.unlockedGear) == nil
			and next(v2.titles) == nil
			and v2.equippedTitle == ""
			and v2.settings.reduceScares == Config.Settings.DefaultReduceScares
			and next(v2.hintsSeen) == nil
			and next(v2.processedReceipts) == nil
	)
	check("migrate v2 validates", ProfileSchema.validate(v2))
	check("default has every v3 field", ProfileSchema.validate(ProfileSchema.default()))

	local bigSet: { [any]: any } = {}
	for i = 1, Meta.MaxOwnedCosmetics + 10 do
		bigSet[`C{i}`] = true
	end
	bigSet[7] = true
	bigSet[string.rep("x", Meta.MaxItemIdLength + 1)] = true
	bigSet.NotTrue = "yes"
	local bigReceipts: { [string]: any } = {}
	for i = 1, Meta.MaxProcessedReceipts + 5 do
		bigReceipts[`R{i}`] = i
	end
	bigReceipts.Bad = 0 / 0
	local v2dirty: any = {
		schemaVersion = 2,
		coins = 0,
		maxDays = 0,
		runs = 0,
		kills = 0,
		bossKills = 0,
		crafted = 0,
		achievements = {},
		lastDailyClaim = 0,
		ownedCosmetics = bigSet,
		equippedCosmetic = 42,
		equippedPerk = string.rep("p", Meta.MaxItemIdLength + 1),
		equippedTitle = "Veteran",
		settings = { reduceScares = "yes", extra = true },
		achievementProgress = { revivesGiven = 1e99, partyRuns = -3, [3] = 1, deepestRing = 2.6 },
		processedReceipts = bigReceipts,
		hintsSeen = "nope",
	}
	ProfileSchema.migrate(v2dirty)
	local owned = 0
	for _ in v2dirty.ownedCosmetics do
		owned += 1
	end
	check("migrate v3 caps owned cosmetics", owned == Meta.MaxOwnedCosmetics)
	check(
		"migrate v3 drops bad cosmetic keys",
		v2dirty.ownedCosmetics[7] == nil and v2dirty.ownedCosmetics.NotTrue == nil
	)
	check(
		"migrate v3 cleans equipped",
		v2dirty.equippedCosmetic == ""
			and v2dirty.equippedPerk == ""
			and v2dirty.equippedTitle == "Veteran"
	)
	check(
		"migrate v3 cleans settings",
		v2dirty.settings.reduceScares == false and v2dirty.settings.extra == nil
	)
	check(
		"migrate v3 clamps progress",
		v2dirty.achievementProgress.revivesGiven == Meta.MaxStatValue
			and v2dirty.achievementProgress.partyRuns == 0
			and v2dirty.achievementProgress.deepestRing == 2
			and v2dirty.achievementProgress[3] == nil
	)
	local receipts = 0
	for _ in v2dirty.processedReceipts do
		receipts += 1
	end
	check("migrate v3 caps receipt log", receipts == Meta.MaxProcessedReceipts)
	check(
		"migrate v3 evicts oldest receipts",
		v2dirty.processedReceipts.R1 == nil
			and v2dirty.processedReceipts[`R{Meta.MaxProcessedReceipts + 5}`] ~= nil
	)
	check(
		"migrate v3 bad hints",
		type(v2dirty.hintsSeen) == "table" and next(v2dirty.hintsSeen) == nil
	)
	check("migrate v3 dirty validates", ProfileSchema.validate(v2dirty))

	-- Receipt log: idempotent, capped, string keys.
	local p = ProfileSchema.default()
	check("receipt unknown", not ProfileSchema.hasReceipt(p, "abc"))
	check(
		"receipt recorded",
		ProfileSchema.recordReceipt(p, "abc", 10) and ProfileSchema.hasReceipt(p, "abc")
	)
	check("receipt bad id refused", not ProfileSchema.recordReceipt(p, "", 10))
	for i = 1, Meta.MaxProcessedReceipts do
		ProfileSchema.recordReceipt(p, `id{i}`, 100 + i)
	end
	local n = 0
	for _ in p.processedReceipts do
		n += 1
	end
	check(
		"receipt log capped",
		n == Meta.MaxProcessedReceipts and not ProfileSchema.hasReceipt(p, "abc")
	)
	check("receipt log validates", ProfileSchema.validate(p))

	-- validate rejects bad v3 shapes
	local badSettings: any = ProfileSchema.default()
	badSettings.settings = { reduceScares = 1 }
	check("validate rejects bad settings", not ProfileSchema.validate(badSettings))
	local badEquip: any = ProfileSchema.default()
	badEquip.equippedPerk = nil
	check("validate rejects missing equipped perk", not ProfileSchema.validate(badEquip))
	local badReceipt: any = ProfileSchema.default()
	badReceipt.processedReceipts = { [1] = 5 }
	check("validate rejects numeric receipt key", not ProfileSchema.validate(badReceipt))
	local badProgress: any = ProfileSchema.default()
	badProgress.achievementProgress = { kills = -1 }
	check("validate rejects negative progress", not ProfileSchema.validate(badProgress))

	-- Stat lookup used by achievement conditions
	local s = ProfileSchema.default()
	s.kills = 9
	s.achievementProgress.revivesGiven = 2
	check(
		"getStat reads both sources",
		ProfileSchema.getStat(s, "kills") == 9
			and ProfileSchema.getStat(s, "revivesGiven") == 2
			and ProfileSchema.getStat(s, "partyRuns") == 0
	)
end
