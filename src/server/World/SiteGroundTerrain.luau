--!strict
-- Roblox Terrain adapter for shared/logic/SiteGround plans: levels the voxel columns under a footprint to the
-- plan's base height (cut where higher, fill where lower) and blends back to the original ground across
-- Config.SiteGround.SkirtWidth, so a structure sits on terrain with no hard-edged pad and is never sunk.
-- Per row, equal columns merge into one FillBlock. The caller owns undoing it (the chunk is rebuilt from the
-- pure height field when the structure is destroyed; see MassiveService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SiteGround = require(Shared:WaitForChild("logic"):WaitForChild("SiteGround"))
local TerrainBuilder = require(script.Parent:WaitForChild("TerrainBuilder"))

local SiteGroundTerrain = {}

local SIZE = Config.Terrain.BlockSize
local OVERLAP = Config.Terrain.BlockSize -- studs a fill reaches down into existing terrain (no seams)

type Run = { x: number, z: number, n: number, ground: number, target: number }

local function flush(run: Run?)
	if run == nil then
		return
	end
	local terrain = Workspace.Terrain
	local width = run.n * SIZE
	local cx = run.x + (run.n - 1) * SIZE / 2
	if run.target > run.ground then
		local bottom = run.ground - OVERLAP
		terrain:FillBlock(
			CFrame.new(cx, (bottom + run.target) / 2, run.z),
			Vector3.new(width, run.target - bottom, SIZE),
			TerrainBuilder.materialAt(run.x, run.z)
		)
	else
		terrain:FillBlock(
			CFrame.new(cx, (run.ground + run.target) / 2, run.z),
			Vector3.new(width, run.ground - run.target, SIZE),
			Enum.Material.Air
		)
	end
end

-- Levels the terrain for `plan`. heightFn = the original ground (World.heightAt closure). Returns columns changed.
function SiteGroundTerrain.apply(plan: SiteGround.Plan, heightFn: SiteGround.HeightFn): number
	local reach = Config.SiteGround.SkirtWidth
	local ix0 = math.floor((plan.cx - plan.halfX - reach) / SIZE)
	local ix1 = math.ceil((plan.cx + plan.halfX + reach) / SIZE) - 1
	local iz0 = math.floor((plan.cz - plan.halfZ - reach) / SIZE)
	local iz1 = math.ceil((plan.cz + plan.halfZ + reach) / SIZE) - 1
	local changed = 0
	for iz = iz0, iz1 do
		local zc = (iz + 0.5) * SIZE
		local run: Run? = nil
		for ix = ix0, ix1 do
			local xc = (ix + 0.5) * SIZE
			local ground = heightFn(xc, zc)
			local target = SiteGround.targetHeight(plan, ground, xc, zc)
			if target == ground then
				flush(run)
				run = nil
			else
				changed += 1
				if run and run.ground == ground and run.target == target then
					run.n += 1
				else
					flush(run)
					run = { x = xc, z = zc, n = 1, ground = ground, target = target }
				end
			end
		end
		flush(run)
	end
	return changed
end

-- World-space axis-aligned rect (centre + halves) of a local rect under a frame whose rotation is a multiple of 90 degrees.
function SiteGroundTerrain.worldRect(
	frame: CFrame,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number
): (number, number, number, number)
	local lox, hix, loz, hiz = math.huge, -math.huge, math.huge, -math.huge
	for _, x in { minX, maxX } do
		for _, z in { minZ, maxZ } do
			local p = frame:PointToWorldSpace(Vector3.new(x, 0, z))
			lox, hix = math.min(lox, p.X), math.max(hix, p.X)
			loz, hiz = math.min(loz, p.Z), math.max(hiz, p.Z)
		end
	end
	return (lox + hix) / 2, (loz + hiz) / 2, (hix - lox) / 2, (hiz - loz) / 2
end

return SiteGroundTerrain
