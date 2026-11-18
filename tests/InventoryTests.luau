--!strict
-- Inventory revamp (Items round): stack sizes from Config.Items, the single validated move path
-- (stack, merge, swap, split, equip rules, quick move, chests), concurrent chest access with revisions,
-- overflow, and old-inventory migration. Pure logic only.

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Equipment = require("../src/shared/logic/Equipment")
local Inventory = require("../src/shared/logic/Inventory")
local InventoryMove = require("../src/shared/logic/InventoryMove")

local function newCtx(): InventoryMove.Ctx
	return {
		inv = Inventory.new(Config.Inventory.HotbarSize + Config.Inventory.BackpackSize),
		equip = Equipment.new(),
	}
end

local function inv(slot: number): InventoryMove.Addr
	return { kind = "inv", slot = slot }
end

local function put(ctx: InventoryMove.Ctx, slot: number, id: string, count: number, dur: number?)
	ctx.inv.slots[slot] = { id = id, count = count, durability = dur }
end

local function stackAt(i: Inventory.Inv, slot: number): Inventory.Stack
	return i.slots[slot] :: Inventory.Stack
end

return function(check: (string, boolean) -> ())
	local I = Config.Inventory
	check(
		"inventory: 9 hotbar + 27 backpack",
		I.HotbarSize == 9 and I.BackpackSize == 27 and I.Columns == 9
	)

	-- Stack sizes (Config.Items)
	local expected: { [string]: number } = {
		Wood = 20,
		Stone = 20,
		Hide = 10,
		FrostShard = 10,
		RawMeat = 10,
		CookedMeat = 10,
		Stew = 5,
		Arrow = 30,
		Axe = 1,
		Pickaxe = 1,
		Spear = 1,
		Bow = 1,
		HideCoat = 1,
		Workbench = 1,
		StorageChest = 1,
		Map = 1,
		Torch = 10,
	}
	local stacksOk = true
	for id, n in expected do
		if ItemCatalog.stackOf(id) ~= n then
			stacksOk = false
			print(`  stack mismatch {id}: {ItemCatalog.stackOf(id)} expected {n}`)
		end
	end
	check("inventory: stack sizes follow Config.Items", stacksOk)
	check(
		"inventory: unknown item falls back",
		ItemCatalog.stackOf("Nope") == Config.Items.FallbackStack
	)

	-- add / overflow
	local a = Inventory.new(2)
	check(
		"inventory: add fills stacks then slots",
		Inventory.add(a, "Wood", 30, 20) == 0
			and stackAt(a, 1).count == 20
			and stackAt(a, 2).count == 10
	)
	check(
		"inventory: overflow returns leftover",
		Inventory.add(a, "Wood", 40, 20) == 30 and Inventory.count(a, "Wood") == 40
	)
	check("inventory: canAdd false when full", not Inventory.canAdd(a, "Wood", 1, 20))
	check(
		"inventory: addRange respects bounds",
		Inventory.addRange(Inventory.new(5), "Wood", 10, 20, nil, 3, 3) == 0
	)

	-- merge, partial merge
	local c = newCtx()
	put(c, 1, "Wood", 15)
	put(c, 10, "Wood", 10)
	local ok, _, t = InventoryMove.move(c, inv(10), inv(1), 10)
	check(
		"move: merge partial up to the cap",
		ok and stackAt(c.inv, 1).count == 20 and stackAt(c.inv, 10).count == 5 and t.inv
	)
	check(
		"move: full target refuses merge",
		select(2, InventoryMove.move(c, inv(10), inv(1), 5)) == "Full"
	)
	-- split
	put(c, 11, "Stone", 10)
	ok = InventoryMove.move(c, inv(11), inv(12), 5)
	check(
		"move: split to empty slot",
		ok and stackAt(c.inv, 11).count == 5 and stackAt(c.inv, 12).count == 5
	)
	check(
		"move: split count bounds",
		select(2, InventoryMove.move(c, inv(11), inv(13), 6)) == "BadCount"
			and select(2, InventoryMove.move(c, inv(11), inv(13), 0)) == "BadCount"
			and select(2, InventoryMove.move(c, inv(11), inv(13), 1.5)) == "BadCount"
	)
	-- swap
	put(c, 14, "Wood", 3)
	ok = InventoryMove.move(c, inv(14), inv(12), 3)
	check(
		"move: swap different items",
		ok and stackAt(c.inv, 12).id == "Wood" and stackAt(c.inv, 14).id == "Stone"
	)
	check(
		"move: partial swap refused",
		select(2, InventoryMove.move(c, inv(12), inv(14), 1)) == "SlotBusy"
	)
	check(
		"move: same slot refused",
		select(2, InventoryMove.move(c, inv(12), inv(12), 1)) == "Same"
	)
	check(
		"move: empty source refused",
		select(2, InventoryMove.move(c, inv(30), inv(31), 1)) == "EmptySlot"
	)
	check(
		"move: out of range slot refused",
		select(2, InventoryMove.move(c, inv(99), inv(1), 1)) == "BadSlot"
	)
	-- durability items never merge
	put(c, 15, "Axe", 1, 40)
	put(c, 16, "Axe", 1, 40)
	check(
		"move: durable items swap, never merge",
		select(2, InventoryMove.move(c, inv(15), inv(16), 1)) == "Ok"
	)
	-- atomic refusal
	local before = Inventory.count(c.inv, "Wood")
	InventoryMove.move(c, inv(1), { kind = "equip", slot = "Head" }, 1)
	check("move: refusal changes nothing", Inventory.count(c.inv, "Wood") == before)

	-- equip rules
	local e = newCtx()
	put(e, 1, "HideHood", 1)
	put(e, 2, "FurHood", 1)
	put(e, 3, "HideCoat", 1)
	check(
		"equip: wrong slot rejected",
		select(2, InventoryMove.move(e, inv(3), { kind = "equip", slot = "Head" }, 1))
			== "WrongSlot"
	)
	ok = InventoryMove.move(e, inv(1), { kind = "equip", slot = "Head" }, 1)
	check(
		"equip: matching slot accepted, removed from grid",
		ok and e.inv.slots[1] == nil and e.equip.slots[1] ~= nil
	)
	ok = InventoryMove.move(e, inv(2), { kind = "equip", slot = "Head" }, 1)
	check(
		"equip: swap returns the old piece to the grid",
		ok and stackAt(e.equip, 1).id == "FurHood" and stackAt(e.inv, 2).id == "HideHood"
	)
	put(e, 4, "Wood", 5)
	put(e, 5, "HideBoots", 1)
	ok = InventoryMove.move(e, { kind = "equip", slot = "Head" }, inv(4), 1)
	check(
		"equip: unequip onto an unrelated item refused",
		not ok and stackAt(e.equip, 1).id == "FurHood"
	)
	check(
		"equip: non-gear rejected",
		select(2, InventoryMove.move(e, inv(4), { kind = "equip", slot = "Feet" }, 1))
			== "WrongSlot"
	)
	ok = InventoryMove.move(e, { kind = "equip", slot = "Head" }, inv(20), 1)
	check(
		"equip: unequip to empty slot",
		ok and e.equip.slots[1] == nil and stackAt(e.inv, 20).id == "FurHood"
	)
	check(
		"equip: unknown equip slot string refused at parse",
		InventoryMove.parseAddr({ kind = "equip", slot = "Tail" }) == nil
	)

	-- quick move
	local q = newCtx()
	put(q, 2, "Wood", 5)
	put(q, 12, "Wood", 5)
	put(q, 20, "HideCoat", 1)
	put(q, 21, "Stone", 4)
	ok = InventoryMove.quickMove(q, inv(12))
	check(
		"quick: grid to hotbar merges",
		ok and stackAt(q.inv, 2).count == 10 and q.inv.slots[12] == nil
	)
	ok = InventoryMove.quickMove(q, inv(21))
	check("quick: grid to first hotbar slot", ok and stackAt(q.inv, 1).id == "Stone")
	ok = InventoryMove.quickMove(q, inv(1))
	check(
		"quick: hotbar to grid",
		ok and q.inv.slots[1] == nil and Inventory.count(q.inv, "Stone") == 4
	)
	ok = InventoryMove.quickMove(q, inv(20))
	check(
		"quick: gear equips into its slot",
		ok and stackAt(q.equip, Equipment.slotIndex("Body") :: number).id == "HideCoat"
	)
	ok = InventoryMove.quickMove(q, { kind = "equip", slot = "Body" })
	check("quick: worn gear returns to the pack", ok and Inventory.count(q.inv, "HideCoat") == 1)

	-- chest transfer + concurrent access
	local chest = Inventory.new(Config.Storage.ChestSlots)
	local p1, p2 = newCtx(), newCtx()
	for _, p in { p1, p2 } do
		p.chest = chest
		p.chestId = "chest1"
	end
	local function ch(slot: number): InventoryMove.Addr
		return { kind = "chest", id = "chest1", slot = slot }
	end
	check("chest: has 9 slots", chest.size == 9 and Config.Storage.ChestSlots == 9)
	put(p1, 1, "Wood", 20)
	ok = InventoryMove.move(p1, inv(1), ch(1), 20)
	check("chest: deposit", ok and stackAt(chest, 1).count == 20 and p1.inv.slots[1] == nil)
	check(
		"chest: wrong chest id refused",
		select(2, InventoryMove.move(p1, inv(2), { kind = "chest", id = "chest9", slot = 1 }, 1))
			== "NoChest"
	)
	check(
		"chest: no chest open refused",
		select(2, InventoryMove.move(newCtx(), inv(2), ch(1), 1)) == "NoChest"
	)
	ok = InventoryMove.move(p2, ch(1), inv(5), 8)
	check(
		"chest: second player withdraws part",
		ok and stackAt(chest, 1).count == 12 and stackAt(p2.inv, 5).count == 8
	)
	-- both want the same stack; player 1 saw rev 0, chest is now rev 1
	local req1: InventoryMove.Request =
		{ from = ch(1), to = inv(2), count = 12, rev = 0, expect = "Wood" }
	local ok1, _, _, stale1 = InventoryMove.perform(p1, req1, 1)
	check(
		"chest: stale revision applies when still valid",
		ok1 and stale1 and chest.slots[1] == nil
	)
	local req2: InventoryMove.Request =
		{ from = ch(1), to = inv(3), count = 1, rev = 0, expect = "Wood" }
	local ok2, r2, _, stale2 = InventoryMove.perform(p2, req2, 2)
	check(
		"chest: stale and gone is refused, nothing changes",
		not ok2 and r2 == "Stale" and stale2 and p2.inv.slots[3] == nil
	)
	chest.slots[1] = { id = "Stone", count = 3 }
	local ok3 = InventoryMove.perform(
		p2,
		{ from = ch(1), to = inv(3), count = 3, rev = 1, expect = "Wood" },
		3
	)
	check(
		"chest: stale and replaced by another item is refused",
		not ok3 and stackAt(chest, 1).count == 3
	)
	local ok4 = InventoryMove.perform(
		p2,
		{ from = ch(1), to = inv(3), count = 3, rev = 3, expect = "Stone" },
		3
	)
	check("chest: current revision applies", ok4 and chest.slots[1] == nil)
	-- full pack refuses withdraw atomically
	local full = newCtx()
	full.chest, full.chestId = chest, "chest1"
	for i = 1, full.inv.size do
		put(full, i, "Wood", 20)
	end
	chest.slots[2] = { id = "Stone", count = 2 }
	check(
		"chest: quick withdraw into a full pack refused",
		select(2, InventoryMove.quickMove(full, ch(2))) == "Full" and stackAt(chest, 2).count == 2
	)
	check(
		"chest: full chest refuses deposit",
		(function(): boolean
			local small = newCtx()
			local tiny = Inventory.new(1)
			tiny.slots[1] = { id = "Stone", count = 20 }
			small.chest, small.chestId = tiny, "chest1"
			put(small, 1, "Wood", 5)
			return select(2, InventoryMove.quickMove(small, inv(1))) == "Full"
				and stackAt(small.inv, 1).count == 5
		end)()
	)

	local recipe = ItemCatalog.Recipes.StorageChest
	check(
		"chest: recipe is 8 wood at workbench tier 1",
		recipe ~= nil
			and recipe.tier == Config.Storage.CraftStationTier
			and recipe.inputs[1].id == "Wood"
			and recipe.inputs[1].count == Config.Storage.CraftWood
			and Config.Storage.CraftWood == 8
	)
	check("chest: per-player cap is 4", Config.Storage.MaxPerPlayer == 4)

	-- parse validation (never trust the client)
	check(
		"parse: garbage payloads rejected",
		InventoryMove.parseRequest(nil) == nil
			and InventoryMove.parseRequest("x") == nil
			and InventoryMove.parseRequest({}) == nil
	)
	check(
		"parse: slot bounds and types",
		InventoryMove.parseAddr({ kind = "inv", slot = 0 }) == nil
			and InventoryMove.parseAddr({ kind = "inv", slot = 37 }) == nil
			and InventoryMove.parseAddr({ kind = "inv", slot = 1.5 }) == nil
			and InventoryMove.parseAddr({ kind = "inv", slot = 0 / 0 }) == nil
			and InventoryMove.parseAddr({ kind = "chest", slot = 1 }) == nil
			and InventoryMove.parseAddr({ kind = "chest", id = "c", slot = 10 }) == nil
	)
	check(
		"parse: count bounds",
		InventoryMove.parseRequest({ from = inv(1), to = inv(2), count = 0 }) == nil
			and InventoryMove.parseRequest({
				from = inv(1),
				to = inv(2),
				count = Config.Items.MaxStack + 1,
			}) == nil
			and InventoryMove.parseRequest({ from = inv(1), to = inv(2), count = 5 }) ~= nil
	)
	check(
		"parse: quick move has no target",
		(function(): boolean
			local r = InventoryMove.parseRequest({ from = inv(1), count = 1 })
			return r ~= nil and r.to == nil
		end)()
	)

	-- migration: old 15-slot backpack shape (9 + 15 = 24 slots, stack cap 50) into 36 slots
	local old: { [number]: any } = {}
	for i = 1, 24 do
		old[i] = { id = "Wood", count = 25 }
	end
	old[3] = { id = "RemovedItem", count = 4 }
	old[4] = { id = "Axe", count = 1, durability = 30 }
	old[5] = "junk"
	old[6] = { id = "Stone", count = -2 }
	local migrated = Inventory.fromSaved(old, 36, function(id: string): number?
		return if ItemCatalog.Items[id] then ItemCatalog.stackOf(id) else nil
	end)
	check(
		"migrate: items that no longer exist are dropped",
		Inventory.count(migrated, "RemovedItem") == 0
	)
	check("migrate: bad shapes and counts dropped", Inventory.count(migrated, "Stone") == 0)
	check("migrate: durability kept", stackAt(migrated, 4).durability == 30)
	check(
		"migrate: over-cap stacks spill, nothing lost",
		Inventory.count(migrated, "Wood") == 25 * 20 and migrated.size == 36
	)
	check(
		"migrate: stacks obey the new cap",
		(function(): boolean
			for i = 1, migrated.size do
				local s = migrated.slots[i]
				if s and s.count > ItemCatalog.stackOf(s.id) then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"migrate: junk input gives empty inventory",
		Inventory.fromSaved("x", 36, function(_: string): number?
			return 1
		end).size == 36
	)
	-- Property: any random sequence of moves (valid, invalid, cancelled) conserves total item counts. A cancelled
	-- drag sends nothing; the only way counts change is the explicit drop, tested separately below.
	do
		local ids = { "Wood", "Stone", "Axe", "Hide", "Torch", "Pickaxe" }
		local seed = 1234
		local rng = {
			NextInteger = function(_: unknown, lo: number, hi: number): number
				seed = (seed * 1103515245 + 12345) % 2147483648
				return lo + math.floor(seed / 65536) % (hi - lo + 1)
			end,
		}
		local propOk = true
		for _ = 1, 40 do
			local ctx = newCtx()
			local box = Inventory.new(Config.Storage.ChestSlots)
			ctx.chest, ctx.chestId = box, "c1"
			local total: { [string]: number } = {}
			for slot = 1, ctx.inv.size do
				if rng:NextInteger(1, 3) == 1 then
					local id = ids[rng:NextInteger(1, #ids)]
					local n = if ItemCatalog.stackOf(id) > 1 then rng:NextInteger(1, 20) else 1
					put(ctx, slot, id, n, if ItemCatalog.stackOf(id) == 1 then 10 else nil)
					total[id] = (total[id] or 0) + n
				end
			end
			local function randAddr(): InventoryMove.Addr
				local r = rng:NextInteger(1, 10)
				if r <= 6 then
					return inv(rng:NextInteger(0, ctx.inv.size + 2)) -- includes out-of-range
				elseif r <= 8 then
					return {
						kind = "chest",
						id = if r == 8 then "c1" else "other",
						slot = rng:NextInteger(0, 11),
					}
				elseif r == 9 then
					return {
						kind = "equip",
						slot = Config.Equipment.Slots[rng:NextInteger(1, #Config.Equipment.Slots)],
					}
				end
				return { kind = "bogus", slot = 1 }
			end
			for _ = 1, 150 do
				local action = rng:NextInteger(1, 4) -- 1 = cancelled drag: nothing is sent
				if action == 2 then
					InventoryMove.quickMove(ctx, randAddr())
				else
					local from = randAddr()
					local count = rng:NextInteger(0, 25)
					InventoryMove.move(ctx, from, randAddr(), count)
				end
			end
			local after: { [string]: number } = {}
			for _, part in { ctx.inv, ctx.equip, box } do
				for id, _ in total do
					after[id] = (after[id] or 0) + Inventory.count(part, id)
				end
			end
			for id, n in total do
				if after[id] ~= n then
					propOk = false
				end
			end
		end
		check("property: random moves (valid, invalid, cancelled) conserve item counts", propOk)
	end

	-- Explicit Drop is the only removal path; failures change nothing.
	do
		local ctx = newCtx()
		put(ctx, 3, "Wood", 10)
		local bad1 = { InventoryMove.drop(ctx.inv, 99, 1) }
		local bad2 = { InventoryMove.drop(ctx.inv, 3, 11) }
		local bad3 = { InventoryMove.drop(ctx.inv, 4, 1) }
		local bad4 = { InventoryMove.drop(ctx.inv, 3, 0) }
		check(
			"drop: invalid slot/count/empty refused, stack unchanged",
			not bad1[1]
				and not bad2[1]
				and not bad3[1]
				and not bad4[1]
				and stackAt(ctx.inv, 3).count == 10
		)
		local dropped, _, id, n = InventoryMove.drop(ctx.inv, 3, 4)
		check(
			"drop: partial drop removes exactly that many",
			dropped and id == "Wood" and n == 4 and stackAt(ctx.inv, 3).count == 6
		)
		InventoryMove.drop(ctx.inv, 3, 6)
		check("drop: whole stack empties the slot", ctx.inv.slots[3] == nil)
	end
end
