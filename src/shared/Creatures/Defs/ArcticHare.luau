--!strict
-- ArcticHare: small grey-blue hare, long dark-tipped ears, white tail, hop gait. Intended root 1.5 x 1.5 x 2.
-- Sound hooks (silent): footstep on landing (phase wraps), hurt squeal, death.
-- Data tables first (studs authored at REF root size, scaled to the real root.Size). Rows: pos = part centre
-- relative to its parent part (forward = -Z); pivot = hinge point in the part's local space (joint C1);
-- rot = degrees. Built only via CreatureBuild.part. Contract: docs/CREATURES_CONTRACT.md
local ArtKit = require("../../ArtKit")
local CreatureBuild = require("../CreatureBuild")
local Types = require("../Types")

local REF = { 1.5, 1.5, 2 } -- intended root (hitbox) size in studs: width, height, length

local PALETTE: { [string]: { number } } = {
	Fur = { 150, 166, 190 },
	Dark = { 28, 30, 40 },
	Snow = { 244, 248, 253 },
}

type Row = {
	name: string,
	parent: string,
	size: { number },
	pos: { number },
	color: string,
	rot: { number }?,
	pivot: { number }?,
	neon: boolean?,
}

local ROWS: { Row } = {
	{
		name = "Body",
		parent = "Root",
		size = { 0.9, 0.8, 1.1 },
		pos = { 0, -0.15, 0.05 },
		color = "Fur",
	},
	{
		name = "Haunch",
		parent = "Body",
		size = { 0.95, 0.85, 0.7 },
		pos = { 0, 0, 0.45 },
		color = "Fur",
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.6, 0.55, 0.65 },
		pos = { 0, 0.3, -0.75 },
		color = "Fur",
		pivot = { 0, -0.15, 0.25 },
	},
	{
		name = "Nose",
		parent = "Head",
		size = { 0.2, 0.15, 0.18 },
		pos = { 0, -0.1, -0.38 },
		color = "Dark",
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.1, 0.1, 0.08 },
		pos = { -0.3, 0.08, -0.12 },
		color = "Dark",
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.1, 0.1, 0.08 },
		pos = { 0.3, 0.08, -0.12 },
		color = "Dark",
	},
	{
		name = "EarL",
		parent = "Head",
		size = { 0.14, 0.85, 0.12 },
		pos = { -0.17, 0.65, 0.12 },
		color = "Fur",
		rot = { 10, 0, 6 },
		pivot = { 0, -0.42, 0 },
	},
	{
		name = "EarR",
		parent = "Head",
		size = { 0.14, 0.85, 0.12 },
		pos = { 0.17, 0.65, 0.12 },
		color = "Fur",
		rot = { 10, 0, -6 },
		pivot = { 0, -0.42, 0 },
	},
	{
		name = "TipL",
		parent = "EarL",
		size = { 0.15, 0.28, 0.13 },
		pos = { 0, 0.4, 0 },
		color = "Dark",
	},
	{
		name = "TipR",
		parent = "EarR",
		size = { 0.15, 0.28, 0.13 },
		pos = { 0, 0.4, 0 },
		color = "Dark",
	},
	{
		name = "LegFL",
		parent = "Body",
		size = { 0.2, 0.5, 0.22 },
		pos = { -0.28, -0.35, -0.3 },
		color = "Fur",
		pivot = { 0, 0.2, 0 },
	},
	{
		name = "LegBR",
		parent = "Body",
		size = { 0.24, 0.5, 0.55 },
		pos = { 0.3, -0.35, 0.45 },
		color = "Fur",
		pivot = { 0, 0.2, 0 },
	},
	{
		name = "LegFR",
		parent = "Body",
		size = { 0.2, 0.5, 0.22 },
		pos = { 0.28, -0.35, -0.3 },
		color = "Fur",
		pivot = { 0, 0.2, 0 },
	},
	{
		name = "LegBL",
		parent = "Body",
		size = { 0.24, 0.5, 0.55 },
		pos = { -0.3, -0.35, 0.45 },
		color = "Fur",
		pivot = { 0, 0.2, 0 },
	},
	{
		name = "Tail",
		parent = "Body",
		size = { 0.3, 0.3, 0.3 },
		pos = { 0, 0.1, 0.85 },
		color = "Snow",
	},
}

