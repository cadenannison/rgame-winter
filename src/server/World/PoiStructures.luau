--!strict
-- Adapter: turns a PoiPlan (pure boxes) into anchored Parts under a Model. No gameplay here (crate, hearth
-- and prompts stay in PoiService). Walls/roof/floor/foundation collide; furniture and trim as planned.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ArtKit = require(Shared:WaitForChild("ArtKit"))
local PoiPlan = require(Shared:WaitForChild("logic"):WaitForChild("PoiPlan"))

local P = ArtKit.palette(Config.Art.World.Palette)

local PoiStructures = {}

export type Style = { color: Color3, material: Enum.Material, transparency: number? }

local function darker(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local STYLES: { [string]: Style } = {
	Wall = { color = P.Wood, material = Enum.Material.Wood },
	WallDark = { color = P.WoodDark, material = Enum.Material.Wood },
	Floor = { color = darker(P.Wood, 0.8), material = Enum.Material.WoodPlanks },
	Roof = { color = P.Roof, material = Enum.Material.Wood },
	Snow = { color = P.Snow, material = Enum.Material.Snow },
	Stone = { color = P.Ruin, material = Enum.Material.Slate },
	StoneDark = { color = P.RuinDark, material = Enum.Material.Slate },
	Metal = { color = P.Metal, material = Enum.Material.Metal },
	MetalDark = { color = P.MetalDark, material = Enum.Material.Metal },
	Rock = { color = P.Rock, material = Enum.Material.Rock },
	RockDark = { color = P.RockDark, material = Enum.Material.Rock },
	CaveFloor = { color = P.Cave, material = Enum.Material.Slate },
	Window = { color = P.Window, material = Enum.Material.Neon, transparency = 0.1 },
	Glass = { color = darker(P.Rune, 0.5), material = Enum.Material.Glass, transparency = 0.35 },
	Lamp = { color = P.Window, material = Enum.Material.Neon },
	Crystal = { color = P.Rune, material = Enum.Material.Neon, transparency = 0.3 },
	Rune = { color = P.Rune, material = Enum.Material.Neon, transparency = 0.3 },
	Tent = { color = P.Tent, material = Enum.Material.Metal },
	TentAlt = { color = P.TentAlt, material = Enum.Material.Fabric },
	Blanket = { color = P.Tent, material = Enum.Material.Fabric },
	Pillow = { color = P.TentAlt, material = Enum.Material.Fabric },
	Scorch = { color = P.Scorch, material = Enum.Material.Slate },
	Foundation = { color = P.RuinDark, material = Enum.Material.Slate },
}

local LIGHT_COLORS: { [string]: Color3 } = {
	Warm = Color3.fromRGB(255, 170, 90),
	Cold = Color3.fromRGB(170, 200, 230),
	Rune = P.Rune,
}

-- Shared look-up so the massive structure builders (World/Structures) match the small POIs and the palette.
function PoiStructures.styleOf(name: string): Style?
	return STYLES[name]
end

function PoiStructures.lightColor(name: string): Color3
	return LIGHT_COLORS[name] or LIGHT_COLORS.Warm
end

local function degrees(v: number?): number
	return math.rad(v or 0)
end

-- Builds the plan's boxes under `parent` at `base` (floor-top centre, +Z = front). Returns the model.
function PoiStructures.build(parent: Instance, plan: PoiPlan.Plan, base: CFrame): Model
	local model = Instance.new("Model")
	model.Name = `{plan.kind}_{plan.variant}`
	model:SetAttribute("PoiVariant", plan.variant)
	for _, box in plan.boxes do
		local style = STYLES[box.style] or STYLES.Wall
		local part = Instance.new("Part")
		part.Name = box.name
		part.Anchored = true
		part.Size = Vector3.new(box.sx, box.sy, box.sz)
		part.CFrame = base
			* CFrame.new(box.x, box.y, box.z)
			* CFrame.Angles(degrees(box.rx), degrees(box.ry), degrees(box.rz))
		part.Color = style.color
		part.Material = style.material
		part.Transparency = style.transparency or 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CastShadow = box.collide
		part.CanTouch = false
		part.CanCollide = box.collide
		part.CanQuery = box.collide
		if box.light then
			local light = Instance.new("PointLight")
			light.Name = "InteriorLight"
			light.Color = LIGHT_COLORS[box.light.color] or LIGHT_COLORS.Warm
			light.Range = box.light.range
			light.Brightness = box.light.brightness
			light.Shadows = false
			light.Parent = part
		end
		part.Parent = model
	end
	model.Parent = parent
	return model
end

return PoiStructures
