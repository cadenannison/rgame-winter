--!strict
-- The single pure move path for hotbar, backpack, equipment and chests. Addresses are typed values:
-- {kind="inv", slot} {kind="equip", slot=<Config.Equipment.Slots id>} {kind="chest", id, slot}.
-- Every move is validated first and atomic (a refusal changes nothing). Stack, merge, swap, split, equip-slot
-- rules and shift-click quick moves live here; services only add permission/state checks. No Roblox APIs.

local Config = require("../Config")
local ItemCatalog = require("../ItemCatalog")
local Equipment = require("./Equipment")
local Inventory = require("./Inventory")

export type Addr = { kind: string, slot: number | string, id: string? }
export type Ctx = {
	inv: Inventory.Inv, -- hotbar (1..HotbarSize) then backpack
	equip: Inventory.Inv, -- Equipment.new()
	chest: Inventory.Inv?, -- the chest the player has open
	chestId: string?,
}
export type Touched = { inv: boolean, equip: boolean, chest: boolean }
export type Request = { from: Addr, to: Addr?, count: number, rev: number?, expect: string? }

local MAX_ID_LENGTH = 32

local InventoryMove = {}

-- Player-facing text for a full inventory (server toast and the client hint match on it).
InventoryMove.FullText = "Inventory full"

local function whole(v: unknown): boolean
	return type(v) == "number" and v == v and v >= 1 and v == math.floor(v) and v < math.huge
end

-- Type/range-checks an address from the client. Returns a clean copy or nil.
function InventoryMove.parseAddr(raw: unknown): Addr?
	if type(raw) ~= "table" then
		return nil
	end
	local r = raw :: { [string]: unknown }
	local kind, slot = r.kind, r.slot
	if kind == "inv" then
		if
			whole(slot)
			and (slot :: number) <= Config.Inventory.HotbarSize + Config.Inventory.BackpackSize
		then
			return { kind = "inv", slot = slot :: number }
		end
	elseif kind == "equip" then
		if type(slot) == "string" and Equipment.slotIndex(slot) ~= nil then
			return { kind = "equip", slot = slot }
		end
	elseif kind == "chest" then
		local id = r.id
		if
			type(id) == "string"
			and #id >= 1
			and #id <= MAX_ID_LENGTH
			and whole(slot)
			and (slot :: number) <= Config.Storage.ChestSlots
		then
			return { kind = "chest", slot = slot :: number, id = id }
		end
	end
	return nil
end

-- Type/range-checks a whole move payload from the client.
function InventoryMove.parseRequest(raw: unknown): Request?
	if type(raw) ~= "table" then
		return nil
	end
	local r = raw :: { [string]: unknown }
	local from = InventoryMove.parseAddr(r.from)
	if from == nil then
		return nil
	end
	local to: Addr? = nil
	if r.to ~= nil then
		to = InventoryMove.parseAddr(r.to)
		if to == nil then
			return nil
		end
	end
	if not whole(r.count) or (r.count :: number) > Config.Items.MaxStack then
		return nil
	end
	local rev: number? = nil
	if r.rev ~= nil then
		if type(r.rev) ~= "number" or r.rev ~= r.rev or r.rev < 0 or r.rev ~= math.floor(r.rev) then
			return nil
		end
		rev = r.rev :: number
	end
	local expect: string? = nil
	if r.expect ~= nil then
		if type(r.expect) ~= "string" or #(r.expect :: string) > MAX_ID_LENGTH then
			return nil
		end
		expect = r.expect :: string
	end
	return { from = from, to = to, count = r.count :: number, rev = rev, expect = expect }
end

