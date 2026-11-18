--!strict
-- Pure inventory model: fixed slot array (hotbar first, then backpack). No Roblox APIs.

export type Stack = { id: string, count: number, durability: number? }
export type Inv = { slots: { [number]: Stack? }, size: number }

local Inventory = {}

function Inventory.new(size: number): Inv
	return { slots = {}, size = size }
end

function Inventory.clone(inv: Inv): Inv
	local copy = Inventory.new(inv.size)
	for i, s in inv.slots do
		if s then
			copy.slots[i] = { id = s.id, count = s.count, durability = s.durability }
		end
	end
	return copy
end

function Inventory.count(inv: Inv, id: string): number
	local total = 0
	for i = 1, inv.size do
		local s = inv.slots[i]
		if s and s.id == id then
			total += s.count
		end
	end
	return total
end

-- Adds into stackable stacks first, then empty slots, only within slots lo..hi. Items with durability
-- never merge. Returns the leftover count that did not fit.
function Inventory.addRange(
	inv: Inv,
	id: string,
	count: number,
	maxStack: number,
	durability: number?,
	lo: number,
	hi: number
): number
	local left = count
	local last = math.min(hi, inv.size)
	if durability == nil then
		for i = lo, last do
			local s = inv.slots[i]
			if left > 0 and s and s.id == id and s.durability == nil and s.count < maxStack then
				local put = math.min(left, maxStack - s.count)
				s.count += put
				left -= put
			end
		end
	end
	for i = lo, last do
		if left <= 0 then
			break
		end
		if inv.slots[i] == nil then
			local put = math.min(left, maxStack)
			inv.slots[i] = { id = id, count = put, durability = durability }
			left -= put
		end
	end
	return left
end

-- Adds into the whole inventory. Returns the leftover count that did not fit.
function Inventory.add(
	inv: Inv,
	id: string,
	count: number,
	maxStack: number,
	durability: number?
): number
	return Inventory.addRange(inv, id, count, maxStack, durability, 1, inv.size)
end

-- Rebuilds an inventory from a saved/old slot table (any older slot count) into `size` slots. Entries keep
-- their index; unknown items (maxStackOf returns nil), bad shapes and bad counts are dropped; counts above
-- the current stack cap spill into free slots. Pure; callers pass the catalog lookup.
function Inventory.fromSaved(raw: unknown, size: number, maxStackOf: (string) -> number?): Inv
	local inv = Inventory.new(size)
	if type(raw) ~= "table" then
		return inv
	end
	local spill: { Stack } = {}
	local indices: { number } = {}
	for key in raw :: { [unknown]: unknown } do
		if type(key) == "number" and key == math.floor(key) and key >= 1 then
			table.insert(indices, key)
		end
	end
	table.sort(indices)
	for _, index in indices do
		local entry = (raw :: { [number]: unknown })[index]
		if type(entry) == "table" then
			local e = entry :: { [string]: unknown }
			local id, count = e.id, e.count
			local cap = if type(id) == "string" then maxStackOf(id) else nil
			if
				cap ~= nil
				and type(count) == "number"
				and count == math.floor(count)
				and count >= 1
				and count < math.huge
			then
				local durability = if type(e.durability) == "number" then e.durability else nil
				local put = math.min(count, cap)
				local stack: Stack = { id = id :: string, count = put, durability = durability }
				if index <= size and inv.slots[index] == nil then
					inv.slots[index] = stack
				else
					table.insert(spill, stack)
				end
				if count > put then
					table.insert(
						spill,
						{ id = id :: string, count = count - put, durability = durability }
					)
				end
			end
		end
	end
	for _, stack in spill do
		Inventory.add(inv, stack.id, stack.count, maxStackOf(stack.id) or 1, stack.durability)
	end
	return inv
end

function Inventory.canAdd(
	inv: Inv,
	id: string,
	count: number,
	maxStack: number,
	durability: number?
): boolean
	return Inventory.add(Inventory.clone(inv), id, count, maxStack, durability) == 0
end

-- Removes exactly count of id (later slots first so the hotbar keeps its stacks). False and unchanged if short.
function Inventory.remove(inv: Inv, id: string, count: number): boolean
	if count <= 0 or Inventory.count(inv, id) < count then
		return false
	end
	local left = count
	for i = inv.size, 1, -1 do
		local s = inv.slots[i]
		if left > 0 and s and s.id == id then
			local take = math.min(left, s.count)
			s.count -= take
			left -= take
			if s.count <= 0 then
				inv.slots[i] = nil
			end
		end
	end
	return true
end

function Inventory.removeSlot(inv: Inv, slot: number)
	inv.slots[slot] = nil
end

-- Applies wear to the stack in slot. Returns true if the item broke (and was removed).
function Inventory.wear(inv: Inv, slot: number, amount: number): boolean
	local s = inv.slots[slot]
	if s == nil or s.durability == nil then
		return false
	end
	s.durability -= amount
	if s.durability <= 0 then
		inv.slots[slot] = nil
		return true
	end
	return false
end

return Inventory
