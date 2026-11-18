--!strict
-- Brief 19 (meta) logic tests: achievement evaluation, idempotent receipts, price validation, perk cap,
-- one-equipped rule, schema bounds, record hint. Registered in tests/run.luau by brief 21.

local Config = require("../src/shared/Config")
local Achievements = require("../src/shared/data/Achievements")
local Shop = require("../src/shared/data/Shop")
local AchievementLogic = require("../src/shared/logic/AchievementLogic")
local MetaSnapshot = require("../src/shared/logic/MetaSnapshot")
local PerkLogic = require("../src/shared/logic/PerkLogic")
local ProfileSchema = require("../src/shared/logic/ProfileSchema")
local RunPayout = require("../src/shared/logic/RunPayout")
local ShopLogic = require("../src/shared/logic/ShopLogic")

return function(check: (string, boolean) -> ())
	-- Achievements
	local p = ProfileSchema.default()
	check(
		"meta fresh profile unlocks nothing",
		#AchievementLogic.evaluate(p, Achievements.List) == 0
	)
	p.maxDays = 3
	local due = AchievementLogic.evaluate(p, Achievements.List)
	local ids: { [string]: boolean } = {}
	for _, def in due do
		ids[def.id] = true
	end
	check(
		"meta maxDays 3 unlocks FirstDawn and ThreeDays",
		ids.FirstDawn and ids.ThreeDays and not ids.WeekSurvivor
	)
	local coinsBefore = p.coins
	local def = Achievements.ById.WeekSurvivor
	p.maxDays = 7
	check("meta grant returns true once", AchievementLogic.grant(p, def))
	local afterFirst = p.coins
	check("meta grant paid coins", afterFirst == coinsBefore + def.coins)
	check("meta grant gave title", p.titles.Survivor == true)
	check("meta grant idempotent", not AchievementLogic.grant(p, def) and p.coins == afterFirst)
	check(
		"meta granted achievement not re-evaluated",
		AchievementLogic.evaluate(p, { def })[1] == nil
	)
	p.achievementProgress.blizzardsSurvived = 1
	check(
		"meta progress stat unlocks",
		AchievementLogic.evaluate(p, { Achievements.ById.Weathered })[1] ~= nil
	)
	check("meta addProgress adds", AchievementLogic.addProgress(p, "revivesGiven", 2) == 2)
	check(
		"meta addProgress ignores unknown field",
		AchievementLogic.addProgress(p, "bogus", 5) == 0 and p.achievementProgress.bogus == nil
	)
	check(
		"meta addProgress ignores negative",
		AchievementLogic.addProgress(p, "revivesGiven", -5) == 2
	)
	check(
		"meta raiseProgress is max",
		AchievementLogic.raiseProgress(p, "deepestRing", 2) == 2
			and AchievementLogic.raiseProgress(p, "deepestRing", 1) == 2
	)
	check("meta progress stays valid", ProfileSchema.validate(p))

	-- Data bounds
	check(
		"meta achievement count in range",
		#Achievements.List >= Config.Meta.MinAchievementDefs
			and #Achievements.List <= Config.Meta.MaxAchievementDefs
	)
	local rewardsOk = true
	for _, a in Achievements.List do
		if
			a.coins < 0
			or a.coins > Config.Meta.MaxAchievementCoinReward
			or not ProfileSchema.isStatField(a.condition.stat)
		then
			rewardsOk = false
		end
	end
	check("meta achievement rewards and stats valid", rewardsOk)

	-- Shop price validation (server recomputes from data)
	local buyer = ProfileSchema.default()
	local hood = Shop.ById.FurTrimHood
	local ok, reason = ShopLogic.canBuyWithCoins(buyer, hood)
	check("meta buy refused without coins", not ok and reason == "coins")
	buyer.coins = hood.price
	ok, reason = ShopLogic.buyWithCoins(buyer, hood)
	check(
		"meta buy succeeds",
		ok and reason == nil and buyer.coins == 0 and buyer.ownedCosmetics.FurTrimHood == true
	)
	buyer.coins = 10000
	ok, reason = ShopLogic.buyWithCoins(buyer, hood)
	check(
		"meta duplicate buy refused, coins kept",
		not ok and reason == "owned" and buyer.coins == 10000
	)
	ok, reason = ShopLogic.buyWithCoins(buyer, nil)
	check("meta unknown item refused", not ok and reason == "unavailable")
	ok, reason = ShopLogic.buyWithCoins(buyer, Shop.ById.AuroraParka)
	check("meta robux item cannot be bought with coins", not ok and reason == "unavailable")
	ok, reason = ShopLogic.buyWithCoins(buyer, Shop.ById.CoinPackSmall)
	check("meta coin pack cannot be bought with coins", not ok)
	ok, reason = ShopLogic.buyWithCoins(buyer, Shop.ById.StarterHideCoat)
	check("meta gear locked until milestone", not ok and reason == "locked")
	buyer.maxDays = 3
	ok = ShopLogic.buyWithCoins(buyer, Shop.ById.StarterHideCoat)
	check("meta gear buy after milestone", ok and buyer.unlockedGear.StarterHideCoat == true)
	local pricesOk = true
	for _, item in Shop.List do
		if
			item.currency == "coins"
			and (item.price < Config.Meta.MinCoinPrice or item.price > Config.Meta.MaxCoinPrice)
		then
			pricesOk = false
		end
	end
	check("meta coin prices in range", pricesOk)

	-- Receipts (idempotent)
	local r = ProfileSchema.default()
	local pack = Shop.ById.CoinPackSmall
	check(
		"meta receipt grants once",
		ShopLogic.grantReceipt(r, "P1", pack, 100) == "granted"
			and r.coins == Config.StartingCoins + (pack.coins or 0)
	)
	local coinsAfter = r.coins
	check(
		"meta duplicate receipt grants nothing",
		ShopLogic.grantReceipt(r, "P1", pack, 101) == "duplicate" and r.coins == coinsAfter
	)
	check("meta receipt recorded", ProfileSchema.hasReceipt(r, "P1"))
	check(
		"meta receipt unknown item invalid",
		ShopLogic.grantReceipt(r, "P2", nil, 100) == "invalid"
			and not ProfileSchema.hasReceipt(r, "P2")
	)
	check(
		"meta receipt coin item invalid",
		ShopLogic.grantReceipt(r, "P3", Shop.ById.FurTrimHood, 100) == "invalid"
	)
	check(
		"meta receipt bad id invalid",
		ShopLogic.grantReceipt(r, string.rep("x", Config.Meta.MaxReceiptIdLength + 1), pack, 100)
			== "invalid"
	)
	local parka = Shop.ById.AuroraParka
	check(
		"meta robux cosmetic granted",
		ShopLogic.grantReceipt(r, "P4", parka, 100) == "granted"
			and r.ownedCosmetics.AuroraParka == true
	)
	check(
		"meta owned robux cosmetic recorded, nothing granted",
		ShopLogic.grantReceipt(r, "P5", parka, 100) == "granted"
			and ProfileSchema.hasReceipt(r, "P5")
	)
	check("meta profile with receipts valid", ProfileSchema.validate(r))
	for i = 1, Config.Meta.MaxProcessedReceipts + 20 do
		ShopLogic.grantReceipt(r, `R{i}`, pack, 200 + i)
	end
	local receiptCount = 0
	for _ in r.processedReceipts do
		receiptCount += 1
	end
	check(
		"meta receipt log capped",
		receiptCount <= Config.Meta.MaxProcessedReceipts and ProfileSchema.validate(r)
	)
	local noRandom = true
	for _, item in Shop.List do
		local name = string.lower(item.id)
		if
			string.find(name, "random")
			or string.find(name, "crate")
			or string.find(name, "box")
		then
			noRandom = false
		end
	end
	check("meta shop has no random items", noRandom)

	-- Perks: one equipped, capped
	local perks = ProfileSchema.default()
	local warm = Shop.ById.WarmBlood
	local kind = Shop.ById.Kindler
	check("meta perk cannot equip unowned", not (PerkLogic.canEquipPerk(perks, "WarmBlood", warm)))
	perks.ownedCosmetics.WarmBlood = true
	perks.ownedCosmetics.Kindler = true
	check(
		"meta perk equip owned",
		PerkLogic.equipPerk(perks, "WarmBlood", warm) and perks.equippedPerk == "WarmBlood"
	)
	check(
		"meta perk equip replaces (one equipped)",
		PerkLogic.equipPerk(perks, "Kindler", kind) and perks.equippedPerk == "Kindler"
	)
	check("meta perk unequip", PerkLogic.equipPerk(perks, "", nil) and perks.equippedPerk == "")
	check(
		"meta cosmetic id is not a perk",
		not (PerkLogic.canEquipPerk(perks, "FurTrimHood", Shop.ById.FurTrimHood))
	)
	check("meta max equipped perks is one", Config.Meta.MaxEquippedPerks == 1)
	local capOk = true
	for _, item in Shop.List do
		if item.category == "perk" and not PerkLogic.effectValid(item.perk) then
			capOk = false
		end
	end
	check("meta every perk within cap and stat list", capOk)
	check("meta over-cap perk rejected", not PerkLogic.effectValid({
		stat = "warmthDrain",
		amount = Config.Meta.MaxPerkMagnitude + 0.01,
	}))
	check(
		"meta unknown perk stat rejected",
		not PerkLogic.effectValid({ stat = "godMode", amount = 0.01 })
	)
	perks.equippedCosmetic = "Ghost"
	perks.equippedTitle = "Nope"
	perks.equippedPerk = "WarmBlood"
	local changed = PerkLogic.sanitizeEquipped(perks, function(id: string): boolean
		return Shop.ById[id] ~= nil and Shop.ById[id].category == "perk"
	end)
	check(
		"meta sanitize unequips unowned",
		changed
			and perks.equippedCosmetic == ""
			and perks.equippedTitle == ""
			and perks.equippedPerk == "WarmBlood"
	)
	check("meta title equip needs earned", not (PerkLogic.equipTitle(perks, "Survivor", true)))
	perks.titles.Survivor = true
	check(
		"meta title equip earned",
		PerkLogic.equipTitle(perks, "Survivor", true) and perks.equippedTitle == "Survivor"
	)

	-- Schema bounds
	local bad = ProfileSchema.default()
	bad.achievementProgress.x = Config.Meta.MaxStatValue + 1
	check("meta schema rejects out-of-range progress", not ProfileSchema.validate(bad))
	local snap = MetaSnapshot.build(r)
	check(
		"meta snapshot has no receipts",
		(snap :: any).processedReceipts == nil and snap.coins == r.coins
	)
	check("meta snapshot lists stats", snap.stats.maxDays ~= nil and snap.stats.deepestRing ~= nil)

	-- Run summary hooks
	check("meta record hint near", MetaSnapshot.recordHint(8, 10, 2) == "2 days to your record")
	check("meta record hint one", MetaSnapshot.recordHint(9, 10, 2) == "1 day to your record")
	check("meta record hint far", MetaSnapshot.recordHint(3, 10, 2) == nil)
	check(
		"meta record hint passed",
		MetaSnapshot.recordHint(10, 10, 2) == nil and MetaSnapshot.recordHint(1, 0, 2) == nil
	)
	check(
		"meta summary carries previousBest",
		RunPayout.summarize({ daysSurvived = 2, kills = 0, bossKills = 0, partners = 0 }, 5).previousBest
			== 5
	)
	check(
		"meta tip for cause",
		RunPayout.tip("Wolf") ~= RunPayout.tip(nil) and #RunPayout.tip("Zzz") > 0
	)
	local solo = RunPayout.coins({ daysSurvived = 2, kills = 0, bossKills = 0, partners = 0 })
	local party = RunPayout.coins({ daysSurvived = 2, kills = 0, bossKills = 0, partners = 2 })
	check("meta party coin bonus", party == solo + 2 * Config.Meta.CoinsPerFriendInParty)
end
