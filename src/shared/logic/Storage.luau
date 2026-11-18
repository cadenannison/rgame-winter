--!strict
-- Pure shared-chest model: a chest is an Inventory with Config.Storage.ChestSlots slots. Deposit and
-- withdraw validate type, range and capacity, and are atomic (a refusal changes nothing). No Roblox APIs.

local ItemCatalog = require("../ItemCatalog")
local Inventory = require("./Inventory")

local Storage = {}

local function wholeNumber(v: unknown): boolean
	return type(v) == "number" and v == v and v >= 1 and v == math.floor(v) and v < math.huge
end

-- Moves up to count of the stack in `from` slot into `to`. Returns (ok, reason).
local function move(
	from: Inventory.Inv,
	slot: unknown,
	count: unknown,
	to: Inventory.Inv,
	fullReason: string
): (boolean, string)
	if not wholeNumber(slot) or not wholeNumber(count) then
		return false, "BadArgs"
	end
	local index, n = slot :: number, count :: number
	if index > from.size then
		return false, "BadSlot"
	end
	local stack = from.slots[index]
	if stack == nil then
		return false, "EmptySlot"
	end
	if n > stack.count then
		return false, "BadCount"
	end
	local def = ItemCatalog.Items[stack.id]
	if def == nil then
		return false, "UnknownItem"
	end
	if not Inventory.canAdd(to, stack.id, n, def.maxStack, stack.durability) then
		return false, fullReason
	end
	Inventory.add(to, stack.id, n, def.maxStack, stack.durability)
	stack.count -= n
	if stack.count <= 0 then
		from.slots[index] = nil
	end
	return true, "Ok"
end

-- Player inventory slot -> chest. Reasons: BadArgs, BadSlot, EmptySlot, BadCount, UnknownItem, ChestFull.
function Storage.deposit(
	chest: Inventory.Inv,
	player: Inventory.Inv,
	slot: unknown,
	count: unknown
): (boolean, string)
	return move(player, slot, count, chest, "ChestFull")
end

-- Chest slot -> player inventory. Reasons as deposit, with InventoryFull instead of ChestFull.
function Storage.withdraw(
	chest: Inventory.Inv,
	player: Inventory.Inv,
	chestSlot: unknown,
	count: unknown
): (boolean, string)
	return move(chest, chestSlot, count, player, "InventoryFull")
end

return Storage
