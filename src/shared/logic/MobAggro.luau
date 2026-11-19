--!strict
-- Pure aggro rules for fire-safe hostiles (no Roblox APIs). A fireSafe mob never becomes aggressive toward
-- a target standing inside a lit fire's radius unless that target hit it first (HitGraceSeconds); it gives
-- up (de-aggro, wander) when the target is beyond LeashDistance or out of sight for LoseSightSeconds.
-- Horror kinds (Stalker, lurkers, wraiths) are never fireSafe. Mobs that are not fireSafe are untouched.

local Config = require("../Config")
local FireRepel = require("./FireRepel")

export type State = { aggro: boolean, unseen: number }
export type Input = {
	fireSafe: boolean,
	dist: number?, -- flat distance to the nearest player (nil = none)
	aggroRange: number, -- distance at which the mob starts hunting
	targetInFire: boolean,
	hitRecently: boolean, -- the target hit this mob within HitGraceSeconds
	canSee: boolean,
}

local MobAggro = {}

function MobAggro.new(): State
	return { aggro = false, unseen = 0 }
end

-- Flagged by role (Config.Aggro.FireSafeRoles) or by an explicit species flag; never when excluded
-- (horror/ambush kinds) or when the kind ignores fire entirely (breaksFire).
function MobAggro.isFireSafe(
	kindName: string,
	role: string,
	explicit: boolean?,
	breaksFire: boolean
): boolean
	if table.find(Config.Aggro.FireSafeExclude, kindName) ~= nil or breaksFire then
		return false
	end
	if explicit ~= nil then
		return explicit
	end
	return table.find(Config.Aggro.FireSafeRoles, role) ~= nil
end

function MobAggro.targetInFire(x: number, z: number, fires: { FireRepel.Fire }): boolean
	return FireRepel.insideAny(x, z, fires, 0, Config.Fire.WarmRadius) ~= nil
end

-- The player hit the mob at hitAt (os.clock) and the grace window is still open.
function MobAggro.hitRecently(now: number, hitAt: number?): boolean
	return hitAt ~= nil and now - hitAt <= Config.Aggro.HitGraceSeconds
end

-- One step. Returns the new state and whether the mob may treat the nearest player as its target.
function MobAggro.step(state: State, input: Input, dt: number): (State, boolean)
	if not input.fireSafe then
		return MobAggro.new(), true
	end
	local A = Config.Aggro
	local dist = input.dist
	if dist == nil or dist > A.LeashDistance then
		return MobAggro.new(), false
	end
	local blocked = input.targetInFire and not input.hitRecently
	if not state.aggro then
		if input.canSee and dist <= input.aggroRange and not blocked then
			return { aggro = true, unseen = 0 }, true
		end
		return MobAggro.new(), false
	end
	local unseen = if input.canSee then 0 else state.unseen + dt
	if blocked or unseen >= A.LoseSightSeconds then
		return MobAggro.new(), false
	end
	return { aggro = true, unseen = unseen }, true
end

return MobAggro
