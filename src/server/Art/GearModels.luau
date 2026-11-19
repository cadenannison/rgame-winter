--!strict
-- Worn gear parts for the R15 character. Part-built, WeldConstraint to the R15 part (no Motor6D, no scripts),
-- Massless + non-colliding so animations, the held tool and movement are unaffected. Server-built under
-- character.<Config.ArtGear.FolderName> so it replicates. Plans come from shared/logic/GearPlan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local GearPlan = require(Shared.logic.GearPlan)

local GearModels = {}

local function gearFolder(character: Model): Folder
	local existing = character:FindFirstChild(Config.ArtGear.FolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = Config.ArtGear.FolderName
	folder.Parent = character
	return folder
end

-- Parts currently in the folder for `slot`.
function GearModels.slotParts(character: Model, slot: string): { BasePart }
	local out: { BasePart } = {}
	local folder = character:FindFirstChild(Config.ArtGear.FolderName)
	if folder then
		for _, child in folder:GetChildren() do
			if
				child:IsA("BasePart")
				and child:GetAttribute(Config.ArtGear.PartAttribute) == slot
			then
				table.insert(out, child)
			end
		end
	end
	return out
end

function GearModels.clearSlot(character: Model, slot: string)
	for _, part in GearModels.slotParts(character, slot) do
		part:Destroy()
	end
end

function GearModels.clearAll(character: Model)
	local folder = character:FindFirstChild(Config.ArtGear.FolderName)
	if folder then
		folder:Destroy()
	end
end

-- Builds the parts for `itemId` worn in `slot`. Replaces any parts already built for that slot. Parts whose
-- R15 rig part is missing are skipped (caller may retry); the per-player cap is enforced here.
function GearModels.build(itemId: string, slot: string, character: Model): { BasePart }
	GearModels.clearSlot(character, slot)
	local built: { BasePart } = {}
	local folder = gearFolder(character)
	local used = #folder:GetChildren()
	for _, plan in GearPlan.parts(itemId, slot) do
		if used >= Config.ArtGear.MaxPartsPerPlayer then
			break
		end
		local rig = character:FindFirstChild(plan.rig)
		if rig and rig:IsA("BasePart") then
			local sx, sy, sz = GearPlan.size(plan, rig.Size.X, rig.Size.Y, rig.Size.Z)
			local part = Instance.new("Part")
			part.Name = plan.name
			part.Size = Vector3.new(sx, sy, sz)
			part.Color = Color3.fromRGB(plan.color[1], plan.color[2], plan.color[3])
			local ok, material = pcall(function(): Enum.Material
				return (Enum.Material :: any)[plan.material]
			end)
			part.Material = if ok then material else Enum.Material.Fabric
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			part.CastShadow = false
			part.CFrame = rig.CFrame * CFrame.new(plan.offset[1], plan.offset[2], plan.offset[3])
			part:SetAttribute(Config.ArtGear.PartAttribute, slot)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rig
			weld.Part1 = part
			weld.Parent = part
			part.Parent = folder
			used += 1
			table.insert(built, part)
		end
	end
	return built
end

return GearModels
