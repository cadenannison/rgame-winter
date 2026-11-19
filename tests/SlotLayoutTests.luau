--!strict
-- SlotLayout + end-to-end slot mapping. Every case goes client intent -> InventoryMove.parseRequest/perform
-- (the server path) -> SlotLayout.snapshot (the wire) -> SlotViewModel.decodeSlots + SlotLayout.gridCellToSlot
-- (the panel's draw path), so a hotbar->grid drag cannot land in a slot no area draws.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Equipment = require("../src/shared/logic/Equipment")
local Inventory = require("../src/shared/logic/Inventory")
local InventoryMove = require("../src/shared/logic/InventoryMove")
local SlotLayout = require("../src/shared/logic/SlotLayout")
local SlotViewModel = require("../src/shared/logic/SlotViewModel")

type Ctx = InventoryMove.Ctx

local function newCtx(): Ctx
	return { inv = Inventory.new(SlotLayout.InvSize), equip = Equipment.new() }
end

-- What the client sends for a drag (HudHotbarDrag / BackpackPanel build the same table).
local function drag(ctx: Ctx, from: InventoryMove.Addr, to: InventoryMove.Addr): (boolean, string)
	local stack: Inventory.Stack?
	if from.kind == "inv" then
		stack = ctx.inv.slots[from.slot :: number]
	elseif from.kind == "chest" and ctx.chest then
		stack = ctx.chest.slots[from.slot :: number]
	end
	local payload = { from = from, to = to, count = if stack then stack.count else 1 }
	local req = InventoryMove.parseRequest(payload)
	if req == nil then
		return false, "ParseRejected"
	end
	local ok, reason = InventoryMove.perform(ctx, req, 0)
	return ok, reason
end

-- Wire round trip: dense snapshot, optionally re-keyed as a remote might (string keys, array order).
local function decoded(inv: Inventory.Inv, asStrings: boolean): { [number]: SlotViewModel.Stack }
	local entries = SlotLayout.snapshot(inv)
	if asStrings then
		local keyed: { [string]: any } = {}
		for _, e in entries do
			keyed[tostring(e.slot)] = { id = e.id, count = e.count, durability = e.durability }
		end
		return SlotViewModel.decodeSlots(keyed)
	end
	return SlotViewModel.decodeSlots(entries)
end

local function shows(
	stacks: { [number]: SlotViewModel.Stack },
	slot: number,
	name: string,
	countText: string
): boolean
	local v = SlotViewModel.view(stacks[slot])
	return v.occupied and v.name == name and v.countText == countText
end

return function(check: (string, boolean) -> ())
	local hot, cells = Config.Inventory.HotbarSize, Config.Inventory.BackpackSize
	local woodName = SlotViewModel.name({ id = "Wood", count = 1 })

	-- Layout constants and conversions
	check(
		"layout: ranges are hotbar 1..9, grid 10..36",
		SlotLayout.HotbarFirst == 1
			and SlotLayout.HotbarLast == hot
			and SlotLayout.GridFirst == hot + 1
			and SlotLayout.GridLast == hot + cells
			and SlotLayout.InvSize == hot + cells
	)
	local convOk = true
	for cell = 1, cells do
		local slot = SlotLayout.gridCellToSlot(cell)
		convOk = convOk
			and slot == hot + cell
			and SlotLayout.areaOf(slot) == "grid"
			and SlotLayout.slotToGridCell(slot :: number) == cell
	end
	check("layout: gridCellToSlot/slotToGridCell round trip for every cell", convOk)
	local areaOk = true
	for slot = 1, SlotLayout.InvSize do
		areaOk = areaOk and (SlotLayout.areaOf(slot) == (if slot <= hot then "hotbar" else "grid"))
	end
	check("layout: areaOf classifies every valid slot", areaOk)
	check(
		"layout: areaOf rejects out-of-area and malformed",
		SlotLayout.areaOf(0) == nil
			and SlotLayout.areaOf(-1) == nil
			and SlotLayout.areaOf(SlotLayout.InvSize + 1) == nil
			and SlotLayout.areaOf(2.5) == nil
			and SlotLayout.areaOf(0 / 0) == nil
			and SlotLayout.areaOf(math.huge) == nil
			and SlotLayout.areaOf("5") == nil
			and SlotLayout.areaOf(nil) == nil
			and SlotLayout.gridCellToSlot(0) == nil
			and SlotLayout.gridCellToSlot(cells + 1) == nil
			and SlotLayout.slotToGridCell(hot) == nil
			and SlotLayout.slotToGridCell(SlotLayout.InvSize + 1) == nil
	)

	-- Server rejects every out-of-area address, strictly
	local bad: { unknown } = { 0, -1, 37, 2.5, 0 / 0, math.huge, "5", true, 1e9 }
	local rejectOk = true
	for _, slot in bad do
		rejectOk = rejectOk
			and InventoryMove.parseAddr({ kind = "inv", slot = slot }) == nil
			and InventoryMove.parseRequest({
				from = { kind = "inv", slot = slot },
				to = { kind = "inv", slot = 1 },
				count = 1,
			}) == nil
			and InventoryMove.parseRequest({
				from = { kind = "inv", slot = 1 },
				to = { kind = "inv", slot = slot },
				count = 1,
			}) == nil
			and InventoryMove.parseAddr({ kind = "chest", id = "c", slot = slot }) == nil
	end
	check("server: parse rejects any inv/chest index outside a valid area", rejectOk)
	check(
		"server: parse rejects unknown equip slot, bad kind, chest slot past ChestSlots",
		InventoryMove.parseAddr({ kind = "equip", slot = "Tail" }) == nil
			and InventoryMove.parseAddr({ kind = "equip", slot = 3 }) == nil
			and InventoryMove.parseAddr({ kind = "bag", slot = 1 }) == nil
			and InventoryMove.parseAddr({
					kind = "chest",
					id = "c",
					slot = Config.Storage.ChestSlots + 1,
				})
				== nil
	)
	do
		-- Even a hand-built Addr that skipped parse cannot touch a stray index.
		local ctx = newCtx()
		ctx.inv.slots[2] = { id = "Wood", count = 4 }
		local ok1 = InventoryMove.move(
			ctx,
			{ kind = "inv", slot = 2 },
			{ kind = "inv", slot = 0 },
			4
		)
		local ok2 = InventoryMove.move(
			ctx,
			{ kind = "inv", slot = 2 },
			{ kind = "inv", slot = 37 },
			4
		)
		local ok3 = InventoryMove.move(
			ctx,
			{ kind = "inv", slot = 2 },
			{ kind = "inv", slot = 2.5 },
			4
		)
		check(
			"server: move() refuses out-of-area targets and changes nothing",
			not ok1 and not ok2 and not ok3 and (ctx.inv.slots[2] :: Inventory.Stack).count == 4
		)
		local dropOk = InventoryMove.drop(ctx.inv, 37, 1)
		check("server: drop() refuses an out-of-area slot", not dropOk)
	end

	-- Hotbar slot 2 dragged onto every grid cell, then pickup merge, then back to the hotbar
	local e2eOk, mergeOk, backOk, strayOk = true, true, true, true
	for cell = 1, cells do
		for _, asStrings in { false, true } do
			local ctx = newCtx()
			ctx.inv.slots[1] = { id = "Axe", count = 1, durability = 10 }
			ctx.inv.slots[2] = { id = "Wood", count = 5 }
			local target = SlotLayout.gridCellToSlot(cell) :: number
			local ok = drag(ctx, { kind = "inv", slot = 2 }, { kind = "inv", slot = target })
			local view = decoded(ctx.inv, asStrings)
			e2eOk = e2eOk and ok and ctx.inv.slots[2] == nil and shows(view, target, woodName, "x5")
			-- the item is also inside the grid by the panel's own mapping
			e2eOk = e2eOk and SlotLayout.slotToGridCell(target) == cell

			-- auto-pickup of 3 more wood merges into that stack and the count updates
			local left = Inventory.add(ctx.inv, "Wood", 3, ItemCatalog.stackOf("Wood"))
			view = decoded(ctx.inv, asStrings)
			mergeOk = mergeOk and left == 0 and shows(view, target, woodName, "x8")
			local woodStacks = 0
			for _, s in ctx.inv.slots do
				if s and s.id == "Wood" then
					woodStacks += 1
				end
			end
			mergeOk = mergeOk and woodStacks == 1

			-- and back to hotbar slot 2
			local ok2 = drag(ctx, { kind = "inv", slot = target }, { kind = "inv", slot = 2 })
			view = decoded(ctx.inv, asStrings)
			backOk = backOk and ok2 and shows(view, 2, woodName, "x8") and view[target] == nil
			strayOk = strayOk and #SlotLayout.strays(ctx.inv.slots :: any, ctx.inv.size) == 0
		end
	end
	check("e2e: hotbar 2 -> grid cell k shows name + count in cell k (all 27 cells)", e2eOk)
	check("e2e: auto-pickup merges into the grid stack and the displayed count updates", mergeOk)
	check("e2e: grid cell -> hotbar slot 2 works", backOk)
	check("e2e: no item outside a valid area after any of the moves", strayOk)

	-- Pickup with an empty hotbar slot never lands outside the drawn areas
	do
		local ctx = newCtx()
		local ok = true
		for _ = 1, SlotLayout.InvSize do
			ok = ok and Inventory.add(ctx.inv, "Axe", 1, 1, 10) == 0
		end
		ok = ok and Inventory.add(ctx.inv, "Axe", 1, 1, 10) == 1
		check(
			"e2e: filling the inventory stays inside 1..InvSize",
			ok and #SlotLayout.strays(ctx.inv.slots :: any, ctx.inv.size) == 0
		)
	end

	-- Chest grid: inv slot -> chest cell c -> shows; chest -> inv grid cell
	local chestOk, chestBackOk = true, true
	for c = 1, Config.Storage.ChestSlots do
		local ctx = newCtx()
		local box = Inventory.new(Config.Storage.ChestSlots)
		ctx.chest, ctx.chestId = box, "c1"
		ctx.inv.slots[2] = { id = "Wood", count = 6 }
		local ok = drag(ctx, { kind = "inv", slot = 2 }, { kind = "chest", id = "c1", slot = c })
		local view = decoded(box, false)
		chestOk = chestOk and ok and shows(view, c, woodName, "x6") and ctx.inv.slots[2] == nil
		local gridSlot = SlotLayout.gridCellToSlot(c) :: number
		local ok2 = drag(
			ctx,
			{ kind = "chest", id = "c1", slot = c },
			{ kind = "inv", slot = gridSlot }
		)
		chestBackOk = chestBackOk
			and ok2
			and shows(decoded(ctx.inv, true), gridSlot, woodName, "x6")
			and next(box.slots) == nil
	end
	check("e2e: inv -> chest cell c shows in chest cell c (all cells)", chestOk)
	check("e2e: chest cell c -> grid cell c shows in the grid", chestBackOk)

	-- Equipment: a wearable goes inv -> its slot (and shows there), and back to a grid cell
	do
		local wearId: string? = nil
		local wearSlot: string? = nil
		for id, def in ItemCatalog.Items do
			if def.equipSlot ~= nil and ItemCatalog.stackOf(id) == 1 then
				for _, slotId in Config.Equipment.Slots do
					if wearId == nil and Equipment.accepts(slotId, id) then
						wearId, wearSlot = id, slotId
					end
				end
			end
		end
		if wearId == nil or wearSlot == nil then
			check("e2e: a wearable item exists to test equipment", false)
		else
			local ctx = newCtx()
			ctx.inv.slots[3] = { id = wearId, count = 1 }
			local ok = drag(ctx, { kind = "inv", slot = 3 }, { kind = "equip", slot = wearSlot })
			local idx = Equipment.slotIndex(wearSlot) :: number
			local worn = ctx.equip.slots[idx]
			local wearName = SlotViewModel.name({ id = wearId, count = 1 })
			check(
				"e2e: inv -> equipment slot shows the worn item",
				ok
					and worn ~= nil
					and worn.id == wearId
					and ctx.inv.slots[3] == nil
					and SlotViewModel.view(worn).name == wearName
			)
			local target = SlotLayout.gridCellToSlot(5) :: number
			local ok2 = drag(
				ctx,
				{ kind = "equip", slot = wearSlot },
				{ kind = "inv", slot = target }
			)
			check(
				"e2e: equipment -> grid cell 5 shows it in the grid",
				ok2
					and ctx.equip.slots[idx] == nil
					and shows(decoded(ctx.inv, false), target, wearName, "")
			)
			check(
				"e2e: equipment moves leave no stray slots",
				#SlotLayout.strays(ctx.inv.slots :: any, ctx.inv.size) == 0
					and #SlotLayout.strays(ctx.equip.slots :: any, ctx.equip.size) == 0
			)
		end
	end

	-- Rescue: items stored outside any valid area come back into the first free valid slot
	do
		local inv = Inventory.new(SlotLayout.InvSize)
		inv.slots[1] = { id = "Axe", count = 1, durability = 10 }
		inv.slots[2] = { id = "Wood", count = 5 }
		local slots = inv.slots :: { [any]: any }
		slots[0] = { id = "Wood", count = 4 }
		slots[SlotLayout.InvSize + 1] = { id = "Stone", count = 3 }
		slots[2.5] = { id = "Hide", count = 2 }
		slots["x"] = { id = "Nope", count = 1 }
		check("rescue: strays are detected", #SlotLayout.strays(inv.slots :: any, inv.size) == 4)
		local moved, remaining = SlotLayout.rescue(inv)
		check(
			"rescue: strays move into valid slots (merged and first free), junk dropped",
			moved == 9
				and remaining == 0
				and Inventory.count(inv, "Wood") == 9
				and Inventory.count(inv, "Stone") == 3
				and Inventory.count(inv, "Hide") == 2
				and #SlotLayout.strays(inv.slots :: any, inv.size) == 0
				and (inv.slots[2] :: Inventory.Stack).count == 9
		)
		-- Full inventory: nothing is deleted, strays stay and are reported
		local full = Inventory.new(SlotLayout.InvSize)
		for i = 1, SlotLayout.InvSize do
			full.slots[i] = { id = "Axe", count = 1, durability = 10 }
		end
		(full.slots :: { [any]: any })[0] = { id = "Wood", count = 4 }
		local m2, r2 = SlotLayout.rescue(full)
		check(
			"rescue: a full inventory keeps the stray (never deletes)",
			m2 == 0 and r2 == 1 and (full.slots :: { [any]: any })[0] ~= nil
		)
	end
end
