--!strict
-- Integrated day-3 solo flow on pure logic (headless mirror of tools/qa scenario day3-solo):
-- starter axe -> gather wood -> pickaxe -> stone -> workbench craft + placement -> spear at bench ->
-- fuel the camp fire and survive 3 days by it -> hunt a hare for meat -> wolf retreats at the fire edge.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Inventory = require("../src/shared/logic/Inventory")
local Crafting = require("../src/shared/logic/Crafting")
local ItemsGather = require("../src/shared/logic/ItemsGather")
local Placement = require("../src/shared/logic/Placement")
local FireLogic = require("../src/shared/logic/FireLogic")
local SurvivalLogic = require("../src/shared/logic/SurvivalLogic")
local DayClock = require("../src/shared/logic/DayClock")
local MobAI = require("../src/shared/logic/MobAI")
local MobRules = require("../src/shared/logic/MobRules")
local Sim = require("./sim")

local FEED_PER_MEAL = 40 -- test-only: no food values exist in Config yet (eat handler pending)
local EAT_BELOW = 50 -- test-only: eat when hunger drops below this
local REFUEL_BELOW = Config.Fire.WoodFuelSeconds -- player tops the fire up when it runs low

type Flow = {
	inv: Inventory.Inv,
	fire: FireLogic.Fire,
	meters: SurvivalLogic.State,
	minWarmth: number,
	fireOutSeconds: number,
	inBounds: boolean,
	downed: boolean,
	meals: number,
}

local function slotOf(inv: Inventory.Inv, id: string): Inventory.Stack?
	for i = 1, inv.size do
		local s = inv.slots[i]
		if s and s.id == id then
			return s
		end
	end
	return nil
end

-- Hits one node until depleted with the given tool; returns the yield added (0 if the tool cannot).
local function harvest(inv: Inventory.Inv, kind: string, toolId: string): number
	local tool = slotOf(inv, toolId)
	if not ItemsGather.canHarvest(kind, tool) then
		return 0
	end
	local node = ItemCatalog.Nodes[kind]
	local def = ItemCatalog.Items[node.yieldId]
	-- HitsToDeplete hits; only the last yields (wear is covered in ItemTests).
	return node.yieldCount
		- Inventory.add(inv, def.id, node.yieldCount, def.maxStack, def.durability)
end

local function give(inv: Inventory.Inv, id: string, n: number)
	local def = ItemCatalog.Items[id]
	Inventory.add(inv, id, n, def.maxStack, def.durability)
end

