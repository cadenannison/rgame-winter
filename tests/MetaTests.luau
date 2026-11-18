--!strict
-- Phase 4 contract data tests (brief 21): Achievements, Shop, AudioCues, Config caps, Remotes, Assets.

local Config = require("../src/shared/Config")
local Assets = require("../src/shared/Assets")
local ItemCatalog = require("../src/shared/ItemCatalog")
local ProfileSchema = require("../src/shared/logic/ProfileSchema")
local Achievements = require("../src/shared/data/Achievements")
local Shop = require("../src/shared/data/Shop")
local AudioCues = require("../src/shared/data/AudioCues")
local PerkLogic = require("../src/shared/logic/PerkLogic")
local CueResolve = require("../src/shared/logic/CueResolve")

local function all<T>(list: { T }, pred: (T) -> boolean): boolean
	for _, v in list do
		if not pred(v) then
			return false
		end
	end
	return true
end

local function unique<T>(list: { T }, key: (T) -> string): boolean
	local seen: { [string]: boolean } = {}
	for _, v in list do
		local k = key(v)
		if seen[k] then
			return false
		end
		seen[k] = true
	end
	return true
end

local function isWhole(n: number): boolean
	return n == math.floor(n) and n >= 0
end

return function(check: (string, boolean) -> ())
	local Meta = Config.Meta

	-- Config caps present and sane
	check(
		"meta: caps present",
		Meta.MaxEquippedPerks == 1
			and Meta.MaxPerkMagnitude > 0
			and Meta.MaxPerkMagnitude <= 0.25
			and Meta.MinCoinPrice > 0
			and Meta.MaxCoinPrice > Meta.MinCoinPrice
			and Meta.MaxProcessedReceipts > 0
			and Meta.MaxReceiptIdLength >= 36 -- PurchaseId is a GUID
			and Meta.MaxAchievementDefs <= Meta.MaxAchievements
			and Meta.MinAchievementDefs <= Meta.MaxAchievementDefs
	)
	check("perf: budgets present", Config.Perf.TargetFps >= 30 and Config.Perf.MaxLiveParts > 0)
	check("perf: live mobs single source", Config.Perf.MaxLiveMobs == Config.Scaling.MaxLiveMobs)
	check(
		"perf: chunk and particle budgets",
		Config.Perf.ChunkLoadBudgetPerFrame >= 1
			and Config.Perf.ChunkPartBudgetPerFrame >= 1
			and Config.Perf.MaxParticleEmitters >= 1
			and Config.Perf.MaxParticleRate >= 1
			and Config.Perf.MaxActiveSounds >= 1
	)
	check(
		"settings: reduceScares key",
		table.find(Config.Settings.Keys, Config.Settings.ReduceScares) ~= nil
			and Config.Settings.ReducedScareVisualMultiplier >= 0
			and Config.Settings.ReducedScareVisualMultiplier < 1
	)
	check("hints: ids unique and short", unique(Config.Hints.Ids, function(h)
		return h
	end) and all(Config.Hints.Ids, function(h)
		return #h > 0 and #h <= Meta.MaxItemIdLength
	end) and #Config.Hints.Ids <= Meta.MaxHintsSeen)
	check(
		"progress fields fit the saved cap",
		#ProfileSchema.PROGRESS_FIELDS <= Meta.MaxProgressEntries
	)

	-- Achievements
	local list = Achievements.List
	check(
		"achievements: count in range",
		#list >= Meta.MinAchievementDefs and #list <= Meta.MaxAchievementDefs
	)
	check(
		"achievements: unique ids",
		unique(list, function(a)
			return a.id
		end)
	)
	check(
		"achievements: id length",
		all(list, function(a)
			return #a.id > 0 and #a.id <= Meta.MaxAchievementIdLength
		end)
	)
	check(
		"achievements: reference real stat fields",
		all(list, function(a)
			return ProfileSchema.isStatField(a.condition.stat)
		end)
	)
	check(
		"achievements: thresholds positive whole",
		all(list, function(a)
			return a.condition.atLeast >= 1 and isWhole(a.condition.atLeast)
		end)
	)
	check(
		"achievements: coin rewards capped",
		all(list, function(a)
			return isWhole(a.coins) and a.coins <= Meta.MaxAchievementCoinReward
		end)
	)
	check(
		"achievements: titles exist",
		all(list, function(a)
			return a.title == nil or Achievements.TitleById[a.title] ~= nil
		end)
	)
	check("titles: unique, short, all earnable", unique(Achievements.Titles, function(t)
		return t.id
	end) and #Achievements.Titles <= Meta.MaxTitles and all(Achievements.Titles, function(t)
		if #t.id == 0 or #t.id > Meta.MaxItemIdLength then
			return false
		end
		for _, a in list do
			if a.title == t.id then
				return true
			end
		end
		return false
	end))
	check("achievements: some grant titles", #Achievements.Titles >= 1)

	-- Shop
	local items = Shop.List
	local categories = { "cosmetic", "perk", "gear", "coinPack" }
	local slots = { "outfit", "trail", "camp", "pet" }
	check(
		"shop: unique ids",
		unique(items, function(i)
			return i.id
		end)
	)
	check(
		"shop: ids short",
		all(items, function(i)
			return #i.id > 0 and #i.id <= Meta.MaxItemIdLength
		end)
	)
	check(
		"shop: known category and currency",
		all(items, function(i)
			return table.find(categories, i.category) ~= nil
				and (i.currency == "coins" or i.currency == "robux")
		end)
	)
	check(
		"shop: no random items",
		all(items, function(i)
			local raw = i :: any
			local id = string.lower(i.id)
			return raw.random == nil
				and raw.lootTable == nil
				and raw.odds == nil
				and raw.pool == nil
				and not string.find(id, "random", 1, true)
				and not string.find(id, "mystery", 1, true)
				and not string.find(id, "crate", 1, true)
				and not string.find(id, "box", 1, true)
		end)
	)
	check(
		"shop: coin prices in bounds",
		all(items, function(i)
			return i.currency ~= "coins"
				or (
					isWhole(i.price)
					and i.price >= Meta.MinCoinPrice
					and i.price <= Meta.MaxCoinPrice
				)
		end)
	)
	check(
		"shop: robux items flagged with a product key",
		all(items, function(i)
			if i.currency ~= "robux" then
				return i.productKey == nil
			end
			return i.productKey ~= nil
				and Meta.ProductIds[i.productKey] ~= nil
				and i.price > 0
				and i.price <= Meta.MaxRobuxPrice
		end)
	)
	check(
		"shop: product keys unique and all used",
		(function()
			local used: { [string]: number } = {}
			for _, i in items do
				if i.productKey then
					used[i.productKey] = (used[i.productKey] or 0) + 1
				end
			end
			for key in Meta.ProductIds do
				if used[key] ~= 1 then
					return false
				end
			end
			for key in used do
				if Meta.ProductIds[key] == nil then
					return false
				end
			end
			return true
		end)()
	)
	check("shop: robux-only cosmetics exist", #items > 0 and (function()
		local n = 0
		for _, i in items do
			if i.category == "cosmetic" and i.currency == "robux" then
				n += 1
			end
		end
		return n >= 1
	end)())
	check(
		"shop: cosmetics have a slot",
		all(items, function(i)
			return i.category ~= "cosmetic"
				or (i.cosmeticSlot ~= nil and table.find(slots, i.cosmeticSlot) ~= nil)
		end)
	)
	check(
		"shop: cosmetics have an asset key",
		all(items, function(i)
			return i.category ~= "cosmetic" or Assets[`Cosmetic{i.id}`] ~= nil
		end)
	)
	check(
		"shop: perks capped, coins only",
		all(items, function(i)
			if i.category ~= "perk" then
				return i.perk == nil
			end
			local perk = i.perk
			return perk ~= nil
				and i.currency == "coins"
				and table.find(Meta.PerkStats, perk.stat) ~= nil
				and perk.amount ~= 0
				and math.abs(perk.amount) <= Meta.MaxPerkMagnitude
		end)
	)
	check(
		"shop: gear grants real items, capped, gated",
		all(items, function(i)
			if i.category ~= "gear" then
				return i.gear == nil
			end
			local gear = i.gear
			local def = gear and ItemCatalog.Items[gear.itemId]
			return gear ~= nil
				and def ~= nil
				and i.currency == "coins"
				and gear.count >= 1
				and gear.count <= Meta.MaxStarterGearCount
				and gear.count <= def.maxStack
		end)
	)
	check(
		"shop: milestones reference real stat fields",
		all(items, function(i)
			local req = i.requires
			return req == nil or (ProfileSchema.isStatField(req.stat) and req.atLeast >= 1)
		end)
	)
	check(
		"shop: coin packs are robux, fixed and capped",
		all(items, function(i)
			if i.category ~= "coinPack" then
				return i.coins == nil
			end
			local coins = i.coins
			return i.currency == "robux"
				and coins ~= nil
				and isWhole(coins)
				and coins > 0
				and coins <= Meta.MaxCoinPackCoins
		end)
	)
	check("shop: three coin packs", #(function()
		local packs = {}
		for _, i in items do
			if i.category == "coinPack" then
				table.insert(packs, i)
			end
		end
		return packs
	end)() == 3)
	check(
		"shop: saved tables fit caps",
		#items <= Meta.MaxOwnedCosmetics and #items <= Meta.MaxUnlockedGear + Meta.MaxOwnedCosmetics
	)

	-- AudioCues
	local cues = AudioCues.List
	check(
		"audio: unique keys",
		unique(cues, function(c)
			return c.key
		end)
	)
	check(
		"audio: every Cue kind mapped",
		all(Config.Cue.Kinds, function(k)
			return AudioCues.ByKey[k] ~= nil
		end)
	)
	check(
		"audio: every event mapped",
		AudioCues.ByKey.Blizzard ~= nil
			and AudioCues.ByKey.FalseNight ~= nil
			and AudioCues.ByKey.TheQuiet ~= nil
			and AudioCues.ByKey.DeepFreeze ~= nil
			and AudioCues.ByKey.StalkerStrike ~= nil
	)
	check(
		"audio: asset keys exist",
		all(cues, function(c)
			return (c.sound == nil or Assets[c.sound] ~= nil)
				and (c.particle == nil or Assets[c.particle] ~= nil)
		end)
	)
	check(
		"audio: groups and volume",
		all(cues, function(c)
			return table.find(AudioCues.Groups, c.group) ~= nil and c.volume >= 0 and c.volume <= 1
		end)
	)
	check(
		"audio: horror cues are scary (reduce-scares applies)",
		all(cues, function(c)
			return c.group ~= "horror" or c.scary
		end)
	)

	-- Hidden metrics never in a Phase 4 replicated name
	local hiddenWords = { "dread", "hunt", "timer", "chance" }
	local function leaks(name: string): boolean
		local lower = string.lower(name)
		for _, w in hiddenWords do
			if string.find(lower, w, 1, true) then
				return true
			end
		end
		return false
	end
	local names = {
		Meta.BestDaysAttribute,
		Meta.TitleAttribute,
		Meta.CosmeticAttribute,
		Config.Settings.ReduceScaresAttribute,
	}
	for _, f in ProfileSchema.PROGRESS_FIELDS do
		table.insert(names, f)
	end
	-- Brief 21 integration: perk multipliers, perk/cosmetic namespacing, Forge hint
	local perkCount, perkOk = 0, true
	for _, item in Shop.List do
		if item.category == "perk" and item.perk then
			perkCount += 1
			local m = PerkLogic.multiplier(item.perk, item.perk.stat)
			perkOk = perkOk
				and m ~= 1
				and math.abs(m - 1) <= Meta.MaxPerkMagnitude
				and PerkLogic.multiplier(item.perk, "notAStat") == 1
		end
	end
	check("perks: multiplier capped and stat-specific", perkCount > 0 and perkOk)
	check(
		"perks: over-cap effect ignored",
		PerkLogic.multiplier(
			{ stat = "warmthDrain", amount = -(Meta.MaxPerkMagnitude + 0.5) },
			"warmthDrain"
		) == 1
	)
	check(
		"perks: team fuel picks the best within cap",
		PerkLogic.lowestMultiplier(
			{ { stat = "fuelBurn", amount = -0.05 }, { stat = "fuelBurn", amount = -0.1 } },
			"fuelBurn"
		)
				== 0.9
			and PerkLogic.lowestMultiplier({}, "fuelBurn") == 1
	)
	local carry, paid = 0, 0
	for _ = 1, 10 do
		local extra
		extra, carry = PerkLogic.bonusYield(carry, 2, 1.1)
		paid += extra
	end
	check("perks: gather bonus pays 10% over 10 harvests", paid == 2 and carry < 1)
	check("perks: no bonus at multiplier 1", (PerkLogic.bonusYield(0, 3, 1)) == 0)
	-- Perks live in ownedCosmetics: safe only while shop ids are unique across categories.
	check(
		"shop: ids unique across categories (perks share ownedCosmetics)",
		unique(Shop.List, function(i)
			return i.id
		end)
	)
	local hintIdsOk = true
	for _, def in CueResolve.HintDefs do
		hintIdsOk = hintIdsOk and table.find(Config.Hints.Ids, def.id) ~= nil
	end
	check("hints: every hint def id is in Config.Hints.Ids", hintIdsOk)
	check(
		"hints: Forge hint completes on forgePlaced",
		(function()
			for _, def in CueResolve.HintDefs do
				if def.id == "Forge" then
					return table.find(def.done, "forgePlaced") ~= nil
				end
			end
			return false
		end)()
	)

	check(
		"hidden metrics: no phase 4 name carries them",
		all(names, function(n)
			return not leaks(n)
		end)
	)
end
