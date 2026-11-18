--!strict
-- Pure prey behaviors (no Roblox APIs): Flee (sprint / pause rhythm) and ReturnAfterFlee (drift home once calm).
-- Each is step(state, input, dt) -> (newState, output); the server species module maps outputs to movement.

local Flee = {}
local ReturnAfterFlee = {}

export type FleeState = { fleeing: boolean, burstLeft: number, restLeft: number }
export type FleeInput = {
	dist: number?, -- nearest threat distance, nil = none
	fleeRange: number,
	burstSeconds: number,
	restSeconds: number, -- <= 0: never pauses
}
export type FleeOutput = { fleeing: boolean, moving: boolean }

function Flee.new(): FleeState
	return { fleeing = false, burstLeft = 0, restLeft = 0 }
end

function Flee.step(state: FleeState, input: FleeInput, dt: number): (FleeState, FleeOutput)
	local dist = input.dist
	if dist == nil or dist >= input.fleeRange then
		return Flee.new(), { fleeing = false, moving = false }
	end
	local burstLeft, restLeft = state.burstLeft, state.restLeft
	if not state.fleeing then
		burstLeft, restLeft = input.burstSeconds, 0
	end
	local moving = true
	if input.restSeconds > 0 and restLeft > 0 then
		restLeft = math.max(0, restLeft - dt)
		moving = false
		if restLeft <= 0 then
			burstLeft = input.burstSeconds
		end
	else
		burstLeft -= dt
		if burstLeft <= 0 and input.restSeconds > 0 then
			restLeft = input.restSeconds
		end
	end
	return { fleeing = true, burstLeft = burstLeft, restLeft = restLeft }, {
		fleeing = true,
		moving = moving,
	}
end

export type ReturnPhase = "Home" | "Away" | "Returning"
export type ReturnState = { phase: ReturnPhase, calm: number }
export type ReturnInput = {
	fleeing: boolean,
	homeDist: number, -- studs from the home point
	returnDelay: number, -- calm seconds before heading back
	homeRadius: number, -- counts as home inside this
}
export type ReturnOutput = { goHome: boolean, phase: ReturnPhase }

function ReturnAfterFlee.new(): ReturnState
	return { phase = "Home", calm = 0 }
end

function ReturnAfterFlee.step(
	state: ReturnState,
	input: ReturnInput,
	dt: number
): (ReturnState, ReturnOutput)
	if input.fleeing then
		return { phase = "Away", calm = 0 }, { goHome = false, phase = "Away" }
	end
	local phase: ReturnPhase, calm = state.phase, state.calm
	if phase == "Away" then
		calm += dt
		if calm >= input.returnDelay then
			phase = "Returning"
		end
	elseif phase == "Home" and input.homeDist > input.homeRadius * 2 then
		phase = "Returning" -- wandered too far
	end
	if phase == "Returning" and input.homeDist <= input.homeRadius then
		phase, calm = "Home", 0
	end
	return { phase = phase, calm = calm }, { goHome = phase == "Returning", phase = phase }
end

return { Flee = Flee, ReturnAfterFlee = ReturnAfterFlee }
