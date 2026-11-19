--!strict
-- Frostbound Brute: huge hunched ice-armoured bruiser. Root size comes from Config.Mobs.Species.FrostboundBrute.size (5 x 7 x 5): the single source of truth; rows below are fractions of it.
-- Telegraph = both fists raised overhead and trembling (readable from far), Attack = SlamDown snap.
-- Mount "Slam" on each fist marks the impact point for client Art/CreatureFx. Sound hooks (silent):
-- growl on Telegraph, slam thud on Attack, footstep, hurt, death.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local ARMOUR, ICE, EYE = rgb(38, 52, 78), rgb(190, 225, 245), rgb(90, 230, 255)

local ROWS: { Scaled.Row } = {
	{ name = "Torso", size = { 0.8, 0.34, 0.62 }, pos = { 0, 0.1, -0.02 }, color = ARMOUR },
	{ name = "Pelvis", size = { 0.5, 0.16, 0.42 }, pos = { 0, -0.14, 0 }, color = ARMOUR },
	{
		name = "Head",
		parent = "Torso",
		size = { 0.34, 0.16, 0.4 },
		pos = { 0, 0.34, -0.1 },
		color = ARMOUR,
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.07, 0.03, 0.04 },
		pos = { -0.08, 0.35, -0.305 },
		color = EYE,
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.07, 0.03, 0.04 },
		pos = { 0.08, 0.35, -0.305 },
		color = EYE,
		neon = true,
	},
	{
		name = "HornL",
		parent = "Head",
		size = { 0.07, 0.16, 0.07 },
		pos = { -0.14, 0.47, -0.08 },
		color = ICE,
		rot = { 0, 0, 25 },
	},
	{
		name = "HornR",
		parent = "Head",
		size = { 0.07, 0.16, 0.07 },
		pos = { 0.14, 0.47, -0.08 },
		color = ICE,
		rot = { 0, 0, -25 },
	},
	{
		name = "IceCore",
		parent = "Torso",
		size = { 0.16, 0.1, 0.05 },
		pos = { 0, 0.12, -0.34 },
		color = EYE,
		neon = true,
	},
	{
		name = "ChestPlate",
		parent = "Torso",
		size = { 0.62, 0.2, 0.1 },
		pos = { 0, 0.15, -0.33 },
		color = ICE,
		mat = Enum.Material.Ice,
	},
	{
		name = "PauldronL",
		parent = "Torso",
		size = { 0.26, 0.2, 0.4 },
		pos = { -0.5, 0.26, 0 },
		color = ICE,
		mat = Enum.Material.Ice,
		rot = { 0, 0, 15 },
	},
	{
		name = "PauldronR",
		parent = "Torso",
		size = { 0.26, 0.2, 0.4 },
		pos = { 0.5, 0.26, 0 },
		color = ICE,
		mat = Enum.Material.Ice,
		rot = { 0, 0, -15 },
	},
	{
		name = "ArmL",
		parent = "Torso",
		size = { 0.17, 0.46, 0.2 },
		pos = { -0.48, 0.24, 0 },
		color = ARMOUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "ArmR",
		parent = "Torso",
		size = { 0.17, 0.46, 0.2 },
		pos = { 0.48, 0.24, 0 },
		color = ARMOUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "FistL",
		parent = "ArmL",
		size = { 0.28, 0.2, 0.28 },
		pos = { -0.48, -0.3, 0 },
		color = ICE,
		mat = Enum.Material.Ice,
	},
	{
		name = "FistR",
		parent = "ArmR",
		size = { 0.28, 0.2, 0.28 },
		pos = { 0.48, -0.3, 0 },
		color = ICE,
		mat = Enum.Material.Ice,
	},
	{
		name = "LegL",
		parent = "Pelvis",
		size = { 0.2, 0.3, 0.26 },
		pos = { -0.16, -0.2, 0 },
		color = ARMOUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegR",
		parent = "Pelvis",
		size = { 0.2, 0.3, 0.26 },
		pos = { 0.16, -0.2, 0 },
		color = ARMOUR,
		hinge = { 0, 1, 0 },
	},
	{
		name = "Shard1",
		parent = "Torso",
		size = { 0.1, 0.24, 0.1 },
		pos = { -0.2, 0.34, 0.26 },
		color = ICE,
		mat = Enum.Material.Ice,
		rot = { 30, 0, 0 },
	},
	{
		name = "Shard2",
		parent = "Torso",
		size = { 0.1, 0.24, 0.1 },
		pos = { 0.2, 0.34, 0.26 },
		color = ICE,
		mat = Enum.Material.Ice,
		rot = { 30, 0, 0 },
	},
	{
		name = "Shard3",
		parent = "Torso",
		size = { 0.1, 0.26, 0.1 },
		pos = { 0, 0.4, 0.28 },
		color = ICE,
		mat = Enum.Material.Ice,
		rot = { 30, 0, 0 },
	},
}
local MOUNTS: { Scaled.Mount } = {
	{ part = "FistL", name = "Slam", pos = { 0, -0.12, 0 } },
	{ part = "FistR", name = "Slam", pos = { 0, -0.12, 0 } },
}

local def: Types.CreatureDef = {
	kind = "FrostboundBrute",
	rig = {
		kind = "FrostboundBrute",
		body = "Torso",
		head = "Head",
		legs = { "LegL", "LegR" },
		wings = {},
		attach = { "Slam" },
		gait = "Biped",
		stride = 0.5,
		runScale = 1.3,
		bob = 0.08,
		idleSway = 0.02,
		telegraphPose = "Slam",
		attackPose = "SlamDown",
		custom = Scaled.armCustom({
			arms = { "ArmL", "ArmR" },
			raised = 2.9,
			down = 0.25,
			swing = 0.4,
			sway = 0.04,
		}),
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS, MOUNTS)
	end,
}

return def
