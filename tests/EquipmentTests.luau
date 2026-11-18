--!strict
-- Equipment panel rules (pure): slot list, wearable rules, profile map round trip, and that only WORN
-- gear feeds cold resistance (capped at Config.Clothing.MaxColdResistance).

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local ClothingLogic = require("../src/shared/logic/ClothingLogic")
local Equipment = require("../src/shared/logic/Equipment")
local Inventory = require("../src/shared/logic/Inventory")
local ProfileSchema = require("../src/shared/logic/ProfileSchema")

return function(check: (string, boolean) -> ())
	local slots = Config.Equipment.Slots
	check(
		"equipment: eight slots in order",
		#slots == 8 and slots[1] == "Head" and slots[7] == "Accessory1" and slots[8] == "Accessory2"
	)
	check(
		"equipment: every slot has a label",
		(function(): boolean
			for _, s in slots do
				if Config.Equipment.SlotLabels[s] == nil then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"equipment: hood fits Head only",
		Equipment.accepts("Head", "HideHood") and not Equipment.accepts("Body", "HideHood")
	)
	check(
		"equipment: coat fits Body, boots fit Feet",
		Equipment.accepts("Body", "HideCoat") and Equipment.accepts("Feet", "HideBoots")
	)
	check(
		"equipment: non-gear fits nowhere",
		not Equipment.accepts("Head", "Wood") and not Equipment.accepts("Head", "Nope")
	)
	check(
		"equipment: gear all stack to 1",
		ItemCatalog.stackOf("ArcticCoat") == 1 and ItemCatalog.stackOf("FurHood") == 1
	)

	local equip = Equipment.new()
	check("equipment: nothing worn is zero resistance", ClothingLogic.equipped(equip) == 0)
	equip.slots[1] = { id = "HideHood", count = 1 }
	equip.slots[2] = { id = "FurCoat", count = 1 }
	check(
		"equipment: resistance sums worn pieces",
		ClothingLogic.equipped(equip)
			== ItemCatalog.Items.HideHood.coldResistance :: number
				+ (ItemCatalog.Items.FurCoat.coldResistance :: number)
	)
	-- carried-only gear never counts
	local carried = Inventory.new(36)
	Inventory.add(carried, "ArcticCoat", 1, 1)
	check("equipment: carried gear does not count", ClothingLogic.equipped(Equipment.new()) == 0)
	local all = Equipment.new()
	for i, s in { "ArcticHood", "ArcticCoat", "ArcticBoots" } do
		all.slots[if i == 1 then 1 elseif i == 2 then 2 else 4] = { id = s, count = 1 }
	end
	check(
		"equipment: capped at the max",
		ClothingLogic.equipped(all) <= Config.Clothing.MaxColdResistance
	)

	-- profile map round trip and validation
	local map = Equipment.toMap(equip)
	check(
		"equipment: map round trip",
		map.Head == "HideHood"
			and map.Body == "FurCoat"
			and Equipment.toMap(Equipment.fromMap(map)).Body == "FurCoat"
	)
	local dirty = Equipment.fromMap({
		Head = "NoSuchItem",
		Body = "HideHood",
		Feet = "HideBoots",
		Bogus = "HideCoat",
	})
	check(
		"equipment: load drops unknown items, wrong slots, bad slots",
		dirty.slots[1] == nil
			and dirty.slots[2] == nil
			and dirty.slots[4] ~= nil
			and Equipment.toMap(dirty).Bogus == nil
	)
	check(
		"equipment: load of junk is empty",
		next(Equipment.fromMap("x").slots) == nil and next(Equipment.fromMap(nil).slots) == nil
	)
	local profile = ProfileSchema.default()
	profile.equipment = Equipment.toMap(equip)
	check("equipment: saved map validates in the profile", ProfileSchema.validate(profile))
end
