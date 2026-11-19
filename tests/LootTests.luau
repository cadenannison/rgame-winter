--!strict
-- Round contracts: item rarity, server-only loot tables, massive structure config, tree rules, fire/wolf/terrain knobs.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Rarity = require("../src/shared/data/Rarity")
local LootRoll = require("../src/shared/logic/LootRoll")
local MassiveRules = require("../src/shared/logic/MassiveRules")
local MobScaling = require("../src/shared/logic/MobScaling")
local TreeRules = require("../src/shared/logic/TreeRules")
local LootTables = require("../src/server/Loot/LootTables")

local SAMPLES = 4000
local SMALL_POIS = { "cabin", "plane", "cave", "ruin", "campsite" }

local function meanRank(items: { LootRoll.Stack }, sum: { number }): ()
	for _, s in items do
		sum[1] += Rarity.rank(ItemCatalog.rarityOf(s.id))
		sum[2] += 1
	end
end
local Biomes = require("../src/shared/data/Biomes")
local LootChests = require("../src/shared/logic/LootChests")
return function(check: (string, boolean) -> ())
	-- Rarity tags
	local tagged = true
	for id, def in ItemCatalog.Items do
		if not Rarity.isRarity(def.rarity) or Rarity.Tags[id] == nil then
			tagged = false
		end
	end
	check("loot: every item has a rarity", tagged)
	check(
		"loot: five rarities, same as Config.Loot",
		#Rarity.List == 5 and #Config.Loot.Rarities == 5 and Config.Loot.Rarities[5] == "legendary"
	)
	check(
		"loot: no unknown Rarity.Tags ids",
		(function()
			for id in Rarity.Tags do
				if ItemCatalog.Items[id] == nil then
					return false
				end
			end
			return true
		end)()
	)

	-- Tables are server-only: nothing in Config carries weights.
	local leaked = false
	for key in Config.Loot :: any do
		if string.find(string.lower(tostring(key)), "weight") then
			leaked = true
		end
	end
	check("loot: no weights in shared Config", not leaked)

	-- Table coverage
	local covered = true
	for _, id in Config.Massive.Ids do
		if LootTables.structureWeights[id] == nil or LootTables.structureChests[id] == nil then
			covered = false
		end
	end
	for _, kind in SMALL_POIS do
		if LootTables.structureWeights[kind] == nil or LootTables.structureChests[kind] == nil then
			covered = false
		end
	end
	check("loot: every structure type has weights and chest counts", covered)
	check("loot: depth max matches Config", LootTables.depth.MaxTier == Config.Loot.MaxDepthTier)
	local chestsOk = true
	for _, r in Rarity.List do
		local c = LootTables.chests[r]
		if
			c == nil
			or #c.items ~= 2
			or c.items[1] < 1
			or c.items[2] > Config.Storage.ChestSlots
		then
			chestsOk = false
		end
	end
	check("loot: a table per chest rarity", chestsOk)

	-- Chest rarity by ring: expected rank rises outward.
	local state = 12345
	local function r(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	local function meanChestRank(ring: number, structure: string, depth: number): number
		local sum = 0
		for _ = 1, SAMPLES do
			sum += Rarity.rank(LootRoll.pickChestRarity(LootTables, ring, structure, depth, r))
		end
		return sum / SAMPLES
	end
	local m0, m1, m2, m3 =
		meanChestRank(0, "cabin", 0),
		meanChestRank(1, "cabin", 0),
		meanChestRank(2, "cabin", 0),
		meanChestRank(3, "cabin", 0)
	check("loot: chest rarity improves with ring", m0 < m1 and m1 < m2 and m2 < m3)
	check(
		"loot: ring 0 almost never epic+",
		(function()
			local n = 0
			for _ = 1, SAMPLES do
				if Rarity.rank(LootRoll.pickChestRarity(LootTables, 0, "cabin", 0, r)) >= 4 then
					n += 1
				end
			end
			return n == 0
		end)()
	)
	check(
		"loot: massive structures beat small ones in the same ring",
		meanChestRank(2, "RuinedTemple", 0) > meanChestRank(2, "cabin", 0)
	)
	check(
		"loot: deeper chests roll better",
		meanChestRank(2, "ExpandedRuins", 4) > meanChestRank(2, "ExpandedRuins", 0) + 0.2
	)

	-- Contents by chest rarity
	local pool = LootRoll.buildPool(ItemCatalog.Items :: any)
	local function contents(chest: string): ({ number }, number)
		local sum = { 0, 0 }
		local high = 0
		local rolls = 0
		for _ = 1, SAMPLES do
			local items = LootRoll.rollChest(LootTables, pool, chest, r)
			rolls += 1
			for _, s in items do
				if Rarity.rank(ItemCatalog.rarityOf(s.id)) >= 4 then
					high += 1
				end
			end
			meanRank(items, sum)
		end
		return sum, high / rolls
	end
	local commonSum, commonHigh = contents("common")
	local legSum, legHigh = contents("legendary")
	check("loot: common chests almost never give epic+", commonHigh < 0.01)
	check(
		"loot: legendary chests give better gear",
		legSum[1] / legSum[2] > commonSum[1] / commonSum[2] + 1.2 and legHigh > 0.5
	)
	local sizeOk = true
	for _, chest in Rarity.List do
		for _ = 1, 200 do
			local items = LootRoll.rollChest(LootTables, pool, chest, r)
			local def = LootTables.chests[chest]
			if #items > def.items[2] or #items < 1 then
				sizeOk = false
			end
			for _, s in items do
				if s.count < 1 or s.count > ItemCatalog.Items[s.id].maxStack then
					sizeOk = false
				end
			end
		end
	end
	check("loot: stack and item counts in range", sizeOk)
	local categories = true
	for _, cat in Rarity.Categories do
		if #LootRoll.bucket(pool, cat, "common") == 0 then
			categories = false
		end
	end
	check("loot: every category has common items", categories)

	-- Massive structures
	local M = Config.Massive
	check("massive: six structures", #M.Ids == 6)
	local massiveOk, budgetOk = true, true
	local half = Config.World.GridSize * Config.World.ChunkSize / 2
	local largest = 0
	for _, id in M.Ids do
		local d = M.Structures[id]
		if
			d == nil
			or d.Id ~= id
			or d.MinRooms < 6
			or d.MinLevels < 2
			or d.CountMin < 1
			or d.CountMin > d.CountMax
		then
			massiveOk = false
			continue
		end
		if
			d.MinFootprintX > Config.World.ChunkSize
			or d.MinFootprintZ > Config.World.ChunkSize
			or MassiveRules.footprintRadius(id) > half / 4
		then
			massiveOk = false
		end
		for _, ring in d.Rings do
			if ring < 0 or ring > 3 then
				massiveOk = false
			end
		end
		local b = d.Budget
		largest = math.max(largest, b.Parts)
		if
			b.DressingParts >= b.Parts
			or b.Particles * M.MaxLiveStructures > Config.Perf.MaxParticleEmitters
			or b.Lights < 1
		then
			budgetOk = false
		end
	end
	check("massive: footprints, rooms, levels, rings, counts", massiveOk)
	check("massive: budgets fit", budgetOk)
	check(
		"massive: underground where required",
		M.Structures.MineComplex.UndergroundDepth >= 20
			and M.Structures.ResearchStation.UndergroundDepth > 0
	)
	check(
		"massive: corridor and ceiling minimums",
		M.CorridorWidthMin >= 6 and M.CeilingHeightMin > Config.Shelter.CeilingHeight
	)
	check(
		"massive: dressing hysteresis",
		M.DressingDespawnRadius > M.DressingSpawnRadius and M.DressingSpawnRadius > 0
	)
	check(
		"massive: parts fit inside the unraised Perf cap",
		M.MaxLiveParts >= M.MaxLiveStructures * largest
			and Config.Perf.MaxLiveParts <= 6000
			and M.MaxLiveParts < Config.Perf.MaxLiveParts
	)
	check(
		"massive: ring rules",
		MassiveRules.ringAllowed("FrozenShipwreck", 1)
			and not MassiveRules.ringAllowed("FrozenShipwreck", 3)
	)
	check(
		"massive: validatePlan accepts the minimum, rejects a short corridor",
		(function()
			local d = M.Structures.RangerLodge
			local plan: MassiveRules.PlanSummary = {
				id = "RangerLodge",
				footprintX = d.MinFootprintX,
				footprintZ = d.MinFootprintZ,
				rooms = d.MinRooms,
				levels = d.MinLevels,
				undergroundDepth = d.UndergroundDepth,
				minCorridorWidth = M.CorridorWidthMin,
				minCeilingHeight = M.CeilingHeightMin,
				parts = d.Budget.Parts,
				dressingParts = d.Budget.DressingParts,
				lights = d.Budget.Lights,
				particles = d.Budget.Particles,
			}
			local ok = #MassiveRules.validatePlan(plan) == 0
			plan.minCorridorWidth = 3
			return ok and #MassiveRules.validatePlan(plan) == 1
		end)()
	)

	-- Trees
	local T = Config.Trees
	check(
		"trees: canopy clearance is head + 2",
		T.MinCanopyBottom == T.HeadHeight + T.CanopyClearance and T.CanopyClearance >= 2
	)
	local treesOk = #Config.Forest.Classes == #T.SizeClasses
	for i, c in Config.Forest.Classes do
		if
			c.Id ~= T.SizeClasses[i]
			or c.Height[1] < T.MinTotalHeight
			or c.Height[1] - T.MinFoliageThickness < T.MinCanopyBottom
		then
			treesOk = false
		end
	end
	local giant = Config.Forest.Classes[#Config.Forest.Classes]
	check("trees: classes meet min height", treesOk)
	check(
		"trees: giant heights",
		giant.Height[1] == T.GiantHeightMin
			and giant.Height[2] == T.GiantHeightMax
			and T.GiantHeightMin >= 70
	)
	check(
		"trees: foliageBottom clamps",
		TreeRules.foliageBottom(20, 0.1) >= T.MinCanopyBottom
			and TreeRules.canopyOk(30, TreeRules.foliageBottom(30, 0.2))
			and not TreeRules.canopyOk(30, 3)
	)

	-- Fire, terrain, wolf knobs
	local F = Config.FireRules
	check(
		"fire rules: spawn exclusion and tree clear",
		#F.SpawnExcludeCategories >= 3
			and F.TreeClearRadius == Config.Forest.FireClearRadius
			and F.TreeClearMaxRadius >= F.TreeClearRadius
	)
	check(
		"terrain: per-tick build budget",
		Config.Terrain.BuildBlocksPerTick > 0
			and Config.Terrain.BuildBlocksPerTick <= Config.Terrain.MaxBlocksPerChunkBuild
			and Config.Terrain.BuildMsPerTick > 0
	)
	check(
		"wolf scaling: capped and rising",
		MobScaling.wolfDamageFactor(1) == 1
			and MobScaling.wolfDamageFactor(6) > 1
			and MobScaling.wolfDamageFactor(1000) == Config.WolfScaling.MaxDamageMultiplier
			and MobScaling.wolfSpawnFactor(1000) == Config.WolfScaling.MaxSpawnRateMultiplier
	)

	-- Iron gating by ring (Config.Loot.Rings): none in ring 1, rare in ring 2, more in ring 3+
	local ironSet: { [string]: boolean } = {}
	for _, id in Config.Loot.Rings.IronItems do
		ironSet[id] = true
	end
	check(
		"iron: every IronItems id exists in the catalog",
		(function(): boolean
			for id in ironSet do
				if ItemCatalog.Items[id] == nil then
					return false
				end
			end
			return true
		end)()
	)
	local function ironRate(ring: number): number
		local rng = LootChests.makeRng(4242 + ring)
		local hits, stacks = 0, 0
		for i = 1, 6000 do
			local rarity = Rarity.List[(i % #Rarity.List) + 1]
			for _, s in
				LootRoll.rollChest(LootTables, pool, rarity, rng, LootChests.itemWeightFor(ring))
			do
				stacks += 1
				if ironSet[s.id] then
					hits += 1
				end
			end
		end
		return hits / math.max(stacks, 1)
	end
	local r1, r2, r3, r4 = ironRate(0), ironRate(1), ironRate(2), ironRate(3)
	check("iron: ring 1 chests never contain iron", r1 == 0)
	check("iron: ring 2 chests have rare iron", r2 > 0 and r2 < 0.03)
	check("iron: ring 3 has more iron than ring 2", r3 > r2 * 1.5)
	check("iron: ring 4 has at least ring 3 iron", r4 >= r3)
	local planIron = 0
	for i = 1, 4000 do
		local plan = LootChests.plan(LootTables, pool, 100 + i, {
			x = i * 7,
			y = 0,
			z = i * 13,
			depth = i % 5,
			structureType = ({ "cabin", "plane", "ruin", "MineComplex", "RuinedTemple" })[i % 5 + 1],
			ring = 0,
			index = i % 4,
			topMode = if i % 50 == 0 then "force" else nil,
		})
		for _, s in plan.items do
			if ironSet[s.id] then
				planIron += 1
			end
		end
	end
	check("iron: planned ring-1 chests (any structure/rarity) have zero iron", planIron == 0)
	check(
		"iron: starter items contain no iron",
		(function(): boolean
			for _, s in Config.Inventory.StarterItems do
				if ironSet[s.id] then
					return false
				end
			end
			return true
		end)()
	)
	local biomesOk = true
	for tier = 1, 2 do
		for _, e in Biomes.Loot[tier].entries do
			if ironSet[e.id] then
				biomesOk = false
			end
		end
	end
	check("iron: POI crate tiers 1-2 (rings 1-2 of the biome table) have no iron", biomesOk)
	check(
		"iron: node ring gate is ring 2 or later",
		Config.Loot.Rings.IronNodeMinRing >= Config.Loot.Rings.IronMinRing
			and Config.Loot.Rings.IronNodeMinRing >= 2
	)
	local nodeBiomesOk = true
	for _, b in Biomes.List do
		if
			table.find(b.nodeKinds, "IronOre")
			and b.ring + 1 < Config.Loot.Rings.IronNodeMinRing
		then
			nodeBiomesOk = false
		end
	end
	check("iron: biome node kinds respect IronNodeMinRing", nodeBiomesOk)
end
