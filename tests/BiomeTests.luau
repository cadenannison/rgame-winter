--!strict
-- Brief 13 (WorldGen) tests: determinism, ring math, loot tiers, camp guarantee, variants, node memory,
-- hearth, thin ice, fog map. Uses the live Config.World so a ring/config change breaks here first.

local Biomes = require("../src/shared/data/Biomes")
local BiomeLogic = require("../src/shared/logic/BiomeLogic")
local Chunks = require("../src/shared/data/Chunks")
local Config = require("../src/shared/Config")
local FogMap = require("../src/shared/logic/FogMap")
local ItemCatalog = require("../src/shared/ItemCatalog")
local WorldLayout = require("../src/shared/logic/WorldLayout")

local PARAMS: WorldLayout.Params = Config.World
local SEEDS = 40

local function dist(a: WorldLayout.Vec2, b: WorldLayout.Vec2): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

return function(check: (string, boolean) -> ())
	-- Determinism
	local a = WorldLayout.generate(777, PARAMS)
	local b = WorldLayout.generate(777, PARAMS)
	local c = WorldLayout.generate(778, PARAMS)
	check("biome same seed same layout", WorldLayout.serialize(a) == WorldLayout.serialize(b))
	check("biome different seed differs", WorldLayout.serialize(a) ~= WorldLayout.serialize(c))

	-- Ring math
	local r = Config.World.ChunkSize
	check("biome ring centre", BiomeLogic.ringAt(0, 0) == 0)
	check("biome ring 1 edge", BiomeLogic.ringAt(r, 0) == 1 and BiomeLogic.ringAt(-r + 1, 0) == 0)
	check("biome ring 3", BiomeLogic.ringAt(0, 3.5 * r) == 3)
	check("biome ring clamps outside map", BiomeLogic.ringAt(99999, -99999) == 3)
	local ringMatches = true
	for _, chunk in a.chunks do
		ringMatches = ringMatches
			and BiomeLogic.ringAt(chunk.center.x, chunk.center.z) == chunk.ring
	end
	check("biome ringAt matches chunk ring", ringMatches)
	local ringsOk = true
	for i, def in Biomes.List do
		ringsOk = ringsOk and def.ring == i - 1 and def.outerRadius - def.innerRadius == r
	end
	check("biome list is concentric rings", ringsOk)
	local drainOk = BiomeLogic.drainMultiplier(0, 0) == 1
	for ring = 1, 3 do
		drainOk = drainOk
			and BiomeLogic.drainMultiplier(ring, 0) > BiomeLogic.drainMultiplier(ring - 1, 0)
	end
	check("biome drain rises with ring, ring 0 neutral", drainOk)
	check(
		"biome resistance lowers drain",
		BiomeLogic.drainMultiplier(2, 6) < BiomeLogic.drainMultiplier(2, 0)
			and BiomeLogic.drainMultiplier(3, 999) >= Config.Biome.MinDrainFraction
	)

	-- Variants
	local variantsOk = true
	for _, def in Biomes.List do
		variantsOk = variantsOk and #Chunks.forBiome(def.id) >= 3
	end
	check("biome >=3 variants per biome", variantsOk)
	local seen: { [string]: boolean } = {}
	local biomeOk = true
	for seed = 1, SEEDS do
		local l = WorldLayout.generate(seed, PARAMS)
		for _, chunk in l.chunks do
			seen[chunk.variantId] = true
			biomeOk = biomeOk and chunk.biome == Biomes.forRing(chunk.ring).id
		end
	end
	local allVariants = true
	for _, v in Chunks.Variants do
		allVariants = allVariants and seen[v.id] == true
	end
	check("biome chunk biome matches ring", biomeOk)
	check("biome every variant appears across seeds", allVariants)

	-- Camp guarantee over many seeds (Config.World.StartForestRing, now 0)
	local campOk, woodOk, foodOk, nearOk, inChunk, oneFood = true, true, true, true, true, true
	for seed = 1, SEEDS do
		local l = WorldLayout.generate(seed, PARAMS)
		local camp = l.camp
		local chunk = l.chunks[camp.chunkIndex]
		campOk = campOk
			and chunk.ring == Config.World.StartForestRing
			and chunk.biome == "SnowyForest"
		woodOk = woodOk and #camp.wood >= Config.World.CampGuaranteedWoodCount
		foodOk = foodOk and #camp.food >= Config.World.CampGuaranteedFoodCount
		inChunk = inChunk and WorldLayout.distanceToChunk(l, chunk, camp.position) == 0
		for _, v in camp.wood do
			nearOk = nearOk and dist(v, camp.position) <= Config.World.CampGuaranteeRadius
			inChunk = inChunk and WorldLayout.distanceToChunk(l, chunk, v) == 0
		end
		for _, v in camp.food do
			nearOk = nearOk and dist(v, camp.position) <= Config.World.CampGuaranteeRadius
			inChunk = inChunk and WorldLayout.distanceToChunk(l, chunk, v) == 0
		end
		oneFood = oneFood and #chunk.food >= #camp.food and #chunk.trees >= #camp.wood
	end
	check("biome camp in start forest ring", campOk)
	check("biome camp guaranteed wood", woodOk)
	check("biome camp guaranteed food", foodOk)
	check("biome camp resources within radius", nearOk)
	check("biome camp resources inside camp chunk", inChunk)
	check("biome camp chunk holds the slots", oneFood)
	check("biome start ring is ring 0", Config.World.StartForestRing == 0)

	-- Loot tiers
	local monotonic, last = true, 0
	for d = 0, 3000, 25 do
		local tier = BiomeLogic.lootTier(d)
		monotonic = monotonic
			and tier >= last
			and tier >= 1
			and tier <= BiomeLogic.Tuning.MaxLootTier
		last = tier
	end
	check(
		"biome loot tier monotonic in distance",
		monotonic and last == BiomeLogic.Tuning.MaxLootTier
	)
	local valueOk = true
	for tier = 2, #Biomes.Loot do
		valueOk = valueOk
			and BiomeLogic.expectedLootValue(tier) > BiomeLogic.expectedLootValue(tier - 1)
	end
	check("biome loot value rises with tier", valueOk)
	local idsOk = #Biomes.Loot == BiomeLogic.Tuning.MaxLootTier
	for _, t in Biomes.Loot do
		for _, e in t.entries do
			idsOk = idsOk and ItemCatalog.Items[e.id] ~= nil and e.min >= 1 and e.max >= e.min
		end
	end
	check("biome loot ids exist", idsOk)
	local function rngFrom(seed: number): () -> number
		local s = seed
		return function()
			s = (s * 1664525 + 1013904223) % 4294967296
			return s / 4294967296
		end
	end
	local l1 = BiomeLogic.rollLoot(3, rngFrom(5))
	local l2 = BiomeLogic.rollLoot(3, rngFrom(5))
	local same = #l1 == #l2 and #l1 == Biomes.Loot[3].rolls
	for i, item in l1 do
		same = same and l2[i].id == item.id and l2[i].count == item.count
	end
	check("biome loot roll deterministic", same)
	local tierOk, poiCount = true, 0
	for _, chunk in a.chunks do
		for _, poi in chunk.pois do
			poiCount += 1
			local d = dist(poi.position, a.camp.position)
			if poi.kind == "hotspring" or poi.kind == "thinice" then
				tierOk = tierOk and poi.lootTier == 0
			else
				tierOk = tierOk and poi.lootTier == BiomeLogic.lootTier(d)
			end
		end
	end
	check("biome pois exist with tiers from camp distance", poiCount > 10 and tierOk)
	local hotOuter, cabinInner = true, true
	for seed = 1, SEEDS do
		for _, chunk in WorldLayout.generate(seed, PARAMS).chunks do
			for _, poi in chunk.pois do
				if poi.kind == "hotspring" then
					hotOuter = hotOuter and chunk.ring >= 2
				end
				if poi.kind == "thinice" then
					hotOuter = hotOuter and chunk.biome == "FrozenLake" and #poi.patches > 0
				end
				if poi.kind == "cabin" then
					cabinInner = cabinInner and chunk.ring <= 1
				end
			end
		end
	end
	check("biome hot springs only in outer rings, thin ice on lake", hotOuter)
	check("biome cabins in inner rings", cabinInner)

	-- Node memory (depleted stays depleted across unload/reload)
	local respawn, maxHits = 240, 3
	check("node memory none is full", BiomeLogic.nodeState(nil, 100, respawn, maxHits) == "full")
	local st, rem = BiomeLogic.nodeState({ depletedAt = 100 }, 150, respawn, maxHits)
	check("node memory depleted stays depleted", st == "depleted" and rem == 190)
	check(
		"node memory respawns after timer",
		BiomeLogic.nodeState({ depletedAt = 100 }, 400, respawn, maxHits) == "full"
	)
	check(
		"node memory partial hits kept",
		BiomeLogic.nodeState({ hits = 1 }, 0, respawn, maxHits) == "partial"
	)
	check(
		"node memory full hits is full",
		BiomeLogic.nodeState({ hits = maxHits }, 0, respawn, maxHits) == "full"
	)

	-- Hearth fuel
	local lit = BiomeLogic.hearthAfterWood(0, 100)
	check("hearth wood lights it", lit == 100 + BiomeLogic.Tuning.HearthBurnSeconds)
	local capped = 0
	for _ = 1, 20 do
		capped = BiomeLogic.hearthAfterWood(capped, 100)
	end
	check("hearth fuel capped", capped == 100 + BiomeLogic.Tuning.HearthMaxSeconds)

	-- Thin ice
	local secs, broke = 0, false
	local ticks = 0
	while not broke and ticks < 100 do
		secs, broke = BiomeLogic.iceStep(secs, true, 0.25)
		ticks += 1
	end
	check(
		"ice breaks after standing",
		broke and ticks * 0.25 >= BiomeLogic.Tuning.ThinIceCrackSeconds
	)
	local resetSecs = BiomeLogic.iceStep(2, false, 0.25)
	check("ice resets when leaving", resetSecs == 0)

	-- Fog map
	local fog = FogMap.new(2560, 64)
	check("fog grid size", fog.cellsPerSide == 40 and fog.count == 0)
	check(
		"fog corner cells",
		FogMap.cellIndex(fog, -1280, -1280) == 1 and FogMap.cellIndex(fog, 1279, 1279) == 1600
	)
	local added = FogMap.mark(fog, 0, 0, 96)
	check("fog mark adds cells", added >= 4 and fog.count == added)
	check("fog mark idempotent", FogMap.mark(fog, 0, 0, 96) == 0)
	check("fog zero radius marks own cell", FogMap.mark(fog, 500, 500, 0) == 1)
	local list = FogMap.list(fog, 1600)
	check("fog list sorted explored only", #list == fog.count and list[1] < list[#list])
	check("fog list capped", #FogMap.list(fog, 3) == 3)
end
