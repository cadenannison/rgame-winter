--!strict
-- Pure mob decision logic (no Roblox APIs). The server adapter turns an Action into movement.

export type Behavior = "Flee" | "Hunt"
export type Action = "Wander" | "Flee" | "Chase" | "Attack" | "Retreat" | "Leave"

export type Input = {
	behavior: Behavior,
	nearestPlayerDist: number?, -- nil when no player is in range
	isNight: boolean,
	nightOnly: boolean,
	fleeRange: number,
	aggroRange: number,
	attackRange: number,
	inFireRepel: boolean, -- mob is inside a campfire's repel radius
	canAttack: boolean, -- attack cooldown ready
}

local MobAI = {}

function MobAI.decide(input: Input): Action
	local dist = input.nearestPlayerDist
	if input.behavior == "Flee" then
		if dist ~= nil and dist < input.fleeRange then
			return "Flee"
		end
		return "Wander"
	end
	-- Hunt
	if input.inFireRepel then
		return "Retreat"
	end
	if input.nightOnly and not input.isNight then
		return "Leave" -- dawn: night hunters run off and despawn
	end
	if dist == nil or dist > input.aggroRange then
		return "Wander"
	end
	if dist <= input.attackRange and input.canAttack then
		return "Attack"
	end
	return "Chase"
end

-- Attack windup (growl/telegraph) state machine for a mob that is in attack range and ready.
export type Windup = { startedAt: number? }
export type WindupResult = "Start" | "Wait" | "Strike" | "Cancel" | "Idle"

-- ready: decide() said Attack (in range, cooldown over). reach: still within strike reach right now.
-- "Start" begins the windup; "Wait" keeps winding; "Strike" lands the bite (clears state); "Cancel"
-- aborts (target stepped away); "Idle" = nothing to do.
function MobAI.windupStep(
	state: Windup,
	now: number,
	ready: boolean,
	reach: boolean,
	windupSeconds: number
): WindupResult
	local started = state.startedAt
	if started == nil then
		if not ready then
			return "Idle"
		end
		if windupSeconds <= 0 then
			return "Strike"
		end
		state.startedAt = now
		return "Start"
	end
	if not reach then
		state.startedAt = nil
		return "Cancel"
	end
	if now - started >= windupSeconds then
		state.startedAt = nil
		return "Strike"
	end
	return "Wait"
end

export type Burst = { burstEnd: number, restEnd: number }

-- Flee in sprints with pauses. Call each AI step while the mob is fleeing; mutates and returns
-- whether the mob should move this step. A finished sprint starts a rest; a finished rest starts a
-- sprint. restSeconds <= 0 means it never rests.
function MobAI.fleeBurst(
	state: Burst,
	now: number,
	burstSeconds: number,
	restSeconds: number
): boolean
	if restSeconds <= 0 then
		return true
	end
	if now < state.burstEnd then
		return true
	end
	if now < state.restEnd then
		return false
	end
	if state.burstEnd > 0 and state.restEnd < state.burstEnd then
		state.restEnd = now + restSeconds
		return false
	end
	state.burstEnd = now + burstSeconds
	return true
end

return MobAI
