--!strict
-- Ruin Colossus (mini boss): blocky stone-and-rebar golem with an amber core and visor. Root size (existing):
-- 8 x 14 x 8. Telegraph = both boulder fists raised; Attack = SlamDown. Sound hooks (silent): grind, slam, death.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local STONE, DARK, RUST, AMBER =
	rgb(126, 120, 114), rgb(72, 70, 74), rgb(150, 92, 60), rgb(255, 165, 60)
local ROCK = Enum.Material.Slate

local ROWS: { Scaled.Row } = {
	{
		name = "Pelvis",
		size = { 0.62, 0.14, 0.44 },
		pos = { 0, -0.07, 0 },
		color = DARK,
		mat = ROCK,
	},
	{ name = "Torso", size = { 0.75, 0.36, 0.5 }, pos = { 0, 0.14, 0 }, color = STONE, mat = ROCK },
	{
		name = "Core",
		parent = "Torso",
		size = { 0.18, 0.12, 0.06 },
		pos = { 0, 0.16, -0.27 },
		color = AMBER,
		neon = true,
	},
	{
		name = "Head",
		parent = "Torso",
		size = { 0.26, 0.12, 0.26 },
		pos = { 0, 0.38, 0 },
		color = DARK,
		mat = ROCK,
	},
	{
		name = "Visor",
		parent = "Head",
		size = { 0.22, 0.025, 0.04 },
		pos = { 0, 0.385, -0.15 },
		color = AMBER,
		neon = true,
	},
	{
		name = "ShoulderL",
		parent = "Torso",
		size = { 0.3, 0.2, 0.36 },
		pos = { -0.5, 0.28, 0 },
		color = STONE,
		mat = ROCK,
	},
	{
		name = "ShoulderR",
		parent = "Torso",
		size = { 0.3, 0.2, 0.36 },
		pos = { 0.5, 0.28, 0 },
		color = STONE,
		mat = ROCK,
	},
	{
		name = "ArmL",
		parent = "Torso",
		size = { 0.2, 0.4, 0.26 },
		pos = { -0.52, 0.26, 0 },
		color = STONE,
		mat = ROCK,
		hinge = { 0, 1, 0 },
	},
	{
		name = "ArmR",
		parent = "Torso",
		size = { 0.2, 0.4, 0.26 },
		pos = { 0.52, 0.26, 0 },
		color = STONE,
		mat = ROCK,
		hinge = { 0, 1, 0 },
	},
	{
		name = "FistL",
		parent = "ArmL",
		size = { 0.3, 0.2, 0.34 },
		pos = { -0.52, -0.24, 0 },
		color = DARK,
		mat = ROCK,
	},
	{
		name = "FistR",
		parent = "ArmR",
		size = { 0.3, 0.2, 0.34 },
		pos = { 0.52, -0.24, 0 },
		color = DARK,
		mat = ROCK,
	},
	{
		name = "LegL",
		parent = "Pelvis",
		size = { 0.26, 0.4, 0.3 },
		pos = { -0.2, -0.1, 0 },
		color = STONE,
		mat = ROCK,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegR",
		parent = "Pelvis",
		size = { 0.26, 0.4, 0.3 },
		pos = { 0.2, -0.1, 0 },
		color = STONE,
		mat = ROCK,
		hinge = { 0, 1, 0 },
	},
	{
		name = "Slab1",
		parent = "Torso",
		size = { 0.3, 0.25, 0.1 },
		pos = { -0.2, 0.24, 0.3 },
		color = DARK,
		mat = ROCK,
		rot = { 0, 0, 8 },
	},
	{
		name = "Slab2",
		parent = "Torso",
		size = { 0.3, 0.25, 0.1 },
		pos = { 0.2, 0.1, 0.3 },
		color = STONE,
		mat = ROCK,
		rot = { 0, 0, -6 },
	},
	{
		name = "Slab3",
		parent = "Torso",
		size = { 0.26, 0.2, 0.1 },
		pos = { 0, 0.3, 0.31 },
		color = DARK,
		mat = ROCK,
	},
	{
		name = "Rebar1",
		parent = "ShoulderL",
		size = { 0.03, 0.3, 0.03 },
		pos = { -0.55, 0.45, 0.05 },
		color = RUST,
		mat = Enum.Material.CorrodedMetal,
		rot = { 10, 0, 18 },
	},
	{
		name = "Rebar2",
		parent = "ShoulderR",
		size = { 0.03, 0.3, 0.03 },
		pos = { 0.55, 0.45, -0.05 },
		color = RUST,
		mat = Enum.Material.CorrodedMetal,
		rot = { -10, 0, -18 },
	},
}

local def: Types.CreatureDef = {
	kind = "RuinColossus",
	rig = {
		kind = "RuinColossus",
		body = "Torso",
		head = "Head",
		legs = { "LegL", "LegR" },
		wings = {},
		attach = {},
		gait = "Biped",
		stride = 0.3,
		runScale = 1.2,
		bob = 0.06,
		idleSway = 0.015,
		telegraphPose = "Slam",
		attackPose = "SlamDown",
		custom = Scaled.armCustom({
			arms = { "ArmL", "ArmR" },
			raised = 2.8,
			down = 0.25,
			swing = 0.3,
			sway = 0.02,
		}),
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS)
	end,
}

return def
