--!strict
-- Whiteout Beast (blizzard boss): shaggy white mane-backed quadruped. Root size (existing): 7 x 9 x 11.
-- Value contrast for whiteout: black muzzle and claws, blue-grey belly, glowing cyan eyes, ice spines/tusks.
-- Sound hooks (silent): roar on Telegraph (BossRoarSound), swipe, footstep thud, death.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local FUR, UNDER, DARK, ICE, EYE =
	rgb(232, 236, 244), rgb(150, 166, 196), rgb(24, 30, 46), rgb(150, 225, 255), rgb(120, 245, 255)

local ROWS: { Scaled.Row } = {
	{ name = "Body", size = { 0.8, 0.45, 0.55 }, pos = { 0, 0.02, 0.08 }, color = FUR },
	{
		name = "Belly",
		parent = "Body",
		size = { 0.7, 0.2, 0.5 },
		pos = { 0, -0.18, 0.08 },
		color = UNDER,
	},
	{
		name = "Mane",
		parent = "Body",
		size = { 0.85, 0.5, 0.3 },
		pos = { 0, 0.1, -0.2 },
		color = FUR,
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.46, 0.3, 0.2 },
		pos = { 0, 0.1, -0.46 },
		color = FUR,
	},
	{
		name = "Muzzle",
		parent = "Head",
		size = { 0.3, 0.18, 0.14 },
		pos = { 0, 0.02, -0.57 },
		color = DARK,
	},
	{
		name = "TuskL",
		parent = "Head",
		size = { 0.05, 0.16, 0.05 },
		pos = { -0.12, -0.1, -0.6 },
		color = ICE,
		rot = { -15, 0, 0 },
	},
	{
		name = "TuskR",
		parent = "Head",
		size = { 0.05, 0.16, 0.05 },
		pos = { 0.12, -0.1, -0.6 },
		color = ICE,
		rot = { -15, 0, 0 },
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.06, 0.04, 0.03 },
		pos = { -0.13, 0.16, -0.565 },
		color = EYE,
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.06, 0.04, 0.03 },
		pos = { 0.13, 0.16, -0.565 },
		color = EYE,
		neon = true,
	},
	{
		name = "LegFL",
		parent = "Body",
		size = { 0.24, 0.3, 0.16 },
		pos = { -0.28, -0.2, -0.22 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegBR",
		parent = "Body",
		size = { 0.24, 0.3, 0.16 },
		pos = { 0.28, -0.2, 0.36 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegFR",
		parent = "Body",
		size = { 0.24, 0.3, 0.16 },
		pos = { 0.28, -0.2, -0.22 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegBL",
		parent = "Body",
		size = { 0.24, 0.3, 0.16 },
		pos = { -0.28, -0.2, 0.36 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "ClawFL",
		parent = "LegFL",
		size = { 0.26, 0.06, 0.12 },
		pos = { -0.28, -0.47, -0.29 },
		color = DARK,
	},
	{
		name = "ClawBR",
		parent = "LegBR",
		size = { 0.26, 0.06, 0.12 },
		pos = { 0.28, -0.47, 0.29 },
		color = DARK,
	},
	{
		name = "ClawFR",
		parent = "LegFR",
		size = { 0.26, 0.06, 0.12 },
		pos = { 0.28, -0.47, -0.29 },
		color = DARK,
	},
	{
		name = "ClawBL",
		parent = "LegBL",
		size = { 0.26, 0.06, 0.12 },
		pos = { -0.28, -0.47, 0.29 },
		color = DARK,
	},
	{
		name = "Tail",
		parent = "Body",
		size = { 0.12, 0.12, 0.2 },
		pos = { 0, 0.1, 0.42 },
		color = UNDER,
	},
	{
		name = "Spine1",
		parent = "Body",
		size = { 0.08, 0.2, 0.08 },
		pos = { 0, 0.33, 0.15 },
		color = ICE,
	},
	{
		name = "Spine2",
		parent = "Body",
		size = { 0.08, 0.2, 0.08 },
		pos = { 0, 0.33, 0.28 },
		color = ICE,
	},
	{
		name = "Spine3",
		parent = "Body",
		size = { 0.08, 0.2, 0.08 },
		pos = { 0, 0.33, 0.0 },
		color = ICE,
	},
}

local def: Types.CreatureDef = {
	kind = "WhiteoutBeast",
	rig = {
		kind = "WhiteoutBeast",
		body = "Body",
		head = "Head",
		legs = { "LegFL", "LegBR", "LegFR", "LegBL" },
		tail = "Tail",
		wings = {},
		attach = {},
		gait = "Quad",
		stride = 0.45,
		runScale = 1.5,
		bob = 0.04,
		idleSway = 0.02,
		telegraphPose = "Rear",
		attackPose = "Swipe",
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS)
	end,
}

return def
