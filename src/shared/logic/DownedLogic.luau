--!strict
-- Pure downed / revive / spectate rules (no Roblox APIs). Server uses them to decide; the client uses
-- the same functions for prompts (display only, the server re-validates every step).

local World = require("./World")

export type Actor = { downed: boolean, dead: boolean }
export type Candidate = { id: number, dist: number, downed: boolean, dead: boolean }

local DownedLogic = {}

-- Zero health outcome: downed only while some teammate can still act (solo = immediate death).
function DownedLogic.onZeroHealth(hasAbleTeammate: boolean): string
	return if hasAbleTeammate then "down" else "dead"
end

-- A reviver must be up and alive, the target downed and not dead, and within range.
function DownedLogic.canStartRevive(
	reviver: Actor,
	target: Actor,
	dist: number,
	range: number
): boolean
	if reviver.downed or reviver.dead or target.dead or not target.downed then
		return false
	end
	return dist <= range
end

-- One channel step. Returns "continue" | "done" | "cancel" and the new remaining seconds.
-- Cancels when the reviver stopped holding (no refresh for staleAfter), moved beyond cancelRange,
-- or either side stopped being valid. Release before the end never revives.
function DownedLogic.channelStep(
	remaining: number,
	dt: number,
	dist: number,
	cancelRange: number,
	sinceRefresh: number,
	staleAfter: number,
	reviver: Actor,
	target: Actor
): (string, number)
	if reviver.downed or reviver.dead or target.dead or not target.downed then
		return "cancel", remaining
	end
	if dist > cancelRange or sinceRefresh > staleAfter then
		return "cancel", remaining
	end
	local left = remaining - dt
	if left <= 0 then
		return "done", 0
	end
	return "continue", left
end

-- Channel progress 0..1.
function DownedLogic.progress(remaining: number, total: number): number
	if total <= 0 then
		return 1
	end
	return math.clamp(1 - remaining / total, 0, 1)
end

-- Whole seconds shown for the revive window (never negative).
function DownedLogic.bleedSeconds(bleed: number): number
	return math.max(0, math.ceil(bleed))
end

-- Fell out of the world: ends the player outright (not revivable).
function DownedLogic.fellOut(x: number, y: number, z: number): boolean
	return World.shouldKill(x, y, z)
end

-- Next spectate target. candidates are ids of living teammates in a stable order; dir is +1 or -1.
-- A current target that is no longer a candidate restarts from the first. Nil when nobody is left.
function DownedLogic.nextSpectate(candidates: { number }, current: number?, dir: number): number?
	local count = #candidates
	if count == 0 then
		return nil
	end
	local index = if current then table.find(candidates, current) else nil
	if index == nil then
		return candidates[1]
	end
	local step = if dir < 0 then -1 else 1
	return candidates[(index - 1 + step) % count + 1]
end

-- Nearest downed teammate in range the local player could revive (nil when none or the viewer cannot act).
function DownedLogic.pickReviveTarget(
	viewer: Actor,
	candidates: { Candidate },
	range: number
): number?
	if viewer.downed or viewer.dead then
		return nil
	end
	local best: number? = nil
	local bestDist = math.huge
	for _, c in candidates do
		if c.downed and not c.dead and c.dist <= range and c.dist < bestDist then
			best = c.id
			bestDist = c.dist
		end
	end
	return best
end

return DownedLogic
