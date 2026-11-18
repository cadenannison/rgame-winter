--!strict
-- Shared builder helper for creature Defs: every visual part is a Motor6D child of its parent part.
-- Joint is named "J_<partName>", Part0 = parent, Part1 = the new part, C0 = offset (rest pose).

local CreatureBuild = {}

export type PartOpts = {
	name: string,
	parent: BasePart, -- root or another creature part
	size: Vector3,
	offset: CFrame, -- position of the new part relative to `parent` (becomes joint C0)
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	neon: boolean?,
	pivot: CFrame?, -- joint C1 (defaults identity: part rotates about its own centre)
}

function CreatureBuild.part(opts: PartOpts): BasePart
	local part = Instance.new("Part")
	part.Name = opts.name
	part.Size = opts.size
	part.Color = opts.color
	part.Material = if opts.neon
		then Enum.Material.Neon
		else (opts.material or Enum.Material.SmoothPlastic)
	part.Shape = opts.shape or Enum.PartType.Block
	part.Transparency = opts.transparency or 0
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Anchored = false
	part.CFrame = opts.parent.CFrame * opts.offset
	local joint = Instance.new("Motor6D")
	joint.Name = "J_" .. opts.name
	joint.Part0 = opts.parent
	joint.Part1 = part
	joint.C0 = opts.offset
	joint.C1 = opts.pivot or CFrame.identity
	joint.Parent = part
	part.Parent = opts.parent.Parent
	return part
end

function CreatureBuild.attachment(parent: BasePart, name: string, offset: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = offset
	a.Parent = parent
	return a
end

function CreatureBuild.countParts(model: Instance): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	if model:IsA("BasePart") then
		n += 1
	end
	return n
end

return CreatureBuild
