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

-- Lines: name, then Warmth / Armor / damage when the item has them.
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
	return out
end

function ItemTooltip.text(id: string): string
	return table.concat(ItemTooltip.lines(id), "\n")
end

return ItemTooltip
