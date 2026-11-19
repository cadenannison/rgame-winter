--!strict
-- Headless tests: bug-fix round (data-driven fuel, forage respawn, rope recipes, payouts, budgets).

local Config = require("../src/shared/Config")
local CreatureFxLogic = require("../src/shared/logic/CreatureFxLogic")
local DayClock = require("../src/shared/logic/DayClock")
local FireLogic = require("../src/shared/logic/FireLogic")
local ItemCatalog = require("../src/shared/ItemCatalog")
local PerfBudget = require("../src/shared/logic/PerfBudget")
local RunPayout = require("../src/shared/logic/RunPayout")

return function(check: (string, boolean) -> ())
	-- Fuel is data-driven ------------------------------------------------------------------------------------------------
	local E = Config.Items.Entries
	local function fuelOf(id: string): number?
		local def = ItemCatalog.Items[id]
		return if def then def.fuelSeconds else nil
	end
	check("fuel: wood is the baseline", E.Wood.fuelSeconds == Config.Fire.WoodFuelSeconds)
	check(
		"fuel: catalog stamps fuel values",
		fuelOf("Blubber") == E.Blubber.fuelSeconds and fuelOf("Stone") == nil
	)
	check(
		"fuel: blubber long, sticks and pinecones short",
		(fuelOf("Blubber") or 0) > (fuelOf("Wood") or 0)
			and (fuelOf("Stick") or 0) < (fuelOf("Wood") or 0)
			and (fuelOf("Pinecone") or 0) < (fuelOf("Wood") or 0)
			and (fuelOf("Pinecone") or 0) > 0
	)
	local baseWood = Config.Fire.WoodFuelSeconds
	check(
		"fuel: tier 1 seconds equal the item value",
		FireLogic.fuelSeconds(fuelOf("Blubber"), baseWood, baseWood) == fuelOf("Blubber")
	)
	local tier2 = Config.Fire.Tiers[2].WoodFuelSeconds
	check(
		"fuel: higher tiers scale, wood = tier wood value",
		FireLogic.fuelSeconds(fuelOf("Wood"), tier2, baseWood) == tier2
	)
	check("fuel: non-fuel gives 0", FireLogic.fuelSeconds(nil, baseWood, baseWood) == 0)
	local order = Config.Fire.FuelOrder
	check(
		"fuel: pick selected fuel",
		FireLogic.pickFuel({ Wood = 3, Blubber = 1 }, "Blubber", order, fuelOf) == "Blubber"
	)
	check(
		"fuel: pick falls to order",
		FireLogic.pickFuel({ Wood = 3, Blubber = 1 }, "Stone", order, fuelOf) == "Wood"
	)
	check(
		"fuel: blubber alone feeds",
		FireLogic.pickFuel({ Blubber = 1, Stone = 5 }, nil, order, fuelOf) == "Blubber"
	)
	check(
		"fuel: none held",
		FireLogic.pickFuel({ Stone = 5, Wood = 0 }, "Stone", order, fuelOf) == nil
	)
	local fire = FireLogic.new(0)
	local added = FireLogic.addFuel(
		fire,
		FireLogic.fuelSeconds(fuelOf("Blubber"), baseWood, baseWood),
		Config.Fire.MaxFuelSeconds
	)
	check("fuel: blubber lights a fire", added == E.Blubber.fuelSeconds and FireLogic.isLit(fire))

	-- Node / relic coins reach RunPayout ---------------------------------------------------------------------------------
	local base: RunPayout.RunResult = { daysSurvived = 2, kills = 1, bossKills = 0, partners = 0 }
	local withForage: RunPayout.RunResult =
		{ daysSurvived = 2, kills = 1, bossKills = 0, partners = 0, forageCoins = 13 }
	check(
		"payout: forage coins add to the run total",
		RunPayout.coins(withForage) == RunPayout.coins(base) + 13
	)
	check("payout: forage coins are capped by MaxCoinsPerRun", RunPayout.coins({
		daysSurvived = 0,
		kills = 0,
		bossKills = 0,
		partners = 0,
		forageCoins = 10 ^ 9,
	}) == Config.Meta.MaxCoinsPerRun)
	check("payout: bad forage values count as 0", RunPayout.coins({
		daysSurvived = 2,
		kills = 1,
		bossKills = 0,
		partners = 0,
		forageCoins = -5,
	}) == RunPayout.coins(base) and RunPayout.coins({
		daysSurvived = 2,
		kills = 1,
		bossKills = 0,
		partners = 0,
		forageCoins = 0 / 0,
	}) == RunPayout.coins(base))
	check(
		"payout: summarize carries forage coins",
		RunPayout.summarize(withForage, nil).coinsEarned == RunPayout.coins(withForage)
	)

	-- Forage respawn follows DayClock's day counter (dawn) ---------------------------------------------------------------
	local T = Config.Time
	local last: number? = nil
	local rollovers = 0
	local rolloverOk = true
	for second = 0, T.DayLengthSeconds * 4 do
		local info = DayClock.at(second, T)
		if DayClock.isNewDay(last, info.day) then
			if last ~= nil then
				rollovers += 1
				local prev = DayClock.at(second - 1, T)
				-- the counter turns exactly where the night ends and daylight starts at StartClockHour
				rolloverOk = rolloverOk
					and second % T.DayLengthSeconds == 0
					and prev.isNight
					and not info.isNight
					and math.abs(info.hour - T.StartClockHour) < 1e-6
			end
			last = info.day
		end
	end
	check("forage day: Day rolls over only at dawn", rolloverOk and rollovers == 4)
	check(
		"forage day: same day does not regrow, bad values ignored",
		not DayClock.isNewDay(3, 3)
			and not DayClock.isNewDay(3, nil)
			and not DayClock.isNewDay(3, "4")
	)
	check(
		"forage day: first observation and debug jumps count",
		DayClock.isNewDay(nil, 1) and DayClock.isNewDay(5, 2)
	)

	-- Part budget counts forage (and every extra reservation) ----------------------------------------------------------
	local cap, reserve = Config.Perf.MaxLiveParts, Config.Forage.PartHeadroom
	check("budget: cap stays 6000", cap == 6000)
	check("budget: room when under", PerfBudget.hasPartRoom(1000, 200, cap, reserve))
	check(
		"budget: live forage parts use up room",
		not PerfBudget.hasPartRoom(cap - reserve - 100, 100, cap, reserve)
	)
	check(
		"budget: forage below the line still fits",
		PerfBudget.hasPartRoom(cap - reserve - 101, 100, cap, reserve)
	)
	check(
		"budget: forage max + headroom fits the cap",
		Config.Forage.MaxLiveParts + Config.Forage.PartHeadroom < cap
	)

	-- Rope has a use ---------------------------------------------------------------------------------------------------
	local ropeUses = 0
	for _, recipe in ItemCatalog.Recipes do
		for _, input in recipe.inputs do
			if input.id == "Rope" then
				ropeUses += 1
			end
		end
	end
	check("rope: used as an ingredient in at least 2 recipes", ropeUses >= 2)
	check(
		"rope: storage chest needs rope and rope is craftable",
		ItemCatalog.Recipes.StorageChest ~= nil
			and ItemCatalog.Recipes.Rope ~= nil
			and Config.Storage.CraftRope >= 1
	)

	-- Brute slam: config reach, not root size ------------------------------------------------------------------------
	local brute = Config.Mobs.Species.FrostboundBrute
	local leeway = brute.tune.strikeLeeway or Config.Night.StrikeLeeway
	check(
		"brute: slam radius = attackRange + leeway",
		CreatureFxLogic.slamRadius(brute.attackRange, leeway) == brute.attackRange + leeway
	)
	local resized = CreatureFxLogic.slamRadius(brute.attackRange, leeway)
	check(
		"brute: slam radius ignores root size",
		resized == 10 and brute.size[1] == 5 and brute.size[2] == 7
	)
	check("slam radius clamps negatives", CreatureFxLogic.slamRadius(-3, -1) == 0)
	check(
		"beacon: dead glow tag removed",
		table.find(Config.Blizzard.GlowTags, "StructureBeacon") == nil
	)
end
