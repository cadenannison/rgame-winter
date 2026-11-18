--!strict
-- Eyes In Dark (lurker): two glowing amber eyes with vertical slit pupils, nothing else. Root size (existing):
-- 1.4 x 0.4 x 0.2. Static (gait None). Sound hook (silent): LurkerWhisperSound on sighting.
local Scaled = require("../Scaled")
local Types = require("../Types")

local rgb = Color3.fromRGB
local AMBER, SLIT = rgb(255, 230, 140), rgb(20, 16, 10)

local ROWS: { Scaled.Row } = {
	{ name = "EyeL", size = { 0.3, 0.85, 0.9 }, pos = { -0.28, 0, 0 }, color = AMBER, neon = true },
	{ name = "EyeR", size = { 0.3, 0.85, 0.9 }, pos = { 0.28, 0, 0 }, color = AMBER, neon = true },
	{
		name = "PupilL",
		parent = "EyeL",
		size = { 0.06, 0.95, 0.2 },
		pos = { -0.28, 0, -0.5 },
		color = SLIT,
	},
	{
		name = "PupilR",
		parent = "EyeR",
		size = { 0.06, 0.95, 0.2 },
		pos = { 0.28, 0, -0.5 },
		color = SLIT,
	},
}

local def: Types.CreatureDef = {
	kind = "EyesInDark",
	rig = {
		kind = "EyesInDark",
		body = "EyeL",
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
