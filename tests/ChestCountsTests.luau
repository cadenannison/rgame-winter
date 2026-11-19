--!strict
-- Items round: loot chest counts per structure class (Config.Loot.Chests), exactly one top-rarity chest in a
-- Beacon, determinism from the run seed, ring rarity weighting (not count), spread over rooms/depth, and the
-- short chest beam rules (Config.Loot.Beam). All pure.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Rarity = require("../src/shared/data/Rarity")
local ChestStyle = require("../src/shared/logic/ChestStyle")
local LootChests = require("../src/shared/logic/LootChests")
local LootRoll = require("../src/shared/logic/LootRoll")
local LootTables = require("../src/server/Loot/LootTables")

local pool = LootRoll.buildPool(ItemCatalog.Items :: any)
local SEEDS = 400
local TOP = Rarity.List[#Rarity.List]

-- A structure with `rooms` rooms (two candidate chests in some), depth rising with the room number.
local function candidates(rooms: number): { LootChests.Candidate }
	local out: { LootChests.Candidate } = {}
	for r = 1, rooms do
		table.insert(
			out,
			{ index = #out + 1, room = `r{r}`, depth = (r - 1) % (Config.Loot.MaxDepthTier + 1) }
		)
		if r % 3 == 0 then
			table.insert(out, {
				index = #out + 1,
				room = `r{r}`,
				depth = (r + 1) % (Config.Loot.MaxDepthTier + 1),
			})
		end
	end
	return out
end

local function structureFor(class: string): string
	for id, c in Config.Loot.StructureClass do
		if c == class then
			return id
		end
	end
	return "unknown"
end

return function(check: (string, boolean) -> ())
	-- count ranges per class
	for class, rule in Config.Loot.Chests do
		local id = structureFor(class)
		local inRange, seen = true, {}
		for seed = 1, SEEDS do
			local picks = LootChests.selectSlots(id, seed, `{id}#1`, candidates(12))
			inRange = inRange and #picks >= rule.Min and #picks <= rule.Max
			seen[#picks] = true
		end
		check(`chestcount: {class} count within {rule.Min}-{rule.Max}`, inRange)
		local distinctCounts = 0
		for _ in seen do
			distinctCounts += 1
		end
		check(
			`chestcount: {class} count varies with the seed`,
			rule.Max == rule.Min or distinctCounts > 1
		)
	end
	check(
		"chestcount: unknown structure uses DefaultClass",
		LootChests.classOf("somethingNew") == Config.Loot.DefaultClass
	)

	-- Beacon: exactly one top-rarity chest, the others never top
	local beacon = structureFor("Beacon")
	local exactlyOne, noOtherTop = true, true
	for seed = 1, SEEDS do
		local picks = LootChests.selectSlots(beacon, seed, `{beacon}#1`, candidates(12))
		local forced = 0
		for _, p in picks do
			local plan = LootChests.plan(LootTables, pool, seed, {
				x = p.index * 17,
				y = 0,
				z = p.index * 31,
				depth = 4,
				structureType = beacon,
				ring = 3,
				index = p.index,
				topMode = p.topMode,
			})
			if plan.rarity == TOP then
				forced += 1
				if p.topMode ~= "force" then
					noOtherTop = false
				end
			end
		end
		exactlyOne = exactlyOne and forced == (Config.Loot.Chests.Beacon.TopRarity or 1)
	end
	check("chestcount: Beacon has exactly one top-rarity chest", exactlyOne)
	check("chestcount: Beacon other chests never roll top rarity", noOtherTop)

	-- determinism: same seed => same picks, in any candidate order
	local same = true
	for seed = 1, 100 do
		local a = LootChests.selectSlots("MineComplex", seed, "MineComplex#1", candidates(15))
		local reversed = candidates(15)
		for i = 1, #reversed // 2 do
			reversed[i], reversed[#reversed - i + 1] = reversed[#reversed - i + 1], reversed[i]
		end
		local b = LootChests.selectSlots("MineComplex", seed, "MineComplex#1", reversed)
		if #a ~= #b then
			same = false
		else
			for i, p in a do
				if b[i].index ~= p.index or b[i].topMode ~= p.topMode then
					same = false
				end
			end
		end
	end
	check("chestcount: same seed => same count and positions", same)
	local differs = false
	for seed = 2, 40 do
		local a = LootChests.selectSlots("MineComplex", 1, "MineComplex#1", candidates(15))
		local b = LootChests.selectSlots("MineComplex", seed, "MineComplex#1", candidates(15))
		if #a ~= #b or a[1].index ~= b[1].index then
			differs = true
		end
	end
	check("chestcount: different seeds differ", differs)

	-- spread: distinct rooms when enough rooms exist; depth mix
	local roomsOk, depthMix = true, true
	for seed = 1, SEEDS do
		local cands = candidates(12)
		local picks = LootChests.selectSlots("MineComplex", seed, "MineComplex#1", cands)
		local rooms, depths, nd = {}, {}, 0
		for _, p in picks do
			local c = cands[p.index]
			if rooms[c.room :: string] then
				roomsOk = false
			end
			rooms[c.room :: string] = true
			if not depths[c.depth] then
				depths[c.depth] = true
				nd += 1
			end
		end
		depthMix = depthMix and nd >= math.min(#picks, 3)
	end
	check("chestcount: never two chests in one room when avoidable", roomsOk)
	check("chestcount: chests span several depth tiers", depthMix)

	-- ring weighting raises rarity, never the count
	local function meanRank(ring: number): number
		local sum = 0
		local rng = LootChests.makeRng(99)
		for _ = 1, 3000 do
			sum += Rarity.rank(
				LootRoll.pickChestRarity(
					LootTables,
					2,
					"ExpandedRuins",
					2,
					rng,
					LootChests.ringBonus(ring)
				)
			)
		end
		return sum / 3000
	end
	check(
		"chestcount: ring bonus rises with ring",
		LootChests.ringBonus(3) > LootChests.ringBonus(2)
	)
	check(
		"chestcount: ring bonus 0 in rings 0 and 1",
		LootChests.ringBonus(0) == 0 and LootChests.ringBonus(1) == 0
	)
	check("chestcount: ring 3 bonus weights rarer chests more", meanRank(3) > meanRank(0) + 0.05)
	local countsEqual = true
	for seed = 1, 100 do
		local c = candidates(12)
		-- selectSlots has no ring input: counts depend only on (class, seed, key)
		countsEqual = countsEqual
			and #LootChests.selectSlots("MineComplex", seed, "MineComplex#1", c)
				== #LootChests.selectSlots("MineComplex", seed, "MineComplex#1", c)
	end
	check("chestcount: ring does not change chest count", countsEqual)

	-- never more chests than candidates
	check(
		"chestcount: capped by available slots",
		#LootChests.selectSlots("MineComplex", 1, "x", candidates(1)) == 1
	)

	-- beams: short, rare+ only, capped, distance fade configured
	local B = Config.Loot.Beam
	local beamOk, minOk = true, true
	for _, name in Rarity.List do
		local s = ChestStyle.Styles[name]
		if s.beamHeight > B.Height or s.beamHeight > B.MaxHeight then
			beamOk = false
		end
		local wants = Rarity.rank(name) >= Rarity.rank(B.MinRarity)
		if (s.beamHeight > 0) ~= wants then
			minOk = false
		end
	end
	check(
		"beam: height <= Beam.Height and hard cap MaxHeight",
		beamOk and B.Height <= B.MaxHeight and B.MaxHeight <= 12
	)
	check("beam: only rarity >= Beam.MinRarity", minOk)
	check(
		"beam: fade band inside the visible radius, MaxActive small",
		B.FadeBand < B.VisibleRadius and B.MaxActive >= 1 and B.MaxActive <= 12
	)
	check(
		"beam: one beam part per chest at most",
		ChestStyle.partCount(ChestStyle.get("legendary")) <= ChestStyle.Budget.MaxParts
	)
	local R, band = B.VisibleRadius, B.FadeBand
	check(
		"beam: fade 0 near, 1 beyond VisibleRadius, between in the band",
		ChestStyle.beamFade(5, R, band) == 0
			and ChestStyle.beamFade(R + 1, R, band) == 1
			and ChestStyle.beamFade(R - band / 2, R, band) > 0
			and ChestStyle.beamFade(R - band / 2, R, band) < 1
	)

	-- Ring chest rules: ring N (player-facing 1..4) holds at most N chests, each chance-based
	for ring = 0, 3 do
		local rr = Config.Loot.Rings.Chests[ring + 1]
		local maxSeen, minSeen, total = 0, 99, 0
		for seed = 1, SEEDS do
			local n = LootChests.countFor("RangerLodge", seed, `RangerLodge#{seed}`, 99, ring)
			local nCabin = LootChests.countFor("cabin", seed, `cabin#{seed}`, 99, ring)
			maxSeen, minSeen, total = math.max(maxSeen, n), math.min(minSeen, n), total + n
			if nCabin > math.min(rr.MaxPerStructure, Config.Loot.Chests.Small.Max) then
				maxSeen = 99
			end
		end
		check(
			`ringchests: ring {ring + 1} never exceeds {rr.MaxPerStructure}`,
			maxSeen <= rr.MaxPerStructure
		)
		check(`ringchests: ring {ring + 1} can have no chest`, minSeen == 0)
		local trials = math.min(rr.MaxPerStructure, Config.Loot.Chests.Medium.Max)
		local expected = trials * rr.ChestChance
		check(
			`ringchests: ring {ring + 1} mean count follows ChestChance`,
			math.abs(total / SEEDS - expected) < 0.12
		)
	end
	check(
		"ringchests: ring 1 max 1, ring 4 max 4 in config",
		Config.Loot.Rings.Chests[1].MaxPerStructure == 1
			and Config.Loot.Rings.Chests[4].MaxPerStructure == 4
	)
	local ownOk = true
	for seed = 1, 200 do
		for ring = 0, 3 do
			local mass = LootChests.countFor("MineComplex", seed, `m{seed}`, 99, ring)
			local rule = Config.Loot.Chests.Massive
			ownOk = ownOk and mass >= rule.Min and mass <= rule.Max
			local picks =
				LootChests.selectSlots("ResearchStation", seed, `b{seed}`, candidates(12), ring)
			ownOk = ownOk and #picks >= Config.Loot.Chests.Beacon.Min
		end
	end
	check("ringchests: massive and beacon structures keep their own range", ownOk)
	local detOk = true
	for seed = 1, 100 do
		local a = LootChests.selectSlots("ruin", seed, "ruin#1", candidates(8), 2)
		local b = LootChests.selectSlots("ruin", seed, "ruin#1", candidates(8), 2)
		detOk = detOk and #a == #b
		for i, p in a do
			detOk = detOk and b[i].index == p.index
		end
	end
	check("ringchests: ring-based picks are deterministic from the seed", detOk)
end
