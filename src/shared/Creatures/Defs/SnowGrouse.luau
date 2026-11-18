--!strict
-- SnowGrouse: plump slate bird, white breast, red comb, folded wings that flare when it flushes. Intended root 1.5 x 1.5 x 1.8.
-- Wings: WingR (+X) first. Sound hooks (silent): wing flutter on Run (flush), cluck, hurt, death.
-- Data tables first (studs authored at REF root size, scaled to the real root.Size). Rows: pos = part centre
-- relative to its parent part (forward = -Z); pivot = hinge point in the part's local space (joint C1);
-- rot = degrees. Built only via CreatureBuild.part. Contract: docs/CREATURES_CONTRACT.md
local ArtKit = require("../../ArtKit")
local CreatureBuild = require("../CreatureBuild")
local Types = require("../Types")

local REF = { 1.5, 1.5, 1.8 } -- intended root (hitbox) size in studs: width, height, length

local PALETTE: { [string]: { number } } = {
	Feather = { 92, 92, 108 },
	White = { 236, 240, 247 },
	Dark = { 30, 30, 38 },
	Red = { 206, 64, 58 },
	Wing = { 68, 70, 92 },
	Leg = { 196, 150, 92 },
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
		size = { 1.0, 0.9, 1.2 },
		pos = { 0, 0, 0.05 },
		color = "Feather",
	},
	{
		name = "Breast",
		parent = "Body",
		size = { 0.9, 0.7, 0.6 },
		pos = { 0, -0.12, -0.45 },
		color = "White",
	},
	{
		name = "Head",
		parent = "Body",
		size = { 0.45, 0.45, 0.5 },
		pos = { 0, 0.5, -0.6 },
		color = "Feather",
		pivot = { 0, -0.15, 0.15 },
	},
	{
		name = "Beak",
		parent = "Head",
		size = { 0.12, 0.1, 0.25 },
		pos = { 0, -0.06, -0.35 },
		color = "Dark",
	},
	{
		name = "Comb",
		parent = "Head",
		size = { 0.34, 0.07, 0.14 },
		pos = { 0, 0.2, -0.1 },
		color = "Red",
	},
	{
		name = "EyeL",
		parent = "Head",
		size = { 0.08, 0.08, 0.08 },
		pos = { -0.23, 0.05, -0.12 },
		color = "Dark",
	},
	{
		name = "EyeR",
		parent = "Head",
		size = { 0.08, 0.08, 0.08 },
		pos = { 0.23, 0.05, -0.12 },
		color = "Dark",
	},
	{
		name = "WingR",
		parent = "Body",
		size = { 0.1, 0.6, 1.0 },
		pos = { 0.56, 0, 0.05 },
		color = "Wing",
		pivot = { 0, 0.3, 0 },
	},
	{
		name = "WingL",
		parent = "Body",
		size = { 0.1, 0.6, 1.0 },
		pos = { -0.56, 0, 0.05 },
		color = "Wing",
		pivot = { 0, 0.3, 0 },
	},
	{
		name = "LegL",
		parent = "Body",
		size = { 0.1, 0.35, 0.1 },
		pos = { -0.2, -0.575, 0.05 },
		color = "Leg",
		pivot = { 0, 0.175, 0 },
	},
	{
		name = "LegR",
		parent = "Body",
		size = { 0.1, 0.35, 0.1 },
		pos = { 0.2, -0.575, 0.05 },
		color = "Leg",
		pivot = { 0, 0.175, 0 },
	},
	{
		name = "Tail",
		parent = "Body",
		size = { 0.5, 0.12, 0.5 },
		pos = { 0, 0.15, 0.85 },
		color = "Wing",
		rot = { -20, 0, 0 },
		pivot = { 0, 0, -0.25 },
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
	kind = "SnowGrouse",
	rig = {
		kind = "SnowGrouse",
		body = "Body",
		head = "Head",
		tail = "Tail",
		legs = { "LegL", "LegR" },
		wings = { "WingR", "WingL" },
		attach = { "Hit" },
		gait = "Bird",
		stride = 0.7,
		runScale = 1.4,
		bob = 0.05,
		idleSway = 0.04,
		telegraphPose = "Spread",
		attackPose = "Peck",
	},
	build = buildRows,
}

return def
