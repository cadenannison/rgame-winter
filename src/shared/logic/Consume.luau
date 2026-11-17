--!strict
-- Pure rules for eating: whether a use is allowed and how much hunger it restores.

local ItemCatalog = require("../ItemCatalog")

export type Meters = { hunger: number, dead: boolean, downed: boolean }

local Consume = {}

-- Returns (ok, reasonOrGain). On success the second value is the hunger gain (clamped to the cap).
-- Reasons: NotFood, Dead, Downed, Full.
function Consume.eat(
	def: ItemCatalog.ItemDef,
	meters: Meters,
	maxHunger: number
): (boolean, string | number)
	if def.kind ~= "food" or def.hunger == nil or def.hunger <= 0 then
		return false, "NotFood"
	end
	if meters.dead then
		return false, "Dead"
	end
	if meters.downed then
		return false, "Downed"
	end
	local room = maxHunger - meters.hunger
	if room <= 0 then
		return false, "Full"
	end
	return true, math.min(def.hunger, room)
end

return Consume
