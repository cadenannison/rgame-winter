--!strict
-- Fish (arctic char): small silver fish, dark back, orange fins, Slither gait. Intended root 1 x 0.8 x 2 (existing kind keeps its size).
-- Sound hooks (silent): splash on flee, death.
-- Data tables first (studs authored at REF root size, scaled to the real root.Size). Rows: pos = part centre
-- relative to its parent part (forward = -Z); pivot = hinge point in the part's local space (joint C1);
-- rot = degrees. Built only via CreatureBuild.part. Contract: docs/CREATURES_CONTRACT.md
local ArtKit = require("../../ArtKit")
local CreatureBuild = require("../CreatureBuild")
local Types = require("../Types")

local REF = { 1, 0.8, 2 } -- intended root (hitbox) size in studs: width, height, length

local PALETTE: { [string]: { number } } = {
	Silver = { 170, 200, 222 },
	Back = { 52, 84, 118 },
	Fin = { 222, 128, 92 },
	Dark = { 16, 18, 26 },
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
		size = { 0.55, 0.55, 0.95 },
		pos = { 0, 0, -0.45 },
		color = "Silver",
	},
	{
		name = "Back",
		parent = "Body",
		size = { 0.5, 0.2, 0.85 },
		pos = { 0, 0.25, 0 },
		color = "Back",
	},
	{
		name = "Mid",
		parent = "Body",
		size = { 0.4, 0.45, 0.7 },
		pos = { 0, 0, 0.8 },
		color = "Silver",
		pivot = { 0, 0, -0.3 },
	},
	{
		name = "TailFin",
		parent = "Mid",
		size = { 0.08, 0.6, 0.5 },
		pos = { 0, 0, 0.55 },
		color = "Fin",
		pivot = { 0, 0, -0.2 },
	},
	{
		name = "Dorsal",
		parent = "Body",
		size = { 0.06, 0.3, 0.4 },
		pos = { 0, 0.45, 0.05 },
		color = "Back",
	},
	{
		name = "PecL",
		parent = "Body",
		size = { 0.3, 0.05, 0.22 },
		pos = { -0.38, -0.12, -0.2 },
		color = "Fin",
		pivot = { 0.15, 0, 0 },
	},
	{
		name = "PecR",
		parent = "Body",
		size = { 0.3, 0.05, 0.22 },
		pos = { 0.38, -0.12, -0.2 },
		color = "Fin",
		pivot = { -0.15, 0, 0 },
	},
	{
		name = "EyeL",
		parent = "Body",
		size = { 0.08, 0.12, 0.12 },
		pos = { -0.28, 0.08, -0.35 },
		color = "Dark",
	},
	{
		name = "EyeR",
		parent = "Body",
		size = { 0.08, 0.12, 0.12 },
		pos = { 0.28, 0.08, -0.35 },
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

local PEC_HZ = 6
local PEC_AMP = 0.4
local DEATH_ROLL_RATE = 5 -- rad/s toward belly-up

-- Pectoral flutter; dead fish roll belly-up and drift to the surface. Pectorals are not generic joints.
local function custom(ctx: Types.AnimCtx)
	local flutter = math.sin(ctx.t * PEC_HZ) * PEC_AMP
	if ctx.state == "Death" then
		local roll = math.min(math.pi, ctx.stateTime * DEATH_ROLL_RATE)
		ctx.pose("Body", CFrame.new(0, 0.05 * roll, 0) * CFrame.Angles(0, 0, roll))
		flutter = 0
	end
	ctx.pose("PecL", CFrame.Angles(0, 0, flutter))
	ctx.pose("PecR", CFrame.Angles(0, 0, -flutter))
end

local def: Types.CreatureDef = {
	kind = "Fish",
	rig = {
		kind = "Fish",
		body = "Body",
		tail = "TailFin",
		legs = { "Mid" }, -- body segments, front to back
		wings = {},
		attach = { "Hit" },
		gait = "Slither",
		stride = 0.35,
		runScale = 1.6,
		bob = 0,
		idleSway = 0.05,
		custom = custom,
	},
	build = buildRows,
}

return def
