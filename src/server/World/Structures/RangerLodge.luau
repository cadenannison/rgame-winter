--!strict
-- Ranger lodge in the forest ring (ring 0-1): kitchen, bunk room, hearth, cellar.
-- build(origin, seed, parent) -> StructureKitB.Handle. origin: footprint centre (Y ignored: ground is sampled).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LodgePlan = require(Shared:WaitForChild("logic"):WaitForChild("LodgePlan"))
local StructureKitB = require(script.Parent:WaitForChild("StructureKitB"))

local RangerLodge = {}

RangerLodge.Id = "RangerLodge"

function RangerLodge.build(origin: Vector3, seed: number, parent: Instance): StructureKitB.Handle
	return StructureKitB.build(LodgePlan.make(seed), origin, seed, parent)
end

return RangerLodge
