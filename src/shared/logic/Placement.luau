--!strict
-- Pure placement rules: grid snapping and the structure checks the server runs before placing.

local ItemCatalog = require("../ItemCatalog")
local FireTiers = require("./FireTiers")

export type Point = { x: number, z: number }
export type BuildFire = FireTiers.BuildFire

export type Check = {
	structureId: string,
	target: Point, -- snapped placement point
	player: Point, -- placer position
	placeRange: number,
	minSpacing: number,
	others: { Point }, -- existing structures
	ownedCount: number,
	maxOwned: number,
	fireCount: number,
	maxFires: number,
	itemCount: number, -- how many of the structure's item the player holds
	litFires: { FireTiers.BuildFire }, -- lit campfires with their tier build radius
	buildExempt: boolean, -- structure is exempt from the build radius (Config.Build.RangeExempt)
}

local Placement = {}

local function finite(v: number): boolean
	return v == v and v ~= math.huge and v ~= -math.huge
end

-- Snaps a coordinate to the nearest multiple of step.
function Placement.snap(v: number, step: number): number
	return math.floor(v / step + 0.5) * step
end

-- Snaps degrees to a multiple of step, wrapped to [0, 360).
function Placement.snapRotation(degrees: number, step: number): number
	return Placement.snap(degrees, step) % 360
end

local function dist(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Returns (ok, reason). reason: "UnknownStructure" | "BadPosition" | "OutOfRange" | "TooClose"
-- | "OutOfBuildRange" | "StructureCap" | "FireCap" | "MissingItem" | "Ok".
function Placement.check(c: Check): (boolean, string)
	local def = ItemCatalog.Structures[c.structureId]
	if def == nil then
		return false, "UnknownStructure"
	end
	if not (finite(c.target.x) and finite(c.target.z)) then
		return false, "BadPosition"
	end
	if dist(c.target, c.player) > c.placeRange then
		return false, "OutOfRange"
	end
	if not c.buildExempt and not FireTiers.inBuildRange(c.litFires, c.target.x, c.target.z) then
		return false, "OutOfBuildRange"
	end
	for _, other in c.others do
		if dist(c.target, other) < c.minSpacing then
			return false, "TooClose"
		end
	end
	if c.ownedCount >= c.maxOwned then
		return false, "StructureCap"
	end
	if def.role == "campfire" and c.fireCount >= c.maxFires then
		return false, "FireCap"
	end
	if c.itemCount < 1 then
		return false, "MissingItem"
	end
	return true, "Ok"
end

return Placement
