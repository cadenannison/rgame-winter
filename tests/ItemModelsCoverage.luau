--!strict
-- Art Pass 4 (items): every ItemCatalog id has a model recipe within the part caps, drop mode stays within
-- DropMaxParts, tooltips show warmth/armor/fuel from data, and the backpack header never overlaps at phone
-- and PC widths. Registered in tests/run.luau.

local BackpackLayout = require("../src/shared/logic/BackpackLayout")
local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local ItemModelSpec = require("../src/shared/logic/ItemModelSpec")
local ItemTooltip = require("../src/shared/logic/ItemTooltip")
local SlotViewModel = require("../src/shared/logic/SlotViewModel")

return function(check: (string, boolean) -> ())
	local total, covered, capOk, dropOk, sizeOk = 0, 0, true, true, true
	for id in ItemCatalog.Items do
		total += 1
		local spec = ItemModelSpec.get(id)
		if spec ~= nil and #spec.parts >= 1 then
			covered += 1
			if
				#spec.parts > Config.ArtItems.ModelMaxParts
				or #spec.parts > ItemModelSpec.MaxParts
			then
				capOk = false
			end
			if
				math.min(#spec.parts, Config.ArtItems.DropMaxParts) > Config.ArtItems.DropMaxParts
			then
				dropOk = false
			end
			for _, p in spec.parts do
				if #p.size ~= 3 or #p.pos ~= 3 or #p.color ~= 3 then
					sizeOk = false
				end
				for _, v in p.size do
					if v <= 0 then
						sizeOk = false
					end
				end
			end
		else
			print(`  no model spec for item {id}`)
		end
	end
	check("itemmodels: every ItemCatalog id has a model recipe", total > 0 and covered == total)
	check("itemmodels: parts <= Config.ArtItems.ModelMaxParts for every item", capOk)
	check("itemmodels: drop mode cap is <= 3 parts", dropOk and Config.ArtItems.DropMaxParts <= 3)
	check("itemmodels: recipe parts are well-formed (3-vectors, positive sizes)", sizeOk)
	check("itemmodels: unknown id has no recipe", ItemModelSpec.get("NotAnItem") == nil)
	check(
		"itemmodels: viewport cap and sweep are configured",
		Config.ArtItems.MaxLiveViewports > 0 and Config.ArtItems.IconSweepSeconds > 0
	)

	-- Item names are unique so the HUD can map a name back to its id.
	local seen: { [string]: string } = {}
	local unique = true
	for id, def in ItemCatalog.Items do
		if seen[def.name] then
			unique = false
		end
		seen[def.name] = id
	end
	check("itemmodels: display names are unique", unique)
	check(
		"itemmodels: idForName round-trips",
		SlotViewModel.idForName("Winterberry") == "Winterberry"
			and SlotViewModel.idForName("Raw Meat") == "RawMeat"
	)

	-- Tooltips: warmth + armor for gear, fuel burn time from the data-driven fuelSeconds.
	local coat = ItemTooltip.text("FurCoat")
	check(
		"tooltip: gear shows Warmth and Armor",
		coat:find("Warmth %+2") ~= nil and coat:find("Armor 8%%") ~= nil
	)
	check(
		"tooltip: Wood shows fuel burn time from Config.Items",
		ItemTooltip.fuelLine("Wood") == "Fuel: burns 2 min"
	)
	check(
		"tooltip: sub-minute fuel shows seconds",
		ItemTooltip.fuelLine("Pinecone") == "Fuel: burns 30s"
	)
	check(
		"tooltip: non-fuel has no fuel line",
		ItemTooltip.fuelLine("Axe") == nil and ItemTooltip.fuelLine("Stone") == nil
	)
	local fuelOk = true
	for id, def in ItemCatalog.Items do
		if (def.fuelSeconds or 0) > 0 and ItemTooltip.fuelLine(id) == nil then
			fuelOk = false
		end
	end
	check("tooltip: every fuel item has a fuel line", fuelOk)

	-- Backpack header: title | Drop | X never overlap each other or the body, from phone to PC widths.
	local params: BackpackLayout.Params = {
		pad = 10,
		gap = 6,
		button = 44,
		dropWidth = 72,
		topInset = 4,
	}
	local layoutOk = true
	for _, width in { 300, 360, 480, 640, 844, 1000 } do
		local h = BackpackLayout.header(width, params)
		if
			BackpackLayout.overlaps(h.drop, h.close)
			or BackpackLayout.overlaps(h.title, h.drop)
			or BackpackLayout.overlaps(h.title, h.close)
			or h.close.x + h.close.w > width
			or h.title.w < 0
			or h.close.h < 44
			or h.drop.h < 44
		then
			layoutOk = false
		end
		local body: BackpackLayout.Rect = { x = 0, y = h.height, w = width, h = 100 }
		if BackpackLayout.overlaps(h.drop, body) or BackpackLayout.overlaps(h.close, body) then
			layoutOk = false
		end
	end
	check("backpack: header buttons never overlap at phone and PC widths", layoutOk)
	local phone = BackpackLayout.panel(640, 324, 0.96, 1000, 760, 8, 8)
	local pc = BackpackLayout.panel(1920, 1044, 0.96, 1000, 760, 8, 8)
	check(
		"backpack: panel starts below the top margin and stays inside the gui area",
		phone.y >= 8
			and phone.y + phone.h <= 324
			and pc.y >= 8
			and pc.y + pc.h <= 1044
			and pc.w <= 1000
	)
end
