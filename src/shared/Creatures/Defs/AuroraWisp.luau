--!strict
-- Aurora Wisp: soft glowing orb with ribbon tails. Root size (suggested): 2 x 2 x 2. Glow is Neon only;
-- the ONE PointLight per nearby wisp is added client-side by Art/CreatureFx (never here).
-- Attachments TrailA/TrailB (orb top/bottom) feed the client Trail. Sound hook (silent): wisp hum loop.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local TEAL, BLUE, VIOLET, WHITE =
	rgb(110, 255, 205), rgb(130, 200, 255), rgb(190, 150, 255), rgb(235, 255, 250)
local RIBBONS = { "Ribbon1", "Ribbon2", "Ribbon3", "Ribbon4", "Ribbon5" }
local SWAY = 0.35 -- radians
local PULSE = 0.06 -- studs of core bob

local ROWS: { Scaled.Row } = {
	{
		name = "Orb",
		shape = Enum.PartType.Ball,
		size = { 0.5, 0.5, 0.5 },
		pos = { 0, 0, 0 },
		color = TEAL,
		neon = true,
		alpha = 0.1,
	},
	{
		name = "Core",
		parent = "Orb",
		shape = Enum.PartType.Ball,
		size = { 0.26, 0.26, 0.26 },
		pos = { 0, 0, 0 },
		color = WHITE,
		neon = true,
	},
	{
		name = "Halo",
		parent = "Orb",
		shape = Enum.PartType.Ball,
		size = { 0.95, 0.95, 0.95 },
		pos = { 0, 0, 0 },
		color = TEAL,
		neon = true,
		alpha = 0.82,
	},
	{
		name = "Ribbon1",
		parent = "Orb",
		size = { 0.14, 0.6, 0.02 },
		pos = { 0.12, -0.2, 0 },
		color = TEAL,
		neon = true,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, 12 },
	},
	{
		name = "Ribbon2",
		parent = "Orb",
		size = { 0.14, 0.6, 0.02 },
		pos = { -0.12, -0.2, 0 },
		color = BLUE,
		neon = true,
		hinge = { 0, 1, 0 },
		rot = { 0, 0, -12 },
	},
	{
		name = "Ribbon3",
		parent = "Orb",
		size = { 0.02, 0.6, 0.14 },
		pos = { 0, -0.2, 0.12 },
		color = VIOLET,
		neon = true,
		hinge = { 0, 1, 0 },
		rot = { -12, 0, 0 },
	},
	{
		name = "Ribbon4",
		parent = "Orb",
		size = { 0.02, 0.6, 0.14 },
		pos = { 0, -0.2, -0.12 },
		color = BLUE,
		neon = true,
		hinge = { 0, 1, 0 },
		rot = { 12, 0, 0 },
	},
	{
		name = "Ribbon5",
		parent = "Orb",
		size = { 0.12, 0.75, 0.02 },
		pos = { 0, -0.22, 0 },
		color = VIOLET,
		neon = true,
		hinge = { 0, 1, 0 },
	},
}
local MOUNTS: { Scaled.Mount } = {
	{ part = "Orb", name = "TrailA", pos = { 0, 0.2, 0 } },
	{ part = "Orb", name = "TrailB", pos = { 0, -0.2, 0 } },
	{ part = "Orb", name = "Glow", pos = { 0, 0, 0 } },
}

local def: Types.CreatureDef = {
	kind = "AuroraWisp",
	rig = {
		kind = "AuroraWisp",
		body = "Orb",
		legs = {},
		wings = {},
		attach = { "TrailA", "TrailB", "Glow" },
		gait = "Float",
		stride = 0.3,
		runScale = 1.4,
		bob = 0.15,
		idleSway = 0.05,
		custom = function(ctx: Types.AnimCtx)
			for i, name in RIBBONS do
				ctx.pose(
					name,
					CFrame.Angles(
						math.sin(ctx.t * 1.8 + i) * SWAY,
						0,
						math.sin(ctx.t * 1.5 + i * 1.7) * SWAY
					)
				)
			end
			ctx.pose("Core", CFrame.new(0, math.sin(ctx.t * 3) * PULSE, 0))
		end,
	},
	build = function(root: BasePart)
		Scaled.build(root, ROWS, MOUNTS)
	end,
}

return def
