--!strict
-- Real-terrain ground probe (server adapter). World.heightAt is the *planned* height; the built voxel terrain can
-- differ (voxel size, smoothing, chunk not built yet). GroundProbe.groundY raycasts the actual Terrain, so fires,
-- spawn pads and structures sit on what the player sees. Falls back to the supplied height when nothing is hit
-- (chunk unbuilt, headless).

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GroundFix = require(Shared:WaitForChild("logic"):WaitForChild("GroundFix"))

local RAY_UP = 80 -- studs above the planned height the ray starts (covers a terrain that is higher than planned)
local RAY_LENGTH = 400
local SETTLE_FRAMES = 6 -- Heartbeats a placed part is re-verified after placement
local SETTLE_TOLERANCE = 0.2
local SETTLE_MAX_DROP = 6 -- never sink a part further than this (a ray that hit something odd)

local GroundProbe = {}

local params: RaycastParams? = nil

local function rayParams(): RaycastParams
	local existing = params
	if existing ~= nil then
		return existing
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = { Workspace.Terrain }
	params = p
	return p
end

-- Real terrain surface Y at (x, z), or nil when the raycast hits no terrain.
function GroundProbe.raycastY(x: number, z: number, nearY: number): number?
	local hit = Workspace:Raycast(
		Vector3.new(x, nearY + RAY_UP, z),
		Vector3.new(0, -RAY_LENGTH, 0),
		rayParams()
	)
	return if hit then hit.Position.Y else nil
end

function GroundProbe.groundY(x: number, z: number, fallbackY: number): number
	return GroundProbe.raycastY(x, z, fallbackY) or fallbackY
end

-- Highest real surface under a footprint (centre + corners), or nil if nothing was hit.
local function footprintSurface(
	x: number,
	z: number,
	sizeX: number,
	sizeZ: number,
	nearY: number
): number?
	local top: number? = nil
	local hx, hz = sizeX / 2, sizeZ / 2
	for _, o in { { 0, 0 }, { -hx, -hz }, { hx, -hz }, { -hx, hz }, { hx, hz } } do
		local y = GroundProbe.raycastY(x + o[1], z + o[2], nearY)
		if y ~= nil and (top == nil or y > top) then
			top = y
		end
	end
	return top
end

-- Re-verifies an anchored part's bottom against the real terrain for a few frames after placement and shifts it
-- onto the surface when it is buried or floating. Runs off the caller's thread. Returns nothing.
function GroundProbe.settle(part: BasePart)
	task.spawn(function()
		for _ = 1, SETTLE_FRAMES do
			task.wait()
			if part.Parent == nil then
				return
			end
			local pos, size = part.Position, part.Size
			local surface = footprintSurface(pos.X, pos.Z, size.X, size.Z, pos.Y)
			if surface ~= nil then
				local delta = GroundFix.clampedCorrection(
					pos.Y - size.Y / 2,
					surface,
					SETTLE_TOLERANCE,
					SETTLE_MAX_DROP
				)
				if delta ~= nil then
					part.Position = pos + Vector3.new(0, delta, 0)
				end
			end
		end
	end)
end

return GroundProbe
