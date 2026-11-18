--!strict
-- Pure lobby pad state machine (no Roblox APIs). Time is passed in as `now` (seconds, any clock).
-- A pad holds `capacity` players. The first player to join is the host and starts the timer; every
-- later join resets it. An empty pad is idle. PartyService owns the real clock, friend checks and teleport.

local Config = require("../Config")

export type Pad = {
	index: number,
	capacity: number,
	mode: string,
	hostId: number?,
	memberIds: { number },
	endsAt: number?, -- nil when idle
	launching: boolean,
}

local PadLogic = {}

local function isValidMode(mode: unknown): boolean
	return mode == Config.Lobby.PadModeFriends or mode == Config.Lobby.PadModeOpen
end

function PadLogic.new(index: number, capacity: number): Pad
	return {
		index = index,
		capacity = capacity,
		mode = Config.Lobby.DefaultPadMode,
		hostId = nil,
		memberIds = {},
		endsAt = nil,
		launching = false,
	}
end

-- Back to the empty idle state (cancel, failed launch, or finished launch).
function PadLogic.reset(pad: Pad)
	pad.mode = Config.Lobby.DefaultPadMode
	pad.hostId = nil
	table.clear(pad.memberIds)
	pad.endsAt = nil
	pad.launching = false
end

function PadLogic.isMember(pad: Pad, userId: number): boolean
	return table.find(pad.memberIds, userId) ~= nil
end

-- True if this player would be refused by the friends-only rule (needs the host friend result).
function PadLogic.needsFriendCheck(pad: Pad, userId: number): boolean
	return pad.hostId ~= nil and pad.hostId ~= userId and pad.mode == Config.Lobby.PadModeFriends
end

-- Join a pad. `isFriendOfHost` is the already-resolved friend result (only read on a friends-only pad).
-- Returns ok, reason (reason: "launching" | "already" | "full" | "friends_only").
function PadLogic.join(
	pad: Pad,
	userId: number,
	now: number,
	isFriendOfHost: boolean
): (boolean, string?)
	if pad.launching then
		return false, "launching"
	end
	if PadLogic.isMember(pad, userId) then
		return false, "already"
	end
	if #pad.memberIds >= pad.capacity then
		return false, "full"
	end
	if PadLogic.needsFriendCheck(pad, userId) and not isFriendOfHost then
		return false, "friends_only"
	end
	if pad.hostId == nil then
		pad.hostId = userId
	end
	table.insert(pad.memberIds, userId)
	pad.endsAt = now + Config.Lobby.PadTimerSeconds -- first step starts it; every join resets it
	return true, nil
end

-- Remove a player. A leaving host passes to the next member; an empty pad cancels the timer.
-- Returns true if the player was on the pad.
function PadLogic.leave(pad: Pad, userId: number): boolean
	if pad.launching then
		return false -- the party is already on its way
	end
	local at = table.find(pad.memberIds, userId)
	if at == nil then
		return false
	end
	table.remove(pad.memberIds, at)
	if #pad.memberIds == 0 then
		PadLogic.reset(pad)
	elseif pad.hostId == userId then
		pad.hostId = pad.memberIds[1]
	end
	return true
end

-- Host-only mode change. Returns ok, reason ("launching" | "not_host" | "bad_mode").
function PadLogic.setMode(pad: Pad, userId: number, mode: string): (boolean, string?)
	if pad.launching then
		return false, "launching"
	end
	if pad.hostId == nil or pad.hostId ~= userId then
		return false, "not_host"
	end
	if not isValidMode(mode) then
		return false, "bad_mode"
	end
	pad.mode = mode
	return true, nil
end

-- Advance the clock. Returns true exactly once, when the timer ends and the pad starts launching.
function PadLogic.tick(pad: Pad, now: number): boolean
	if pad.launching or pad.endsAt == nil or #pad.memberIds == 0 then
		return false
	end
	if now < pad.endsAt then
		return false
	end
	pad.launching = true
	return true
end

-- Copy of the members taken at launch time.
function PadLogic.members(pad: Pad): { number }
	return table.clone(pad.memberIds)
end

return PadLogic
