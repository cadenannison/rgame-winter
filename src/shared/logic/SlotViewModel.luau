--!strict
-- Pure slot-to-display mapping shared by every slot type (hotbar, backpack grid, equipment, chest) and by the
-- inventory decoders. No Roblox APIs. A remote turns sparse numeric-keyed tables into string keys, so decode
-- accepts number keys, numeric-string keys and {slot=...} entries and never drops an occupied slot.

local ItemCatalog = require("../ItemCatalog")
local Repair = require("./Repair")

export type Stack = { id: string, count: number, durability: number? }
export type Highlight = "held" | "target" | "hover" | "focus" | "hotbar" | "rarity" | "none"
export type View = {
	occupied: boolean,
	name: string, -- display name, never empty when occupied
	countText: string, -- "xN" when stack > 1, else durability label or ""
	rarity: string,
}
export type HighlightInput = {
	isHeld: boolean,
	canReceive: boolean, -- a stack is held and this slot could take it
	isHover: boolean,
	isFocus: boolean,
	isSelectedHotbar: boolean,
	rarity: string,
}

local SlotViewModel = {}

local function decodeStack(s: any): Stack?
	if type(s) ~= "table" or type(s.id) ~= "string" or s.id == "" then
		return nil
	end
	local n = if type(s.count) == "number" and s.count >= 1 then s.count else 1
	return {
		id = s.id,
		count = n,
		durability = if type(s.durability) == "number" then s.durability else nil,
	}
end

-- raw: the payload's slots table. Returns slot index -> stack.
function SlotViewModel.decodeSlots(raw: any): { [number]: Stack }
	local out: { [number]: Stack } = {}
	if type(raw) ~= "table" then
		return out
	end
	for k, v in raw do
		-- An entry's own slot field wins (dense array payloads); else the key (number or numeric string).
		local index: number? = nil
		if type(v) == "table" and type(v.slot) == "number" then
			index = v.slot
		elseif type(k) == "number" then
			index = k
		elseif type(k) == "string" then
			index = tonumber(k)
		end
		local stack = decodeStack(v)
		if index ~= nil and stack ~= nil and index >= 1 and index % 1 == 0 then
			out[index] = stack
		end
	end
	return out
end

function SlotViewModel.name(stack: Stack): string
	local def = ItemCatalog.Items[stack.id]
	if def and def.name ~= "" then
		return def.name
	end
	return stack.id
end

local idByName: { [string]: string }? = nil

-- Reverse of name(): item id for a display name (HUD slots that only receive the name text). nil if unknown.
function SlotViewModel.idForName(name: string): string?
	local map = idByName
	if map == nil then
		map = {}
		for id, def in ItemCatalog.Items do
			(map :: { [string]: string })[def.name] = id
		end
		idByName = map
	end
	return (map :: { [string]: string })[name] or (if ItemCatalog.Items[name] then name else nil)
end

function SlotViewModel.view(stack: Stack?): View
	if stack == nil then
		return { occupied = false, name = "", countText = "", rarity = "common" }
	end
	local def = ItemCatalog.Items[stack.id]
	local text = ""
	if stack.count > 1 then
		text = `x{stack.count}`
	elseif def and stack.durability ~= nil then
		text = Repair.durabilityLabel(def, stack.durability) or ""
	end
	return {
		occupied = true,
		name = SlotViewModel.name(stack),
		countText = text,
		rarity = ItemCatalog.rarityOf(stack.id),
	}
end

function SlotViewModel.highlight(input: HighlightInput): Highlight
	if input.isHeld then
		return "held"
	elseif input.canReceive then
		return if input.isHover then "hover" else "target"
	elseif input.isFocus then
		return "focus"
	elseif input.isSelectedHotbar then
		return "hotbar"
	elseif input.rarity ~= "common" then
		return "rarity"
	end
	return "none"
end

return SlotViewModel
