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

export type Result = { ok: boolean, reason: string }

local Placement = {}

local function finite(v: number): boolean
	return v == v and v ~= math.huge and v ~= -math.huge
end

-- Snaps a coordinate to the nearest multiple of step.
function Placement.snap(v: number, step: number): number
	return math.floor(v / step + 0.5) * step
end

-- Snaps an XZ point to the build grid (client ghost and server place handler share this).
function Placement.snapPoint(x: number, z: number, step: number): Point
	return { x = Placement.snap(x, step), z = Placement.snap(z, step) }
end

-- Snaps degrees to a multiple of step, wrapped to [0, 360).
function Placement.snapRotation(degrees: number, step: number): number
	return Placement.snap(degrees, step) % 360
end

local function dist(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- The single rule set for "can this structure go here". Used by the client ghost (tint + reason) and the
-- server place handler (authoritative). Returns {ok, reason}. reason: "UnknownStructure" | "BadPosition" | "OutOfRange" | "TooClose"
-- | "OutOfBuildRange" | "StructureCap" | "FireCap" | "MissingItem" | "Ok".
function Placement.validate(c: Check): Result
	local def = ItemCatalog.Structures[c.structureId]
	if def == nil then
		return { ok = false, reason = "UnknownStructure" }
	end
	if not (finite(c.target.x) and finite(c.target.z)) then
		return { ok = false, reason = "BadPosition" }
	end
	if dist(c.target, c.player) > c.placeRange then
		return { ok = false, reason = "OutOfRange" }
	end
	if not c.buildExempt and not FireTiers.inBuildRange(c.litFires, c.target.x, c.target.z) then
		return { ok = false, reason = "OutOfBuildRange" }
	end
	for _, other in c.others do
		if dist(c.target, other) < c.minSpacing then
			return { ok = false, reason = "TooClose" }
		end
	end
	if c.ownedCount >= c.maxOwned then
		return { ok = false, reason = "StructureCap" }
	end
	if def.role == "campfire" and c.fireCount >= c.maxFires then
		return { ok = false, reason = "FireCap" }
	end
	if c.itemCount < 1 then
		return { ok = false, reason = "MissingItem" }
	end
	return { ok = true, reason = "Ok" }
end

-- Tuple form of validate: (ok, reason).
function Placement.check(c: Check): (boolean, string)
	local r = Placement.validate(c)
	return r.ok, r.reason
end

return Placement
