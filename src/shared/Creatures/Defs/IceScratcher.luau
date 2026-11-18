--!strict
-- Ice Scratcher (lurker): flat dark patch of ice raked by four claw marks and two cracks. Root size (existing):
-- 3 x 0.4 x 3. Static (gait None). Sound hook (silent): IceCrackSound on thin-ice crack.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local SLAB, MARK = rgb(40, 50, 70), rgb(186, 220, 245)

local ROWS: { Scaled.Row } = {
	{
		name = "Slab",
		size = { 0.92, 0.5, 0.92 },
		pos = { 0, 0, 0 },
		color = SLAB,
		alpha = 0.5,
		mat = Enum.Material.Ice,
	},
	{
		name = "Claw1",
		parent = "Slab",
		size = { 0.05, 0.9, 0.8 },
		pos = { -0.21, 0, 0 },
		color = MARK,
		alpha = 0.2,
		rot = { 0, 20, 0 },
	},
	{
		name = "Claw2",
		parent = "Slab",
		size = { 0.05, 0.9, 0.8 },
		pos = { -0.07, 0, 0 },
		color = MARK,
		alpha = 0.2,
		rot = { 0, 20, 0 },
	},
	{
		name = "Claw3",
		parent = "Slab",
		size = { 0.05, 0.9, 0.8 },
		pos = { 0.07, 0, 0 },
		color = MARK,
		alpha = 0.2,
		rot = { 0, 20, 0 },
	},
	{
		name = "Claw4",
		parent = "Slab",
		size = { 0.05, 0.9, 0.8 },
		pos = { 0.21, 0, 0 },
		color = MARK,
		alpha = 0.2,
		rot = { 0, 20, 0 },
	},
	{
		name = "Crack1",
		parent = "Slab",
		size = { 0.04, 0.9, 0.5 },
		pos = { 0.3, 0, 0.2 },
		color = MARK,
		alpha = 0.3,
		rot = { 0, -35, 0 },
	},
	{
		name = "Crack2",
		parent = "Slab",
		size = { 0.04, 0.9, 0.5 },
		pos = { -0.3, 0, -0.22 },
		color = MARK,
		alpha = 0.3,
		rot = { 0, -35, 0 },
	},
}

local def: Types.CreatureDef = {
	kind = "IceScratcher",
	rig = {
		kind = "IceScratcher",
		body = "Slab",
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
