--!strict
-- Snow Lurker: hunched pale ambusher that knuckle-walks. Root size (existing): 2.5 x 3 x 2.5.
-- Shaggy pale fur, dark flat face, two icy eyes, dark claws. Sound hooks (silent): hiss on Alert, lunge, hurt, death.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local FUR, DARK, EYE = rgb(206, 216, 228), rgb(34, 40, 58), rgb(190, 235, 255)

local ROWS: { Scaled.Row } = {
	{ name = "Body", size = { 0.6, 0.34, 0.5 }, pos = { 0, 0.06, 0.04 }, color = FUR },
	{
		name = "Hump",
		parent = "Body",
		size = { 0.62, 0.24, 0.34 },
		pos = { 0, 0.22, 0.08 },
		color = FUR,
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.34, 0.22, 0.26 },
		pos = { 0, 0.14, -0.38 },
		color = FUR,
	},
	{
		name = "Face",
		parent = "Head",
		size = { 0.26, 0.14, 0.05 },
		pos = { 0, 0.13, -0.51 },
		color = DARK,
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.07, 0.05, 0.03 },
		pos = { -0.07, 0.15, -0.545 },
		color = EYE,
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.07, 0.05, 0.03 },
		pos = { 0.07, 0.15, -0.545 },
		color = EYE,
		neon = true,
	},
	{
		name = "ArmL",
		parent = "Body",
		size = { 0.14, 0.7, 0.14 },
		pos = { -0.4, 0.2, -0.12 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "ArmR",
		parent = "Body",
		size = { 0.14, 0.7, 0.14 },
		pos = { 0.4, 0.2, -0.12 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "HandL",
		parent = "ArmL",
		size = { 0.18, 0.1, 0.2 },
		pos = { -0.4, -0.45, -0.14 },
		color = DARK,
	},
	{
		name = "HandR",
		parent = "ArmR",
		size = { 0.18, 0.1, 0.2 },
		pos = { 0.4, -0.45, -0.14 },
		color = DARK,
	},
	{
		name = "LegL",
		parent = "Body",
		size = { 0.18, 0.26, 0.18 },
		pos = { -0.18, -0.2, 0.12 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegR",
		parent = "Body",
		size = { 0.18, 0.26, 0.18 },
		pos = { 0.18, -0.2, 0.12 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "Spike1",
		parent = "Hump",
		size = { 0.07, 0.15, 0.07 },
		pos = { 0, 0.4, 0.2 },
		color = DARK,
	},
	{
		name = "Spike2",
		parent = "Hump",
		size = { 0.07, 0.15, 0.07 },
		pos = { 0, 0.42, 0.08 },
		color = DARK,
	},
	{
		name = "Spike3",
		parent = "Hump",
		size = { 0.07, 0.15, 0.07 },
		pos = { 0, 0.4, -0.04 },
		color = DARK,
	},
}

local def: Types.CreatureDef = {
	kind = "SnowLurker",
	rig = {
		kind = "SnowLurker",
		body = "Body",
		head = "Head",
		legs = { "LegL", "LegR" },
		wings = {},
		attach = {},
		gait = "Biped",
		stride = 0.6,
		runScale = 1.5,
		bob = 0.04,
		idleSway = 0.05,
		telegraphPose = "Crouch",
		attackPose = "Lunge",
		custom = Scaled.armCustom({
			arms = { "ArmL", "ArmR" },
			raised = 1.3,
			down = 0.2,
			swing = 0.5,
			sway = 0.05,
		}),
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS)
	end,
}

return def
