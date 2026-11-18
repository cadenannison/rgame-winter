--!strict
-- Pure ambient behaviors (no Roblox APIs): Circle (crows) and Lure (aurora wisps). No damage here:
-- the wisp's touch is a capped warmth drain amount the server applies.

local Circle = {}
local Lure = {}

export type Point = { x: number, z: number }

export type CircleState = { angle: number, scatterLeft: number? }
export type CircleInput = {
	self: Point,
	center: Point,
	radius: number,
	angularSpeed: number, -- radians per second
	scatter: boolean, -- a player came close / the Stalker hunts
	scatterDir: Point, -- unit direction to flee along
	scatterSeconds: number,
	scatterStep: number, -- studs ahead per step while scattering
}
export type CirclePhase = "Circle" | "Scatter" | "Gone"
export type CircleOutput = { phase: CirclePhase, goal: Point, heading: Point }

function Circle.new(angle: number?): CircleState
	return { angle = angle or 0, scatterLeft = nil }
end

function Circle.step(
	state: CircleState,
	input: CircleInput,
	dt: number
): (CircleState, CircleOutput)
	local scatterLeft = state.scatterLeft
	if scatterLeft == nil and input.scatter then
		scatterLeft = input.scatterSeconds
	end
	if scatterLeft ~= nil then
		scatterLeft -= dt
		local dir = input.scatterDir
		local goal = {
			x = input.self.x + dir.x * input.scatterStep,
			z = input.self.z + dir.z * input.scatterStep,
		}
		local phase: CirclePhase = if scatterLeft <= 0 then "Gone" else "Scatter"
		return { angle = state.angle, scatterLeft = scatterLeft }, {
			phase = phase,
			goal = goal,
			heading = dir,
		}
	end
	local angle = state.angle + input.angularSpeed * dt
	local goal = {
		x = input.center.x + math.cos(angle) * input.radius,
		z = input.center.z + math.sin(angle) * input.radius,
	}
	return { angle = angle, scatterLeft = nil }, {
		phase = "Circle",
		goal = goal,
		heading = { x = -math.sin(angle), z = math.cos(angle) },
	}
end

export type LureState = { cool: number, drained: number }
export type LureInput = {
	self: Point,
	player: Point?, -- nearest player
	hazard: Point?, -- where it drifts toward
	lureRange: number,
	leadDistance: number,
	touchRange: number,
	drainCooldown: number,
	drainAmount: number, -- warmth per touch (before the cap)
	drainCap: number, -- total warmth this wisp may ever drain
}
export type LureMode = "Drift" | "Lure" | "Touch" | "Spent"
export type LureOutput = { mode: LureMode, goal: Point?, drain: number }

function Lure.new(): LureState
	return { cool = 0, drained = 0 }
end

local function unit(from: Point, to: Point): Point
	local dx, dz = to.x - from.x, to.z - from.z
	local m = math.sqrt(dx * dx + dz * dz)
	if m < 1e-6 then
		return { x = 1, z = 0 }
	end
	return { x = dx / m, z = dz / m }
end

function Lure.step(state: LureState, input: LureInput, dt: number): (LureState, LureOutput)
	local cool = math.max(0, state.cool - dt)
	local drained = state.drained
	local player, hazard = input.player, input.hazard
	if drained >= input.drainCap then
		local away = if player then unit(player, input.self) else { x = 1, z = 0 }
		return { cool = cool, drained = drained }, {
			mode = "Spent",
			goal = { x = input.self.x + away.x * 30, z = input.self.z + away.z * 30 },
			drain = 0,
		}
	end
	if player == nil then
		local goal = if hazard then hazard else nil
		return { cool = cool, drained = drained }, { mode = "Drift", goal = goal, drain = 0 }
	end
	local dx, dz = player.x - input.self.x, player.z - input.self.z
	local d = math.sqrt(dx * dx + dz * dz)
	if d <= input.touchRange and cool <= 0 then
		local amount = math.min(input.drainAmount, input.drainCap - drained)
		local away = unit(player, input.self)
		return { cool = input.drainCooldown, drained = drained + amount }, {
			mode = "Touch",
			goal = {
				x = input.self.x + away.x * input.leadDistance,
				z = input.self.z + away.z * input.leadDistance,
			},
			drain = amount,
		}
	end
	if d <= input.lureRange then
		-- Hovers ahead of the player on the hazard side (or just out of reach when there is none).
		local dir = if hazard then unit(player, hazard) else unit(player, input.self)
		return { cool = cool, drained = drained }, {
			mode = "Lure",
			goal = {
				x = player.x + dir.x * input.leadDistance,
				z = player.z + dir.z * input.leadDistance,
			},
			drain = 0,
		}
	end
	return { cool = cool, drained = drained }, { mode = "Drift", goal = hazard, drain = 0 }
end

return { Circle = Circle, Lure = Lure }
