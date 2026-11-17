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

-- Adds into stackable stacks first, then empty slots. Items with durability never merge.
-- Returns the leftover count that did not fit.
function Inventory.add(
	inv: Inv,
	id: string,
	count: number,
	maxStack: number,
	durability: number?
): number
	local left = count
	if durability == nil then
		for i = 1, inv.size do
			local s = inv.slots[i]
			if left > 0 and s and s.id == id and s.durability == nil and s.count < maxStack then
				local put = math.min(left, maxStack - s.count)
				s.count += put
				left -= put
			end
		end
	end
	for i = 1, inv.size do
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
