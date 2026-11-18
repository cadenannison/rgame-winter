--!strict
-- Pure combat behaviors (no Roblox APIs): Retaliate, TerritorialWarn, HerdAlert, Telegraph, PackFlank.
-- step(state, input, dt) -> (newState, output). Damage is never decided here: the server recomputes reach
-- and damage at the strike (Telegraph "Strike" is only a timing event).

local Retaliate = {}
local TerritorialWarn = {}
local HerdAlert = {}
local Telegraph = {}
local PackFlank = {}

export type Point = { x: number, z: number }

-- Retaliate: neutral until hit, then chases and bites for a while.
export type RetaliateState = { angryLeft: number }
export type RetaliateInput = {
	hit: boolean, -- damaged (or herd-provoked) this step
	dist: number?, -- distance to the nearest player
	attackRange: number,
	canAttack: boolean,
	leash: number, -- gives up beyond this distance
	retaliateSeconds: number,
}
export type RetaliateAction = "Idle" | "Chase" | "Attack"
export type RetaliateOutput = { action: RetaliateAction, angry: boolean }

function Retaliate.new(): RetaliateState
	return { angryLeft = 0 }
end

function Retaliate.step(
	state: RetaliateState,
	input: RetaliateInput,
	dt: number
): (RetaliateState, RetaliateOutput)
	local left = if input.hit then input.retaliateSeconds else math.max(0, state.angryLeft - dt)
	local dist = input.dist
	if dist == nil or dist > input.leash then
		left = 0
	end
	if left <= 0 or dist == nil then
		return { angryLeft = 0 }, { action = "Idle", angry = false }
	end
	local action: RetaliateAction = if dist <= input.attackRange and input.canAttack
		then "Attack"
		else "Chase"
	return { angryLeft = left }, { action = action, angry = true }
end

-- TerritorialWarn: Calm -> Warn (posture, no damage) -> Attack only if the player keeps coming.
export type WarnPhase = "Calm" | "Warn" | "Attack" | "Cool"
export type WarnState = { phase: WarnPhase, t: number }
export type WarnInput = {
	dist: number?,
	hit: boolean,
	warnRange: number,
	warnSeconds: number,
	commitRange: number, -- inside this after the warning = the player ignored it
	attackSeconds: number,
	cooldownSeconds: number,
	loseRange: number,
}
export type WarnOutput = { phase: WarnPhase, warnLeft: number }

function TerritorialWarn.new(): WarnState
	return { phase = "Calm", t = 0 }
end

function TerritorialWarn.step(
	state: WarnState,
	input: WarnInput,
	dt: number
): (WarnState, WarnOutput)
	local phase: WarnPhase, t = state.phase, state.t
	local dist = input.dist
	if phase == "Calm" then
		if input.hit then
			phase, t = "Attack", input.attackSeconds
		elseif dist ~= nil and dist <= input.warnRange then
			phase, t = "Warn", input.warnSeconds
		end
	elseif phase == "Warn" then
		if input.hit then
			phase, t = "Attack", input.attackSeconds
		elseif dist == nil or dist > input.loseRange then
			phase, t = "Calm", 0
		else
			t = math.max(0, t - dt)
			if t <= 0 and dist <= input.commitRange then
				phase, t = "Attack", input.attackSeconds
			end
		end
	elseif phase == "Attack" then
		t -= dt
		if t <= 0 or dist == nil or dist > input.loseRange then
			phase, t = "Cool", input.cooldownSeconds
		end
	else -- Cool
		t -= dt
		if t <= 0 then
			phase, t = "Calm", 0
		end
	end
	return { phase = phase, t = t }, { phase = phase, warnLeft = if phase == "Warn" then t else 0 }
end

-- HerdAlert: any member that notices a threat alerts every member within the herd radius.
export type AlertState = { alertLeft: number }
export type AlertInput = { threat: boolean, neighborAlert: boolean, alertSeconds: number }

function HerdAlert.new(): AlertState
	return { alertLeft = 0 }
end

