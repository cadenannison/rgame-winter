--!strict
-- Wolf: lean grey night hunter, dark saddle, pale chest, amber neon eyes; Crouch wind-up for the bite telegraph.
-- Intended root 2 x 3 x 4 (existing kind keeps its size). Sound hooks (silent): growl on Alert/Telegraph, bite, howl, footstep, hurt, death.
-- Data tables first (studs authored at REF root size, scaled to the real root.Size). Rows: pos = part centre
-- relative to its parent part (forward = -Z); pivot = hinge point in the part's local space (joint C1);
-- rot = degrees. Built only via CreatureBuild.part. Contract: docs/CREATURES_CONTRACT.md
local ArtKit = require("../../ArtKit")
local CreatureBuild = require("../CreatureBuild")
local Types = require("../Types")

local REF = { 2, 3, 4 } -- intended root (hitbox) size in studs: width, height, length

local PALETTE: { [string]: { number } } = {
	Fur = { 104, 112, 128 },
	Pale = { 196, 206, 218 },
	Dark = { 40, 44, 56 },
	Eye = { 255, 190, 60 },
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
		size = { 0.9, 1.0, 2.0 },
		pos = { 0, 0, 0.2 },
		color = "Fur",
	},
	{
		name = "Chest",
		parent = "Body",
		size = { 0.95, 1.15, 0.85 },
		pos = { 0, -0.02, -0.7 },
		color = "Pale",
	},
	{
		name = "Saddle",
		parent = "Body",
		size = { 0.6, 0.2, 1.3 },
		pos = { 0, 0.55, -0.1 },
		color = "Dark",
	},
	{
		name = "Neck",
		parent = "Body",
		size = { 0.55, 0.7, 0.6 },
		pos = { 0, 0.45, -1.05 },
		color = "Fur",
		rot = { -40, 0, 0 },
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.62, 0.58, 0.7 },
		pos = { 0, 0.8, -1.45 },
		color = "Fur",
		pivot = { 0, -0.1, 0.3 },
	},
	{
		name = "Muzzle",
		parent = "Head",
		size = { 0.3, 0.28, 0.5 },
		pos = { 0, -0.12, -0.55 },
		color = "Pale",
	},
	{
		name = "Nose",
		parent = "Muzzle",
		size = { 0.18, 0.14, 0.1 },
		pos = { 0, 0.06, -0.28 },
		color = "Dark",
	},
	{
		name = "Jaw",
		parent = "Head",
		size = { 0.26, 0.1, 0.42 },
		pos = { 0, -0.3, -0.5 },
		color = "Dark",
		pivot = { 0, 0, 0.2 },
	},
	{
		name = "EarL",
		parent = "Head",
		size = { 0.18, 0.36, 0.1 },
		pos = { -0.2, 0.45, 0.1 },
		color = "Dark",
	},
	{
		name = "EarR",
		parent = "Head",
		size = { 0.18, 0.36, 0.1 },
		pos = { 0.2, 0.45, 0.1 },
		color = "Dark",
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.1, 0.08, 0.08 },
		pos = { -0.22, 0.1, -0.28 },
		color = "Eye",
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.1, 0.08, 0.08 },
		pos = { 0.22, 0.1, -0.28 },
		color = "Eye",
		neon = true,
	},
	{
		name = "LegFL",
		parent = "Body",
		size = { 0.28, 1.0, 0.3 },
		pos = { -0.32, -1.0, -0.75 },
		color = "Fur",
		pivot = { 0, 0.5, 0 },
	},
	{
		name = "LegBR",
		parent = "Body",
		size = { 0.28, 1.0, 0.3 },
		pos = { 0.32, -1.0, 0.75 },
		color = "Fur",
		pivot = { 0, 0.5, 0 },
	},
	{
		name = "LegFR",
		parent = "Body",
		size = { 0.28, 1.0, 0.3 },
		pos = { 0.32, -1.0, -0.75 },
		color = "Fur",
		pivot = { 0, 0.5, 0 },
	},
	{
		name = "LegBL",
		parent = "Body",
		size = { 0.28, 1.0, 0.3 },
		pos = { -0.32, -1.0, 0.75 },
		color = "Fur",
		pivot = { 0, 0.5, 0 },
	},
	{
		name = "Tail",
		parent = "Body",
		size = { 0.28, 0.28, 1.0 },
		pos = { 0, 0.3, 1.35 },
		color = "Fur",
		rot = { 30, 0, 0 },
		pivot = { 0, 0, -0.5 },
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

local JAW_SNARL = 0.15 -- radians of jaw open while Alert
local JAW_WINDUP = 0.5
local JAW_BITE = 0.9
local ATTACK_SECONDS = 0.45
local EAR_PIN = 0.6 -- ears laid back for the wind-up and the attack

local function smooth01(x: number): number
	local c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

-- Jaw and ears are not generic joints, so they are posed every step (snarl, wind-up open, bite).
local function custom(ctx: Types.AnimCtx)
	local state = ctx.state
	local jaw, pin = 0, 0
	if state == "Alert" then
		jaw = JAW_SNARL
	elseif state == "Telegraph" then
		local e = smooth01(ctx.stateTime / math.max(ctx.stateTime + ctx.telegraphLeft, 0.01))
		jaw, pin = JAW_WINDUP * e, EAR_PIN * e
	elseif state == "Attack" then
		local q = math.clamp(ctx.stateTime / ATTACK_SECONDS, 0, 1)
		jaw, pin = JAW_BITE * (1 - q * q), EAR_PIN
	elseif state == "Run" then
		pin = EAR_PIN * 0.5
	end
	ctx.pose("Jaw", CFrame.Angles(-jaw, 0, 0))
	ctx.pose("EarL", CFrame.Angles(pin, 0, -pin * 0.4))
	ctx.pose("EarR", CFrame.Angles(pin, 0, pin * 0.4))
end

local def: Types.CreatureDef = {
	kind = "Wolf",
	rig = {
		kind = "Wolf",
		body = "Body",
		head = "Head",
		tail = "Tail",
		legs = { "LegFL", "LegBR", "LegFR", "LegBL" },
		wings = {},
		attach = { "Mouth", "Hit" },
		gait = "Quad",
		stride = 0.75,
		runScale = 1.5,
		bob = 0.08,
		idleSway = 0.02,
		telegraphPose = "Crouch",
		attackPose = "Bite",
		custom = custom,
	},
	build = buildRows,
}

return def
