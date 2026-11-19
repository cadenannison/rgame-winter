--!strict
-- Art Pass 4: pure Part-recipe data for every item model (no Roblox APIs, so headless tests cover it).
-- ItemModels turns a spec into Parts. Authoring rules: units are studs, the model is centred on the origin,
-- long axis is +Y, the FIRST part is the primary/grip part and should be unrotated, parts are ordered by
-- importance (drop mode keeps only the first Config.ArtItems.DropMaxParts), at most MAX_SPEC_PARTS parts.
-- Shapes: "Block" | "Ball" | "Wedge" | "Cylinder" (Cylinder size = {diameter, length, diameter}, axis +Y).
-- rot is degrees {rx, ry, rz} applied about the part's own centre. Every id in ItemCatalog.Items resolves:
-- a bespoke recipe by id, else a generic recipe per kind/equip slot, else a plain block.

local ItemCatalog = require("../ItemCatalog")

export type PartSpec = {
	shape: string,
	size: { number },
	pos: { number },
	rot: { number }?,
	color: { number },
	material: string?,
	transparency: number?,
}
export type ModelSpec = {
	parts: { PartSpec },
	tilt: number, -- icon mode: roll about Z in degrees so long items read diagonally
}

local ItemModelSpec = {}

ItemModelSpec.MaxParts = 6 -- hard authoring cap (Config.ArtItems.ModelMaxParts mirrors it; tests assert both)

type Color = { number }
local WOOD: Color = { 124, 88, 56 }
local DARK_WOOD: Color = { 82, 58, 38 }
local STONE: Color = { 128, 132, 140 }
local DARK_STONE: Color = { 70, 74, 82 }
local IRON: Color = { 168, 174, 184 }
local DARK_IRON: Color = { 84, 88, 98 }
local GOLD: Color = { 232, 192, 72 }
local ICE: Color = { 176, 224, 246 }
local CRYSTAL: Color = { 110, 205, 255 }
local AURORA: Color = { 90, 255, 205 }
local FUR: Color = { 200, 172, 132 }
local WHITE: Color = { 238, 242, 246 }
local RED_MEAT: Color = { 196, 78, 82 }
local COOKED: Color = { 142, 84, 48 }
local HIDE: Color = { 134, 102, 76 }
local BONE: Color = { 228, 222, 202 }
local LEATHER: Color = { 108, 78, 54 }
local EMBER: Color = { 255, 140, 40 }
local COAL: Color = { 36, 38, 44 }
local BLUBBER: Color = { 240, 226, 176 }
local BERRY: Color = { 186, 54, 92 }
local LEAF: Color = { 84, 140, 90 }
local BLUE: Color = { 96, 136, 188 }
local ORANGE: Color = { 220, 130, 60 }

local function part(
	shape: string,
	size: { number },
	pos: { number },
	color: Color,
	material: string?,
	rot: { number }?,
	transparency: number?
): PartSpec
	return {
		shape = shape,
		size = size,
		pos = pos,
		color = color,
		material = material,
		rot = rot,
		transparency = transparency,
	}
end

local function blk(
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	color: Color,
	material: string?,
	rot: { number }?
): PartSpec
	return part("Block", { sx, sy, sz }, { x, y, z }, color, material, rot)
end

local function ball(
	d: number,
	x: number,
	y: number,
	z: number,
	color: Color,
	material: string?
): PartSpec
	return part("Ball", { d, d, d }, { x, y, z }, color, material or "SmoothPlastic")
end

local function ellipsoid(
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	color: Color,
	material: string?
): PartSpec
	return part("Ball", { sx, sy, sz }, { x, y, z }, color, material or "SmoothPlastic")
end

local function cyl(
	d: number,
	len: number,
	x: number,
	y: number,
	z: number,
	color: Color,
	material: string?,
	rot: { number }?
): PartSpec
	return part("Cylinder", { d, len, d }, { x, y, z }, color, material or "SmoothPlastic", rot)
end

local function wedge(
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	color: Color,
	material: string?,
	rot: { number }?
): PartSpec
	return part("Wedge", { sx, sy, sz }, { x, y, z }, color, material, rot)
end

local function spec(parts: { PartSpec }, tilt: number?): ModelSpec
	return { parts = parts, tilt = tilt or 0 }
end

local TOOL_TILT = 35

-- Archetypes ---------------------------------------------------------------------------------------------

local function axe(handle: Color, head: Color, edge: Color): ModelSpec
	return spec({
		cyl(0.3, 3, 0, 0, 0, handle, "Wood"),
		blk(0.9, 0.85, 0.24, 0.5, 1.0, 0, head, "Metal"),
		blk(0.2, 1.1, 0.24, 1.0, 1.0, 0, edge, "Metal"),
	}, TOOL_TILT)
end

