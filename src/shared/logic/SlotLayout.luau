--!strict
-- The single source of truth for slot indices. Player inventory ("inv" addresses) is one array: hotbar
-- 1..HotbarSize, then the Backpack grid HotbarSize+1..HotbarSize+BackpackSize (cell k of the grid = slot
-- HotbarSize+k). Equipment is indexed by Config.Equipment.Slots; a chest by 1..Config.Storage.ChestSlots.
-- Server validation, the move path, the HUD hotbar, the Backpack panel and the tests all use this module; no
-- other file converts a grid cell to a slot or the reverse. No Roblox APIs.

local Config = require("../Config")
local ItemCatalog = require("../ItemCatalog")
local Inventory = require("./Inventory")

export type Area = "hotbar" | "grid" | "equip" | "chest"
export type Stray = { key: any, stack: any }

local SlotLayout = {}

local hotbarLast = Config.Inventory.HotbarSize
local gridFirst = hotbarLast + 1
local gridLast = hotbarLast + Config.Inventory.BackpackSize

SlotLayout.HotbarFirst = 1
SlotLayout.HotbarLast = hotbarLast
SlotLayout.GridFirst = gridFirst
SlotLayout.GridLast = gridLast
SlotLayout.GridCells = Config.Inventory.BackpackSize
SlotLayout.InvSize = gridLast
SlotLayout.EquipFirst = 1
SlotLayout.EquipLast = #Config.Equipment.Slots
SlotLayout.ChestFirst = 1
SlotLayout.ChestLast = Config.Storage.ChestSlots

local function whole(v: unknown): boolean
	return type(v) == "number"
		and v == v
		and v == math.floor(v)
		and v > -math.huge
		and v < math.huge
end

-- "hotbar" | "grid" for a valid player-inventory index, nil for anything else (0, 37, 2.5, NaN, strings).
function SlotLayout.areaOf(index: unknown): Area?
	if not whole(index) then
		return nil
	end
	local i = index :: number
	if i >= 1 and i <= hotbarLast then
		return "hotbar"
	elseif i >= gridFirst and i <= gridLast then
		return "grid"
	end
	return nil
end

-- Backpack grid cell (1..GridCells, row-major) -> inventory slot index; nil for a bad cell.
function SlotLayout.gridCellToSlot(cell: number): number?
	if not whole(cell) or cell < 1 or cell > SlotLayout.GridCells then
		return nil
	end
	return hotbarLast + cell
end

-- Inventory slot index -> Backpack grid cell; nil when the index is not a grid slot.
function SlotLayout.slotToGridCell(index: number): number?
	if SlotLayout.areaOf(index) ~= "grid" then
		return nil
	end
	return index - hotbarLast
end

-- Whether an address kind + slot is inside a valid area. kind: "inv" (slot number), "equip" (slot id string),
-- "chest" (slot number).
function SlotLayout.validAddr(kind: unknown, slot: unknown): boolean
	if kind == "inv" then
		return SlotLayout.areaOf(slot) ~= nil
	elseif kind == "equip" then
		return type(slot) == "string" and table.find(Config.Equipment.Slots, slot) ~= nil
	elseif kind == "chest" then
		return whole(slot)
			and (slot :: number) >= SlotLayout.ChestFirst
			and (slot :: number) <= SlotLayout.ChestLast
	end
	return false
end

-- The wire snapshot of a container: a dense array of { slot, id, count, durability } for slots 1..size. Every
-- entry carries its own index, so a remote can never turn sparse numeric keys into something readers miss.
function SlotLayout.snapshot(
	inv: Inventory.Inv
): { { slot: number, id: string, count: number, durability: number? } }
	local out = {}
	for i = 1, inv.size do
		local s = inv.slots[i]
		if s then
			table.insert(out, { slot = i, id = s.id, count = s.count, durability = s.durability })
		end
	end
	return out
end

-- Entries of an inventory table that sit outside every valid area (bad key, or a malformed stack). The invariant
-- "every non-empty slot lies inside a valid area" is `#SlotLayout.strays(inv, size) == 0`.
function SlotLayout.strays(slots: { [any]: any }, size: number): { Stray }
	local out: { Stray } = {}
	for key, stack in slots do
		if stack ~= nil and (not whole(key) or (key :: number) < 1 or (key :: number) > size) then
			table.insert(out, { key = key, stack = stack })
		end
	end
	return out
end

-- Moves every stray entry of a player inventory into the first free valid slots (merging into stacks first).
-- Returns (moved, remaining): `remaining` strays did not fit (inventory full) and stay where they are, so
-- nothing is ever deleted; /debug inv reports them.
function SlotLayout.rescue(inv: Inventory.Inv): (number, number)
	local moved, remaining = 0, 0
	for _, entry in SlotLayout.strays(inv.slots :: any, inv.size) do
		local slots = inv.slots :: { [any]: any }
		local s = entry.stack
		local valid = type(s) == "table"
			and type(s.id) == "string"
			and ItemCatalog.Items[s.id] ~= nil
		if not valid then
			slots[entry.key] = nil -- not an item at all: drop the junk entry
		else
			local count = if type(s.count) == "number" and s.count >= 1
				then math.floor(s.count)
				else 1
			local durability = if type(s.durability) == "number" then s.durability else nil
			slots[entry.key] = nil
			local left = Inventory.add(inv, s.id, count, ItemCatalog.stackOf(s.id), durability)
			moved += count - left
			if left > 0 then
				slots[entry.key] = { id = s.id, count = left, durability = durability }
				remaining += 1
			end
		end
	end
	return moved, remaining
end

return SlotLayout
