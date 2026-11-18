--!strict
-- Ice Warden (mini boss): tall narrow ice sentinel with a spiked crown and a glowing core. Root size (existing):
-- 6 x 10 x 6. Telegraph = arms raised overhead; Attack = SlamDown. Sound hooks (silent): creak, slam, death.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local ICE, ICE_LIGHT, DARK, GLOW =
	rgb(122, 184, 232), rgb(200, 235, 255), rgb(28, 40, 72), rgb(130, 235, 255)
local ICE_MAT = Enum.Material.Ice

local ROWS: { Scaled.Row } = {
	{ name = "Pelvis", size = { 0.5, 0.14, 0.36 }, pos = { 0, -0.1, 0 }, color = DARK },
	{
		name = "Torso",
		size = { 0.55, 0.34, 0.4 },
		pos = { 0, 0.14, 0 },
		color = ICE,
		mat = ICE_MAT,
	},
	{
		name = "Core",
		parent = "Torso",
		size = { 0.16, 0.14, 0.06 },
		pos = { 0, 0.16, -0.22 },
		color = GLOW,
		neon = true,
	},
	{
		name = "Head",
		parent = "Torso",
		size = { 0.26, 0.12, 0.26 },
		pos = { 0, 0.36, -0.02 },
		color = ICE_LIGHT,
		mat = ICE_MAT,
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.05, 0.02, 0.02 },
		pos = { -0.06, 0.37, -0.155 },
		color = GLOW,
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.05, 0.02, 0.02 },
		pos = { 0.06, 0.37, -0.155 },
		color = GLOW,
		neon = true,
	},
	{
		name = "Crown1",
		parent = "Head",
		size = { 0.05, 0.16, 0.05 },
		pos = { -0.08, 0.47, 0 },
		color = ICE_LIGHT,
		rot = { 0, 0, 15 },
	},
	{
		name = "Crown2",
		parent = "Head",
		size = { 0.05, 0.2, 0.05 },
		pos = { 0, 0.49, 0 },
		color = ICE_LIGHT,
	},
	{
		name = "Crown3",
		parent = "Head",
		size = { 0.05, 0.16, 0.05 },
		pos = { 0.08, 0.47, 0 },
		color = ICE_LIGHT,
		rot = { 0, 0, -15 },
	},
	{
		name = "PauldronL",
		parent = "Torso",
		size = { 0.22, 0.18, 0.3 },
		pos = { -0.4, 0.28, 0 },
		color = ICE_LIGHT,
		mat = ICE_MAT,
		rot = { 0, 0, 20 },
	},
	{
		name = "PauldronR",
		parent = "Torso",
		size = { 0.22, 0.18, 0.3 },
		pos = { 0.4, 0.28, 0 },
		color = ICE_LIGHT,
		mat = ICE_MAT,
		rot = { 0, 0, -20 },
	},
	{
		name = "ArmL",
		parent = "Torso",
		size = { 0.16, 0.4, 0.2 },
		pos = { -0.42, 0.26, 0 },
		color = ICE,
		mat = ICE_MAT,
		hinge = { 0, 1, 0 },
	},
	{
		name = "ArmR",
		parent = "Torso",
		size = { 0.16, 0.4, 0.2 },
		pos = { 0.42, 0.26, 0 },
		color = ICE,
		mat = ICE_MAT,
		hinge = { 0, 1, 0 },
	},
	{
		name = "FistL",
		parent = "ArmL",
		size = { 0.22, 0.2, 0.26 },
		pos = { -0.42, -0.24, 0 },
		color = ICE_LIGHT,
		mat = ICE_MAT,
	},
	{
		name = "FistR",
		parent = "ArmR",
		size = { 0.22, 0.2, 0.26 },
		pos = { 0.42, -0.24, 0 },
		color = ICE_LIGHT,
		mat = ICE_MAT,
	},
	{
		name = "LegL",
		parent = "Pelvis",
		size = { 0.2, 0.38, 0.22 },
		pos = { -0.17, -0.12, 0 },
		color = ICE,
		mat = ICE_MAT,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegR",
		parent = "Pelvis",
		size = { 0.2, 0.38, 0.22 },
		pos = { 0.17, -0.12, 0 },
		color = ICE,
		mat = ICE_MAT,
		hinge = { 0, 1, 0 },
	},
	{
		name = "Shard1",
		parent = "Torso",
		size = { 0.1, 0.3, 0.1 },
		pos = { -0.14, 0.4, 0.28 },
		color = ICE_LIGHT,
		rot = { 25, 0, 0 },
	},
	{
		name = "Shard2",
		parent = "Torso",
		size = { 0.1, 0.3, 0.1 },
		pos = { 0.14, 0.4, 0.28 },
		color = ICE_LIGHT,
		rot = { 25, 0, 0 },
	},
}

local def: Types.CreatureDef = {
	kind = "IceWarden",
	rig = {
		kind = "IceWarden",
		body = "Torso",
		head = "Head",
		legs = { "LegL", "LegR" },
		wings = {},
		attach = {},
		gait = "Biped",
		stride = 0.35,
		runScale = 1.2,
		bob = 0.05,
		idleSway = 0.02,
		telegraphPose = "Slam",
		attackPose = "SlamDown",
		custom = Scaled.armCustom({
			arms = { "ArmL", "ArmR" },
			raised = 2.7,
			down = 0.2,
			swing = 0.35,
			sway = 0.03,
		}),
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS)
	end,
}

return def
