--!strict
-- Pure map from a mob's AI action (MobService lastAction) to the replicated creature State attribute
-- (Config.Creatures.States). Server writes State on change only; the client animates from it.

local MobStateMap = {}

local MAP: { [string]: string } = {
	Rest = "Idle",
	Idle = "Idle",
	Hold = "Idle",
	Wander = "Walk",
	Return = "Walk",
	Circle = "Walk",
	Drift = "Walk",
	Flee = "Run",
	Chase = "Run",
	Retreat = "Run",
	Leave = "Run",
	Charge = "Run",
	Rush = "Run",
	Scatter = "Run",
	Alert = "Alert",
	Warn = "Alert",
	Windup = "Telegraph",
	Telegraph = "Telegraph",
	Attack = "Attack",
	Strike = "Attack",
	Hurt = "Hurt",
	Death = "Death",
}

-- State for an action ("Idle" for nil / unknown actions).
function MobStateMap.stateFor(action: string?): string
	if action == nil then
		return "Idle"
	end
	return MAP[action] or "Idle"
end

-- Actions that have a target (the Target attribute carries the player's UserId).
local TARGETED: { [string]: boolean } = {
	Chase = true,
	Windup = true,
	Telegraph = true,
	Attack = true,
	Charge = true,
	Rush = true,
	Alert = true,
	Warn = true,
}

function MobStateMap.hasTarget(action: string?): boolean
	return action ~= nil and TARGETED[action] == true
end

-- State precedence for the final write: Death > Hurt (while hurtLeft > 0) > Attack (hold) > action state.
function MobStateMap.resolve(
	action: string?,
	hurtLeft: number,
	attackLeft: number,
	dead: boolean
): string
	if dead then
		return "Death"
	end
	if hurtLeft > 0 then
		return "Hurt"
	end
	if attackLeft > 0 then
		return "Attack"
	end
	return MobStateMap.stateFor(action)
end

return MobStateMap
