--!strict
-- LakeSeal: blubbery blue-grey seal, pale belly, dark back marks; territorial rear-up (Rear) telegraph, Bite.
-- Intended root 2.5 x 1.8 x 5. Sound hooks (silent): bark on Telegraph, bite, flop on Walk phase, hurt, death.
-- Data tables first (studs authored at REF root size, scaled to the real root.Size). Rows: pos = part centre
-- relative to its parent part (forward = -Z); pivot = hinge point in the part's local space (joint C1);
-- rot = degrees. Built only via CreatureBuild.part. Contract: docs/CREATURES_CONTRACT.md
local ArtKit = require("../../ArtKit")
local CreatureBuild = require("../CreatureBuild")
local Types = require("../Types")

local REF = { 2.5, 1.8, 5 } -- intended root (hitbox) size in studs: width, height, length

local PALETTE: { [string]: { number } } = {
	Skin = { 98, 112, 134 },
	Pale = { 200, 210, 224 },
	Dark = { 40, 48, 66 },
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
		size = { 1.7, 1.3, 3.0 },
		pos = { 0, -0.1, 0.2 },
		color = "Skin",
	},
	{
		name = "Belly",
		parent = "Body",
		size = { 1.4, 0.6, 2.4 },
		pos = { 0, -0.45, -0.1 },
		color = "Pale",
	},
	{
		name = "Hind",
		parent = "Body",
		size = { 0.9, 0.8, 1.2 },
		pos = { 0, -0.15, 1.8 },
		color = "Skin",
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.8, 0.75, 0.9 },
		pos = { 0, 0.35, -1.85 },
		color = "Skin",
		pivot = { 0, -0.15, 0.4 },
	},
	{
		name = "Snout",
		parent = "Head",
		size = { 0.42, 0.3, 0.4 },
		pos = { 0, -0.12, -0.6 },
		color = "Pale",
	},
	{
		name = "Nose",
		parent = "Snout",
		size = { 0.2, 0.12, 0.1 },
		pos = { 0, 0.08, -0.22 },
		color = "Dark",
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.14, 0.14, 0.1 },
		pos = { -0.3, 0.12, -0.3 },
		color = "Dark",
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.14, 0.14, 0.1 },
		pos = { 0.3, 0.12, -0.3 },
		color = "Dark",
	},
	{
		name = "FlipL",
		parent = "Body",
		size = { 0.9, 0.12, 0.5 },
		pos = { -1.15, -0.5, -0.7 },
		color = "Skin",
		rot = { 0, 0, 20 },
		pivot = { 0.45, 0, 0 },
	},
	{
		name = "FlipR",
		parent = "Body",
		size = { 0.9, 0.12, 0.5 },
		pos = { 1.15, -0.5, -0.7 },
		color = "Skin",
		rot = { 0, 0, -20 },
		pivot = { -0.45, 0, 0 },
	},
	{
		name = "TailFlip",
		parent = "Hind",
		size = { 1.2, 0.12, 0.6 },
		pos = { 0, -0.05, 0.75 },
		color = "Skin",
		pivot = { 0, 0, -0.3 },
	},
	{
		name = "MarkA",
		parent = "Body",
		size = { 0.6, 0.06, 0.6 },
		pos = { 0.3, 0.66, -0.2 },
		color = "Dark",
	},
	{
		name = "MarkB",
		parent = "Body",
		size = { 0.5, 0.06, 0.5 },
		pos = { -0.35, 0.66, 0.6 },
		color = "Dark",
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

local def: Types.CreatureDef = {
	kind = "LakeSeal",
	rig = {
		kind = "LakeSeal",
		body = "Body",
		head = "Head",
		tail = "TailFlip",
		legs = { "FlipL", "FlipR" },
		wings = {},
		attach = { "Mouth", "Hit" },
		gait = "Seal",
		stride = 0.6,
		runScale = 1.5,
		bob = 0.12,
		idleSway = 0.04,
		telegraphPose = "Rear",
		attackPose = "Bite",
	},
	build = buildRows,
}

return def
