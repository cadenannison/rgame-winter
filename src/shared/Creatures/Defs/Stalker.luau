--!strict
-- The Stalker: tall, pale, over-long limbs, a stretched head with a void face and two tiny cold glints.
-- Unkillable; server-built through HorrorWorld.makeModel (anchored root, moved by PivotTo). Root size
-- (existing): 2.4 x 12 x 1.6. Deliberately mid-grey rather than bright so it is never fully lit.
-- Sound hooks (silent): StalkerCrunch footsteps, strike, retreat.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local PALE, GREY, VOID, GLINT =
	rgb(188, 194, 208), rgb(140, 146, 162), rgb(14, 16, 24), rgb(235, 240, 255)

local ROWS: { Scaled.Row } = {
	{ name = "Pelvis", size = { 0.4, 0.08, 0.4 }, pos = { 0, -0.04, 0.02 }, color = GREY },
	{ name = "Torso", size = { 0.7, 0.24, 0.6 }, pos = { 0, 0.1, 0.02 }, color = PALE },
	{
		name = "Rib1",
		parent = "Torso",
		size = { 0.62, 0.03, 0.08 },
		pos = { 0, 0.14, -0.31 },
		color = VOID,
	},
	{
		name = "Rib2",
		parent = "Torso",
		size = { 0.62, 0.03, 0.08 },
		pos = { 0, 0.07, -0.31 },
		color = VOID,
	},
	{
		name = "Neck",
		parent = "Torso",
		size = { 0.14, 0.16, 0.2 },
		pos = { 0, 0.26, -0.08 },
		color = GREY,
	},
	{
		name = "Head",
		parent = "Neck",
		size = { 0.5, 0.1, 0.5 },
		pos = { 0, 0.35, -0.2 },
		color = PALE,
	},
	{
		name = "Face",
		parent = "Head",
		size = { 0.4, 0.07, 0.06 },
		pos = { 0, 0.35, -0.46 },
		color = VOID,
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.05, 0.012, 0.02 },
		pos = { -0.09, 0.36, -0.495 },
		color = GLINT,
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.05, 0.012, 0.02 },
		pos = { 0.09, 0.36, -0.495 },
		color = GLINT,
		neon = true,
	},
	{
		name = "ArmL",
		parent = "Torso",
		size = { 0.1, 0.55, 0.16 },
		pos = { -0.42, 0.2, 0 },
		color = GREY,
		hinge = { 0, 1, 0 },
	},
	{
		name = "ArmR",
		parent = "Torso",
		size = { 0.1, 0.55, 0.16 },
		pos = { 0.42, 0.2, 0 },
		color = GREY,
		hinge = { 0, 1, 0 },
	},
	{
		name = "FingersL",
		parent = "ArmL",
		size = { 0.12, 0.14, 0.2 },
		pos = { -0.42, -0.42, 0 },
		color = PALE,
	},
	{
		name = "FingersR",
		parent = "ArmR",
		size = { 0.12, 0.14, 0.2 },
		pos = { 0.42, -0.42, 0 },
		color = PALE,
	},
	{
		name = "LegL",
		parent = "Pelvis",
		size = { 0.14, 0.44, 0.2 },
		pos = { -0.14, -0.06, 0.02 },
		color = GREY,
		hinge = { 0, 1, 0 },
	},
	{
		name = "LegR",
		parent = "Pelvis",
		size = { 0.14, 0.44, 0.2 },
		pos = { 0.14, -0.06, 0.02 },
		color = GREY,
		hinge = { 0, 1, 0 },
	},
}

local def: Types.CreatureDef = {
	kind = "Stalker",
	rig = {
		kind = "Stalker",
		body = "Torso",
		head = "Head",
		legs = { "LegL", "LegR" },
		wings = {},
		attach = {},
		gait = "Biped",
		stride = 0.25,
		runScale = 1.4,
		bob = 0.015,
		idleSway = 0.015,
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS)
	end,
}

return def
