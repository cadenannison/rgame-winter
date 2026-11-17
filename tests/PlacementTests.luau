--!strict
-- Tests for structure placement rules and the integration-era Config/catalog rows.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Placement = require("../src/shared/logic/Placement")

return function(check: (string, boolean) -> ())
	check("snap rounds to grid", Placement.snap(5.9, 4) == 4 and Placement.snap(6.1, 4) == 8)
	check("snap negative", Placement.snap(-5.9, 4) == -4)
	check("snap rotation wraps", Placement.snapRotation(-80, 90) == 270)

	local function base(): Placement.Check
		return {
			structureId = "Campfire",
			target = { x = 8, z = 0 },
			player = { x = 0, z = 0 },
			placeRange = Config.Build.PlaceRange,
			minSpacing = Config.Build.MinSpacing,
			others = {},
			ownedCount = 0,
			maxOwned = Config.Build.MaxStructuresPerPlayer,
			fireCount = 0,
			maxFires = Config.Fire.MaxPerTeam,
			itemCount = 1,
		}
	end
	check("place ok", (Placement.check(base())))
	local c = base()
	c.structureId = "Castle"
	check("place unknown structure", select(2, Placement.check(c)) == "UnknownStructure")
	c = base()
	c.target = { x = 0 / 0, z = 0 }
	check("place nan rejected", select(2, Placement.check(c)) == "BadPosition")
	c = base()
	c.target = { x = Config.Build.PlaceRange + 1, z = 0 }
	check("place out of range", select(2, Placement.check(c)) == "OutOfRange")
	c = base()
	c.others = { { x = 8, z = 1 } }
	check("place too close", select(2, Placement.check(c)) == "TooClose")
	c = base()
	c.fireCount = Config.Fire.MaxPerTeam
	check("place fire cap", select(2, Placement.check(c)) == "FireCap")
	c.structureId = "Workbench"
	check("fire cap ignores workbench", (Placement.check(c)))
	c = base()
	c.ownedCount = Config.Build.MaxStructuresPerPlayer
	check("place structure cap", select(2, Placement.check(c)) == "StructureCap")
	c = base()
	c.itemCount = 0
	check("place needs item", select(2, Placement.check(c)) == "MissingItem")

	-- Catalog wiring: every structure has a placeable item and recipe; mob drops are real items.
	local rowsOk = true
	for id, def in ItemCatalog.Structures do
		local item = ItemCatalog.Items[def.itemId]
		rowsOk = rowsOk
			and item ~= nil
			and item.structureId == id
			and ItemCatalog.Recipes[def.itemId] ~= nil
	end
	check("structures have items and recipes", rowsOk)
	local dropsOk = true
	for _, stats in { Config.Mobs.Hare, Config.Mobs.Caribou, Config.Mobs.Wolf } do
		dropsOk = dropsOk and stats.DropId ~= nil and ItemCatalog.Items[stats.DropId] ~= nil
	end
	check("mob drops are items", dropsOk)
	check(
		"hare/caribou meat, wolf hide",
		Config.Mobs.Hare.DropId == "RawMeat"
			and Config.Mobs.Caribou.DropId == "RawMeat"
			and Config.Mobs.Wolf.DropId == "Hide"
	)
	check("spear damage from config", ItemCatalog.Items.Spear.damage == Config.Combat.SpearDamage)
	local starterOk = true
	for _, s in Config.Inventory.StarterItems do
		starterOk = starterOk and ItemCatalog.Items[s.id] ~= nil
	end
	check("starter items exist", starterOk)
end
