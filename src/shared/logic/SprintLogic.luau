--!strict
-- Pure sprint rules: gating (hunger, downed, dead) and the extra hunger cost. No Roblox APIs.

export type Cfg = {
	SpeedMultiplier: number,
	ExtraHungerPerSecond: number,
	MinHungerToStart: number,
	MinHungerToKeep: number,
	MinMoveSpeed: number,
}

local SprintLogic = {}

-- May a player begin sprinting? Needs hunger above the start threshold, and to be alive and not downed.
function SprintLogic.canStart(hunger: number, downed: boolean, dead: boolean, c: Cfg): boolean
	return not downed and not dead and hunger >= c.MinHungerToStart
end

-- May an active sprint continue? Same as canStart but with the lower keep threshold (hysteresis).
function SprintLogic.canKeep(hunger: number, downed: boolean, dead: boolean, c: Cfg): boolean
	return not downed and not dead and hunger > c.MinHungerToKeep
end

-- Extra hunger lost over dt: only while sprinting AND moving.
function SprintLogic.hungerCost(sprinting: boolean, moveSpeed: number, dt: number, c: Cfg): number
	if not sprinting or dt <= 0 or moveSpeed < c.MinMoveSpeed then
		return 0
	end
	return c.ExtraHungerPerSecond * dt
end

-- Walk speed for a base speed: multiplied while sprinting.
function SprintLogic.speed(base: number, sprinting: boolean, c: Cfg): number
	return if sprinting then base * c.SpeedMultiplier else base
end

-- Resolves the sprint flag for one tick: wanted = the player's last validated request.
function SprintLogic.resolve(
	wanted: boolean,
	active: boolean,
	hunger: number,
	downed: boolean,
	dead: boolean,
	c: Cfg
): boolean
	if not wanted then
		return false
	end
	if active then
		return SprintLogic.canKeep(hunger, downed, dead, c)
	end
	return SprintLogic.canStart(hunger, downed, dead, c)
end

return SprintLogic
