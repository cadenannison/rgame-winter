--!strict
-- ResearchStation builder (massive structures A). Interface: build(origin, seed, parent) -> Handle; see StructureKitA.
-- The layout, loot slots, lights and dressing come from the pure plan shared/logic/ResearchStationPlan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Plan = require(Shared:WaitForChild("logic"):WaitForChild("ResearchStationPlan"))
local StructureKitA = require(script.Parent:WaitForChild("StructureKitA"))

local ResearchStation = {}

export type Handle = StructureKitA.Handle

function ResearchStation.build(origin: Vector3, seed: number, parent: Instance): Handle
	return StructureKitA.build(Plan.plan(seed), origin, seed, parent)
end

return ResearchStation
