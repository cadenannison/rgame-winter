--!strict
-- Carrion Crow: tiny ambient bird, 7 parts + root. Root size (suggested): 1 x 0.9 x 1.3.
-- Near-black on pale snow, pale glare line for the eyes. Wings hinge at the shoulder so the Bird gait flaps them.
-- Sound hooks (silent): caw on Alert/scatter, wing flutter on Run.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local FEATHER, BEAK, EYE = rgb(28, 30, 42), rgb(150, 138, 104), rgb(232, 238, 255)

local ROWS: { Scaled.Row } = {
	{ name = "Body", size = { 0.5, 0.5, 0.6 }, pos = { 0, 0, 0 }, color = FEATHER },
	{
		name = "Head",
		parent = "Body",
		size = { 0.34, 0.34, 0.3 },
		pos = { 0, 0.2, -0.38 },
		color = FEATHER,
	},
	{
		name = "Beak",
		parent = "Head",
		size = { 0.1, 0.1, 0.22 },
		pos = { 0, 0.16, -0.62 },
		color = BEAK,
	},
	{
		name = "Eyes",
		parent = "Head",
		size = { 0.36, 0.05, 0.05 },
		pos = { 0, 0.24, -0.53 },
		color = EYE,
		neon = true,
	},
	{
		name = "WingL",
		parent = "Body",
		size = { 0.9, 0.06, 0.5 },
		pos = { -0.25, 0.12, 0 },
		color = FEATHER,
		hinge = { 1, 0, 0 },
		rot = { 0, 0, 35 },
	},
	{
		name = "WingR",
		parent = "Body",
		size = { 0.9, 0.06, 0.5 },
		pos = { 0.25, 0.12, 0 },
		color = FEATHER,
		hinge = { -1, 0, 0 },
		rot = { 0, 0, -35 },
	},
	{
		name = "Tail",
		parent = "Body",
		size = { 0.3, 0.06, 0.35 },
		pos = { 0, 0, 0.45 },
		color = FEATHER,
		hinge = { 0, 0, -1 },
	},
}

local def: Types.CreatureDef = {
	kind = "CarrionCrow",
	rig = {
		kind = "CarrionCrow",
		body = "Body",
		head = "Head",
		legs = {},
		tail = "Tail",
		wings = { "WingL", "WingR" },
		attach = {},
		gait = "Bird",
		stride = 0.6,
		runScale = 1.6,
		bob = 0.05,
		idleSway = 0.03,
		telegraphPose = "Spread",
		attackPose = "Peck",
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS)
	end,
}

return def