-- (container, index) for an address, or (nil, reason).
local function resolve(ctx: Ctx, addr: Addr): (Inventory.Inv?, number, string)
	if addr.kind == "inv" then
		local slot = addr.slot :: number
		if slot < 1 or slot > ctx.inv.size then
			return nil, 0, "BadSlot"
		end
		return ctx.inv, slot, "ok"
	elseif addr.kind == "equip" then
		local index = Equipment.slotIndex(addr.slot :: string)
		if index == nil then
			return nil, 0, "BadSlot"
		end
		return ctx.equip, index, "ok"
	elseif addr.kind == "chest" then
		if ctx.chest == nil or ctx.chestId == nil or addr.id ~= ctx.chestId then
			return nil, 0, "NoChest"
		end
		local slot = addr.slot :: number
		if slot < 1 or slot > ctx.chest.size then
			return nil, 0, "BadSlot"
		end
		return ctx.chest, slot, "ok"
	end
	return nil, 0, "BadSlot"
end

local function accepts(addr: Addr, id: string): boolean
	if addr.kind == "equip" then
		return Equipment.accepts(addr.slot :: string, id)
	end
	return true
end

local function mark(touched: Touched, addr: Addr)
	if addr.kind == "inv" then
		touched.inv = true
	elseif addr.kind == "equip" then
		touched.equip = true
	else
		touched.chest = true
	end
end

local function newTouched(): Touched
	return { inv = false, equip = false, chest = false }
end

-- Source item id at an address (for the stale-revision check), nil if empty/unreachable.
function InventoryMove.itemAt(ctx: Ctx, addr: Addr): string?
	local c, i = resolve(ctx, addr)
	local s = if c then c.slots[i] else nil
	return if s then s.id else nil
end

-- Moves `count` of the stack at `from` to `to`: empty target = move/split, same item = merge up to the
-- stack cap (partial allowed), different item = swap (whole stack only, both must fit their new slots).
-- Returns (ok, reason, touched).
function InventoryMove.move(
	ctx: Ctx,
	from: Addr,
	to: Addr,
	count: number
): (boolean, string, Touched)
	local touched = newTouched()
	local src, si, why = resolve(ctx, from)
	if src == nil then
		return false, why, touched
	end
	local dst, di, why2 = resolve(ctx, to)
	if dst == nil then
		return false, why2, touched
	end
	if src == dst and si == di then
		return false, "Same", touched
	end
	local s = src.slots[si]
	if s == nil then
		return false, "EmptySlot", touched
	end
	if not whole(count) or count > s.count then
		return false, "BadCount", touched
	end
	if ItemCatalog.Items[s.id] == nil then
		return false, "UnknownItem", touched
	end
	if not accepts(to, s.id) then
		return false, "WrongSlot", touched
	end
	local maxStack = ItemCatalog.stackOf(s.id)
	local d = dst.slots[di]
	if d == nil then
		dst.slots[di] = { id = s.id, count = count, durability = s.durability }
		s.count -= count
		if s.count <= 0 then
			src.slots[si] = nil
		end
	elseif d.id == s.id and d.durability == nil and s.durability == nil and maxStack > 1 then
		local room = maxStack - d.count
		if room <= 0 then
			return false, "Full", touched
		end
		local put = math.min(count, room)
		d.count += put
		s.count -= put
		if s.count <= 0 then
			src.slots[si] = nil
		end
	else
		if count ~= s.count then
			return false, "SlotBusy", touched
		end
		if not accepts(from, d.id) then
			return false, "WrongSlot", touched
		end
		src.slots[si], dst.slots[di] = d, s
	end
	mark(touched, from)
	mark(touched, to)
	return true, "Ok", touched
end

-- Moves as much of the whole stack as fits into dst slots lo..hi. Returns the count moved.
local function transfer(
	src: Inventory.Inv,
	si: number,
	dst: Inventory.Inv,
	lo: number,
	hi: number
): number
	local s = src.slots[si]
	if s == nil then
		return 0
	end
	local left =
		Inventory.addRange(dst, s.id, s.count, ItemCatalog.stackOf(s.id), s.durability, lo, hi)
	local put = s.count - left
	if put > 0 then
		s.count = left
		if left <= 0 then
			src.slots[si] = nil
		end
	end
	return put
