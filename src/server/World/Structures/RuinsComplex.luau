--!strict
-- Expanded ruins complex (ring 1-3): yard, hall, wings, inner court, archive, tower, crypt, cellar, cistern, treasury.
-- build(origin, seed, parent) -> StructureKitB.Handle. origin: footprint centre (Y ignored: ground is sampled).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RuinsPlan = require(Shared:WaitForChild("logic"):WaitForChild("RuinsPlan"))
local StructureKitB = require(script.Parent:WaitForChild("StructureKitB"))

local RuinsComplex = {}

RuinsComplex.Id = "ExpandedRuins"

function RuinsComplex.build(origin: Vector3, seed: number, parent: Instance): StructureKitB.Handle
	return StructureKitB.build(RuinsPlan.make(seed), origin, seed, parent)
end

return RuinsComplex