local ZERO = { 0, 0, 0 }

local function buildRows(root: BasePart)
	local s = root.Size
	local kx, ky, kz = s.X / REF[1], s.Y / REF[2], s.Z / REF[3]
	local built: { [string]: BasePart } = {}
	for _, r in ROWS do
		local parent = if r.parent == "Root" then root else built[r.parent]
		if parent then
			local rot = r.rot or ZERO
			local pv = r.pivot or ZERO
			local pivot = CFrame.new(pv[1] * kx, pv[2] * ky, pv[3] * kz)
			built[r.name] = CreatureBuild.part({
				name = r.name,
				parent = parent,
				size = Vector3.new(r.size[1] * kx, r.size[2] * ky, r.size[3] * kz),
				offset = CFrame.new(r.pos[1] * kx, r.pos[2] * ky, r.pos[3] * kz)
					* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
					* pivot,
				color = ArtKit.color(PALETTE[r.color]),
				neon = r.neon,
				pivot = pivot,
			})
		end
	end
end

local HOP_HEIGHT = 0.32 -- fraction of hitbox height
local HOP_RUN_BOOST = 1.4
local HOP_FRONT = 0.9 -- radians of foreleg reach in the air
local HOP_PITCH = 0.35
local EAR_BACK = 0.85 -- ears laid back while hopping
local EAR_UP = -0.15
local EAR_TWITCH = 0.3

-- Hop gait + ear play. Ears are not generic joints, so they are posed every step.
local function custom(ctx: Types.AnimCtx)
	local state = ctx.state
	local ear = EAR_UP
	if state == "Walk" or state == "Run" then
		local s = math.sin(ctx.phase)
		local root = ctx.model.PrimaryPart
		local unit = if root then root.Size.Y else REF[2]
		local height = unit * HOP_HEIGHT * (if state == "Run" then HOP_RUN_BOOST else 1)
		ctx.pose(
			"Body",
			CFrame.new(0, math.max(0, s) * height, 0)
				* CFrame.Angles(HOP_PITCH * math.cos(ctx.phase), 0, 0)
		)
		ctx.pose("LegFL", CFrame.Angles(HOP_FRONT * s, 0, 0))
		ctx.pose("LegFR", CFrame.Angles(HOP_FRONT * s, 0, 0))
		ctx.pose("LegBR", CFrame.Angles(-HOP_FRONT * s, 0, 0))
		ctx.pose("LegBL", CFrame.Angles(-HOP_FRONT * s, 0, 0))
		ear = EAR_BACK
	elseif state ~= "Death" then
		local twitch = math.max(0, math.sin(ctx.t * 0.9)) ^ 8
		ear = EAR_UP + twitch * EAR_TWITCH
		if state == "Alert" then
			ear = EAR_UP - 0.1
		end
	else
		ear = EAR_BACK
	end
	ctx.pose("EarL", CFrame.Angles(ear, 0, 0))
	ctx.pose("EarR", CFrame.Angles(ear, 0, 0))
end

local def: Types.CreatureDef = {
	kind = "ArcticHare",
	rig = {
		kind = "ArcticHare",
		body = "Body",
		head = "Head",
		tail = "Tail",
		legs = { "LegFL", "LegBR", "LegFR", "LegBL" },
		wings = {},
		attach = { "Hit" },
		gait = "Quad",
		stride = 0.9,
		runScale = 1.3,
		bob = 0.15,
		idleSway = 0.03,
		custom = custom,
	},
	build = buildRows,
}

return def
