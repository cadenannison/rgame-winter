--!strict
-- Tests for eating rules, food catalog data and the HUD context-action choice.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Consume = require("../src/shared/logic/Consume")
local ActionPick = require("../src/shared/logic/ActionPick")

return function(check: (string, boolean) -> ())
	local meat = ItemCatalog.Items.RawMeat
	local max = Config.Meters.MaxHunger
	check(
		"raw meat is food with data value",
		meat.kind == "food" and meat.hunger == Config.Food.RawMeatHunger
	)
	local ok, gain = Consume.eat(meat, { hunger = 10, dead = false, downed = false }, max)
	check("eat restores hunger value", ok and gain == Config.Food.RawMeatHunger)
	ok, gain = Consume.eat(meat, { hunger = max - 5, dead = false, downed = false }, max)
	check("eat clamps to cap", ok and gain == 5)
	check(
		"eat refused when full",
		select(2, Consume.eat(meat, { hunger = max, dead = false, downed = false }, max)) == "Full"
	)
	check(
		"eat refused non-food",
		select(
			2,
			Consume.eat(ItemCatalog.Items.Wood, { hunger = 0, dead = false, downed = false }, max)
		) == "NotFood"
	)
	check(
		"eat refused downed",
		select(2, Consume.eat(meat, { hunger = 0, dead = false, downed = true }, max)) == "Downed"
	)
	check(
		"eat refused dead",
		select(2, Consume.eat(meat, { hunger = 0, dead = true, downed = false }, max)) == "Dead"
	)

	local ctx: ActionPick.Context =
		{ fireInRange = false, hasWood = false, targetKind = "none", selectedKind = nil }
	check("pick none", ActionPick.choose(ctx) == "none")
	ctx.selectedKind = "food"
	ctx.targetKind = "gather"
	check("pick eat beats target", ActionPick.choose(ctx) == "eat")
	ctx.selectedKind = "placeable"
	check("pick place beats target", ActionPick.choose(ctx) == "place")
	ctx.selectedKind, ctx.selectedId = "tool", "Axe"
	check("pick gather with tool", ActionPick.choose(ctx) == "gather")
	ctx.fireInRange, ctx.hasWood = true, true
	check("target beats fuel when holding a tool", ActionPick.choose(ctx) == "gather")
	ctx.selectedKind, ctx.selectedId = "resource", "Wood"
	check("wood in hand fuels", ActionPick.choose(ctx) == "fuel")
	ctx.selectedKind, ctx.selectedId, ctx.targetKind = nil, nil, "none"
	check("fuel when nothing targeted", ActionPick.choose(ctx) == "fuel")
	ctx.hasWood = false
	check("no fuel without wood", ActionPick.choose(ctx) == "none")
end
