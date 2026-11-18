--!strict
-- Tree Watcher (lurker): a dark tree-shaped figure that only has two pale glints. Root size (existing):
-- 1.6 x 11 x 1.2. Static (gait None); the server vanishes it when approached or looked at.
-- Sound hook (silent): LurkerWhisperSound on sighting.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local BARK, DEEP, GLINT = rgb(30, 30, 34), rgb(18, 18, 22), rgb(225, 230, 240)

local ROWS: { Scaled.Row } = {
	{
		name = "Trunk",
		size = { 0.6, 0.55, 0.7 },
		pos = { 0, -0.2, 0 },
		color = BARK,
		mat = Enum.Material.Wood,
	},
	{
		name = "Mid",
		parent = "Trunk",
		size = { 0.45, 0.4, 0.55 },
		pos = { 0, 0.17, 0 },
		color = DEEP,
		mat = Enum.Material.Wood,
	},
	{
		name = "Neck",
		parent = "Mid",
		size = { 0.25, 0.14, 0.3 },
		pos = { 0, 0.4, 0 },
		color = BARK,
	},
	{
		name = "Head",
		parent = "Neck",
		size = { 0.4, 0.09, 0.5 },
		pos = { 0, 0.46, -0.05 },
		color = DEEP,
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.06, 0.012, 0.03 },
		pos = { -0.08, 0.465, -0.3 },
		color = GLINT,
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.06, 0.012, 0.03 },
		pos = { 0.08, 0.465, -0.3 },
		color = GLINT,
		neon = true,
	},
	{
		name = "ArmL",
		parent = "Mid",
		size = { 0.1, 0.5, 0.14 },
		pos = { -0.28, 0.25, 0 },
		color = BARK,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, -15 },
	},
	{
		name = "ArmR",
		parent = "Mid",
		size = { 0.1, 0.5, 0.14 },
		pos = { 0.28, 0.25, 0 },
		color = BARK,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, 15 },
	},
	{
		name = "BranchL1",
		parent = "Head",
		size = { 0.08, 0.2, 0.08 },
		pos = { -0.2, 0.5, 0 },
		color = DEEP,
		rot = { 0, 0, 40 },
	},
	{
		name = "BranchL2",
		parent = "Head",
		size = { 0.07, 0.16, 0.07 },
		pos = { -0.12, 0.52, 0.06 },
		color = DEEP,
		rot = { 0, 0, 20 },
	},
	{
		name = "BranchR1",
		parent = "Head",
		size = { 0.08, 0.2, 0.08 },
		pos = { 0.2, 0.5, 0 },
		color = DEEP,
		rot = { 0, 0, -40 },
	},
	{
		name = "BranchR2",
		parent = "Head",
		size = { 0.07, 0.16, 0.07 },
		pos = { 0.12, 0.52, 0.06 },
		color = DEEP,
		rot = { 0, 0, -20 },
	},
}

local def: Types.CreatureDef = {
	kind = "TreeWatcher",
	rig = {
		kind = "TreeWatcher",
		body = "Trunk",
		head = "Head",
		legs = {},
		wings = {},
		attach = {},
		gait = "None",
		stride = 0,
		runScale = 1,
		bob = 0,
		idleSway = 0,
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS)
	end,
}

return def
