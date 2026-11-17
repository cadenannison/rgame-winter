--!strict
-- Pure mob decision logic (no Roblox APIs). The server adapter turns an Action into movement.

export type Behavior = "Flee" | "Hunt"
export type Action = "Wander" | "Flee" | "Chase" | "Attack" | "Retreat"

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
		return "Wander"
	end
	if dist == nil or dist > input.aggroRange then
		return "Wander"
	end
	if dist <= input.attackRange and input.canAttack then
		return "Attack"
	end
	return "Chase"
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
