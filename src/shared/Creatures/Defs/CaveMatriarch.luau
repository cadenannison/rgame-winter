--!strict
-- Cave Matriarch (mini boss): giant violet-black spider with glowing egg sacs and eight long legs. Root size
-- (existing): 7 x 7 x 11 (legs splay wider than the hitbox on purpose). Sound hooks (silent): hiss, skitter, bite, death.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local CHITIN, DARK, BONE, EYE, EGG =
	rgb(74, 52, 92), rgb(38, 28, 52), rgb(225, 215, 195), rgb(210, 120, 255), rgb(220, 200, 255)

local function leg(name: string, side: number, z: number): Scaled.Row
	return {
		name = name,
		parent = "Body",
		size = { 0.05, 0.7, 0.05 },
		pos = { side * 0.26, 0.04, z },
		color = DARK,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, side * 40 },
	}
end

local ROWS: { Scaled.Row } = {
	{ name = "Body", size = { 0.55, 0.36, 0.3 }, pos = { 0, 0.05, -0.05 }, color = CHITIN },
	{
		name = "Abdomen",
		parent = "Body",
		size = { 0.62, 0.55, 0.4 },
		pos = { 0, 0.08, 0.3 },
		color = CHITIN,
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.36, 0.26, 0.18 },
		pos = { 0, 0.02, -0.3 },
		color = DARK,
	},
	{
		name = "Crest",
		parent = "Body",
		size = { 0.3, 0.14, 0.2 },
		pos = { 0, 0.2, -0.12 },
		color = DARK,
	},
	{
		name = "FangL",
		parent = "Head",
		size = { 0.06, 0.14, 0.05 },
		pos = { -0.07, -0.06, -0.39 },
		color = BONE,
		hinge = { 0, 1, 0 },
	},
	{
		name = "FangR",
		parent = "Head",
		size = { 0.06, 0.14, 0.05 },
		pos = { 0.07, -0.06, -0.39 },
		color = BONE,
		hinge = { 0, 1, 0 },
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.07, 0.07, 0.03 },
		pos = { -0.1, 0.08, -0.395 },
		color = EYE,
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.07, 0.07, 0.03 },
		pos = { 0.1, 0.08, -0.395 },
		color = EYE,
		neon = true,
	},
	{
		name = "EyeL2",
		parent = "Head",
		size = { 0.04, 0.04, 0.03 },
		pos = { -0.05, 0.13, -0.395 },
		color = EYE,
		neon = true,
	},
	{
		name = "EyeR2",
		parent = "Head",
		size = { 0.04, 0.04, 0.03 },
		pos = { 0.05, 0.13, -0.395 },
		color = EYE,
		neon = true,
	},
	{
		name = "EggSac1",
		parent = "Abdomen",
		shape = Enum.PartType.Ball,
		size = { 0.12, 0.12, 0.12 },
		pos = { -0.12, -0.2, 0.32 },
		color = EGG,
		neon = true,
		alpha = 0.2,
	},
	{
		name = "EggSac2",
		parent = "Abdomen",
		shape = Enum.PartType.Ball,
		size = { 0.12, 0.12, 0.12 },
		pos = { 0.1, -0.2, 0.38 },
		color = EGG,
		neon = true,
		alpha = 0.2,
	},
	{
		name = "EggSac3",
		parent = "Abdomen",
		shape = Enum.PartType.Ball,
		size = { 0.12, 0.12, 0.12 },
		pos = { 0, -0.22, 0.24 },
		color = EGG,
		neon = true,
		alpha = 0.2,
	},
	leg("Leg1L", -1, -0.22),
	leg("Leg2L", -1, -0.08),
	leg("Leg3L", -1, 0.06),
	leg("Leg4L", -1, 0.2),
	leg("Leg1R", 1, -0.22),
	leg("Leg2R", 1, -0.08),
	leg("Leg3R", 1, 0.06),
	leg("Leg4R", 1, 0.2),
}

local def: Types.CreatureDef = {
	kind = "CaveMatriarch",
	rig = {
		kind = "CaveMatriarch",
		body = "Body",
		head = "Head",
		legs = { "Leg1L", "Leg4R", "Leg1R", "Leg4L", "Leg2R", "Leg3L", "Leg2L", "Leg3R" },
		wings = {},
		attach = {},
		gait = "Quad",
		stride = 0.4,
		runScale = 1.5,
		bob = 0.02,
		idleSway = 0.02,
		telegraphPose = "Rear",
		attackPose = "Bite",
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS)
	end,
}

return def
