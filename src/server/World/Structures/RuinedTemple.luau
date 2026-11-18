--!strict
-- Ruined temple in the deep tundra (ring 2-3): courtyard, great hall, side chambers, crypt, legendary chamber.
-- build(origin, seed, parent) -> StructureKitB.Handle. origin: footprint centre (Y ignored: ground is sampled).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TemplePlan = require(Shared:WaitForChild("logic"):WaitForChild("TemplePlan"))
local StructureKitB = require(script.Parent:WaitForChild("StructureKitB"))

local RuinedTemple = {}

RuinedTemple.Id = "RuinedTemple"

function RuinedTemple.build(origin: Vector3, seed: number, parent: Instance): StructureKitB.Handle
	return StructureKitB.build(TemplePlan.make(seed), origin, seed, parent)
end

return RuinedTemple
