--!strict
-- Pure run roster state machine (no Roblox APIs; times are passed in). Members are alive, downed, dead
-- or held (disconnected, character kept for the rejoin window). The run is over when nobody can act.

export type Status = "alive" | "downed" | "dead" | "held"

export type Member = {
	userId: number,
	status: Status,
	heldFrom: Status, -- status before the disconnect (alive or downed)
	holdDeadline: number,
	downDeadline: number, -- when a downed member dies unless revived
	kills: number,
	bossKills: number,
	darkEvents: number, -- dark events this member was alive for at the end (coins)
}

export type Options = { rejoinWindow: number, reviveLimit: number }

export type Run = {
	members: { [number]: Member },
	order: { number },
	options: Options,
	cause: string?,
}

local RunState = {}

function RunState.new(partyIds: { number }, options: Options): Run
	local run: Run = { members = {}, order = {}, options = options, cause = nil }
	for _, id in partyIds do
		if not run.members[id] then
			run.members[id] = {
				userId = id,
				status = "alive",
				heldFrom = "alive",
				holdDeadline = 0,
				downDeadline = 0,
				kills = 0,
				bossKills = 0,
				darkEvents = 0,
			}
			table.insert(run.order, id)
		end
	end
	return run
end

-- Adds a member mid-run (Studio fallback only; real runs fix the roster from teleport data).
function RunState.add(run: Run, userId: number)
	if not run.members[userId] then
		run.members[userId] = {
			userId = userId,
			status = "alive",
			heldFrom = "alive",
			holdDeadline = 0,
			downDeadline = 0,
			kills = 0,
			bossKills = 0,
			darkEvents = 0,
		}
		table.insert(run.order, userId)
	end
end

function RunState.get(run: Run, userId: number): Member?
	return run.members[userId]
end

function RunState.status(run: Run, userId: number): Status?
	local m = run.members[userId]
	return m and m.status
end

function RunState.setCause(run: Run, cause: string?)
	if cause and cause ~= "" then
		run.cause = cause
	end
end

function RunState.setDowned(run: Run, userId: number, now: number)
	local m = run.members[userId]
	if m and m.status == "alive" then
		m.status = "downed"
		m.downDeadline = now + run.options.reviveLimit
	end
end

-- True only if the member is downed and still inside the revive time limit.
function RunState.revive(run: Run, userId: number, now: number): boolean
	local m = run.members[userId]
	if m and m.status == "downed" and now < m.downDeadline then
		m.status = "alive"
		return true
	end
	return false
end

-- Debug/real respawn: a downed or dead member becomes alive again (held and alive stay as they are).
function RunState.respawn(run: Run, userId: number): boolean
	local m = run.members[userId]
	if m and (m.status == "downed" or m.status == "dead") then
		m.status = "alive"
		m.downDeadline = 0
		return true
	end
	return false
end

function RunState.setDead(run: Run, userId: number)
	local m = run.members[userId]
	if m then
		m.status = "dead"
	end
end

-- Disconnect: hold the member for the rejoin window. Dead members stay dead.
function RunState.disconnect(run: Run, userId: number, now: number)
	local m = run.members[userId]
	if m and (m.status == "alive" or m.status == "downed") then
		m.heldFrom = m.status
		m.status = "held"
		m.holdDeadline = now + run.options.rejoinWindow
	end
end

-- Rejoin inside the window restores the prior status (a downed member whose limit passed is dead).
function RunState.rejoin(run: Run, userId: number, now: number): boolean
	local m = run.members[userId]
	if not m or m.status ~= "held" or now >= m.holdDeadline then
		return false
	end
	if m.heldFrom == "downed" and now >= m.downDeadline then
		m.status = "dead"
	else
		m.status = m.heldFrom
	end
	return true
end

-- Expires revive limits and rejoin windows. Returns the ids that died this call.
function RunState.tick(run: Run, now: number): { number }
	local died: { number } = {}
	for _, id in run.order do
		local m = run.members[id]
		local expired = (m.status == "downed" and now >= m.downDeadline)
			or (m.status == "held" and now >= m.holdDeadline)
		if expired then
			m.status = "dead"
			table.insert(died, id)
		end
	end
	return died
end

local function canAct(m: Member): boolean
	return m.status == "alive" or (m.status == "held" and m.heldFrom == "alive")
end

-- Over when no member can act: everyone is downed, dead, or held while already downed.
function RunState.isOver(run: Run): boolean
	for _, m in run.members do
		if canAct(m) then
			return false
		end
	end
	return true
end

function RunState.recordKill(run: Run, userId: number, boss: boolean)
	local m = run.members[userId]
	if m then
		if boss then
			m.bossKills += 1
		else
			m.kills += 1
		end
	end
end

-- A dark event ended with this member alive (Meta.CoinsPerDarkEventSurvived).
function RunState.recordDarkEvent(run: Run, userId: number)
	local m = run.members[userId]
	if m then
		m.darkEvents += 1
	end
end

-- Party totals: stats are shared by the party, so each member's summary uses the party kill count.
function RunState.totals(run: Run): (number, number)
	local kills, boss = 0, 0
	for _, m in run.members do
		kills += m.kills
		boss += m.bossKills
	end
	return kills, boss
end

return RunState
