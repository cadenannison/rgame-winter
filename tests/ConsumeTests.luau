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
	check("pick eat", ActionPick.choose(ctx) == "eat")
	ctx.selectedKind = "placeable"
	check("pick place", ActionPick.choose(ctx) == "place")
	ctx.targetKind = "gather"
	check("pick gather beats place", ActionPick.choose(ctx) == "gather")
	ctx.fireInRange, ctx.hasWood = true, true
	check("pick fuel first", ActionPick.choose(ctx) == "fuel")
	ctx.hasWood = false
	check("no fuel without wood", ActionPick.choose(ctx) == "gather")
end
