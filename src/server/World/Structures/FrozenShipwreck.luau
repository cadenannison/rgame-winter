--!strict
-- Frozen shipwreck on the lake ice (ring 1): hull, three decks, hold, captain's quarters, flooded lower deck.
-- build(origin, seed, parent) -> StructureKitB.Handle. origin: footprint centre (Y ignored: ground is sampled).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShipwreckPlan = require(Shared:WaitForChild("logic"):WaitForChild("ShipwreckPlan"))
local StructureKitB = require(script.Parent:WaitForChild("StructureKitB"))

local FrozenShipwreck = {}

FrozenShipwreck.Id = "FrozenShipwreck"

function FrozenShipwreck.build(
	origin: Vector3,
	seed: number,
	parent: Instance
): StructureKitB.Handle
	return StructureKitB.build(ShipwreckPlan.make(seed), origin, seed, parent)
end

return FrozenShipwreck
