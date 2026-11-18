--!strict
-- Shared geometry helpers for the world prop modules (Props/*): Part/Model factories, rotation and shade
-- helpers, the art palette and materials, and the part counter. No gameplay logic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ArtKit = require(ReplicatedStorage.Shared.ArtKit)

local W = Config.Art.World
local P = ArtKit.palette(W.Palette)

local PropKit = {
	W = W,
	P = P,
	Material = {
		WOOD = Enum.Material.Wood,
		SLATE = Enum.Material.Slate,
		ROCK = Enum.Material.Rock,
		SNOW = Enum.Material.Snow,
		ICE = Enum.Material.Ice,
		NEON = Enum.Material.Neon,
		METAL = Enum.Material.Metal,
		GRASS = Enum.Material.Grass,
		FABRIC = Enum.Material.Fabric,
		GLASS = Enum.Material.Glass,
		PLASTIC = Enum.Material.SmoothPlastic,
	},
}

export type Opts = { collide: boolean?, shape: Enum.PartType?, transparency: number? }

function PropKit.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.CanTouch = false
	local o: Opts = opts or ({} :: Opts)
	p.CanCollide = o.collide == true
	p.CanQuery = o.collide == true
	if o.shape then
		p.Shape = o.shape
	end
	if o.transparency then
		p.Transparency = o.transparency
	end
	p.Parent = parent
	return p
end

function PropKit.model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function PropKit.rad(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

function PropKit.shade(color: Color3, f: number): Color3
	return Color3.new(
		math.clamp(color.R * f, 0, 1),
		math.clamp(color.G * f, 0, 1),
		math.clamp(color.B * f, 0, 1)
	)
end
-- BasePart count under root (budget checks, tools/qa, gallery).
function PropKit.count(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return PropKit
