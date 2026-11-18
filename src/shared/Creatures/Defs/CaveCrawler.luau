--!strict
-- Cave Crawler: low six-legged cave stalker. Root size (existing): 2 x 1.5 x 3.5. Violet-black chitin, pale
-- mandibles, four glowing eyes and two dim abdomen spots. Sound hooks (silent): skitter loop, hiss, bite, death.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local CHITIN, BONE, EYE, SPOT =
	rgb(62, 54, 78), rgb(220, 210, 190), rgb(200, 120, 255), rgb(150, 90, 230)

local ROWS: { Scaled.Row } = {
	{ name = "Body", size = { 0.7, 0.38, 0.4 }, pos = { 0, -0.05, 0.05 }, color = CHITIN },
	{
		name = "Abdomen",
		parent = "Body",
		size = { 0.62, 0.5, 0.34 },
		pos = { 0, 0.02, 0.34 },
		color = CHITIN,
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.5, 0.3, 0.2 },
		pos = { 0, -0.08, -0.34 },
		color = CHITIN,
	},
	{
		name = "MandL",
		parent = "Head",
		size = { 0.07, 0.07, 0.16 },
		pos = { -0.12, -0.15, -0.5 },
		color = BONE,
		rot = { 0, 20, 0 },
	},
	{
		name = "MandR",
		parent = "Head",
		size = { 0.07, 0.07, 0.16 },
		pos = { 0.12, -0.15, -0.5 },
		color = BONE,
		rot = { 0, -20, 0 },
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.07, 0.07, 0.04 },
		pos = { -0.14, 0, -0.44 },
		color = EYE,
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.07, 0.07, 0.04 },
		pos = { 0.14, 0, -0.44 },
		color = EYE,
		neon = true,
	},
	{
		name = "EyeL2",
		parent = "Head",
		size = { 0.05, 0.05, 0.04 },
		pos = { -0.07, 0.05, -0.44 },
		color = EYE,
		neon = true,
	},
	{
		name = "EyeR2",
		parent = "Head",
		size = { 0.05, 0.05, 0.04 },
		pos = { 0.07, 0.05, -0.44 },
		color = EYE,
		neon = true,
	},
	{
		name = "SpotL",
		parent = "Abdomen",
		size = { 0.12, 0.04, 0.12 },
		pos = { -0.12, 0.27, 0.34 },
		color = SPOT,
		neon = true,
	},
	{
		name = "SpotR",
		parent = "Abdomen",
		size = { 0.12, 0.04, 0.12 },
		pos = { 0.12, 0.27, 0.34 },
		color = SPOT,
		neon = true,
	},
	{
		name = "LegFL",
		parent = "Body",
		size = { 0.07, 0.75, 0.07 },
		pos = { -0.34, -0.05, -0.12 },
		color = CHITIN,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, -50 },
	},
	{
		name = "LegBR",
		parent = "Body",
		size = { 0.07, 0.75, 0.07 },
		pos = { 0.34, -0.05, 0.24 },
		color = CHITIN,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, 50 },
	},
	{
		name = "LegFR",
		parent = "Body",
		size = { 0.07, 0.75, 0.07 },
		pos = { 0.34, -0.05, -0.12 },
		color = CHITIN,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, 50 },
	},
	{
		name = "LegBL",
		parent = "Body",
		size = { 0.07, 0.75, 0.07 },
		pos = { -0.34, -0.05, 0.24 },
		color = CHITIN,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, -50 },
	},
	{
		name = "LegMR",
		parent = "Body",
		size = { 0.07, 0.75, 0.07 },
		pos = { 0.34, -0.05, 0.06 },
		color = CHITIN,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, 50 },
	},
	{
		name = "LegML",
		parent = "Body",
		size = { 0.07, 0.75, 0.07 },
		pos = { -0.34, -0.05, 0.06 },
		color = CHITIN,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, -50 },
	},
}

local def: Types.CreatureDef = {
	kind = "CaveCrawler",
	rig = {
		kind = "CaveCrawler",
		body = "Body",
		head = "Head",
		legs = { "LegFL", "LegBR", "LegFR", "LegBL", "LegMR", "LegML" },
		wings = {},
		attach = {},
		gait = "Quad",
		stride = 0.5,
		runScale = 1.6,
		bob = 0.02,
		idleSway = 0.02,
		telegraphPose = "Crouch",
		attackPose = "Bite",
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS)
	end,
}

return def
