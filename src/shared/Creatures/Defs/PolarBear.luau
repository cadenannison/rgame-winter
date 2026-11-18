--!strict
-- Polar Bear: bulky quadruped. Root size (existing): 4 x 5 x 7. Cream coat with a darker blue-grey belly,
-- black nose/eyes/paws so the silhouette separates from snow. Sound hooks (silent): growl, swipe, hurt, death.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local COAT, SHADE, DARK = rgb(226, 216, 196), rgb(168, 180, 198), rgb(30, 32, 40)

local ROWS: { Scaled.Row } = {
	{ name = "Body", size = { 0.82, 0.5, 0.62 }, pos = { 0, 0, 0.08 }, color = COAT },
	{
		name = "Belly",
		parent = "Body",
		size = { 0.74, 0.2, 0.54 },
		pos = { 0, -0.2, 0.08 },
		color = SHADE,
	},
	{
		name = "Hump",
		parent = "Body",
		size = { 0.7, 0.22, 0.3 },
		pos = { 0, 0.28, -0.08 },
		color = COAT,
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.46, 0.28, 0.22 },
		pos = { 0, 0.14, -0.42 },
		color = COAT,
	},
	{
		name = "Snout",
		parent = "Head",
		size = { 0.26, 0.14, 0.16 },
		pos = { 0, 0.08, -0.55 },
		color = COAT,
	},
	{
		name = "Nose",
		parent = "Head",
		size = { 0.1, 0.06, 0.04 },
		pos = { 0, 0.1, -0.635 },
		color = DARK,
	},
	{
		name = "EarL",
		parent = "Head",
		size = { 0.1, 0.1, 0.05 },
		pos = { -0.17, 0.31, -0.38 },
		color = SHADE,
	},
	{
		name = "EarR",
		parent = "Head",
		size = { 0.1, 0.1, 0.05 },
		pos = { 0.17, 0.31, -0.38 },
		color = SHADE,
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.05, 0.04, 0.03 },
		pos = { -0.1, 0.18, -0.525 },
		color = DARK,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.05, 0.04, 0.03 },
		pos = { 0.1, 0.18, -0.525 },
		color = DARK,
	},
	{
		name = "LegFL",
		parent = "Body",
		size = { 0.22, 0.26, 0.14 },
		pos = { -0.3, -0.24, -0.2 },
		color = COAT,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegBR",
		parent = "Body",
		size = { 0.22, 0.26, 0.14 },
		pos = { 0.3, -0.24, 0.36 },
		color = COAT,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegFR",
		parent = "Body",
		size = { 0.22, 0.26, 0.14 },
		pos = { 0.3, -0.24, -0.2 },
		color = COAT,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegBL",
		parent = "Body",
		size = { 0.22, 0.26, 0.14 },
		pos = { -0.3, -0.24, 0.36 },
		color = COAT,
		hinge = { 0, 1, 0 },
	},
	{
		name = "PawFL",
		parent = "LegFL",
		size = { 0.25, 0.07, 0.17 },
		pos = { -0.3, -0.465, -0.22 },
		color = DARK,
	},
	{
		name = "PawBR",
		parent = "LegBR",
		size = { 0.25, 0.07, 0.17 },
		pos = { 0.3, -0.465, 0.34 },
		color = DARK,
	},
	{
		name = "PawFR",
		parent = "LegFR",
		size = { 0.25, 0.07, 0.17 },
		pos = { 0.3, -0.465, -0.22 },
		color = DARK,
	},
	{
		name = "PawBL",
		parent = "LegBL",
		size = { 0.25, 0.07, 0.17 },
		pos = { -0.3, -0.465, 0.34 },
		color = DARK,
	},
	{
		name = "Tail",
		parent = "Body",
		size = { 0.1, 0.1, 0.07 },
		pos = { 0, 0.12, 0.4 },
		color = COAT,
	},
}

local def: Types.CreatureDef = {
	kind = "PolarBear",
	rig = {
		kind = "PolarBear",
		body = "Body",
		head = "Head",
		legs = { "LegFL", "LegBR", "LegFR", "LegBL" },
		tail = "Tail",
		wings = {},
		attach = {},
		gait = "Quad",
		stride = 0.5,
		runScale = 1.5,
		bob = 0.03,
		idleSway = 0.02,
		telegraphPose = "Rear",
		attackPose = "Swipe",
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS)
	end,
}

return def
