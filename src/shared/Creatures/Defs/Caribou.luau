--!strict
-- Caribou: dark brown deer, pale rump and mane, bone antlers. Intended root 2.5 x 4 x 5 (existing kind keeps its size).
-- Sound hooks (silent): footstep (hooves), snort on Alert, hurt, death.
-- Data tables first (studs authored at REF root size, scaled to the real root.Size). Rows: pos = part centre
-- relative to its parent part (forward = -Z); pivot = hinge point in the part's local space (joint C1);
-- rot = degrees. Built only via CreatureBuild.part. Contract: docs/CREATURES_CONTRACT.md
local ArtKit = require("../../ArtKit")
local CreatureBuild = require("../CreatureBuild")
local Types = require("../Types")

local REF = { 2.5, 4, 5 } -- intended root (hitbox) size in studs: width, height, length

local PALETTE: { [string]: { number } } = {
	Fur = { 92, 70, 56 },
	Mane = { 176, 160, 142 },
	Pale = { 214, 206, 196 },
	Leg = { 70, 54, 46 },
	Dark = { 24, 22, 28 },
	Bone = { 226, 220, 200 },
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
		size = { 1.5, 1.4, 2.8 },
		pos = { 0, 0.15, 0.4 },
		color = "Fur",
	},
	{
		name = "Rump",
		parent = "Body",
		size = { 1.3, 0.9, 0.7 },
		pos = { 0, 0.05, 1.3 },
		color = "Pale",
	},
	{
		name = "Neck",
		parent = "Body",
		size = { 0.6, 1.1, 0.7 },
		pos = { 0, 0.6, -1.25 },
		color = "Mane",
		rot = { -35, 0, 0 },
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.6, 0.6, 1.0 },
		pos = { 0, 1.05, -1.9 },
		color = "Fur",
		pivot = { 0, -0.1, 0.45 },
	},
	{
		name = "Nose",
		parent = "Head",
		size = { 0.3, 0.3, 0.25 },
		pos = { 0, -0.1, -0.6 },
		color = "Dark",
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.1, 0.1, 0.1 },
		pos = { -0.3, 0.1, -0.2 },
		color = "Dark",
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.1, 0.1, 0.1 },
		pos = { 0.3, 0.1, -0.2 },
		color = "Dark",
	},
	{
		name = "AntlerL",
		parent = "Head",
		size = { 0.12, 0.95, 0.12 },
		pos = { -0.22, 0.65, 0.2 },
		color = "Bone",
		rot = { 20, 0, 25 },
	},
	{
		name = "AntlerR",
		parent = "Head",
		size = { 0.12, 0.95, 0.12 },
		pos = { 0.22, 0.65, 0.2 },
		color = "Bone",
		rot = { 20, 0, -25 },
	},
	{
		name = "TineL",
		parent = "AntlerL",
		size = { 0.1, 0.55, 0.1 },
		pos = { 0, 0.2, -0.2 },
		color = "Bone",
		rot = { -50, 0, 0 },
	},
	{
		name = "TineR",
		parent = "AntlerR",
		size = { 0.1, 0.55, 0.1 },
		pos = { 0, 0.2, -0.2 },
		color = "Bone",
		rot = { -50, 0, 0 },
	},
	{
		name = "EarL",
		parent = "Head",
		size = { 0.4, 0.12, 0.18 },
		pos = { -0.45, 0.25, 0.3 },
		color = "Fur",
		pivot = { 0.2, 0, 0 },
	},
	{
		name = "EarR",
		parent = "Head",
		size = { 0.4, 0.12, 0.18 },
		pos = { 0.45, 0.25, 0.3 },
		color = "Fur",
		pivot = { -0.2, 0, 0 },
	},
	{
		name = "LegFL",
		parent = "Body",
		size = { 0.3, 1.5, 0.34 },
		pos = { -0.5, -1.45, -1.0 },
		color = "Leg",
		pivot = { 0, 0.75, 0 },
	},
	{
		name = "LegBR",
		parent = "Body",
		size = { 0.3, 1.5, 0.34 },
		pos = { 0.5, -1.45, 1.0 },
		color = "Leg",
		pivot = { 0, 0.75, 0 },
	},
	{
		name = "LegFR",
		parent = "Body",
		size = { 0.3, 1.5, 0.34 },
		pos = { 0.5, -1.45, -1.0 },
		color = "Leg",
		pivot = { 0, 0.75, 0 },
	},
	{
		name = "LegBL",
		parent = "Body",
		size = { 0.3, 1.5, 0.34 },
		pos = { -0.5, -1.45, 1.0 },
		color = "Leg",
		pivot = { 0, 0.75, 0 },
	},
	{
		name = "Tail",
		parent = "Body",
		size = { 0.3, 0.4, 0.2 },
		pos = { 0, 0.45, 1.5 },
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

local EAR_FLICK_HZ = 1.7
local EAR_FLICK_AMP = 0.35

-- Ear flicks. Ears are not generic joints, so they are posed every step.
local function custom(ctx: Types.AnimCtx)
	local flick = 0
	if ctx.state ~= "Death" then
		flick = math.max(0, math.sin(ctx.t * EAR_FLICK_HZ)) ^ 10 * EAR_FLICK_AMP
		if ctx.state == "Alert" then
			flick = 0
		end
	end
	ctx.pose("EarL", CFrame.Angles(0, 0, flick))
	ctx.pose("EarR", CFrame.Angles(0, 0, -flick))
end

local def: Types.CreatureDef = {
	kind = "Caribou",
	rig = {
		kind = "Caribou",
		body = "Body",
		head = "Head",
		tail = "Tail",
		legs = { "LegFL", "LegBR", "LegFR", "LegBL" },
		wings = {},
		attach = { "Hit" },
		gait = "Quad",
		stride = 0.6,
		runScale = 1.5,
		bob = 0.1,
		idleSway = 0.025,
		custom = custom,
	},
	build = buildRows,
}

return def
