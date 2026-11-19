--!strict
-- Backpack slot view-model: every occupied slot in every area (hotbar, grid, equipment, chest) yields a
-- non-empty name, a count when stack > 1 and a highlight state; string-keyed (remote-serialised) payloads decode.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local SlotViewModel = require("../src/shared/logic/SlotViewModel")

local function hl(
	held: boolean,
	receive: boolean,
	hover: boolean,
	rarity: string
): SlotViewModel.Highlight
	return SlotViewModel.highlight({
		isHeld = held,
		canReceive = receive,
		isHover = hover,
		isFocus = false,
		isSelectedHotbar = false,
		rarity = rarity,
	})
end

return function(check: (string, boolean) -> ())
	local hot = Config.Inventory.HotbarSize
	local total = hot + Config.Inventory.BackpackSize
	local ids: { string } = {}
	for id in ItemCatalog.Items do
		table.insert(ids, id)
	end
	table.sort(ids)

	local areas: { [string]: { [number]: SlotViewModel.Stack } } =
		{ hotbar = {}, grid = {}, equip = {}, chest = {} }
	for slot = 1, total do
		local stack = { id = ids[(slot - 1) % #ids + 1], count = if slot % 2 == 0 then 3 else 1 }
		if slot <= hot then
			areas.hotbar[slot] = stack
		else
			areas.grid[slot] = stack
		end
	end
	for slot = 1, #Config.Equipment.Slots do
		areas.equip[slot] = { id = ids[slot], count = 1 }
	end
	for slot = 1, Config.Storage.ChestSlots do
		areas.chest[slot] = { id = ids[slot], count = 5 }
	end

	local namesOk, countOk, hlOk = true, true, true
	for _, stacks in areas do
		for _, stack in stacks do
			local v = SlotViewModel.view(stack)
			namesOk = namesOk and v.occupied and v.name ~= ""
			if stack.count > 1 then
				countOk = countOk and v.countText == `x{stack.count}`
			end
			hlOk = hlOk and hl(false, false, false, v.rarity) ~= nil
		end
	end
	check("slotview: every occupied slot in every area has a name", namesOk)
	check("slotview: stacks > 1 show a count", countOk)
	check("slotview: highlight state resolves", hlOk)
	local empty = SlotViewModel.view(nil)
	check("slotview: empty slot is blank", empty.name == "" and not empty.occupied)
	check(
		"slotview: highlight priority",
		hl(true, true, false, "rare") == "held"
			and hl(false, true, true, "common") == "hover"
			and hl(false, false, false, "common") == "none"
	)

	-- Sparse hotbar + grid slots as serialised over a remote (string keys / entries carrying slot).
	local decoded = SlotViewModel.decodeSlots({
		["2"] = { id = ids[1], count = 2 },
		["20"] = { id = ids[2], count = 1 },
		[30] = { id = ids[3], count = 4 },
		[11] = { slot = 11, id = ids[4], count = 1 },
	})
	check(
		"slotview: decode keeps string-keyed and sparse grid slots",
		decoded[2] ~= nil and decoded[20] ~= nil and decoded[30] ~= nil and decoded[11] ~= nil
	)
	check(
		"slotview: decode drops junk",
		next(SlotViewModel.decodeSlots({ [0] = { id = "x" }, [3] = { id = "" }, a = 5 })) == nil
	)
	check("slotview: decode of non-table is empty", next(SlotViewModel.decodeSlots(nil)) == nil)
end