function HerdAlert.step(
	state: AlertState,
	input: AlertInput,
	dt: number
): (AlertState, { alerted: boolean })
	local left = if input.threat or input.neighborAlert
		then input.alertSeconds
		else math.max(0, state.alertLeft - dt)
	return { alertLeft = left }, { alerted = left > 0 }
end

-- True when any alerted herd member sits within radius of `self`.
function HerdAlert.neighborAlerted(
	self: Point,
	herd: { { x: number, z: number, alerted: boolean } },
	radius: number
): boolean
	for _, member in herd do
		if member.alerted then
			local dx, dz = member.x - self.x, member.z - self.z
			if dx * dx + dz * dz <= radius * radius then
				return true
			end
		end
	end
	return false
end

-- Telegraph: timed wind-up. Start -> Wait... -> Strike; Cancel when the target leaves reach (dodged).
export type TelegraphState = { left: number? }
export type TelegraphInput = { ready: boolean, inReach: boolean, seconds: number }
export type TelegraphEvent = "Idle" | "Start" | "Wait" | "Strike" | "Cancel"
export type TelegraphOutput = { event: TelegraphEvent, left: number }

function Telegraph.new(): TelegraphState
	return { left = nil }
end

function Telegraph.step(
	state: TelegraphState,
	input: TelegraphInput,
	dt: number
): (TelegraphState, TelegraphOutput)
	local left = state.left
	if left == nil then
		if not input.ready then
			return { left = nil }, { event = "Idle", left = 0 }
		end
		if input.seconds <= 0 then
			return { left = nil }, { event = "Strike", left = 0 }
		end
		return { left = input.seconds }, { event = "Start", left = input.seconds }
	end
	if not input.inReach then
		return { left = nil }, { event = "Cancel", left = 0 }
	end
	left -= dt
	if left <= 0 then
		return { left = nil }, { event = "Strike", left = 0 }
	end
	return { left = left }, { event = "Wait", left = left }
end

-- PackFlank (pack level): Surround (members spread evenly round the target) then Rush (all close in).
export type FlankState = { phase: "Surround" | "Rush", t: number }
export type FlankInput = {
	members: { Point },
	target: Point?,
	radius: number,
	engageSeconds: number,
	slotTolerance: number,
}
export type FlankOutput = { phase: "Surround" | "Rush", slots: { Point } }

function PackFlank.new(): FlankState
	return { phase = "Surround", t = 0 }
end

local function dist2(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Evenly spaced slots on a circle round `target`, each member keeping the slot nearest its own bearing.
function PackFlank.slots(members: { Point }, target: Point, radius: number): { Point }
	local n = #members
	local out: { Point } = {}
	if n == 0 then
		return out
	end
	local order: { number } = {}
	local angles: { number } = {}
	for i, m in members do
		order[i] = i
		angles[i] = math.atan2(m.z - target.z, m.x - target.x)
	end
	table.sort(order, function(a, b)
		return angles[a] < angles[b]
	end)
	local base = angles[order[1]]
	for k, index in order do
		local a = base + (k - 1) * 2 * math.pi / n
		out[index] = { x = target.x + math.cos(a) * radius, z = target.z + math.sin(a) * radius }
	end
	return out
end

function PackFlank.step(state: FlankState, input: FlankInput, dt: number): (FlankState, FlankOutput)
	local target = input.target
	if target == nil then
		local own: { Point } = table.clone(input.members)
		return PackFlank.new(), { phase = "Surround", slots = own }
	end
	local slots = PackFlank.slots(input.members, target, input.radius)
	local phase: "Surround" | "Rush", t = state.phase, state.t + dt
	if phase == "Surround" then
		local settled = #input.members > 0
		for i, m in input.members do
			if dist2(m, slots[i]) > input.slotTolerance then
				settled = false
				break
			end
		end
		if settled or t >= input.engageSeconds then
			phase = "Rush"
		end
	end
	if phase == "Rush" then
		for i in input.members do
			slots[i] = target
		end
	end
	return { phase = phase, t = t }, { phase = phase, slots = slots }
end

return {
	Retaliate = Retaliate,
	TerritorialWarn = TerritorialWarn,
	HerdAlert = HerdAlert,
	Telegraph = Telegraph,
	PackFlank = PackFlank,
}
