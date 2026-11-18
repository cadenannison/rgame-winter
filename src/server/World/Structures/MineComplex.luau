--!strict
-- MineComplex builder (massive structures A). Interface: build(origin, seed, parent) -> Handle; see StructureKitA.
-- The layout, loot slots, lights and dressing come from the pure plan shared/logic/MineComplexPlan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Plan = require(Shared:WaitForChild("logic"):WaitForChild("MineComplexPlan"))
local StructureKitA = require(script.Parent:WaitForChild("StructureKitA"))

local MineComplex = {}

export type Handle = StructureKitA.Handle

function MineComplex.build(origin: Vector3, seed: number, parent: Instance): Handle
	return StructureKitA.build(Plan.plan(seed), origin, seed, parent)
end

return MineComplex
