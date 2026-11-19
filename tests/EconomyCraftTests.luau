--!strict
-- Tests: gather effort per task type, workbench tiers, warmth values, armor, cold hint bands, tooltips.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Inventory = require("../src/shared/logic/Inventory")
local Crafting = require("../src/shared/logic/Crafting")
local ItemsGather = require("../src/shared/logic/ItemsGather")
local WorkbenchTier = require("../src/shared/logic/WorkbenchTier")
local WarmthHint = require("../src/shared/logic/WarmthHint")
local ItemTooltip = require("../src/shared/logic/ItemTooltip")
local ClothingLogic = require("../src/shared/logic/ClothingLogic")

return function(check: (string, boolean) -> ())
	local size = Config.Inventory.HotbarSize + Config.Inventory.BackpackSize
	local function give(inv: Inventory.Inv, id: string, n: number)
		local def = ItemCatalog.Items[id]
		Inventory.add(inv, id, n, def.maxStack, def.durability)
	end

	-- Gather effort
	check(
		"effort: forage is instant, no progress",
		ItemsGather.hitsFor("Stick", 0) == 1 and not ItemsGather.showsProgress("Stick")
	)
	check(
		"effort: every forage kind instant",
		(function(): boolean
			for _, k in Config.Forage.Forage do
				if ItemsGather.hitsFor(k.itemId, 0) ~= 1 or ItemsGather.showsProgress(k.itemId) then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"effort: tree and rock keep HitsToDeplete",
		ItemsGather.baseHits("Tree") == Config.Gather.HitsToDeplete
			and ItemsGather.baseHits("Rock") == Config.Gather.HitsToDeplete
	)
	check(
		"effort: ore hits fall with tool tier",
		ItemsGather.hitsFor("Coal", 1) == 6 and ItemsGather.hitsFor("Coal", 3) == 4
	)
	check(
		"effort: tier clamps",
		ItemsGather.hitsFor("Coal", 9) == 4 and ItemsGather.hitsFor("Coal", 0) == 6
	)
	check(
		"effort: scrap base uses min tool tier",
		ItemsGather.baseHits("ScrapMetal") == (Config.Gather.Effort.Scrap.HitsByTier or { 0, 0 })[2]
	)
	check(
		"effort: better tool removes more per hit",
		ItemsGather.hitDamage("Coal", 3) > ItemsGather.hitDamage("Coal", 1)
			and ItemsGather.hitDamage("Coal", 1) == 1
	)
	check(
		"effort: damage sums to base",
		math.abs(
			ItemsGather.hitDamage("Coal", 3) * ItemsGather.hitsFor("Coal", 3)
				- ItemsGather.baseHits("Coal")
		) < 1e-9
	)
	check(
		"effort: progress fraction",
		ItemsGather.progressOf("Tree", 2) == 0.5 and ItemsGather.progressOf("Stick", 1) == nil
	)
	check(
		"effort: every node kind has an effort entry",
		(function(): boolean
			for kind in ItemCatalog.Nodes do
				if ItemsGather.baseHits(kind) < 1 then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"effort: animal hits from health and weapon",
		ItemsGather.animalHits(30, 10) == 3
			and ItemsGather.animalHits(31, 10) == 4
			and ItemsGather.animalHits(5, 10) == 1
	)
	check(
		"effort: chest is a short hold",
		ItemsGather.chestHoldSeconds() == Config.Gather.Effort.Chest.HoldSeconds
			and ItemsGather.chestHoldSeconds() > 0
	)

	-- Workbench tiers
	check(
		"bench: tiers match MaxTier",
		#Config.Workbench.Tiers == Config.Workbench.MaxTier and #Config.Workbench.Tiers[1].Cost == 0
	)
	check(
		"bench: hand recipes always available",
		WorkbenchTier.recipeAvailable("Axe", 1) and WorkbenchTier.recipeAvailable("Torch", 1)
	)
	check(
		"bench: tier-1 recipe at tier 1",
		WorkbenchTier.recipeAvailable("Spear", 1) and WorkbenchTier.recipeAvailable("Wall", 1)
	)
	check(
		"bench: higher recipes hidden until unlocked",
		not WorkbenchTier.recipeAvailable("Watchtower", 2)
			and WorkbenchTier.recipeAvailable("Watchtower", 3)
			and not WorkbenchTier.recipeAvailable("SpikeTrap", 1)
	)
	check("bench: forge recipes ignore bench tier", ItemCatalog.benchTierOf("IronAxe") == 0)
	check(
		"bench: recipe tiers within max",
		(function(): boolean
			for id in ItemCatalog.Recipes do
				if ItemCatalog.benchTierOf(id) > Config.Workbench.MaxTier then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"bench: visible list filters",
		#WorkbenchTier.visible(Crafting.listForTier(Config.Craft.MaxTier), 1)
			< #WorkbenchTier.visible(Crafting.listForTier(Config.Craft.MaxTier), 3)
	)
	check(
		"bench: no cost at max",
		WorkbenchTier.nextCost(Config.Workbench.MaxTier) == nil
			and WorkbenchTier.status({}, Config.Workbench.MaxTier, true) == "MaxTier"
	)
	check(
		"bench: status near and materials",
		WorkbenchTier.status({}, 1, false) == "NeedStation"
			and WorkbenchTier.status({}, 1, true) == "MissingMaterials"
			and WorkbenchTier.status({ Wood = 99, Stone = 99, Rope = 9 }, 1, true) == "Ok"
	)
	local inv = Inventory.new(size)
	give(inv, "Wood", 25)
	give(inv, "Stone", 5)
	local ok, reason = WorkbenchTier.upgrade(inv, 1, true)
	check(
		"bench: upgrade fails short and leaves inventory",
		not ok
			and reason == "MissingMaterials"
			and Inventory.count(inv, "Wood") == 25
			and Inventory.count(inv, "Stone") == 5
	)
	ok, reason = WorkbenchTier.upgrade(inv, 1, false)
	check(
		"bench: upgrade needs a bench nearby",
		not ok and reason == "NeedStation" and Inventory.count(inv, "Wood") == 25
	)
	give(inv, "Stone", 10)
	local ok2, _, newTier = WorkbenchTier.upgrade(inv, 1, true)
	check(
		"bench: upgrade spends cost and returns next tier",
		ok2
			and newTier == 2
			and Inventory.count(inv, "Wood") == 5
			and Inventory.count(inv, "Stone") == 5
	)
	local ok3, reason3 = WorkbenchTier.upgrade(inv, Config.Workbench.MaxTier, true)
	check("bench: refused at max tier", not ok3 and reason3 == "MaxTier")
	check(
		"bench: bad tier values clamp",
		WorkbenchTier.clamp(nil) == 1
			and WorkbenchTier.clamp(99) == Config.Workbench.MaxTier
			and WorkbenchTier.clamp(0) == 1
	)
	local craftInv = Inventory.new(size)
	give(craftInv, "Wood", 30)
	give(craftInv, "Stone", 10)
	local near: Crafting.Near = { workbench = true }
	local cok, creason = Crafting.craft(craftInv, "SpikeTrap", near, 1)
	check(
		"bench: craft refuses locked recipe",
		not cok and creason == "NeedBenchTier" and Inventory.count(craftInv, "Wood") == 30
	)
	check("bench: craft allowed once unlocked", (Crafting.craft(craftInv, "SpikeTrap", near, 2)))
	check(
		"bench: status reports tier gate",
		Crafting.status({ Wood = 30, Stone = 10 }, "Watchtower", near, 2) == "NeedBenchTier"
	)

	-- Warmth, armor
	check(
		"warmth: every clothing piece has warmth equal to its cold resistance",
		(function(): boolean
			for _, def in ItemCatalog.Items do
				if def.equipSlot ~= nil and def.coldResistance ~= nil then
					if def.warmth == nil or def.warmth <= 0 or def.warmth ~= def.coldResistance then
						return false
					end
				end
				if def.kind == "clothing" and (def.warmth == nil or def.warmth <= 0) then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"warmth: not double counted (worn resistance uses coldResistance only)",
		ClothingLogic.resistance({ HideCoat = 1 }) == 1
	)
	check(
		"armor: values name real items and stay in 0..1",
		(function(): boolean
			for id, v in Config.Armor.Values do
				if ItemCatalog.Items[id] == nil or v <= 0 or v >= 1 then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"armor: every clothing piece has armor",
		(function(): boolean
			for id, def in ItemCatalog.Items do
				if def.kind == "clothing" and ItemCatalog.armorOf(id) <= 0 then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"armor: a full best set stays under the cap",
		ItemCatalog.armorOf("ArcticHood")
				+ ItemCatalog.armorOf("ArcticCoat")
				+ ItemCatalog.armorOf("ArcticBoots")
			<= Config.Armor.MaxReduction
	)
	check(
		"armor: tiers increase",
		ItemCatalog.armorOf("FurCoat") > ItemCatalog.armorOf("HideCoat")
			and ItemCatalog.armorOf("ArcticCoat") > ItemCatalog.armorOf("FurCoat")
	)

	-- Cold hint
	check(
		"hint: bands sorted descending, no numbers",
		(function(): boolean
			local last = math.huge
			for _, band in Config.WarmthHints.Bands do
				if band.MinRatio >= last or string.find(band.Text, "%d") ~= nil then
					return false
				end
				last = band.MinRatio
			end
			return not Config.WarmthHints.ShowNumbers
		end)()
	)
	check(
		"hint: comfortable / chilly / dangerous / deadly",
		WarmthHint.band(6, 6).Id == "comfortable"
			and WarmthHint.band(5, 6).Id == "chilly"
			and WarmthHint.band(3, 6).Id == "dangerous"
			and WarmthHint.band(0, 6).Id == "deadly"
	)
	check(
		"hint: zone needing nothing is comfortable",
		WarmthHint.band(0, 0).Id == "comfortable" and WarmthHint.message(0, 0, "Start") == nil
	)
	check(
		"hint: message names the zone without digits",
		(function(): boolean
			local m = WarmthHint.message(3, 6, "Peaks")
			return m ~= nil and string.find(m, "Peaks") ~= nil and string.find(m, "%d") == nil
		end)()
	)
	check(
		"hint: ClothingLogic.warning uses hints",
		ClothingLogic.warning(3, 6, "Peaks") ~= nil and ClothingLogic.warning(9, 6, "Peaks") == nil
	)

	-- Tooltip
	check(
		"tooltip: warmth line",
		ItemTooltip.warmthLine("FurCoat") == "Warmth +2" and ItemTooltip.warmthLine("Axe") == nil
	)
	check(
		"tooltip: lines include name and warmth",
		ItemTooltip.lines("HideHood")[1] == "Hide Hood"
			and ItemTooltip.text("HideHood"):find("Warmth %+1") ~= nil
	)
end
