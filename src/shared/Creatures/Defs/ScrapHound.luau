--!strict
-- Scrap Hound: lean pack hunter in rusted scrap plates. Root size (suggested for new kind): 2 x 3.2 x 4.6.
-- Silhouette: low long body, big rust shoulder plates and a spiked back plate; amber eyes are the accent.
-- Sound hooks (silent): growl on Alert/Telegraph, bite on Attack, hurt, death, footstep on Run.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local FUR, CHEST, RUST, SCRAP, BONE, EYE =
	rgb(58, 62, 74),
	rgb(84, 90, 106),
	rgb(156, 86, 48),
	rgb(116, 122, 134),
	rgb(214, 208, 190),
	rgb(255, 170, 60)

local ROWS: { Scaled.Row } = {
	{ name = "Body", size = { 0.7, 0.34, 0.5 }, pos = { 0, 0, 0.08 }, color = FUR },
	{
		name = "Chest",
		parent = "Body",
		size = { 0.78, 0.4, 0.26 },
		pos = { 0, 0.02, -0.18 },
		color = CHEST,
	},
	{
		name = "Head",
		parent = "Chest",
		size = { 0.46, 0.28, 0.2 },
		pos = { 0, 0.1, -0.42 },
		color = FUR,
	},
	{
		name = "Snout",
		parent = "Head",
		size = { 0.26, 0.13, 0.15 },
		pos = { 0, 0.06, -0.56 },
		color = CHEST,
	},
	{
		name = "Jaw",
		parent = "Head",
		size = { 0.22, 0.05, 0.14 },
		pos = { 0, 0, -0.54 },
		color = BONE,
	},
	{
		name = "EarL",
		parent = "Head",
		size = { 0.1, 0.15, 0.06 },
		pos = { -0.16, 0.27, -0.38 },
		color = RUST,
		rot = { 0, 0, 10 },
	},
	{
		name = "EarR",
		parent = "Head",
		size = { 0.1, 0.15, 0.06 },
		pos = { 0.16, 0.27, -0.38 },
		color = RUST,
		rot = { 0, 0, -10 },
	},
	{
		name = "LegFL",
		parent = "Body",
		size = { 0.15, 0.3, 0.1 },
		pos = { -0.27, -0.2, -0.2 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegBR",
		parent = "Body",
		size = { 0.15, 0.3, 0.1 },
		pos = { 0.27, -0.2, 0.28 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegFR",
		parent = "Body",
		size = { 0.15, 0.3, 0.1 },
		pos = { 0.27, -0.2, -0.2 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegBL",
		parent = "Body",
		size = { 0.15, 0.3, 0.1 },
		pos = { -0.27, -0.2, 0.28 },
		color = FUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "Tail",
		parent = "Body",
		size = { 0.07, 0.07, 0.34 },
		pos = { 0, 0.08, 0.33 },
		color = FUR,
		rot = { -25, 0, 0 },
		hinge = { 0, 0, -1 },
	},
	{
		name = "PlateBack",
		parent = "Body",
		size = { 0.8, 0.1, 0.32 },
		pos = { 0, 0.2, 0.1 },
		color = RUST,
		mat = Enum.Material.CorrodedMetal,
	},
	{
		name = "PlateShL",
		parent = "Chest",
		size = { 0.14, 0.3, 0.3 },
		pos = { -0.42, 0.06, -0.18 },
		color = RUST,
		mat = Enum.Material.CorrodedMetal,
		rot = { 0, 0, 10 },
	},
	{
		name = "PlateShR",
		parent = "Chest",
		size = { 0.14, 0.3, 0.3 },
		pos = { 0.42, 0.06, -0.18 },
		color = RUST,
		mat = Enum.Material.CorrodedMetal,
		rot = { 0, 0, -10 },
	},
	{
		name = "PlateHead",
		parent = "Head",
		size = { 0.4, 0.07, 0.16 },
		pos = { 0, 0.25, -0.42 },
		color = SCRAP,
		mat = Enum.Material.Metal,
	},
	{
		name = "Spike1",
		parent = "PlateBack",
		size = { 0.06, 0.14, 0.06 },
		pos = { 0, 0.31, 0.22 },
		color = SCRAP,
		mat = Enum.Material.Metal,
	},
	{
		name = "Spike2",
		parent = "PlateBack",
		size = { 0.06, 0.14, 0.06 },
		pos = { 0, 0.31, 0.1 },
		color = SCRAP,
		mat = Enum.Material.Metal,
	},
	{
		name = "Spike3",
		parent = "PlateBack",
		size = { 0.06, 0.14, 0.06 },
		pos = { 0, 0.31, -0.02 },
		color = SCRAP,
		mat = Enum.Material.Metal,
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.07, 0.05, 0.04 },
		pos = { -0.11, 0.16, -0.52 },
		color = EYE,
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.07, 0.05, 0.04 },
		pos = { 0.11, 0.16, -0.52 },
		color = EYE,
		neon = true,
	},
}
local MOUNTS: { Scaled.Mount } = { { part = "Head", name = "Mouth", pos = { 0, 0.04, -0.12 } } }

local def: Types.CreatureDef = {
	kind = "ScrapHound",
	rig = {
		kind = "ScrapHound",
		body = "Body",
		head = "Head",
		legs = { "LegFL", "LegBR", "LegFR", "LegBL" },
		tail = "Tail",
		wings = {},
		attach = { "Mouth" },
		gait = "Quad",
		stride = 0.85,
		runScale = 1.5,
		bob = 0.05,
		idleSway = 0.03,
		telegraphPose = "Crouch",
		attackPose = "Lunge",
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS, MOUNTS)
	end,
}

return def