local function pickaxe(handle: Color, head: Color): ModelSpec
	return spec({
		cyl(0.3, 3, 0, 0, 0, handle, "Wood"),
		blk(2.0, 0.3, 0.28, 0, 1.3, 0, head, "Metal"),
		blk(0.3, 0.7, 0.26, -1.05, 1.1, 0, head, "Metal", { 0, 0, 25 }),
		blk(0.3, 0.7, 0.26, 1.05, 1.1, 0, head, "Metal", { 0, 0, -25 }),
	}, TOOL_TILT)
end

local function spear(shaft: Color, tip: Color, wrap: Color): ModelSpec
	return spec({
		cyl(0.22, 4.4, 0, 0, 0, shaft, "Wood"),
		blk(0.36, 1.1, 0.1, 0, 2.6, 0, tip, "Metal"),
		blk(0.1, 1.1, 0.36, 0, 2.6, 0, tip, "Metal"),
		blk(0.3, 0.25, 0.3, 0, 1.9, 0, wrap, "Fabric"),
	}, TOOL_TILT)
end

local function sword(blade: Color, guard: Color, hilt: Color): ModelSpec
	return spec({
		blk(0.36, 2.4, 0.08, 0, 0.7, 0, blade, "Metal"),
		blk(1.1, 0.18, 0.22, 0, -0.55, 0, guard, "Metal"),
		cyl(0.2, 0.8, 0, -1.0, 0, hilt, "Wood"),
		ball(0.34, 0, -1.45, 0, guard, "Metal"),
	}, TOOL_TILT)
end

local function lantern(frame: Color, glow: Color, size: number): ModelSpec
	local s = size
	return spec({
		blk(0.8 * s, 1.0 * s, 0.8 * s, 0, 0, 0, frame, "Metal", nil),
		ball(0.55 * s, 0, 0, 0, glow, "Neon"),
		blk(0.95 * s, 0.16 * s, 0.95 * s, 0, 0.58 * s, 0, frame, "Metal"),
		blk(0.95 * s, 0.16 * s, 0.95 * s, 0, -0.58 * s, 0, frame, "Metal"),
		blk(0.12 * s, 0.6 * s, 0.12 * s, 0, 0.98 * s, 0, frame, "Metal"),
	}, 0)
end

local function torch(head: Color, flame: Color): ModelSpec
	return spec({
		cyl(0.32, 2.4, 0, 0, 0, WOOD, "Wood"),
		ball(0.62, 0, 1.3, 0, head, "Slate"),
		ball(0.5, 0, 1.75, 0, flame, "Neon"),
	}, 20)
end

local function hood(base: Color, trim: Color): ModelSpec
	return spec({
		ball(1.5, 0, 0.1, 0, base, "Fabric"),
		blk(1.3, 0.28, 1.2, 0, -0.55, 0, trim, "Fabric"),
		blk(0.8, 0.7, 0.3, 0, -0.1, 0.62, COAL, "SmoothPlastic"),
	}, 0)
end

local function coat(base: Color, trim: Color): ModelSpec
	return spec({
		blk(1.4, 1.6, 0.8, 0, 0, 0, base, "Fabric"),
		blk(0.5, 1.3, 0.6, -0.97, -0.1, 0, base, "Fabric"),
		blk(0.5, 1.3, 0.6, 0.97, -0.1, 0, base, "Fabric"),
		blk(1.1, 0.3, 0.95, 0, 0.85, 0, trim, "Fabric"),
		blk(1.4, 0.2, 0.84, 0, -0.75, 0, trim, "Fabric"),
	}, 0)
end

local function boots(base: Color, trim: Color): ModelSpec
	return spec({
		blk(0.65, 0.5, 1.15, -0.45, -0.3, 0.15, base, "Fabric"),
		blk(0.65, 0.5, 1.15, 0.45, -0.3, 0.15, base, "Fabric"),
		blk(0.6, 0.75, 0.62, -0.45, 0.2, -0.1, base, "Fabric"),
		blk(0.6, 0.75, 0.62, 0.45, 0.2, -0.1, base, "Fabric"),
		blk(0.66, 0.18, 0.66, -0.45, 0.62, -0.1, trim, "Fabric"),
		blk(0.66, 0.18, 0.66, 0.45, 0.62, -0.1, trim, "Fabric"),
	}, 0)
end

local function legs(base: Color, trim: Color): ModelSpec
	return spec({
		blk(0.6, 1.5, 0.6, -0.4, 0, 0, base, "Fabric"),
		blk(0.6, 1.5, 0.6, 0.4, 0, 0, base, "Fabric"),
		blk(1.4, 0.25, 0.7, 0, 0.8, 0, trim, "Fabric"),
	}, 0)
end