end

-- Shift-click: equipment/chest -> backpack, backpack -> open chest, else wearable -> its slot, else
-- hotbar <-> backpack. Returns (ok, reason, touched).
function InventoryMove.quickMove(ctx: Ctx, from: Addr): (boolean, string, Touched)
	local touched = newTouched()
	local src, si, why = resolve(ctx, from)
	if src == nil then
		return false, why, touched
	end
	local s = src.slots[si]
	if s == nil then
		return false, "EmptySlot", touched
	end
	if ItemCatalog.Items[s.id] == nil then
		return false, "UnknownItem", touched
	end
	local hot = Config.Inventory.HotbarSize
	local put = 0
	if from.kind == "equip" then
		if Inventory.canAdd(ctx.inv, s.id, s.count, ItemCatalog.stackOf(s.id), s.durability) then
			put = transfer(src, si, ctx.inv, 1, ctx.inv.size)
			touched.inv = true
		end
		if put == 0 then
			return false, "Full", touched
		end
		touched.equip = true
		return true, "Ok", touched
	elseif from.kind == "chest" then
		put = transfer(src, si, ctx.inv, 1, ctx.inv.size)
		if put == 0 then
			return false, "Full", touched
		end
		touched.chest = true
		touched.inv = true
		return true, "Ok", touched
	end
	-- from the player inventory
	if ctx.chest ~= nil then
		put = transfer(src, si, ctx.chest, 1, ctx.chest.size)
		if put == 0 then
			return false, "Full", touched
		end
		touched.chest = true
		touched.inv = true
		return true, "Ok", touched
	end
	local def = ItemCatalog.Items[s.id]
	if def.equipSlot ~= nil then
		local fallback: string? = nil
		for index, slot in Config.Equipment.Slots do
			if Equipment.accepts(slot, s.id) then
				if ctx.equip.slots[index] == nil then
					return InventoryMove.move(ctx, from, { kind = "equip", slot = slot }, 1)
				end
				fallback = fallback or slot
			end
		end
		if fallback then
			return InventoryMove.move(ctx, from, { kind = "equip", slot = fallback }, 1)
		end
	end
	local lo, hi = hot + 1, ctx.inv.size
	if si > hot then
		lo, hi = 1, hot
	end
	put = transfer(src, si, ctx.inv, lo, hi)
	if put == 0 then
		return false, "Full", touched
	end
	touched.inv = true
	return true, "Ok", touched
end

-- Revision gate. A request carrying the current revision applies; a stale one applies only when the
-- source still holds the item the client saw (the move rules then validate the rest). Returns ok.
function InventoryMove.revisionOk(
	current: number,
	seen: number?,
	expect: string?,
	actual: string?
): boolean
	if seen == nil or seen == current then
		return true
	end
	return expect ~= nil and expect == actual
end

-- Full validated request: revision gate, then move/quickMove. Returns (ok, reason, touched, stale).
function InventoryMove.perform(
	ctx: Ctx,
	req: Request,
	currentRev: number
): (boolean, string, Touched, boolean)
	local involvesChest = req.from.kind == "chest" or (req.to ~= nil and req.to.kind == "chest")
	local stale = involvesChest and req.rev ~= nil and req.rev ~= currentRev
	if
		stale
		and not InventoryMove.revisionOk(
			currentRev,
			req.rev,
			req.expect,
			InventoryMove.itemAt(ctx, req.from)
		)
	then
		return false, "Stale", newTouched(), true
	end
	local ok, reason, touched
	if req.to == nil then
		ok, reason, touched = InventoryMove.quickMove(ctx, req.from)
	else
		ok, reason, touched = InventoryMove.move(ctx, req.from, req.to, req.count)
	end
	return ok, reason, touched, stale
end

return InventoryMove
