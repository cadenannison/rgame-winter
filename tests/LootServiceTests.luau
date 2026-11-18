--!strict
-- Seeded chest planning (LootChests) against the real LootTables + ItemCatalog: weights respected over many
-- seeds, rarity rises with ring, chest rarity vs item rarity is monotonic, item caps, determinism.

local ItemCatalog = require("../src/shared/ItemCatalog")
local Rarity = require("../src/shared/data/Rarity")
local LootChests = require("../src/shared/logic/LootChests")
local LootRoll = require("../src/shared/logic/LootRoll")
local LootTables = require("../src/server/Loot/LootTables")

local SEEDS = 6000
local pool = LootRoll.buildPool(ItemCatalog.Items :: any)

local function slotAt(i: number, ring: number, structure: string, depth: number): LootChests.Slot
	return {
		x = (i * 37) % 997,
		y = 0,
		z = (i * 91) % 1013,
		depth = depth,
		structureType = structure,
		ring = ring,
		index = i % 5,
	}
end

return function(check: (string, boolean) -> ())
	-- determinism
	local same = true
	for i = 1, 200 do
		local slot = slotAt(i, i % 4, "ruin", i % 5)
		local a = LootChests.plan(LootTables, pool, 777 + i, slot)
		local b = LootChests.plan(LootTables, pool, 777 + i, slot)
		if a.rarity ~= b.rarity or #a.items ~= #b.items or a.seed ~= b.seed then
			same = false
		else
			for k, s in a.items do
				if b.items[k].id ~= s.id or b.items[k].count ~= s.count then
					same = false
				end
			end
		end
	end
	check("lootsvc: same seed and slot => same chest contents", same)

	-- order independence + variation
	local first = LootChests.plan(LootTables, pool, 5, slotAt(1, 2, "cave", 1))
	LootChests.plan(LootTables, pool, 5, slotAt(2, 2, "cave", 1))
	local again = LootChests.plan(LootTables, pool, 5, slotAt(1, 2, "cave", 1))
	check("lootsvc: planning one chest does not affect another", first.seed == again.seed)
	local distinct: { [number]: boolean } = {}
	for i = 1, 100 do
		distinct[LootChests.plan(LootTables, pool, i, slotAt(1, 2, "cave", 1)).seed] = true
	end
	local n = 0
	for _ in distinct do
		n += 1
	end
	check("lootsvc: different run seeds give different chest seeds", n >= 99)

	local rngOk = true
	local rng = LootChests.makeRng(42)
	for _ = 1, 20000 do
		local v = rng()
		if v < 0 or v >= 1 then
			rngOk = false
		end
	end
	check("lootsvc: rng stays in [0,1)", rngOk)

	-- weights respected (ring 2, ruin, depth 0): observed share vs expected within tolerance
	local weights = LootRoll.chestWeights(LootTables, 2, "ruin", 0)
	local total = 0
	for _, name in Rarity.List do
		total += weights[name]
	end
	local counts: { [string]: number } = {}
	for i = 1, SEEDS do
		local r = LootChests.plan(LootTables, pool, i, slotAt(i, 2, "ruin", 0)).rarity
		counts[r] = (counts[r] or 0) + 1
	end
	local weightsOk = true
	for _, name in Rarity.List do
		local expected = weights[name] / total
		local observed = (counts[name] or 0) / SEEDS
		if math.abs(observed - expected) > 0.03 then
			weightsOk = false
		end
	end
	check("lootsvc: chest rarity frequencies match configured weights", weightsOk)

	-- ring rarity rise (mean chest rank), per structure type used
	local ringMeans: { number } = {}
	for ring = 0, 3 do
		local sum = 0
		for i = 1, SEEDS do
			sum += Rarity.rank(
				LootChests.plan(LootTables, pool, i, slotAt(i, ring, "cabin", 0)).rarity
			)
		end
		ringMeans[ring + 1] = sum / SEEDS
	end
	check(
		"lootsvc: chest rarity rises with ring distance",
		ringMeans[1] < ringMeans[2] and ringMeans[2] < ringMeans[3] and ringMeans[3] < ringMeans[4]
	)
	local depthLow, depthHigh = 0, 0
	for i = 1, SEEDS do
		depthLow += Rarity.rank(
			LootChests.plan(LootTables, pool, i, slotAt(i, 1, "ruin", 0)).rarity
		)
		depthHigh += Rarity.rank(
			LootChests.plan(LootTables, pool, i, slotAt(i, 1, "ruin", 4)).rarity
		)
	end
	check("lootsvc: deeper chests roll better", depthHigh > depthLow)

	-- chest rarity -> item rarity monotonic, and item caps
	local itemSum: { [string]: number } = {}
	local itemN: { [string]: number } = {}
	local capsOk = true
	for i = 1, SEEDS * 2 do
		local plan = LootChests.plan(LootTables, pool, i, slotAt(i, i % 4, "ruin", i % 5))
		local cfg = LootTables.chests[plan.rarity]
		if #plan.items > cfg.items[2] then
			capsOk = false
		end
		for _, s in plan.items do
			local def = ItemCatalog.Items[s.id]
			if def == nil or s.count < 1 or s.count > def.maxStack then
				capsOk = false
			end
			itemSum[plan.rarity] = (itemSum[plan.rarity] or 0)
				+ Rarity.rank(ItemCatalog.rarityOf(s.id))
			itemN[plan.rarity] = (itemN[plan.rarity] or 0) + 1
		end
	end
	check("lootsvc: no chest exceeds its configured item cap / stack max", capsOk)
	local monotonic = true
	local prev = 0
	for _, name in Rarity.List do
		if itemN[name] and itemN[name] > 0 then
			local mean = itemSum[name] / itemN[name]
			if mean < prev then
				monotonic = false
			end
			prev = mean
		end
	end
	check("lootsvc: chest rarity correlates monotonically with item rarity", monotonic)

	local commonMax = 0
	for i = 1, 3000 do
		local items = LootRoll.rollChest(LootTables, pool, "common", LootChests.makeRng(i))
		commonMax = math.max(commonMax, #items)
	end
	check(
		"lootsvc: common chests never exceed their cap",
		commonMax <= LootTables.chests.common.items[2]
	)
end