return function(check: (string, boolean) -> ())
	local size = Config.Inventory.HotbarSize + Config.Inventory.BackpackSize
	local inv = Inventory.new(size)
	for _, s in Config.Inventory.StarterItems do
		give(inv, s.id, s.count)
	end
	check("flow starter axe", Inventory.count(inv, "Axe") == 1)
	check("flow hand cannot chop", not ItemsGather.canHarvest("Tree", nil))

	local wood = 0
	for _ = 1, 6 do
		wood += harvest(inv, "Tree", "Axe")
	end
	check("flow gather wood", wood == 6 * Config.Gather.TreeYield)
	check("flow craft pickaxe (wood only)", (Crafting.craft(inv, "Pickaxe", 0)))
	local stone = 0
	for _ = 1, 2 do
		stone += harvest(inv, "Rock", "Pickaxe")
	end
	check("flow mine stone", stone == 2 * Config.Gather.RockYield)
	check("flow craft workbench", (Crafting.craft(inv, "Workbench", 0)))

	local x = Placement.snap(13.7, Config.Build.GridStep)
	local z = Placement.snap(-6.1, Config.Build.GridStep)
	local placeOk = Placement.check({
		structureId = "Workbench",
		target = { x = x, z = z },
		player = { x = 10, z = -4 },
		placeRange = Config.Build.PlaceRange,
		minSpacing = Config.Build.MinSpacing,
		others = { { x = 0, z = 0 } },
		ownedCount = 0,
		maxOwned = Config.Build.MaxStructuresPerPlayer,
		fireCount = 1,
		maxFires = Config.Fire.MaxPerTeam,
		itemCount = Inventory.count(inv, "Workbench"),
	})
	check(
		"flow place workbench snapped",
		placeOk and x % Config.Build.GridStep == 0 and Inventory.remove(inv, "Workbench", 1)
	)
	give(inv, "Wood", 3)
	give(inv, "Stone", 1)
	check("flow spear needs bench tier", (Crafting.craft(inv, "Spear", 1)))

	-- Three days by the camp fire: refuel from gathered wood, eat hare meat, meters stay sane.
	local flow: Flow = {
		inv = inv,
		fire = FireLogic.new(Config.Fire.BurnSeconds),
		meters = SurvivalLogic.new(Config.Meters),
		minWarmth = Config.Meters.MaxWarmth,
		fireOutSeconds = 0,
		inBounds = true,
		downed = false,
		meals = 0,
	}
	local M = Config.Meters
	local system: Sim.System = {
		name = "day3-solo",
		step = function(sim, clock)
			local f = flow
			if f.fire.fuel < REFUEL_BELOW and Inventory.remove(f.inv, "Wood", 1) then
				FireLogic.addFuel(f.fire, Config.Fire.WoodFuelSeconds, Config.Fire.MaxFuelSeconds)
				sim:record("fuel", clock.time)
			end
			FireLogic.burn(f.fire, clock.dt)
			if not FireLogic.isLit(f.fire) then
				f.fireOutSeconds += clock.dt
			end
			local info = DayClock.at(clock.time, Config.Time)
			local inFire = FireLogic.warms(
				f.fire,
				0,
				0,
				Config.World.CampSpawnOffset,
				0,
				Config.Fire.WarmRadius
			)
			if
				SurvivalLogic.step(
					f.meters,
					{ inFire = inFire, isNight = info.isNight, invincible = false },
					M,
					clock.dt
				)
			then
				f.downed = true
			end
			if f.meters.hunger < EAT_BELOW and Inventory.remove(f.inv, "RawMeat", 1) then
				SurvivalLogic.feed(f.meters, FEED_PER_MEAL, M)
				f.meals += 1
			end
			local m = f.meters
			f.inBounds = f.inBounds
				and m.health >= 0
				and m.health <= M.MaxHealth
				and m.warmth >= 0
				and m.warmth <= M.MaxWarmth
				and m.hunger >= 0
				and m.hunger <= M.MaxHunger
			f.minWarmth = math.min(f.minWarmth, m.warmth)
		end,
		onDay = function(sim, day)
			-- Each morning: chop trees for fuel and spear a hare (one hit kills, drops meat).
			for _ = 1, 3 do
				harvest(flow.inv, "Tree", "Axe")
			end
			local spear = ItemCatalog.Items.Spear
			local hare = Config.Mobs.Hare
			if spear.damage and spear.damage >= hare.Health and hare.DropId then
				give(flow.inv, hare.DropId, hare.DropCount * 2)
			end
			sim:record("day", day)
		end,
	}
	local sim =
		Sim.new({ seed = Config.World.DefaultSeed, dayLength = Config.Time.DayLengthSeconds })
	sim:addSystem(system)
	-- Day 1 hunt happens before the first onDay.
	give(inv, "RawMeat", Config.Mobs.Hare.DropCount * 2)
	local r = sim:runDays(3)
	check("flow 3 days elapsed", r.days == 4)
	check("flow fire never out", flow.fireOutSeconds == 0)
	check("flow meters in bounds", flow.inBounds)
	check("flow survived (never downed)", not flow.downed and flow.meters.health > 0)
	check("flow warm by the fire", flow.minWarmth >= M.MaxWarmth * 0.9)
	check("flow ate hare meat", flow.meals > 0)

	-- Wolf at the fire edge at night retreats; just outside the edge it chases.
	local wolf = Config.Mobs.Wolf
	local edge = Config.Fire.RepelRadius - 1
	local camp = { x = 0, z = 0 }
	local function wolfAction(at: number): MobAI.Action
		local d = MobRules.distance({ x = at, z = 0 }, camp)
		return MobAI.decide({
			behavior = "Hunt",
			nearestPlayerDist = math.abs(at - Config.World.CampSpawnOffset),
			isNight = true,
			nightOnly = wolf.NightOnly,
			fleeRange = wolf.FleeRange,
			aggroRange = wolf.AggroRange,
			attackRange = wolf.AttackRange,
			inFireRepel = d <= Config.Fire.RepelRadius,
			canAttack = true,
		})
	end
	check("flow wolf repelled at fire edge", wolfAction(edge) == "Retreat")
	check("flow wolf chases outside edge", wolfAction(Config.Fire.RepelRadius + 5) == "Chase")

	-- Same seed twice -> same flow checksum.
	local det = Sim.determinism(7, 3, function(s)
		s:addSystem({
			name = "fuel",
			step = function(sm, c)
				local f = FireLogic.new(Config.Fire.BurnSeconds)
				if sm.rng:chance(0.01) then
					FireLogic.addFuel(f, Config.Fire.WoodFuelSeconds, Config.Fire.MaxFuelSeconds)
					sm:record("fuel", c.time + f.fuel)
				end
			end,
		})
	end)
	check("flow deterministic", det)
end
