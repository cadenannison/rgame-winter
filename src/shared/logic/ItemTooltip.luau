--!strict
-- Pure item description lines for tooltips (hover on PC, long-press on touch). Never shows cold-resistance
-- numbers; warmth is shown as "Warmth +N". No Roblox APIs.

local ItemCatalog = require("../ItemCatalog")

local ItemTooltip = {}

function ItemTooltip.warmthLine(id: string): string?
	local def = ItemCatalog.Items[id]
	if def and def.warmth and def.warmth > 0 then
		return `Warmth +{def.warmth}`
	end
	return nil
end

local SECONDS_PER_MINUTE = 60

-- "Fuel: burns 2 min" / "Fuel: burns 30s" for campfire fuel items. Value = Config.Items fuelSeconds (tier-1 burn).
function ItemTooltip.fuelLine(id: string): string?
	local def = ItemCatalog.Items[id]
	local seconds = def and def.fuelSeconds
	if seconds == nil or seconds <= 0 then
		return nil
	end
	if seconds >= SECONDS_PER_MINUTE and seconds % SECONDS_PER_MINUTE == 0 then
		return `Fuel: burns {seconds // SECONDS_PER_MINUTE} min`
	end
	return `Fuel: burns {math.floor(seconds + 0.5)}s`
end

-- Lines: name, then Warmth / Armor / Damage / Hunger / Fuel when the item has them.
function ItemTooltip.lines(id: string): { string }
	local def = ItemCatalog.Items[id]
	if def == nil then
		return {}
	end
	local out: { string } = { def.name }
	local warmth = ItemTooltip.warmthLine(id)
	if warmth then
		table.insert(out, warmth)
	end
	local armor = ItemCatalog.armorOf(id)
	if armor > 0 then
		table.insert(out, `Armor {math.floor(armor * 100 + 0.5)}%`)
	end
	if def.damage and def.damage > 0 then
		table.insert(out, `Damage {math.floor(def.damage + 0.5)}`)
	end
	if def.hunger and def.hunger > 0 then
		table.insert(out, `Hunger +{math.floor(def.hunger + 0.5)}`)
	end
	local fuel = ItemTooltip.fuelLine(id)
	if fuel then
		table.insert(out, fuel)
	end
	return out
end

function ItemTooltip.text(id: string): string
	return table.concat(ItemTooltip.lines(id), "\n")
end

return ItemTooltip
