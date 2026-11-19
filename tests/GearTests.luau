--!strict
-- Worn gear plan (pure): per-slot part budget, tier looks, loadout cap, every catalog gear item covered.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local GearPlan = require("../src/shared/logic/GearPlan")

return function(check: (string, boolean) -> ())
	local total = 0
	local slotsOk = true
	for _, slot in Config.Equipment.Slots do
		local n = GearPlan.slotBudget(slot)
		total += n
		if n < 1 or Config.ArtGear.Rig[slot] == nil then
			slotsOk = false
		end
	end
	check("gear: every slot has a rig row and at least one part", slotsOk)
	check("gear: full loadout fits the per-player cap", total <= Config.ArtGear.MaxPartsPerPlayer)

	local fullLoadout: { [string]: string } = {}
	for _, slot in Config.Equipment.Slots do
		fullLoadout[slot] = "ArcticCoat"
	end
	check(
		"gear: loadout plan never exceeds the cap",
		#GearPlan.loadout(fullLoadout) <= Config.ArtGear.MaxPartsPerPlayer
	)

	check(
		"gear: tiers resolve by prefix",
		GearPlan.tierOf("HideHood") == "Hide"
			and GearPlan.tierOf("FurBoots") == "Fur"
			and GearPlan.tierOf("ArcticCoat") == "Arctic"
			and GearPlan.tierOf("InsulatedCoat") == "Insulated"
			and GearPlan.tierOf("Mystery") == Config.ArtGear.DefaultTier
	)

	local covered, distinct = true, true
	for id, def in ItemCatalog.Items do
		if def.equipSlot then
			local plans = GearPlan.parts(id, def.equipSlot)
			if #plans == 0 then
				covered = false
			end
		end
	end
	check("gear: every catalog equip item has parts", covered)
	local hide = GearPlan.parts("HideCoat", "Body")[1]
	local arctic = GearPlan.parts("ArcticCoat", "Body")[1]
	distinct = hide.color[1] ~= arctic.color[1] or hide.color[3] ~= arctic.color[3]
	check("gear: tiers differ by colour and bulk", distinct and arctic.scaleXZ > hide.scaleXZ)

	local sizeOk = true
	for _, slot in Config.Equipment.Slots do
		for _, plan in GearPlan.parts("FurHood", slot) do
			local x, y, z = GearPlan.size(plan, 1, 1, 1)
			if x <= 0 or y <= 0 or z <= 0 then
				sizeOk = false
			end
		end
	end
	check("gear: part sizes positive", sizeOk)

	local noMotor = true
	for _, specs in Config.ArtGear.Parts do
		for _, spec in specs do
			if spec.tone ~= "main" and spec.tone ~= "trim" then
				noMotor = false
			end
		end
	end
	check("gear: part tones valid", noMotor)
end
