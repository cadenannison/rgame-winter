--!strict
-- RidgeStag: big dark herd stag, pale mane and rump, wide bone antlers; head-up Alert, Crouch (antlers down) then Lunge.
-- Intended root 3 x 4.5 x 5.5. Sound hooks (silent): bellow on Alert/Telegraph, antler clash on Attack, hooves, hurt, death.
-- Data tables first (studs authored at REF root size, scaled to the real root.Size). Rows: pos = part centre
-- relative to its parent part (forward = -Z); pivot = hinge point in the part's local space (joint C1);
-- rot = degrees. Built only via CreatureBuild.part. Contract: docs/CREATURES_CONTRACT.md
local ArtKit = require("../../ArtKit")
local CreatureBuild = require("../CreatureBuild")
local Types = require("../Types")

local REF = { 3, 4.5, 5.5 } -- intended root (hitbox) size in studs: width, height, length

local PALETTE: { [string]: { number } } = {
	Fur = { 80, 58, 46 },
	Mane = { 150, 130, 112 },
	Pale = { 214, 206, 196 },
	Leg = { 62, 48, 42 },
	Dark = { 22, 20, 26 },
	Bone = { 230, 224, 204 },
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
		size = { 1.8, 1.7, 3.2 },
		pos = { 0, 0.2, 0.5 },
		color = "Fur",
	},
	{
		name = "Rump",
		parent = "Body",
		size = { 1.5, 1.0, 0.8 },
		pos = { 0, 0.05, 1.45 },
		color = "Pale",
	},
	{
		name = "Mane",
		parent = "Body",
		size = { 1.0, 1.2, 1.0 },
		pos = { 0, 0.55, -1.15 },
		color = "Mane",
	},
	{
		name = "Neck",
		parent = "Body",
		size = { 0.8, 1.4, 0.9 },
		pos = { 0, 0.85, -1.5 },
		color = "Fur",
		rot = { -35, 0, 0 },
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.75, 0.75, 1.3 },
		pos = { 0, 1.25, -2.3 },
		color = "Fur",
		pivot = { 0, -0.15, 0.55 },
	},
	{
		name = "Nose",
		parent = "Head",
		size = { 0.4, 0.35, 0.3 },
		pos = { 0, -0.12, -0.7 },
		color = "Dark",
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.12, 0.12, 0.12 },
		pos = { -0.38, 0.12, -0.3 },
		color = "Dark",
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.12, 0.12, 0.12 },
		pos = { 0.38, 0.12, -0.3 },
		color = "Dark",
	},
	{
		name = "BeamL",
		parent = "Head",
		size = { 0.18, 1.4, 0.18 },
		pos = { -0.3, 0.95, 0.25 },
		color = "Bone",
		rot = { 18, 0, 28 },
	},
	{
		name = "BeamR",
		parent = "Head",
		size = { 0.18, 1.4, 0.18 },
		pos = { 0.3, 0.95, 0.25 },
		color = "Bone",
		rot = { 18, 0, -28 },
	},
	{
		name = "BrowL",
		parent = "BeamL",
		size = { 0.14, 0.8, 0.14 },
		pos = { 0, 0.1, -0.25 },
		color = "Bone",
		rot = { -55, 0, 0 },
	},
	{
		name = "BrowR",
		parent = "BeamR",
		size = { 0.14, 0.8, 0.14 },
		pos = { 0, 0.1, -0.25 },
		color = "Bone",
		rot = { -55, 0, 0 },
	},
	{
		name = "TineL",
		parent = "BeamL",
		size = { 0.14, 0.7, 0.14 },
		pos = { 0, 0.55, 0.15 },
		color = "Bone",
		rot = { 35, 0, 0 },
	},
	{
		name = "TineR",
		parent = "BeamR",
		size = { 0.14, 0.7, 0.14 },
		pos = { 0, 0.55, 0.15 },
		color = "Bone",
		rot = { 35, 0, 0 },
	},
	{
		name = "EarL",
		parent = "Head",
		size = { 0.45, 0.14, 0.2 },
		pos = { -0.55, 0.3, 0.4 },
		color = "Fur",
		pivot = { 0.22, 0, 0 },
	},
	{
		name = "EarR",
		parent = "Head",
		size = { 0.45, 0.14, 0.2 },
		pos = { 0.55, 0.3, 0.4 },
		color = "Fur",
		pivot = { -0.22, 0, 0 },
	},
	{
		name = "LegFL",
		parent = "Body",
		size = { 0.38, 1.6, 0.42 },
		pos = { -0.6, -1.65, -1.2 },
		color = "Leg",
		pivot = { 0, 0.8, 0 },
	},
	{
		name = "LegBR",
		parent = "Body",
		size = { 0.38, 1.6, 0.42 },
		pos = { 0.6, -1.65, 1.2 },
		color = "Leg",
		pivot = { 0, 0.8, 0 },
	},
	{
		name = "LegFR",
		parent = "Body",
		size = { 0.38, 1.6, 0.42 },
		pos = { 0.6, -1.65, -1.2 },
		color = "Leg",
		pivot = { 0, 0.8, 0 },
	},
	{
		name = "LegBL",
		parent = "Body",
		size = { 0.38, 1.6, 0.42 },
		pos = { -0.6, -1.65, 1.2 },
		color = "Leg",
		pivot = { 0, 0.8, 0 },
	},
	{
		name = "Tail",
		parent = "Body",
		size = { 0.3, 0.5, 0.25 },
		pos = { 0, 0.5, 1.7 },
		color = "Pale",
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
	kind = "RidgeStag",
	rig = {
		kind = "RidgeStag",
		body = "Body",
		head = "Head",
		tail = "Tail",
		legs = { "LegFL", "LegBR", "LegFR", "LegBL" },
		wings = {},
		attach = { "Hit" },
		gait = "Quad",
		stride = 0.55,
		runScale = 1.6,
		bob = 0.1,
		idleSway = 0.02,
		telegraphPose = "Crouch",
		attackPose = "Lunge",
		custom = custom,
	},
	build = buildRows,
}

return def
