--!strict
-- Pure equipment model: an Inventory with one slot per Config.Equipment.Slots entry (index = panel order).
-- Worn gear (not merely carried) feeds cold resistance. No Roblox APIs.

local Config = require("../Config")
local ItemCatalog = require("../ItemCatalog")
local Inventory = require("./Inventory")
local ProfileSchema = require("./ProfileSchema")

local Equipment = {}

function Equipment.new(): Inventory.Inv
	return Inventory.new(#Config.Equipment.Slots)
end

-- Panel index of a slot id (nil for an unknown slot).
function Equipment.slotIndex(slot: string): number?
	return table.find(Config.Equipment.Slots, slot)
end

-- Whether item `id` may be worn in equipment slot `slot` (accessories fit either accessory slot).
function Equipment.accepts(slot: string, id: string): boolean
	local def = ItemCatalog.Items[id]
	return def ~= nil
		and def.equipSlot ~= nil
		and ItemCatalog.stackOf(id) == 1
		and ProfileSchema.slotAccepts(slot, def.equipSlot)
end

-- Worn items as the profile map slot -> item id.
function Equipment.toMap(equip: Inventory.Inv): { [string]: string }
	local map: { [string]: string } = {}
	for index, slot in Config.Equipment.Slots do
		local stack = equip.slots[index]
		if stack then
			map[slot] = stack.id
		end
	end
	return map
end

-- Builds the worn set from a profile map. Unknown slots/items and items that do not fit are dropped.
function Equipment.fromMap(map: unknown): Inventory.Inv
	local equip = Equipment.new()
	if type(map) ~= "table" then
		return equip
	end
	for index, slot in Config.Equipment.Slots do
		local id = (map :: { [string]: unknown })[slot]
		if type(id) == "string" and Equipment.accepts(slot, id) then
			equip.slots[index] = { id = id, count = 1 }
		end
	end
	return equip
end

-- Cold resistance of what is worn: sum of the pieces, capped at Config.Clothing.MaxColdResistance.
function Equipment.resistance(equip: Inventory.Inv): number
	local total = 0
	for index = 1, equip.size do
		local stack = equip.slots[index]
		local def = if stack then ItemCatalog.Items[stack.id] else nil
		if def and def.coldResistance then
			total += def.coldResistance
		end
	end
	return math.min(total, Config.Clothing.MaxColdResistance)
end

return Equipment
