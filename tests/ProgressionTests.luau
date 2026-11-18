--!strict
-- Brief 17 (structures and progression): clothing gate math, durability and repair, cooking buffs with
-- caps, shared storage capacity and validation, the fog-of-war payload contract, ping and placement caps.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Biomes = require("../src/shared/data/Biomes")
local Clothing = require("../src/shared/data/Clothing")
local Food = require("../src/shared/data/Food")
local Structures = require("../src/shared/data/Structures")
local Buffs = require("../src/shared/logic/Buffs")
local ClothingLogic = require("../src/shared/logic/ClothingLogic")
local Cooking = require("../src/shared/logic/Cooking")
local Inventory = require("../src/shared/logic/Inventory")
local Ping = require("../src/shared/logic/Ping")
local Placement = require("../src/shared/logic/Placement")
local Repair = require("../src/shared/logic/Repair")
local Storage = require("../src/shared/logic/Storage")

return function(check: (string, boolean) -> ())
	-- Clothing gate math: a full set of tier t opens exactly the biome it is meant for.
	local ids: { [string]: boolean } = {}
	for tier, biomeId in Clothing.UnlocksBiome do
		local required = Biomes.ById[biomeId].requiredColdResistance
		check(
			`clothing: tier {tier} set meets {biomeId}`,
			ClothingLogic.setResistance(tier) >= required
		)
		if tier > 1 then
			check(
				`clothing: tier {tier - 1} set is short for {biomeId}`,
				ClothingLogic.setResistance(tier - 1) < required
			)
		end
		ids[biomeId] = true
	end
	check("clothing: starting biome needs none", Biomes.List[1].requiredColdResistance == 0)
	check("clothing: no clothes is zero", ClothingLogic.resistance({}) == 0)
	check(
		"clothing: best piece per slot, not summed across tiers",
		ClothingLogic.resistance({ HideCoat = 1, FurCoat = 1 })
			== ItemCatalog.Items.FurCoat.coldResistance
	)
	local full: { [string]: number } = {}
	for _, pieces in Clothing.Pieces do
		for _, id in pieces do
			full[id] = 1
		end
	end
	check(
		"clothing: total is capped",
		ClothingLogic.resistance(full) <= Config.Clothing.MaxColdResistance
	)
	check(
		"clothing: deficit and warning",
		ClothingLogic.deficit(3, 6) == 3
			and ClothingLogic.deficit(9, 6) == 0
			and ClothingLogic.warning(3, 6, "Peaks") ~= nil
			and ClothingLogic.warning(6, 6, "Peaks") == nil
	)

	-- Durability and repair.
	local axe = ItemCatalog.Items.Pickaxe -- the Axe is unbreakable, so repair rules use the Pickaxe
	local torch = ItemCatalog.Items.Torch
	check(
		"repair: tools repairable, plain lights not",
		Repair.isRepairable(axe) and not Repair.isRepairable(torch)
	)
	check(
		"repair: full durability refused",
		select(2, Repair.check(axe, axe.durability)) == "FullDurability"
	)
	check("repair: damaged tool accepted", (Repair.check(axe, 10)))
	check(
		"repair: missing durability refused",
		select(2, Repair.check(axe, nil)) == "NotRepairable"
	)
	local cost = Repair.cost("Pickaxe") :: { { id: string, count: number } }
	check(
		"repair: cost is a rounded-up fraction of the recipe",
		cost ~= nil
			and cost[1].id == "Wood"
			and cost[1].count == math.ceil(3 * Config.Repair.CostFraction)
	)
	check(
		"repair: cost never below MinCost",
		(Repair.cost("Pickaxe") :: any)[1].count >= Config.Repair.MinCost
	)
	check(
		"repair: no recipe, no cost",
		Repair.cost("Torch") == nil or ItemCatalog.Recipes.Torch ~= nil
	)
	check(
		"repair: affordability",
		Repair.canAfford(cost, { Wood = 5 }) and not Repair.canAfford(cost, { Wood = 0 })
	)
	check(
		"repair: percent",
		Repair.percent(axe, axe.durability :: number) == 100 and Repair.percent(axe, 0) == 0
	)
	local worn = Inventory.new(2)
	Inventory.add(worn, "Axe", 1, 1, 5)
	check(
		"durability: wear breaks and removes at zero",
		Inventory.wear(worn, 1, 5) and worn.slots[1] == nil
	)

	-- Cooking and buffs.
	check("cook: raw meat at a fire", (Cooking.check("RawMeat", true, false)))
	check("cook: no heat refused", select(2, Cooking.check("RawMeat", false, false)) == "NoHeat")
	check("cook: station also works", (Cooking.check("RawFish", false, true)))
	check("cook: not cookable", select(2, Cooking.check("Wood", true, true)) == "NotCookable")
	check(
		"cook: every cooked output is a food with a buff",
		(function(): boolean
			for _, c in Food.Cook do
				local cooked = ItemCatalog.Items[c.cookedId]
				if cooked == nil or cooked.kind ~= "food" or Cooking.buffFor(c.cookedId) == nil then
					return false
				end
			end
			return true
		end)()
	)
	local wellFed = Food.BuffById.WellFed
	check(
		"cook: station buff is longer but capped",
		Cooking.buffDuration(wellFed, true) > Cooking.buffDuration(wellFed, false)
			and Cooking.buffDuration(wellFed, true) <= Config.Buffs.MaxDurationSeconds
			and Cooking.buffDuration(wellFed, true)
				<= wellFed.durationSeconds * Config.Cooking.MaxStationBuffMultiplier
	)
	local list = Buffs.new()
	check("buffs: add", Buffs.add(list, "WellFed", 100, 0) and #list == 1)
	Buffs.add(list, "WellFed", 50, 10)
	check("buffs: same id refreshes, never stacks", #list == 1 and list[1].expires == 100)
	check("buffs: unknown id refused", not Buffs.add(list, "Nope", 10, 0))
	Buffs.add(list, "Warmed", 1e9, 0)
	check("buffs: duration capped", list[2].expires <= Config.Buffs.MaxDurationSeconds)
	Buffs.add(list, "Hearty", 500, 0)
	check(
		"buffs: MaxActive holds, soonest evicted",
		#list <= Config.Buffs.MaxActive and Buffs.ids(list):find("WellFed") == nil
	)
	local mods = Buffs.modifiers(list, 1)
	check(
		"buffs: modifiers within caps",
		mods.warmthDrain >= 1 - Config.Buffs.MaxWarmthDrainReduction
			and mods.hungerDrain >= 1 - Config.Buffs.MaxHungerDrainReduction
			and mods.regenBonus <= Config.Buffs.MaxHealthRegenBonus
			and mods.speed <= 1 + Config.Buffs.MaxSpeedBonus
	)
	check("buffs: prune expires", Buffs.prune(list, 1e9) and #list == 0)
	check(
		"buffs: no buffs is neutral",
		Buffs.modifiers({}, 0).warmthDrain == 1 and Buffs.modifiers({}, 0).speed == 1
	)
	local stacked = Buffs.new()
	for _, def in Food.Buffs do
		Buffs.add(stacked, def.id, def.durationSeconds, 0)
	end
	local sm = Buffs.modifiers(stacked, 0)
	check(
		"buffs: stacked list is clamped",
		sm.regenBonus <= Config.Buffs.MaxHealthRegenBonus
			and sm.speed <= 1 + Config.Buffs.MaxSpeedBonus
	)
	check("buffs: raw fish is a debuff", Food.BuffById[Food.EatBuffs.RawFish].debuff)

	-- Shared storage capacity and validation.
	local chest = Inventory.new(Config.Storage.ChestSlots)
	local player = Inventory.new(Config.Inventory.HotbarSize + Config.Inventory.BackpackSize)
	Inventory.add(player, "Wood", 30, ItemCatalog.Items.Wood.maxStack)
	Inventory.add(player, "Axe", 1, 1, 40)
	check("storage: chest has the configured slots", chest.size == Config.Storage.ChestSlots)
	check(
		"storage: deposit moves items",
		Storage.deposit(chest, player, 1, 10)
			and Inventory.count(chest, "Wood") == 10
			and Inventory.count(player, "Wood") == 20
	)
	check(
		"storage: durability travels with the item",
		Storage.deposit(chest, player, 2, 1)
			and chest.slots[2] ~= nil
			and (chest.slots[2] :: any).durability == 40
	)
	check(
		"storage: more than the stack refused",
		select(2, Storage.deposit(chest, player, 1, 999)) == "BadCount"
	)
	check(
		"storage: empty slot refused",
		select(2, Storage.deposit(chest, player, 9, 1)) == "EmptySlot"
	)
	check(
		"storage: bad slot refused",
		select(2, Storage.deposit(chest, player, 0, 1)) == "BadArgs"
			and select(2, Storage.deposit(chest, player, 9999, 1)) == "BadSlot"
	)
	check(
		"storage: fractional and NaN refused",
		select(2, Storage.deposit(chest, player, 1.5, 1)) == "BadArgs"
			and select(2, Storage.deposit(chest, player, 1, 0 / 0)) == "BadArgs"
	)
	check(
		"storage: withdraw returns items",
		Storage.withdraw(chest, player, 1, 10) and Inventory.count(chest, "Wood") == 0
	)
	check(
		"storage: withdraw empty slot refused",
		select(2, Storage.withdraw(chest, player, 5, 1)) == "EmptySlot"
	)
	local small = Inventory.new(1)
	Inventory.add(small, "Stone", 1, ItemCatalog.Items.Stone.maxStack)
	local before = Inventory.count(player, "Wood")
	check(
		"storage: full chest refuses atomically",
		select(2, Storage.deposit(small, player, 1, 5)) == "ChestFull"
			and Inventory.count(player, "Wood") == before
	)
	local tiny = Inventory.new(1)
	Inventory.add(tiny, "Stone", 1, ItemCatalog.Items.Stone.maxStack)
	local chest2 = Inventory.new(2)
	Inventory.add(chest2, "Wood", 5, ItemCatalog.Items.Wood.maxStack)
	check(
		"storage: full inventory refuses withdraw",
		select(2, Storage.withdraw(chest2, tiny, 1, 5)) == "InventoryFull"
			and Inventory.count(chest2, "Wood") == 5
	)
	check(
		"storage: unknown item ids refused",
		(function(): boolean
			local c = Inventory.new(2)
			local p = Inventory.new(2)
			p.slots[1] = { id = "Bogus", count = 1 }
			return select(2, Storage.deposit(c, p, 1, 1)) == "UnknownItem"
		end)()
	)
	check("storage: placement caps chests per run", select(
		2,
		Placement.check({
			structureId = "StorageChest",
			target = { x = 4, z = 0 },
			player = { x = 0, z = 0 },
			placeRange = Config.Build.PlaceRange,
			minSpacing = Config.Build.MinSpacing,
			others = {},
			ownedCount = 0,
			maxOwned = Config.Build.MaxStructuresPerPlayer,
			fireCount = 0,
			maxFires = Config.Fire.MaxPerTeam,
			itemCount = 1,
			litFires = {},
			buildExempt = true,
			roleCount = Config.Storage.MaxChestsPerRun,
			roleMax = Config.Storage.MaxChestsPerRun,
		})
	) == "RoleCap")

	-- Structures: traps hurt mobs only; every new placeable is validated by the shared Placement rules.
	for _, def in Structures.List do
		check(`structure: {def.id} validates through Placement`, select(
			2,
			Placement.check({
				structureId = def.id,
				target = { x = 4, z = 0 },
				player = { x = 0, z = 0 },
				placeRange = Config.Build.PlaceRange,
				minSpacing = Config.Build.MinSpacing,
				others = {},
				ownedCount = 0,
				maxOwned = Config.Build.MaxStructuresPerPlayer,
				fireCount = 0,
				maxFires = Config.Fire.MaxPerTeam,
				itemCount = 1,
				litFires = { { x = 0, z = 0, buildRadius = Config.Fire.Tiers[1].BuildRadius } },
				buildExempt = false,
			})
		) == "Ok")
	end
	local trap = ItemCatalog.Structures.SpikeTrap
	check(
		"structure: trap damage is for mobs and cooldown set",
		trap.trapDamage ~= nil and trap.trapDamage > 0 and (trap.trapCooldown or 0) > 0
	)
	check(
		"structure: door opens for the party, walls block",
		ItemCatalog.Structures.Door.opensForParty == true
			and ItemCatalog.Structures.Wall.blocksPath == true
	)
	check(
		"structure: watchtower extends the explore radius",
		(ItemCatalog.Structures.Watchtower.viewBonus or 0) > 0
	)

	-- Fog of war: the explored cell set a reveal produces fits the payload contract (MapService owns the set;
	-- the server sends explored cells only, never the unexplored layout).
	local cellsPerSide =
		math.ceil(Config.World.GridSize * Config.World.ChunkSize / Config.Map.CellSize)
	local function reveal(x: number, z: number, radius: number): { [number]: boolean }
		local set: { [number]: boolean } = {}
		local c = Config.Map.CellSize
		for cz = 0, cellsPerSide - 1 do
			for cx = 0, cellsPerSide - 1 do
				local px, pz = (cx + 0.5) * c, (cz + 0.5) * c
				if (px - x) ^ 2 + (pz - z) ^ 2 <= radius ^ 2 then
					set[cz * cellsPerSide + cx + 1] = true
				end
			end
		end
		return set
	end
	local function size(set: { [number]: boolean }): number
		local n = 0
		for _ in set do
			n += 1
		end
		return n
	end
	local center = Config.World.GridSize * Config.World.ChunkSize / 2
	local plain = reveal(center, center, Config.Map.ExploreRadius)
	local tower = reveal(
		center,
		center,
		Config.Map.ExploreRadius + (ItemCatalog.Structures.Watchtower.viewBonus or 0)
	)
	check(
		"fog: a reveal marks only nearby cells",
		size(plain) > 0 and size(plain) < cellsPerSide * cellsPerSide
	)
	check(
		"fog: a watchtower reveals more, not everything",
		size(tower) > size(plain) and size(tower) < cellsPerSide * cellsPerSide
	)
	check(
		"fog: indices stay inside the grid",
		(function(): boolean
			for i in tower do
				if i < 1 or i > cellsPerSide * cellsPerSide then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"fog: payload cap covers the grid",
		cellsPerSide * cellsPerSide <= Config.Map.MaxCellsPerPayload
	)

	-- Ping.
	local origin = { x = 0, y = 0, z = 0 }
	check("ping: valid kind and range", (Ping.check("Go", { x = 10, y = 0, z = 10 }, origin)))
	check("ping: bad kind", select(2, Ping.check("Boom", origin, origin)) == "BadKind")
	check("ping: non-string kind", select(2, Ping.check(5, origin, origin)) == "BadKind")
	check(
		"ping: too far",
		select(2, Ping.check("Go", { x = Config.Ping.MaxRange + 1, y = 0, z = 0 }, origin))
			== "TooFar"
	)
	check(
		"ping: NaN position",
		select(2, Ping.check("Go", { x = 0 / 0, y = 0, z = 0 }, origin)) == "BadPosition"
	)
	local live: { number } = {}
	for _ = 1, Config.Ping.MaxActivePerPlayer do
		table.insert(live, 100)
	end
	check(
		"ping: active cap, expired pings free a slot",
		not Ping.canAdd(live, 50) and Ping.canAdd(live, 100)
	)
end
