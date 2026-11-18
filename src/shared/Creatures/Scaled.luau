--!strict
-- Data-driven part builder for creature Defs (Art Pass 3, Agent 3). A Def lists rows (sizes/positions as
-- FRACTIONS of root.Size) and calls Scaled.build(root, rows). Every part goes through CreatureBuild.part.
-- Row.pos is the world-axis position (root-local, fraction of root.Size) of the part centre, or of the hinge
-- point when `hinge` is set. Row.rot is the rest orientation in degrees (applied about the hinge).
-- Row.hinge is in half-extent units of the part itself (0,1,0 = hinge at the top edge: legs, arms).
-- Forward is -Z. Also exposes Scaled.armCustom, a shared rig.custom for readable telegraphs.
local CreatureBuild = require("./CreatureBuild")
local Types = require("./Types")

local MIN_SIZE = 0.05
local RAISE_SECONDS = 0.45 -- arms reach the raised pose after this long in Telegraph
local SLAM_SECONDS = 0.16 -- raised -> down snap in Attack
local TREMBLE_HZ = 34
local TREMBLE_AMP = 0.04
local WALK_SWING_SPEED = 6 -- studs/s at which arm swing is full
local IDLE_BREATH_HZ = 1.4

export type Row = {
	name: string,
	parent: string?, -- row name; nil = root
	size: { number },
	pos: { number },
	color: Color3,
	mat: Enum.Material?,
	shape: Enum.PartType?,
	neon: boolean?,
	alpha: number?,
	rot: { number }?,
	hinge: { number }?,
}

export type Mount = { part: string, name: string, pos: { number } } -- Attachment on a built part

local Scaled = {}

local function vec(v: { number }): Vector3
	return Vector3.new(v[1] or 0, v[2] or 0, v[3] or 0)
end

function Scaled.build(root: BasePart, rows: { Row }, mounts: { Mount }?): { [string]: BasePart }
	local rs = root.Size
	local built: { [string]: BasePart } = {}
	local rest: { [string]: CFrame } = {} -- part centre, root space
	for _, row in rows do
		local size = vec(row.size) * rs
		size = Vector3.new(
			math.max(size.X, MIN_SIZE),
			math.max(size.Y, MIN_SIZE),
			math.max(size.Z, MIN_SIZE)
		)
		local rot = if row.rot
			then CFrame.Angles(
				math.rad(row.rot[1] or 0),
				math.rad(row.rot[2] or 0),
				math.rad(row.rot[3] or 0)
			)
			else CFrame.identity
		local h = if row.hinge then vec(row.hinge) * size / 2 else Vector3.zero
		local joint = CFrame.new(vec(row.pos) * rs) * rot -- hinge frame, root space
		local parentRest = if row.parent then rest[row.parent] else CFrame.identity
		local parentPart = if row.parent then built[row.parent] else root
		assert(parentRest and parentPart, `Scaled: parent {row.parent} missing for {row.name}`)
		local part = CreatureBuild.part({
			name = row.name,
			parent = parentPart,
			size = size,
			offset = parentRest:ToObjectSpace(joint * CFrame.new(h)),
			color = row.color,
			material = row.mat,
			shape = row.shape,
			transparency = row.alpha,
			neon = row.neon,
			pivot = CFrame.new(h),
		})
		built[row.name] = part
		rest[row.name] = joint * CFrame.new(h):Inverse()
	end
	if mounts then
		for _, m in mounts do
			local target = built[m.part]
			if target then
				CreatureBuild.attachment(target, m.name, CFrame.new(vec(m.pos) * rs))
			end
		end
	end
	return built
end

export type ArmCfg = {
	arms: { string }, -- hinged-at-shoulder part names (X rotation: + swings forward/up)
	raised: number, -- radians at the top of the telegraph
	down: number, -- radians at the end of the slam
	swing: number, -- walk swing amplitude
	sway: number, -- idle breathing amplitude
}

-- Shared rig.custom: raised-arms wind-up (clear Telegraph), snap down on Attack, alternating swing on Walk/Run.
function Scaled.armCustom(cfg: ArmCfg): (Types.AnimCtx) -> ()
	return function(ctx: Types.AnimCtx)
		local angle: number? = nil
		if ctx.state == "Telegraph" then
			local e = math.clamp(ctx.stateTime / RAISE_SECONDS, 0, 1)
			e = 1 - (1 - e) * (1 - e)
			angle = cfg.raised * e + math.sin(ctx.t * TREMBLE_HZ) * TREMBLE_AMP * e
		elseif ctx.state == "Attack" then
			local s = math.clamp(ctx.stateTime / SLAM_SECONDS, 0, 1)
			angle = cfg.raised + (cfg.down - cfg.raised) * s * s
		end
		for i, arm in cfg.arms do
			local a = angle
			if a == nil then
				local move = math.clamp(ctx.speed / WALK_SWING_SPEED, 0, 1)
				local sign = if i % 2 == 1 then 1 else -1
				a = math.sin(ctx.phase) * cfg.swing * move * sign
					+ math.sin(ctx.t * IDLE_BREATH_HZ + i) * cfg.sway
			end
			ctx.pose(arm, CFrame.Angles(a :: number, 0, 0))
		end
	end
end

return Scaled