local function gloves(base: Color, trim: Color): ModelSpec
	return spec({
		blk(0.6, 0.8, 0.35, -0.45, 0, 0, base, "Fabric"),
		blk(0.6, 0.8, 0.35, 0.45, 0, 0, base, "Fabric"),
		blk(0.66, 0.2, 0.4, -0.45, -0.4, 0, trim, "Fabric"),
		blk(0.66, 0.2, 0.4, 0.45, -0.4, 0, trim, "Fabric"),
	}, 0)
end

local function scarf(base: Color, trim: Color): ModelSpec
	return spec({
		cyl(1.3, 0.35, 0, 0, 0, base, "Fabric", { 0, 0, 0 }),
		blk(0.4, 1.0, 0.12, 0.3, -0.7, 0.55, base, "Fabric"),
		blk(0.42, 0.16, 0.14, 0.3, -1.1, 0.55, trim, "Fabric"),
	}, 0)
end

local function charm(base: Color, glow: Color): ModelSpec
	return spec({
		cyl(1.0, 0.18, 0, 0, 0, base, "Metal", { 90, 0, 0 }),
		ball(0.5, 0, 0, 0.1, glow, "Neon"),
	}, 0)
end

-- Generic recipes ----------------------------------------------------------------------------------------

local function gem(color: Color, size: number): ModelSpec
	return spec({
		blk(0.5 * size, 1.2 * size, 0.5 * size, 0, 0, 0, color, "Neon", { 0, 25, 8 }),
		blk(
			0.4 * size,
			0.9 * size,
			0.4 * size,
			0.5 * size,
			-0.15 * size,
			0.1 * size,
			color,
			"Neon",
			{ 0, 0, -28 }
		),
	}, 0)
end

local function lump(color: Color, material: string): ModelSpec
	return spec({
		ellipsoid(1.1, 0.9, 1.0, 0, 0, 0, color, material),
		ball(0.6, 0.45, -0.2, 0.35, color, material),
	}, 0)
end

local function genericResource(): ModelSpec
	return lump(STONE, "Slate")
end

local function genericTool(): ModelSpec
	return axe(WOOD, IRON, IRON)
end

local function genericWeapon(): ModelSpec
	return sword(IRON, DARK_IRON, WOOD)
end

local function genericFood(): ModelSpec
	return spec({
		ellipsoid(1.1, 0.7, 0.9, 0, 0, 0, RED_MEAT, "SmoothPlastic"),
		cyl(0.25, 0.9, 0.55, 0.2, 0, BONE, "SmoothPlastic", { 0, 0, 70 }),
	}, 0)
end

local function genericClothing(slot: string?): ModelSpec
	if slot == "Head" then
		return hood(HIDE, FUR)
	elseif slot == "Feet" then
		return boots(HIDE, FUR)
	elseif slot == "Legs" then
		return legs(HIDE, FUR)
	elseif slot == "Hands" then
		return gloves(HIDE, FUR)
	elseif slot == "Neck" then
		return scarf(HIDE, FUR)
	elseif slot == "Accessory1" or slot == "Accessory2" then
		return charm(GOLD, AURORA)
	end
	return coat(HIDE, FUR)
end

local function genericLight(): ModelSpec
	return torch(DARK_WOOD, EMBER)
end

local function genericPlaceable(): ModelSpec
	return spec({
		blk(1.8, 1.2, 1.8, 0, 0, 0, WOOD, "Wood"),
		blk(2.0, 0.2, 2.0, 0, 0.7, 0, DARK_WOOD, "Wood"),
	}, 0)
end

local function genericMap(): ModelSpec
	return spec({
		blk(1.5, 0.08, 1.1, 0, 0, 0, { 226, 210, 168 }, "Fabric"),
		cyl(0.2, 1.2, 0.8, 0.05, 0, WOOD, "Wood", { 0, 0, 90 }),
		blk(0.5, 0.02, 0.5, -0.2, 0.05, 0, { 90, 130, 170 }, "SmoothPlastic"),
	}, 0)
end

local function genericAmmo(): ModelSpec
	return spec({
		cyl(0.1, 1.8, 0, 0, 0, WOOD, "Wood"),
		blk(0.2, 0.45, 0.06, 0, 1.0, 0, IRON, "Metal"),
		blk(0.32, 0.4, 0.03, 0, -0.8, 0, WHITE, "Fabric"),
	}, TOOL_TILT)
end

local BY_KIND: { [string]: (string?) -> ModelSpec } = {
	resource = genericResource,
	tool = genericTool,
	weapon = genericWeapon,
	food = genericFood,
	clothing = genericClothing,
	light = genericLight,
	placeable = genericPlaceable,
	map = genericMap,
	ammo = genericAmmo,
}

-- Bespoke recipes by item id ---------------------------------------------------------------------------

