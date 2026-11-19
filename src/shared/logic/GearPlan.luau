--!strict
-- Pure worn-gear plan (no Roblox APIs): item id -> tier look, slot -> part plans, loadout budget fit.
-- GearModels turns plans into Parts. Design knobs: Config.ArtGear.

local Config = require("../Config")

export type PartPlan = {
	slot: string,
	name: string, -- "<Slot>_<name>"
	rig: string, -- R15 part name to weld to
	offset: { number },
	mult: { number },
	add: { number },
	scaleXZ: number,
	color: { number },
	material: string,
}

local GearPlan = {}

-- Tier id for a gear item (id prefix match, e.g. "FurHood" -> "Fur"); Config.ArtGear.DefaultTier otherwise.
function GearPlan.tierOf(itemId: string): string
	for _, tier in Config.ArtGear.TierOrder do
		if string.sub(itemId, 1, #tier) == tier then
			return tier
		end
	end
	return Config.ArtGear.DefaultTier
end

-- Part plans for one worn item in one slot ({} for an unknown slot).
function GearPlan.parts(itemId: string, slot: string): { PartPlan }
	local specs = Config.ArtGear.Parts[slot]
	local rig = Config.ArtGear.Rig[slot]
	local out: { PartPlan } = {}
	if specs == nil or rig == nil then
		return out
	end
	local look = Config.ArtGear.Tiers[GearPlan.tierOf(itemId)]
		or Config.ArtGear.Tiers[Config.ArtGear.DefaultTier]
	for _, spec in specs do
		local offset = spec.offset
		if spec.rig == nil then
			offset =
				{ offset[1] + rig.offset[1], offset[2] + rig.offset[2], offset[3] + rig.offset[3] }
		end
		local trim = spec.tone == "trim"
		table.insert(out, {
			slot = slot,
			name = `{slot}_{spec.name}`,
			rig = spec.rig or rig.part,
			offset = offset,
			mult = spec.mult,
			add = spec.add,
			scaleXZ = look.scale,
			color = if trim then look.trim else look.main,
			material = if trim then look.trimMaterial else look.material,
		})
	end
	return out
end

-- Final part size for a rig part of size (x, y, z).
function GearPlan.size(plan: PartPlan, x: number, y: number, z: number): (number, number, number)
	local sx = (x * plan.mult[1] + plan.add[1]) * plan.scaleXZ
	local sy = y * plan.mult[2] + plan.add[2]
	local sz = (z * plan.mult[3] + plan.add[3]) * plan.scaleXZ
	return math.max(sx, 0.05), math.max(sy, 0.05), math.max(sz, 0.05)
end

-- Plans for a whole loadout (slot -> item id), in Config.Equipment.Slots order, cut at the player budget.
function GearPlan.loadout(worn: { [string]: string }): { PartPlan }
	local out: { PartPlan } = {}
	for _, slot in Config.Equipment.Slots do
		local id = worn[slot]
		if id ~= nil then
			for _, plan in GearPlan.parts(id, slot) do
				if #out < Config.ArtGear.MaxPartsPerPlayer then
					table.insert(out, plan)
				end
			end
		end
	end
	return out
end

-- Parts the slot would add (0 for an unknown slot).
function GearPlan.slotBudget(slot: string): number
	local specs = Config.ArtGear.Parts[slot]
	return if specs then #specs else 0
end

return GearPlan
