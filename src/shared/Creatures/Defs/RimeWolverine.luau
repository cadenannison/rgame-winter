--!strict
-- RimeWolverine: low stocky near-black brute with frosted back and flank stripes, icy eyes; Crouch then Lunge ambush charge.
-- Intended root 2 x 2 x 3.5. Sound hooks (silent): snarl on Alert/Telegraph, lunge, footstep, hurt, death.
-- Data tables first (studs authored at REF root size, scaled to the real root.Size). Rows: pos = part centre
-- relative to its parent part (forward = -Z); pivot = hinge point in the part's local space (joint C1);
-- rot = degrees. Built only via CreatureBuild.part. Contract: docs/CREATURES_CONTRACT.md
local ArtKit = require("../../ArtKit")
local CreatureBuild = require("../CreatureBuild")
local Types = require("../Types")

local REF = { 2, 2, 3.5 } -- intended root (hitbox) size in studs: width, height, length

local PALETTE: { [string]: { number } } = {
	Fur = { 54, 48, 52 },
	Dark = { 30, 26, 30 },
	Muzzle = { 92, 82, 84 },
	Frost = { 190, 212, 230 },
	Eye = { 160, 230, 255 },
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
		size = { 1.1, 0.9, 1.9 },
		pos = { 0, 0.05, 0.1 },
		color = "Fur",
	},
	{
		name = "FrostBack",
		parent = "Body",
		size = { 0.9, 0.28, 1.3 },
		pos = { 0, 0.5, -0.1 },
		color = "Frost",
	},
	{
		name = "StripeL",
		parent = "Body",
		size = { 0.1, 0.28, 1.5 },
		pos = { -0.58, 0.1, 0.05 },
		color = "Frost",
	},
	{
		name = "StripeR",
		parent = "Body",
		size = { 0.1, 0.28, 1.5 },
		pos = { 0.58, 0.1, 0.05 },
		color = "Frost",
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.75, 0.65, 0.8 },
		pos = { 0, 0.12, -1.25 },
		color = "Fur",
		pivot = { 0, -0.1, 0.3 },
	},
	{
		name = "Muzzle",
		parent = "Head",
		size = { 0.4, 0.3, 0.4 },
		pos = { 0, -0.12, -0.5 },
		color = "Muzzle",
	},
	{
		name = "Nose",
		parent = "Muzzle",
		size = { 0.16, 0.12, 0.1 },
		pos = { 0, 0.06, -0.25 },
		color = "Dark",
	},
	{
		name = "Jaw",
		parent = "Head",
		size = { 0.34, 0.1, 0.4 },
		pos = { 0, -0.3, -0.4 },
		color = "Dark",
		pivot = { 0, 0, 0.18 },
	},
	{
		name = "EarL",
		parent = "Head",
		size = { 0.22, 0.22, 0.1 },
		pos = { -0.28, 0.4, 0.1 },
		color = "Fur",
	},
	{
		name = "EarR",
		parent = "Head",
		size = { 0.22, 0.22, 0.1 },
		pos = { 0.28, 0.4, 0.1 },
		color = "Fur",
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.1, 0.08, 0.08 },
		pos = { -0.27, 0.1, -0.3 },
		color = "Eye",
		neon = true,
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.1, 0.08, 0.08 },
		pos = { 0.27, 0.1, -0.3 },
		color = "Eye",
		neon = true,
	},
	{
		name = "LegFL",
		parent = "Body",
		size = { 0.4, 0.6, 0.42 },
		pos = { -0.5, -0.75, -0.6 },
		color = "Dark",
		pivot = { 0, 0.3, 0 },
	},
	{
		name = "LegBR",
		parent = "Body",
		size = { 0.4, 0.6, 0.42 },
		pos = { 0.5, -0.75, 0.6 },
		color = "Dark",
		pivot = { 0, 0.3, 0 },
	},
	{
		name = "LegFR",
		parent = "Body",
		size = { 0.4, 0.6, 0.42 },
		pos = { 0.5, -0.75, -0.6 },
		color = "Dark",
		pivot = { 0, 0.3, 0 },
	},
	{
		name = "LegBL",
		parent = "Body",
		size = { 0.4, 0.6, 0.42 },
		pos = { -0.5, -0.75, 0.6 },
		color = "Dark",
		pivot = { 0, 0.3, 0 },
	},
	{
		name = "Tail",
		parent = "Body",
		size = { 0.4, 0.4, 0.9 },
		pos = { 0, 0.1, 1.35 },
		color = "Fur",
		rot = { 20, 0, 0 },
		pivot = { 0, 0, -0.45 },
	},
	{
		name = "TailTip",
		parent = "Tail",
		size = { 0.34, 0.34, 0.3 },
		pos = { 0, 0, 0.5 },
		color = "Frost",
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
	kind = "RimeWolverine",
	rig = {
		kind = "RimeWolverine",
		body = "Body",
		head = "Head",
		tail = "Tail",
		legs = { "LegFL", "LegBR", "LegFR", "LegBL" },
		wings = {},
		attach = { "Mouth", "Hit" },
		gait = "Quad",
		stride = 0.9,
		runScale = 1.7,
		bob = 0.06,
		idleSway = 0.015,
		telegraphPose = "Crouch",
		attackPose = "Lunge",
		custom = custom,
	},
	build = buildRows,
}

return def