local BESPOKE: { [string]: () -> ModelSpec } = {
	-- Tools
	Axe = function()
		return axe(WOOD, STONE, DARK_STONE)
	end,
	Pickaxe = function()
		return pickaxe(WOOD, STONE)
	end,
	StonePickaxe = function()
		return pickaxe(DARK_WOOD, DARK_STONE)
	end,
	IronAxe = function()
		return axe(WOOD, IRON, WHITE)
	end,
	IronPickaxe = function()
		return pickaxe(WOOD, IRON)
	end,
	AuroraPickaxe = function()
		return pickaxe(DARK_IRON, AURORA)
	end,
	SunforgedAxe = function()
		return axe(DARK_WOOD, GOLD, EMBER)
	end,
	-- Weapons
	Spear = function()
		return spear(WOOD, STONE, LEATHER)
	end,
	IronSpear = function()
		return spear(WOOD, IRON, LEATHER)
	end,
	FangSpear = function()
		return spear(DARK_WOOD, BONE, HIDE)
	end,
	SunpiercerSpear = function()
		return spear(DARK_WOOD, GOLD, EMBER)
	end,
	AuroraBlade = function()
		return sword(AURORA, DARK_IRON, DARK_WOOD)
	end,
	Bow = function()
		return spec({
			blk(0.2, 0.9, 0.2, 0, 0, 0, DARK_WOOD, "Wood"),
			blk(0.18, 1.3, 0.18, 0.25, 0.95, 0, WOOD, "Wood", { 0, 0, -22 }),
			blk(0.18, 1.3, 0.18, 0.25, -0.95, 0, WOOD, "Wood", { 0, 0, 22 }),
			blk(0.04, 2.9, 0.04, -0.2, 0, 0, WHITE, "Fabric"),
		}, 15)
	end,
	Arrow = genericAmmo,
	-- Lights
	Torch = function()
		return torch(DARK_WOOD, EMBER)
	end,
	BlubberTorch = function()
		return torch(BLUBBER, { 255, 200, 90 })
	end,
	AuroraTorch = function()
		return torch(DARK_STONE, AURORA)
	end,
	Lantern = function()
		return lantern(DARK_IRON, { 255, 190, 90 }, 1)
	end,
	AuroraLantern = function()
		return lantern(DARK_IRON, AURORA, 1.1)
	end,
	SunBeacon = function()
		return lantern(GOLD, { 255, 230, 140 }, 1.3)
	end,
	Flare = function()
		return spec({
			cyl(0.36, 1.7, 0, 0, 0, { 200, 50, 46 }, "SmoothPlastic"),
			cyl(0.42, 0.3, 0, 0.9, 0, DARK_IRON, "Metal"),
			ball(0.4, 0, 1.2, 0, { 255, 90, 70 }, "Neon"),
		}, 20)
	end,
	-- Clothing
	HideHood = function()
		return hood(HIDE, LEATHER)
	end,
	HideCoat = function()
		return coat(HIDE, LEATHER)
	end,
	HideBoots = function()
		return boots(HIDE, LEATHER)
	end,
	FurHood = function()
		return hood(FUR, WHITE)
	end,
	FurCoat = function()
		return coat(FUR, WHITE)
	end,
	FurBoots = function()
		return boots(FUR, WHITE)
	end,
	ArcticHood = function()
		return hood(BLUE, WHITE)
	end,
	ArcticCoat = function()
		return coat(BLUE, WHITE)
	end,
	ArcticBoots = function()
		return boots(BLUE, WHITE)
	end,
	InsulatedCoat = function()
		return coat(ORANGE, DARK_IRON)
	end,
	HideLeggings = function()
		return legs(HIDE, LEATHER)
	end,
	FurLeggings = function()
		return legs(FUR, WHITE)
	end,
	HideGloves = function()
		return gloves(HIDE, LEATHER)
	end,
	FurMittens = function()
		return gloves(FUR, WHITE)
	end,
	FeatherScarf = function()
		return spec({
			blk(1.4, 0.36, 1.1, 0, 0.35, 0, WHITE, "Fabric"),
			blk(0.42, 1.2, 0.22, 0.4, -0.4, 0.58, WHITE, "Fabric"),
			blk(0.42, 0.22, 0.24, 0.4, -1.0, 0.58, ICE, "Fabric"),
		}, 0)
	end,
	FangCharm = function()
		return spec({
			cyl(1.1, 0.1, 0, 0.5, 0, LEATHER, "Fabric", { 90, 0, 0 }),
			wedge(0.32, 0.95, 0.32, 0, -0.2, 0, BONE, "SmoothPlastic"),
			ball(0.3, 0, 0.1, 0, LEATHER, "Fabric"),
		}, 0)
	end,
	AuroraAmulet = function()
		return spec({
			cyl(1.1, 0.1, 0, 0.55, 0, LEATHER, "Fabric", { 90, 0, 0 }),
			cyl(0.95, 0.14, 0, -0.2, 0, GOLD, "Metal", { 90, 0, 0 }),
			ball(0.6, 0, -0.2, 0.05, AURORA, "Neon"),
		}, 0)
	end,
	-- Materials
	Wood = function()
		return spec({
			cyl(0.8, 2.0, 0, 0, 0, WOOD, "Wood", { 0, 0, 90 }),
			cyl(0.7, 0.06, 1.0, 0, 0, { 190, 150, 100 }, "Wood", { 0, 0, 90 }),
			cyl(0.55, 1.6, 0.2, 0.7, 0.1, DARK_WOOD, "Wood", { 0, 0, 90 }),
		}, 0)
	end,
	Stick = function()
		return spec({
			cyl(0.2, 2.0, 0, 0, 0, WOOD, "Wood", { 0, 0, 20 }),
			cyl(0.12, 0.8, 0.2, 0.5, 0, DARK_WOOD, "Wood", { 0, 0, -30 }),
		}, 0)
	end,
	Stone = function()
		return lump(STONE, "Slate")
	end,
	Coal = function()
		return spec({
			blk(0.9, 0.8, 0.8, 0, 0, 0, COAL, "Slate", { 15, 25, 10 }),
			blk(0.6, 0.55, 0.55, 0.55, -0.2, 0.2, COAL, "Slate", { 0, 40, 20 }),
			blk(0.5, 0.45, 0.5, -0.5, -0.25, 0.3, COAL, "Slate", { 20, 0, 35 }),
		}, 0)
	end,
	IronOre = function()
		return spec({
			ellipsoid(1.1, 0.9, 1.0, 0, 0, 0, DARK_STONE, "Slate"),
			blk(0.4, 0.4, 0.4, 0.35, 0.3, 0.2, { 190, 120, 80 }, "Metal", { 20, 30, 10 }),
			blk(0.3, 0.3, 0.3, -0.35, 0.1, 0.4, { 190, 120, 80 }, "Metal", { 0, 15, 40 }),
		}, 0)
	end,
	IronIngot = function()
		return spec({
			blk(1.3, 0.5, 0.7, 0, 0, 0, IRON, "Metal"),
			blk(1.0, 0.2, 0.5, 0, 0.35, 0, WHITE, "Metal"),
		}, 0)
	end,
	ScrapMetal = function()
		return spec({
			blk(1.1, 0.12, 0.8, 0, 0, 0, DARK_IRON, "Metal", { 0, 20, 0 }),
			blk(0.8, 0.12, 0.6, 0.1, 0.15, 0.1, IRON, "Metal", { 0, -30, 12 }),
			blk(0.5, 0.12, 0.7, -0.2, 0.3, 0, { 140, 96, 70 }, "Metal", { 15, 50, 0 }),
		}, 0)
	end,
	Hide = function()
		return spec({
			blk(1.4, 0.18, 1.2, 0, 0, 0, HIDE, "Fabric"),
			blk(0.7, 0.2, 0.6, 0.2, 0.15, 0, LEATHER, "Fabric", { 0, 30, 0 }),
		}, 0)
	end,
	DenseHide = function()
		return spec({
			blk(1.4, 0.3, 1.2, 0, 0, 0, LEATHER, "Fabric"),
			blk(0.9, 0.3, 0.8, 0.1, 0.25, 0, HIDE, "Fabric", { 0, 30, 0 }),
		}, 0)
	end,
	WhiteoutPelt = function()
		return spec({
			blk(1.5, 0.3, 1.3, 0, 0, 0, WHITE, "Fabric"),
			blk(0.8, 0.3, 0.7, 0.1, 0.25, 0, ICE, "Fabric", { 0, 30, 0 }),
		}, 0)
	end,
	Bone = function()
		return spec({
			cyl(0.28, 1.6, 0, 0, 0, BONE, "SmoothPlastic", { 0, 0, 25 }),
			ball(0.45, -0.34, -0.7, 0, BONE),
			ball(0.45, 0.34, 0.7, 0, BONE),
		}, 0)
	end,
	Claw = function()
		return spec({
			wedge(0.35, 1.2, 0.4, 0, 0, 0, BONE, "SmoothPlastic"),
			ball(0.4, 0, -0.55, 0, HIDE),
		}, 0)
	end,
	Fang = function()
		return spec({
			wedge(0.45, 1.3, 0.45, 0, 0, 0, WHITE, "SmoothPlastic"),
			cyl(0.5, 0.2, 0, -0.65, 0, BONE),
		}, 0)
	end,
	MatriarchFang = function()
		return spec({
			wedge(0.6, 1.7, 0.6, 0, 0, 0, ICE, "Glass"),
			cyl(0.65, 0.25, 0, -0.85, 0, BONE),
		}, 0)
	end,
	Feather = function()
		return spec({
			blk(0.5, 1.6, 0.05, 0, 0, 0, WHITE, "Fabric", { 0, 0, 20 }),
			cyl(0.07, 1.8, 0, 0, 0, BONE, "SmoothPlastic", { 0, 0, 20 }),
		}, 0)
	end,
	FrozenReed = function()
		return spec({
			cyl(0.14, 2.2, 0, 0, 0, { 170, 200, 170 }, "SmoothPlastic"),
			ellipsoid(0.3, 0.7, 0.3, 0, 1.0, 0, { 120, 90, 60 }),
			blk(0.1, 0.9, 0.04, 0.2, 0.2, 0, LEAF, "Fabric", { 0, 0, -25 }),
		}, 10)
	end,
	IceBlock = function()
		local p = blk(1.2, 1.2, 1.2, 0, 0, 0, ICE, "Ice")
		p.transparency = 0.25
		return spec({ p, blk(0.4, 0.4, 0.4, 0.3, 0.2, 0.62, WHITE, "Ice") }, 0)
	end,
	IceShard = function()
		return gem(ICE, 1)
	end,
	FrostShard = function()
		return gem({ 150, 190, 255 }, 1.1)
	end,
	CrystalShard = function()
		return gem(CRYSTAL, 0.9)
	end,
	Crystal = function()
		return gem(CRYSTAL, 1.3)
	end,
	AuroraDust = function()
		return spec({
			ball(0.45, 0, 0, 0, AURORA, "Neon"),
			ball(0.3, 0.45, -0.25, 0.1, { 140, 200, 255 }, "Neon"),
			ball(0.25, -0.4, -0.3, 0.2, { 200, 150, 255 }, "Neon"),
		}, 0)
	end,
	Blubber = function()
		return spec({
			ellipsoid(1.2, 0.9, 1.0, 0, 0, 0, BLUBBER, "SmoothPlastic"),
			ellipsoid(0.7, 0.5, 0.6, 0.3, 0.45, 0.1, { 250, 240, 200 }, "SmoothPlastic"),
		}, 0)
	end,
	Rope = function()
		return spec({
			cyl(1.1, 0.25, 0, 0, 0, { 190, 160, 110 }, "Fabric"),
			cyl(0.7, 0.28, 0, 0, 0, { 120, 90, 60 }, "Fabric"),
			cyl(1.1, 0.25, 0, 0.25, 0, { 180, 150, 100 }, "Fabric"),
		}, 18)
	end,
	ColossusHeart = function()
		return spec({
			ellipsoid(1.3, 1.5, 1.2, 0, 0, 0, { 170, 40, 60 }, "Neon"),
			cyl(0.35, 0.6, 0.2, 0.9, 0, { 120, 30, 40 }, "SmoothPlastic"),
			cyl(0.3, 0.5, -0.3, 0.85, 0.1, { 120, 30, 40 }, "SmoothPlastic"),
		}, 0)
	end,
	WardenCore = function()
		return spec({
			ball(0.9, 0, 0, 0, { 120, 200, 255 }, "Neon"),
			cyl(1.5, 0.12, 0, 0, 0, DARK_IRON, "Metal", { 0, 0, 0 }),
			cyl(1.5, 0.12, 0, 0, 0, DARK_IRON, "Metal", { 90, 0, 0 }),
		}, 0)
	end,
	RelicFragment = function()
		return spec({
			wedge(0.9, 1.2, 0.4, 0, 0, 0, GOLD, "Metal"),
			blk(0.5, 0.5, 0.1, 0.2, 0.1, 0.25, AURORA, "Neon", { 0, 0, 30 }),
		}, 0)
	end,
	-- Food
	RawMeat = function()
		return spec({
			ellipsoid(1.2, 0.7, 0.9, 0, 0, 0, RED_MEAT, "SmoothPlastic"),
			cyl(0.22, 0.9, 0.6, 0.15, 0, BONE, "SmoothPlastic", { 0, 0, 70 }),
			ellipsoid(0.7, 0.4, 0.5, -0.1, 0.35, 0, { 232, 150, 150 }, "SmoothPlastic"),
		}, 0)
	end,
	CookedMeat = function()
		return spec({
			ellipsoid(1.2, 0.7, 0.9, 0, 0, 0, COOKED, "SmoothPlastic"),
			cyl(0.22, 0.9, 0.6, 0.15, 0, BONE, "SmoothPlastic", { 0, 0, 70 }),
		}, 0)
	end,
	Venison = function()
		return spec({
			ellipsoid(1.3, 0.8, 1.0, 0, 0, 0, { 150, 60, 62 }, "SmoothPlastic"),
			cyl(0.24, 1.0, 0.7, 0.15, 0, BONE, "SmoothPlastic", { 0, 0, 70 }),
			ellipsoid(0.7, 0.3, 0.6, -0.1, 0.4, 0, { 230, 220, 205 }, "SmoothPlastic"),
		}, 0)
	end,
	RawFish = function()
		return spec({
			ellipsoid(1.7, 0.6, 0.45, 0, 0, 0, { 150, 175, 200 }, "SmoothPlastic"),
			wedge(0.15, 0.6, 0.5, -1.0, 0, 0, { 120, 150, 180 }, "SmoothPlastic", { 0, 0, 90 }),
			ball(0.14, 0.6, 0.1, 0.2, COAL),
		}, 0)
	end,
	CookedFish = function()
		return spec({
			ellipsoid(1.7, 0.6, 0.45, 0, 0, 0, { 210, 150, 90 }, "SmoothPlastic"),
			wedge(0.15, 0.6, 0.5, -1.0, 0, 0, { 180, 120, 70 }, "SmoothPlastic", { 0, 0, 90 }),
			ball(0.14, 0.6, 0.1, 0.2, COAL),
		}, 0)
	end,
	Stew = function()
		return spec({
			cyl(1.3, 0.7, 0, 0, 0, DARK_IRON, "Metal"),
			cyl(1.1, 0.06, 0, 0.34, 0, { 170, 110, 60 }, "SmoothPlastic"),
			ball(0.25, 0.2, 0.4, 0.1, { 190, 80, 70 }),
		}, 0)
	end,
	Winterberry = function()
		return spec({
			ball(0.5, 0, 0, 0, BERRY),
			ball(0.45, 0.45, -0.1, 0.15, { 160, 40, 80 }),
			ball(0.42, -0.35, -0.15, 0.2, { 200, 70, 110 }),
			blk(0.5, 0.06, 0.25, 0, 0.35, 0, LEAF, "Fabric", { 0, 30, 15 }),
		}, 0)
	end,
	Pinecone = function()
		return spec({
			ellipsoid(0.7, 1.1, 0.7, 0, 0, 0, { 120, 82, 52 }, "Wood"),
			wedge(0.3, 0.3, 0.3, 0, 0.7, 0, DARK_WOOD, "Wood"),
		}, 0)
	end,
	FrostMushroom = function()
		return spec({
			cyl(0.35, 0.8, 0, -0.1, 0, WHITE, "SmoothPlastic"),
			ellipsoid(1.1, 0.55, 1.1, 0, 0.35, 0, { 130, 180, 235 }, "SmoothPlastic"),
			ball(0.14, 0.25, 0.55, 0.2, WHITE),
		}, 0)
	end,
	-- Placeables
	Campfire = function()
		return spec({
			cyl(0.4, 1.8, 0, -0.25, 0, DARK_WOOD, "Wood", { 0, 0, 90 }),
			cyl(0.4, 1.8, 0, -0.2, 0, WOOD, "Wood", { 90, 0, 90 }),
			ball(0.8, 0, 0.35, 0, EMBER, "Neon"),
			ball(0.4, 0.1, 0.8, 0, { 255, 220, 90 }, "Neon"),
			ball(0.55, 1.0, -0.4, 0.5, STONE, "Slate"),
			ball(0.55, -1.0, -0.4, -0.5, STONE, "Slate"),
		}, 0)
	end,
	Workbench = function()
		return spec({
			blk(2.0, 0.25, 1.2, 0, 0.5, 0, WOOD, "Wood"),
			blk(0.25, 1.0, 0.25, -0.8, -0.1, 0.4, DARK_WOOD, "Wood"),
			blk(0.25, 1.0, 0.25, 0.8, -0.1, 0.4, DARK_WOOD, "Wood"),
			blk(0.25, 1.0, 0.25, -0.8, -0.1, -0.4, DARK_WOOD, "Wood"),
			blk(0.25, 1.0, 0.25, 0.8, -0.1, -0.4, DARK_WOOD, "Wood"),
			blk(0.4, 0.3, 0.4, 0.5, 0.78, 0, IRON, "Metal"),
		}, 0)
	end,
	CookingStation = function()
		return spec({
			blk(1.6, 0.9, 1.2, 0, -0.2, 0, STONE, "Slate"),
			ball(0.6, 0, 0.35, 0, EMBER, "Neon"),
			cyl(0.2, 1.8, -0.7, 0.8, 0, DARK_IRON, "Metal"),
			cyl(0.2, 1.8, 0.7, 0.8, 0, DARK_IRON, "Metal"),
			cyl(0.15, 1.5, 0, 1.55, 0, DARK_IRON, "Metal", { 0, 0, 90 }),
		}, 0)
	end,
	Forge = function()
		return spec({
			blk(1.6, 1.4, 1.3, 0, 0, 0, DARK_STONE, "Slate"),
			blk(0.9, 0.6, 0.12, 0, -0.1, 0.68, EMBER, "Neon"),
			blk(0.6, 1.0, 0.6, 0.35, 1.1, -0.2, STONE, "Slate"),
			blk(0.8, 0.2, 0.5, 0, 0.7, 0.8, DARK_IRON, "Metal"),
		}, 0)
	end,
	MapTable = function()
		return spec({
			blk(2.0, 0.2, 1.4, 0, 0.5, 0, WOOD, "Wood"),
			blk(1.6, 0.04, 1.0, 0, 0.64, 0, { 226, 210, 168 }, "Fabric"),
			cyl(0.2, 1.0, -0.8, -0.1, 0.5, DARK_WOOD, "Wood"),
			cyl(0.2, 1.0, 0.8, -0.1, 0.5, DARK_WOOD, "Wood"),
			cyl(0.2, 1.0, -0.8, -0.1, -0.5, DARK_WOOD, "Wood"),
			cyl(0.2, 1.0, 0.8, -0.1, -0.5, DARK_WOOD, "Wood"),
		}, 0)
	end,
	StorageChest = function()
		return spec({
			blk(1.8, 1.0, 1.2, 0, -0.2, 0, WOOD, "Wood"),
			blk(1.9, 0.5, 1.3, 0, 0.55, 0, DARK_WOOD, "Wood"),
			blk(0.3, 0.35, 0.1, 0, 0.2, 0.65, IRON, "Metal"),
			blk(0.15, 1.2, 1.32, -0.7, -0.1, 0, DARK_IRON, "Metal"),
			blk(0.15, 1.2, 1.32, 0.7, -0.1, 0, DARK_IRON, "Metal"),
		}, 0)
	end,
	Door = function()
		return spec({
			blk(1.4, 2.4, 0.2, 0, 0, 0, WOOD, "Wood"),
			blk(0.14, 2.4, 0.24, -0.35, 0, 0, DARK_WOOD, "Wood"),
			blk(0.14, 2.4, 0.24, 0.35, 0, 0, DARK_WOOD, "Wood"),
			ball(0.2, 0.5, 0, 0.18, IRON, "Metal"),
		}, 0)
	end,
	Wall = function()
		return spec({
			blk(2.2, 0.5, 0.4, 0, -0.65, 0, WOOD, "Wood"),
			blk(2.2, 0.5, 0.4, 0, 0, 0, DARK_WOOD, "Wood"),
			blk(2.2, 0.5, 0.4, 0, 0.65, 0, WOOD, "Wood"),
		}, 0)
	end,
	Watchtower = function()
		return spec({
			blk(0.3, 2.6, 0.3, -0.7, 0, 0.7, WOOD, "Wood"),
			blk(0.3, 2.6, 0.3, 0.7, 0, 0.7, WOOD, "Wood"),
			blk(0.3, 2.6, 0.3, -0.7, 0, -0.7, WOOD, "Wood"),
			blk(0.3, 2.6, 0.3, 0.7, 0, -0.7, WOOD, "Wood"),
			blk(1.8, 0.2, 1.8, 0, 1.0, 0, DARK_WOOD, "Wood"),
			wedge(2.1, 0.7, 2.1, 0, 1.6, 0, DARK_WOOD, "Wood"),
		}, 0)
	end,
	SleepingBag = function()
		return spec({
			cyl(0.9, 2.0, 0, 0, 0, BLUE, "Fabric", { 0, 0, 90 }),
			ellipsoid(0.6, 0.4, 0.7, -0.75, 0.3, 0, WHITE, "Fabric"),
			blk(0.15, 0.95, 0.95, 0.2, 0, 0, FUR, "Fabric"),
		}, 0)
	end,
	SpikeTrap = function()
		return spec({
			blk(1.6, 0.2, 1.6, 0, -0.3, 0, DARK_WOOD, "Wood"),
			wedge(0.4, 0.9, 0.4, -0.45, 0.2, -0.45, IRON, "Metal"),
			wedge(0.4, 0.9, 0.4, 0.45, 0.2, -0.45, IRON, "Metal"),
			wedge(0.4, 0.9, 0.4, 0, 0.2, 0.45, IRON, "Metal"),
		}, 0)
	end,
	Map = genericMap,
}

-- Public -----------------------------------------------------------------------------------------------

-- Spec for an item id, or nil for an unknown id.
function ItemModelSpec.get(id: string): ModelSpec?
	local def = ItemCatalog.Items[id]
	if def == nil then
		return nil
	end
	local bespoke = BESPOKE[id]
	if bespoke then
		return bespoke()
	end
	local byKind = BY_KIND[def.kind]
	if byKind then
		return byKind(def.equipSlot)
	end
	return genericPlaceable()
end

-- True when the id has a hand-authored recipe (the rest use the per-kind generic shape).
function ItemModelSpec.isBespoke(id: string): boolean
	return BESPOKE[id] ~= nil
end

return ItemModelSpec
