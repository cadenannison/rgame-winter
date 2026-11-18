--!strict
-- Tests for inventory, crafting and gather rules.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Inventory = require("../src/shared/logic/Inventory")
local Crafting = require("../src/shared/logic/Crafting")
local ItemsGather = require("../src/shared/logic/ItemsGather")
local Repair = require("../src/shared/logic/Repair")

return function(check: (string, boolean) -> ())
	local size = Config.Inventory.HotbarSize + Config.Inventory.BackpackSize
	local function fresh(): Inventory.Inv
		return Inventory.new(size)
	end

	local function cnt(i: Inventory.Inv, n: number): number
		local s = i.slots[n]
		return if s then s.count else -1
	end
	local function dur(i: Inventory.Inv, n: number): number
		local s = i.slots[n]
		return if s and s.durability then s.durability else -1
	end

	-- Inventory
	local inv = fresh()
	check(
		"inv add stacks",
		Inventory.add(inv, "Wood", 60, 50) == 0 and Inventory.count(inv, "Wood") == 60
	)
	check("inv split stacks", cnt(inv, 1) == 50 and cnt(inv, 2) == 10)
	check("inv remove ok", Inventory.remove(inv, "Wood", 55) and Inventory.count(inv, "Wood") == 5)
	check(
		"inv remove short unchanged",
		not Inventory.remove(inv, "Wood", 6) and Inventory.count(inv, "Wood") == 5
	)
	local tiny = Inventory.new(1)
	check("inv overflow leftover", Inventory.add(tiny, "Wood", 60, 50) == 10)
	local tools = fresh()
	Inventory.add(tools, "Axe", 1, 1, 5)
	Inventory.add(tools, "Axe", 1, 1, 5)
	check("tools never merge", tools.slots[1] ~= nil and tools.slots[2] ~= nil)
	check("wear reduces", not Inventory.wear(tools, 1, 2) and dur(tools, 1) == 3)
	check("wear breaks", Inventory.wear(tools, 1, 3) and tools.slots[1] == nil)

	-- Crafting without enough materials
	local empty = fresh()
	local ok, reason = Crafting.craft(empty, "Axe", {})
	check("craft no materials fails", not ok and reason == "MissingMaterials")
	local partial = fresh()
	Inventory.add(partial, "Wood", 2, 50)
	ok, reason = Crafting.craft(partial, "Axe", {})
	check("craft short materials fails", not ok and reason == "MissingMaterials")
	check(
		"craft failure leaves inventory",
		Inventory.count(partial, "Wood") == 2 and Inventory.count(partial, "Axe") == 0
	)
	ok, reason = Crafting.craft(partial, "Nope", {})
	check("craft unknown recipe", not ok and reason == "UnknownRecipe")

	-- Success and tiers
	local rich = fresh()
	Inventory.add(rich, "Wood", 10, 50)
	Inventory.add(rich, "Stone", 4, 50)
	ok = Crafting.craft(rich, "Axe", {})
	check(
		"craft axe",
		ok and Inventory.count(rich, "Axe") == 1 and Inventory.count(rich, "Wood") == 7
	)
	ok, reason = Crafting.craft(rich, "Spear", {})
	check(
		"tier1 recipe needs workbench",
		not ok and reason == "NeedStation" and Inventory.count(rich, "Spear") == 0
	)
	ok = Crafting.craft(rich, "Spear", { workbench = true })
	check(
		"craft spear at workbench",
		ok and Inventory.count(rich, "Spear") == 1 and Inventory.count(rich, "Stone") == 3
	)
	local axeStack = nil
	local axeSlot = 0
	for i = 1, size do
		local s = rich.slots[i]
		if s and s.id == "Axe" then
			axeStack = s
			axeSlot = i
		end
	end
	check(
		"crafted tool has durability",
		axeStack ~= nil and dur(rich, axeSlot) == ItemCatalog.Items.Axe.durability
	)

	-- Full inventory refuses craft and keeps materials
	local full = Inventory.new(1)
	Inventory.add(full, "Wood", 50, 50)
	ok, reason = Crafting.craft(full, "Axe", {})
	check(
		"craft inventory full",
		not ok and reason == "InventoryFull" and Inventory.count(full, "Wood") == 50
	)

	-- Gather gating
	check("hand cannot harvest", select(2, ItemsGather.canHarvest("Tree", nil)) == "NoTool")
	check(
		"axe harvests tree",
		(ItemsGather.canHarvest("Tree", { id = "Axe", count = 1, durability = 5 }))
	)
	check(
		"axe cannot mine",
		select(2, ItemsGather.canHarvest("Rock", { id = "Axe", count = 1 })) == "WrongTool"
	)
	check("pickaxe mines", (ItemsGather.canHarvest("Rock", { id = "Pickaxe", count = 1 })))
	check("unknown node", select(2, ItemsGather.canHarvest("Ice", nil)) == "UnknownNode")
	check(
		"recipes reference real items",
		(function(): boolean
			for _, r in ItemCatalog.Recipes do
				if ItemCatalog.Items[r.output.id] == nil then
					return false
				end
				for _, i in r.inputs do
					if ItemCatalog.Items[i.id] == nil then
						return false
					end
				end
			end
			return true
		end)()
	)

	-- Unbreakable tools (Config.Durability.UnbreakableItems): the starting Axe never needs repair.
	local axeDef = ItemCatalog.Items.Axe
	local pickDef = ItemCatalog.Items.Pickaxe
	check(
		"unbreakable: axe flagged, pickaxe not",
		ItemCatalog.isUnbreakable("Axe") and not ItemCatalog.isUnbreakable("Pickaxe")
	)
	check("unbreakable: axe not repairable", not Repair.isRepairable(axeDef))
	check(
		"unbreakable: axe repair refused",
		select(2, Repair.check(axeDef, axeDef.durability :: number)) == "Unbreakable"
	)
	check("unbreakable: axe shows no durability label", Repair.durabilityLabel(axeDef, 1) == nil)
	check("unbreakable: pickaxe still repairable", Repair.isRepairable(pickDef))
	check(
		"unbreakable: pickaxe label is a percent",
		Repair.durabilityLabel(pickDef, (pickDef.durability :: number) / 2) == "50%"
	)
	check(
		"unbreakable: plain resource has no label",
		Repair.durabilityLabel(ItemCatalog.Items.Wood, nil) == nil
	)
end
