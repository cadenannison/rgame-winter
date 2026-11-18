--!strict
-- Phase 3 pure-data validation (brief 12): tables well-formed, caps present, design rules hold.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Biomes = require("../src/shared/data/Biomes")
local Chunks = require("../src/shared/data/Chunks")
local Events = require("../src/shared/data/Events")
local Lurkers = require("../src/shared/data/Lurkers")
local Mobs = require("../src/shared/data/Mobs")
local Clothing = require("../src/shared/data/Clothing")
local Food = require("../src/shared/data/Food")
local Items = require("../src/shared/data/Items")
local Recipes = require("../src/shared/data/Recipes")
local Structures = require("../src/shared/data/Structures")
local WorldLayout = require("../src/shared/logic/WorldLayout")

local function all<T>(list: { T }, pred: (T) -> boolean): boolean
	for _, v in list do
		if not pred(v) then
			return false
		end
	end
	return true
end

local function contains(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

local function uniqueBy<T>(list: { T }, key: (T) -> string): boolean
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

return function(check: (string, boolean) -> ())
	-- Biomes
	local W = Config.World
	local B = Config.Biome
	check("biomes: four rings", #Biomes.List == 4)
	check("biomes: one per grid ring", #Biomes.List == WorldLayout.maxRing(W.GridSize) + 1)
	check("biomes: start forest is the camp ring", Biomes.List[1].ring == W.StartForestRing)
	local radiiOk, monotonic = true, true
	for i, b in Biomes.List do
		radiiOk = radiiOk
			and b.ring == i - 1
			and b.innerRadius == (i - 1) * W.ChunkSize
			and b.outerRadius == i * W.ChunkSize
		if i > 1 then
			local prev = Biomes.List[i - 1]
			monotonic = monotonic
				and b.coldSeverity > prev.coldSeverity
				and b.requiredColdResistance > prev.requiredColdResistance
				and b.mobTier >= prev.mobTier
				and b.lootTier >= prev.lootTier
		end
	end
	check("biomes: contiguous ring radii", radiiOk)
	check(
		"biomes: outer edge is the map edge",
		Biomes.List[4].outerRadius == W.GridSize / 2 * W.ChunkSize
	)
	check("biomes: cold, resistance and tiers rise outward", monotonic)
	check("biomes: start forest needs no resistance", Biomes.List[1].requiredColdResistance == 0)
	check(
		"biomes: severity and resistance under caps",
		all(Biomes.List, function(b)
			return b.coldSeverity >= 1
				and b.coldSeverity <= B.MaxColdSeverity
				and b.requiredColdResistance <= B.MaxRequiredColdResistance
		end)
	)
	check(
		"biomes: node kinds exist",
		all(Biomes.List, function(b)
			return all(b.nodeKinds, function(k)
				return ItemCatalog.Nodes[k] ~= nil
			end)
		end)
	)
	check(
		"biomes: lurker kinds exist",
		all(Biomes.List, function(b)
			return b.lurkerKind == nil or Lurkers.ByKind[b.lurkerKind] ~= nil
		end)
	)
	check(
		"biomes: unique ids",
		uniqueBy(Biomes.List, function(b)
			return b.id
		end)
	)
	check(
		"biomes: forRing clamps",
		Biomes.forRing(99).id == "DeepTundra" and Biomes.forRing(-1).id == "SnowyForest"
	)
	check(
		"biome caps sane",
		B.MinDrainFraction > 0
			and B.MinDrainFraction < 1
			and B.MaxUnderdressedMultiplier >= 1
			and B.ResistanceDrainReductionPerPoint > 0
	)

	-- Chunks
	check(
		"chunks: unique ids",
		uniqueBy(Chunks.Variants, function(v)
			return v.id
		end)
	)
	check(
		"chunks: several variants per biome",
		all(Biomes.List, function(b)
			return #Chunks.forBiome(b.id) >= 3
		end)
	)
	check(
		"chunks: well-formed",
		all(Chunks.Variants, function(v)
			local biome = Biomes.ById[v.biome]
			local counts = v.trees >= 0
				and v.rocks >= 0
				and v.ore >= 0
				and v.food >= 0
				and v.spawnZones >= 1
			local poi = v.poiSlots >= 0 and (v.poiSlots == 0 or #v.poiKinds > 0)
			local spring = not contains(v.poiKinds, "hotspring")
				or (biome ~= nil and biome.hotSprings)
			return biome ~= nil and v.weight > 0 and counts and poi and spring
		end)
	)
	check(
		"chunks: start forest has wood and food",
		all(Chunks.forBiome("SnowyForest"), function(v)
			return v.trees > 0 and v.food > 0
		end)
	)

	-- Dark events and blizzard
	local E = Config.Events
	check("events: none before day 3", E.FirstDay >= 3)
	check(
		"events: every event starts on or after FirstDay",
		all(Events.Dark, function(e)
			return e.minDay >= E.FirstDay
		end)
	)
	check(
		"events: ids match Debug.DarkEvents",
		#Events.Dark == #Config.Debug.DarkEvents
			and all(Config.Debug.DarkEvents, function(id)
				return Events.ById[id] ~= nil
			end)
	)
	check(
		"events: within caps",
		all(Events.Dark, function(e)
			return e.weight > 0
				and e.warningSeconds >= E.MinWarningSeconds
				and e.warningSeconds <= E.MaxWarningSeconds
				and e.durationSeconds > 0
				and e.durationSeconds <= E.MaxDurationSeconds
				and e.warmthDrainMultiplier >= 1
				and e.warmthDrainMultiplier <= E.MaxWarmthDrainMultiplier
				and e.fuelBurnMultiplier >= 1
				and e.fuelBurnMultiplier <= E.MaxFuelBurnMultiplier
				and e.dreadGainMultiplier >= 1
				and e.dreadGainMultiplier <= E.MaxDreadGainMultiplier
				and e.huntChanceBonus >= 0
				and e.huntChanceBonus <= E.MaxHuntChanceBonus
				and contains(Config.Cue.Kinds, e.warningCue)
		end)
	)
	check(
		"events: big events need isolation",
		Events.ById.FalseNight.blockedByFullGroup and Events.ById.TheQuiet.blockedByFullGroup
	)
	check(
		"events: frequency capped",
		E.MaxChancePerCheck >= E.BaseChancePerCheck
			and E.MaxChancePerCheck < 1
			and E.ChancePerDay >= 0
			and E.MaxPerDay >= 1
			and E.CheckIntervalSeconds > 0
	)
	check("events: min gap outlasts any event", E.MinGapSeconds >= E.MaxDurationSeconds)
	check("events: blizzard buffer set (no overlap)", E.BlizzardBufferSeconds > 0)
	check(
		"blizzard: warning equals Time.BlizzardWarningSeconds",
		Events.Blizzard.warningSeconds == Config.Time.BlizzardWarningSeconds
	)
	check(
		"blizzard: within caps",
		Events.Blizzard.durationSeconds > 0
			and Events.Blizzard.warmthDrainMultiplier <= E.MaxWarmthDrainMultiplier
			and Events.Blizzard.dreadGainMultiplier <= E.MaxDreadGainMultiplier
			and contains(Config.Cue.Kinds, Events.Blizzard.warningCue)
	)

	-- Mobs and bosses
	check(
		"mobs: unique kinds",
		uniqueBy(Mobs.List, function(m)
			return m.kind
		end)
	)
	check(
		"mobs: no clash with Phase 1 kinds",
		all(Mobs.List, function(m)
			return not contains(Mobs.LegacyKinds, m.kind)
		end)
	)
	check(
		"mobs: roster present",
		all(
			{ "Fish", "PolarBear", "IceWraith", "SnowLurker", "CaveCrawler", "WhiteoutBeast" },
			function(k)
				return Mobs.ByKind[k] ~= nil
			end
		)
	)
	check("mobs: Stalker is not a killable mob", Mobs.ByKind.Stalker == nil)
	local minibossBiomes: { string } = {}
	local bossCount = 0
	for _, m in Mobs.List do
		if m.category == "miniboss" then
			table.insert(minibossBiomes, m.biomes[1])
		elseif m.category == "boss" then
			bossCount += 1
		end
	end
	check(
		"mobs: one mini-boss per far biome",
		#minibossBiomes == 3
			and contains(minibossBiomes, "FrozenLake")
			and contains(minibossBiomes, "MountainsCaves")
			and contains(minibossBiomes, "DeepTundra")
	)
	check("mobs: one blizzard boss", bossCount == 1)
	check(
		"mobs: well-formed",
		all(Mobs.List, function(m)
			local cat = contains({ "animal", "hostile", "miniboss", "boss" }, m.category)
			local biomes = #m.biomes > 0
				and all(m.biomes, function(id)
					return Biomes.ById[id] ~= nil
				end)
			local drop = m.dropId == nil or ItemCatalog.Items[m.dropId] ~= nil
			local ranged = not m.ranged or (m.projectileRange ~= nil and m.projectileRange > 0)
			local stats = m.health > 0 and m.damage >= 0 and m.weight >= 0 and m.budgetCost >= 0
			return cat and biomes and drop and ranged and stats
		end)
	)
	check(
		"mobs: bosses outside the normal budget and late",
		all(Mobs.List, function(m)
			if m.category == "miniboss" then
				return m.weight == 0 and m.minDay >= Config.Bosses.MiniBossFirstDay
			elseif m.category == "boss" then
				return m.weight == 0 and m.minDay >= Config.Bosses.BlizzardBossFirstDay
			end
			return m.weight > 0
		end)
	)
	check(
		"mobs: ranged and bosses break the fire radius",
		all(Mobs.List, function(m)
			return not (m.ranged or m.category == "miniboss" or m.category == "boss")
				or m.breaksFireRadius
		end)
	)
	check(
		"mobs: legacy biomes exist",
		all(Mobs.LegacyKinds, function(k)
			local list = Mobs.LegacyBiomes[k]
			return list ~= nil and all(list, function(id)
				return Biomes.ById[id] ~= nil
			end)
		end)
	)

	-- Scaling caps (day / depth / party size)
	local S = Config.Scaling
	check(
		"scaling: every factor has a cap",
		S.MaxMobHealthMultiplier >= 1
			and S.MaxMobDamageMultiplier >= 1
			and S.MaxMobBudgetMultiplier >= 1
			and S.MaxRingBudgetMultiplier >= 1
			and S.MaxRingHealthMultiplier >= 1
			and S.MaxRingDamageMultiplier >= 1
			and S.MaxPartyBudgetMultiplier >= 1
			and S.MaxPartyHealthMultiplier >= 1
			and S.MaxLiveMobs >= Config.Mobs.Budget
	)
	local Bo = Config.Bosses
	check(
		"bosses: caps",
		Bo.MaxBlizzardBossChance >= Bo.BlizzardBossChance
			and Bo.MaxBlizzardBossChance <= 1
			and Bo.MaxHealthMultiplier >= 1
			and Bo.MaxDamageMultiplier >= 1
			and Bo.MiniBossMaxAlive >= 1
	)

	-- Horror: Dread, Stalker, isolation, lurkers, scares, cues
	local D, St, I, L = Config.Dread, Config.Stalker, Config.Isolation, Config.Lurkers
	local thresholdsOk = #D.CueThresholds == Config.Cue.MaxLevel
	for i, t in D.CueThresholds do
		thresholdsOk = thresholdsOk
			and t > 0
			and t < D.Max
			and (i == 1 or t > D.CueThresholds[i - 1])
	end
	check("dread: cue thresholds ascending, one per cue level", thresholdsOk)
	check(
		"dread: gain caps",
		D.MaxDayGainMultiplier >= 1 and D.MaxRingGainMultiplier >= 1 and D.Max > 0
	)
	check("stalker: no hunts on day 1", St.FirstHuntDay >= 2)
	check(
		"stalker: hunt chance capped",
		St.MaxHuntChance >= St.BaseHuntChance
			and St.MaxHuntChance + Config.Events.MaxHuntChanceBonus <= 1
			and St.HuntCooldownSeconds > 0
	)
	check("stalker: never kills from full", St.Damage < Config.Meters.MaxHealth)
	check("stalker: outrunnable", St.ChaseSpeed < Config.WALK_SPEED)
	check("stalker: telegraphs", St.TelegraphSeconds > 0 and St.RetreatSeconds > 0)
	check(
		"isolation: lone players weigh most",
		I.WeightAlone > I.WeightPair
			and I.WeightPair > I.WeightGroup
			and I.SoloBaseline < I.WeightAlone
	)
	check(
		"lurkers: density capped",
		L.MaxDensity >= L.BaseDensity
			and L.MaxDensity <= 1
			and L.MaxPerPlayer >= 1
			and L.MaxTotal >= L.MaxPerPlayer
	)
	check("lurkers: well-formed", uniqueBy(Lurkers.List, function(x)
		return x.kind
	end) and all(Lurkers.List, function(x)
		return Biomes.ById[x.biome] ~= nil
			and contains({ "watch", "scratch", "eyes" }, x.behavior)
			and x.dreadOnSight > 0
			and x.dreadOnSight <= D.Max
			and x.vanishDistance > 0
	end))
	check(
		"scares: budget capped",
		Config.Scares.MaxPerDay >= 1 and Config.Scares.MinCooldownSeconds > 0
	)
	check(
		"cues: unique kinds",
		uniqueBy(Config.Cue.Kinds, function(k)
			return k
		end)
	)
	-- Hidden metrics never get an attribute or cue: no replicated name mentions them.
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
	local attrNames = {
		B.RingAttribute,
		B.ColdResistanceAttribute,
		Config.Events.ActiveAttribute,
		Config.Blizzard.ActiveAttribute,
		Config.Blizzard.WarningAttribute,
		Config.Storage.OpenAttribute,
		Config.Buffs.ActiveAttribute,
		St.Tag,
		L.Tag,
	}
	check(
		"hidden metrics: no attribute names them",
		all(attrNames, function(n)
			return not leaks(n)
		end)
	)
	check(
		"hidden metrics: no cue kind carries them",
		all(Config.Cue.Kinds, function(k)
			return not leaks(k) or k == "DreadLevel" -- coarse 0..MaxLevel bucket only
		end)
	)

	-- Friendly fire: projectiles only
	check(
		"friendly fire: projectiles only",
		Config.Projectile.MeleeFriendlyFire == false
			and Config.Projectile.FriendlyFireMultiplier > 0
			and Config.Projectile.FriendlyFireMultiplier <= 1
	)

	-- Clothing gates far biomes
	local C = Config.Clothing
	check(
		"clothing: one tier per MaxTier",
		#Clothing.Tiers == C.MaxTier and #Clothing.Pieces == C.MaxTier
	)
	local clothingOk = true
	for t, tierDef in Clothing.Tiers do
		local full = tierDef.resistancePerPiece * #C.Slots
		local biome = Biomes.ById[Clothing.UnlocksBiome[t]]
		clothingOk = clothingOk
			and tierDef.tier == t
			and full <= C.MaxColdResistance
			and biome ~= nil
			and full >= biome.requiredColdResistance
		if t > 1 then
			-- the previous tier must NOT be enough for this tier's biome (gating)
			clothingOk = clothingOk
				and Clothing.Tiers[t - 1].resistancePerPiece * #C.Slots
					< biome.requiredColdResistance
		end
		for _, slot in C.Slots do
			local item = ItemCatalog.Items[Clothing.Pieces[t][slot] or ""]
			clothingOk = clothingOk
				and item ~= nil
				and item.kind == "clothing"
				and item.clothingSlot == slot
				and item.clothingTier == t
				and item.coldResistance == tierDef.resistancePerPiece
		end
	end
	check("clothing: tiers gate far biomes and pieces exist", clothingOk)
	check(
		"clothing: resistance cap covers the max requirement",
		C.MaxColdResistance >= B.MaxRequiredColdResistance
	)

	-- Food and buffs
	local Bu = Config.Buffs
	check(
		"food: cook pairs exist and cooking helps",
		all(Food.Cook, function(c)
			local raw, cooked = ItemCatalog.Items[c.rawId], ItemCatalog.Items[c.cookedId]
			return raw ~= nil and cooked ~= nil and (cooked.hunger or 0) > (raw.hunger or 0)
		end)
	)
	check(
		"food: buffs within caps",
		all(Food.Buffs, function(b)
			local longest = b.durationSeconds * Config.Cooking.MaxStationBuffMultiplier
			return b.durationSeconds > 0
				and longest <= Bu.MaxDurationSeconds
				and b.warmthDrainMultiplier >= 1 - Bu.MaxWarmthDrainReduction
				and b.hungerDrainMultiplier >= 1 - Bu.MaxHungerDrainReduction
				and b.healthRegenBonus <= Bu.MaxHealthRegenBonus
				and b.speedMultiplier <= 1 + Bu.MaxSpeedBonus
		end)
	)
	local eatOk = true
	for itemId, buffId in Food.EatBuffs do
		local item = ItemCatalog.Items[itemId]
		eatOk = eatOk and item ~= nil and item.kind == "food" and Food.BuffById[buffId] ~= nil
	end
	check("food: eat buffs reference real food and buffs", eatOk)
	check(
		"cooking: station multiplier capped",
		Config.Cooking.StationBuffMultiplier <= Config.Cooking.MaxStationBuffMultiplier
			and Config.Craft.Stations[Config.Cooking.Station] ~= nil
	)

	-- Structures, items, recipes, repair
	check(
		"structures: Phase 3 set present",
		all({
			"Forge",
			"CookingStation",
			"StorageChest",
			"Wall",
			"Door",
			"SpikeTrap",
			"Watchtower",
			"SleepingBag",
			"MapTable",
		}, function(id)
			return ItemCatalog.Structures[id] ~= nil
		end)
	)
	check(
		"structures: item, recipe and station wired",
		all(Structures.List, function(s)
			local item = ItemCatalog.Items[s.itemId]
			return item ~= nil
				and item.structureId == s.id
				and ItemCatalog.Recipes[s.itemId] ~= nil
				and (s.station == nil or Config.Craft.Stations[s.station] ~= nil)
				and s.sizeX > 0
				and s.sizeY > 0
				and s.sizeZ > 0
		end)
	)
	check(
		"structures: chest slots from Config",
		ItemCatalog.Structures.StorageChest.storageSlots == Config.Storage.ChestSlots
	)
	check("structures: sleeping bag is build-exempt", Config.Build.RangeExempt.SleepingBag == true)
	check(
		"items: unique Phase 3 ids",
		uniqueBy(Items.List, function(d)
			return d.id
		end)
	)
	check(
		"recipes: unique Phase 3 ids",
		uniqueBy(Recipes.List, function(r)
			return r.id
		end)
	)
	check(
		"recipes: id equals output and stations configured",
		all(Recipes.List, function(r)
			return r.id == r.output.id
				and r.output.count >= 1
				and r.tier <= Config.Craft.MaxTier
				and (r.station == nil or Config.Craft.Stations[r.station] ~= nil)
				and (r.tier == 0) == (r.station == nil)
		end)
	)
	check(
		"map: item exists and is craftable",
		ItemCatalog.Items[Config.Map.ItemId] ~= nil
			and ItemCatalog.Recipes[Config.Map.ItemId] ~= nil
	)
	check(
		"repair: station configured and repairables have recipes",
		Config.Craft.Stations[Config.Repair.Station] ~= nil
			and Config.Repair.CostFraction > 0
			and Config.Repair.CostFraction <= 1
			and all(Items.List, function(d)
				return not d.repairable
					or (ItemCatalog.Recipes[d.id] ~= nil and d.durability ~= nil)
			end)
	)
	check(
		"weapons: ranged weapons name real ammo",
		all(Items.List, function(d)
			return not d.ranged
				or (d.ammoId ~= nil and ItemCatalog.Items[d.ammoId] ~= nil and (d.damage or 0) > 0)
		end)
	)
	check(
		"lights: radius and burn time",
		all(Items.List, function(d)
			return d.kind ~= "light" or ((d.lightRadius or 0) > 0 and (d.durability or 0) > 0)
		end)
	)
	local nodesOk = true
	for kind, n in Items.Nodes do
		local tool = ItemCatalog.Items[n.toolId]
		nodesOk = nodesOk
			and n.kind == kind
			and ItemCatalog.Items[n.yieldId] ~= nil
			and tool ~= nil
			and tool.toolType == n.toolType
			and (tool.toolTier or 0) >= n.minTier
	end
	check("nodes: Phase 3 nodes harvestable by a real tool", nodesOk)

	-- Map, ping, storage
	local mapCells = (W.GridSize * W.ChunkSize / Config.Map.CellSize) ^ 2
	check("map: payload cap covers every cell", Config.Map.MaxCellsPerPayload >= mapCells)
	check(
		"ping: kinds and caps",
		#Config.Ping.Kinds > 0
			and Config.Ping.MaxActivePerPlayer >= 1
			and Config.Ping.LifetimeSeconds > 0
	)
	check("storage: caps", Config.Storage.ChestSlots >= 1 and Config.Storage.MaxChestsPerRun >= 1)
end
