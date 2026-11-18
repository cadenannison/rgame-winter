--!strict
-- Ice Wraith: floating hooded spirit. Root size (existing): 2 x 5 x 2. Translucent ice robe, void-dark face with
-- two white eyes, glowing claws; Telegraph raises both arms. Sound hooks (silent): wail on Alert, swipe, hurt, death.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local ICE, ICE_LIGHT, VOID, EYE, CLAW =
	rgb(150, 215, 250), rgb(205, 236, 255), rgb(22, 34, 58), rgb(235, 252, 255), rgb(170, 235, 255)

local ROWS: { Scaled.Row } = {
	{ name = "Torso", size = { 0.62, 0.3, 0.4 }, pos = { 0, 0.2, 0 }, color = ICE, alpha = 0.2 },
	{
		name = "Robe1",
		parent = "Torso",
		size = { 0.5, 0.26, 0.34 },
		pos = { 0, -0.02, 0 },
		color = ICE,
		alpha = 0.3,
	},
	{
		name = "Robe2",
		parent = "Robe1",
		size = { 0.34, 0.22, 0.26 },
		pos = { 0, -0.25, 0 },
		color = ICE,
		alpha = 0.4,
	},
	{
		name = "Tip",
		parent = "Robe2",
		size = { 0.16, 0.16, 0.14 },
		pos = { 0, -0.43, 0 },
		color = ICE,
		alpha = 0.5,
		rot = { 0, 0, 45 },
	},
	{
		name = "Head",
		parent = "Torso",
		size = { 0.42, 0.15, 0.4 },
		pos = { 0, 0.42, -0.02 },
		color = ICE_LIGHT,
	},
	{
		name = "Face",
		parent = "Head",
		size = { 0.3, 0.08, 0.05 },
		pos = { 0, 0.42, -0.22 },
		color = VOID,
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.06, 0.03, 0.03 },
		pos = { -0.1, 0.43, -0.25 },
		color = EYE,
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.06, 0.03, 0.03 },
		pos = { 0.1, 0.43, -0.25 },
		color = EYE,
		neon = true,
	},
	{
		name = "Shard1",
		parent = "Head",
		size = { 0.06, 0.14, 0.06 },
		pos = { -0.14, 0.54, 0 },
		color = ICE_LIGHT,
		rot = { 0, 0, 20 },
	},
	{
		name = "Shard2",
		parent = "Head",
		size = { 0.06, 0.18, 0.06 },
		pos = { 0, 0.55, 0 },
		color = ICE_LIGHT,
	},
	{
		name = "Shard3",
		parent = "Head",
		size = { 0.06, 0.14, 0.06 },
		pos = { 0.14, 0.54, 0 },
		color = ICE_LIGHT,
		rot = { 0, 0, -20 },
	},
	{
		name = "ArmL",
		parent = "Torso",
		size = { 0.12, 0.36, 0.12 },
		pos = { -0.38, 0.3, 0 },
		color = ICE,
		alpha = 0.2,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, -12 },
	},
	{
		name = "ArmR",
		parent = "Torso",
		size = { 0.12, 0.36, 0.12 },
		pos = { 0.38, 0.3, 0 },
		color = ICE,
		alpha = 0.2,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, 12 },
	},
	{
		name = "HandL",
		parent = "ArmL",
		size = { 0.16, 0.12, 0.16 },
		pos = { -0.57, -0.06, 0 },
		color = CLAW,
		neon = true,
	},
	{
		name = "HandR",
		parent = "ArmR",
		size = { 0.16, 0.12, 0.16 },
		pos = { 0.57, -0.06, 0 },
		color = CLAW,
		neon = true,
	},
}

local def: Types.CreatureDef = {
	kind = "IceWraith",
	rig = {
		kind = "IceWraith",
		body = "Torso",
		head = "Head",
		legs = {},
		wings = {},
		attach = {},
		gait = "Float",
		stride = 0.3,
		runScale = 1.3,
		bob = 0.12,
		idleSway = 0.04,
		telegraphPose = "Raise",
		attackPose = "Swipe",
		custom = Scaled.armCustom({
			arms = { "ArmL", "ArmR" },
			raised = 2.6,
			down = 0.3,
			swing = 0.2,
			sway = 0.06,
		}),
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS)
	end,
}

return def
