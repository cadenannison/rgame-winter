--!strict
-- Pure lobby helpers (no Roblox APIs): pad status text, join checks, countdown, UTC-day daily check,
-- leaderboard encode/decode, stat attribute names. Shared by src/client/Lobby and src/server/Lobby.

export type Pad = {
	index: number,
	capacity: number,
	mode: string,
	hostId: number?,
	memberIds: { number },
	endsAt: number?,
	launching: boolean,
}
export type BoardEntry = { name: string, score: number }

local SECONDS_PER_DAY = 86400

local LobbyLogic = {}

-- Attribute names the server publishes (shown values only; no hidden metrics). Player attributes
-- except `Board`, which is a Workspace attribute holding the encoded leaderboard.
LobbyLogic.ATTR = {
	Coins = "LobbyCoins",
	MaxDays = "LobbyMaxDays",
	Runs = "LobbyRuns",
	Kills = "LobbyKills",
	BossKills = "LobbyBossKills",
	Crafted = "LobbyCrafted",
	Achievements = "LobbyAchievements", -- comma-joined sorted ids
	LastDailyClaim = "LobbyLastDailyClaim", -- os.time seconds, 0 = never
	Board = "LobbyLeaderboard",
}

-- Whole seconds left (rounded up, never negative); nil when no timer.
function LobbyLogic.secondsLeft(endsAt: number?, now: number): number?
	if endsAt == nil then
		return nil
	end
	return math.max(0, math.ceil(endsAt - now))
end

function LobbyLogic.isMember(pad: Pad, userId: number): boolean
	return table.find(pad.memberIds, userId) ~= nil
end

-- Client-side hint only; the server re-validates every join.
function LobbyLogic.canJoin(pad: Pad, userId: number): (boolean, string?)
	if pad.launching then
		return false, "Launching"
	end
	if LobbyLogic.isMember(pad, userId) then
		return false, "Already here"
	end
	if #pad.memberIds >= pad.capacity then
		return false, "Full"
	end
	return true, nil
end

-- One line under each pad: "Empty", "2/4 open", "1/3 friends", "Launching".
function LobbyLogic.padStatus(pad: Pad, friendsMode: string): string
	if pad.launching then
		return "Launching"
	end
	if #pad.memberIds == 0 then
		return "Empty"
	end
	local tag = if pad.mode == friendsMode then "friends" else "open"
	return `{#pad.memberIds}/{pad.capacity} {tag}`
end

-- Pad for the re-queue button: prefer an empty pad, else the first one that accepts us. nil if none.
function LobbyLogic.pickRequeuePad(pads: { Pad }, userId: number): number?
	local fallback: number? = nil
	for _, pad in pads do
		if LobbyLogic.canJoin(pad, userId) then
			if #pad.memberIds == 0 then
				return pad.index
			end
			if fallback == nil and pad.mode ~= "friends" then
				fallback = pad.index
			end
		end
	end
	return fallback
end

function LobbyLogic.utcDay(t: number): number
	return math.floor(t / SECONDS_PER_DAY)
end

-- Display check for the daily button: claimable when the UTC day changed since the last claim.
function LobbyLogic.canClaimDaily(lastClaim: number, now: number): boolean
	return lastClaim <= 0 or LobbyLogic.utcDay(now) > LobbyLogic.utcDay(lastClaim)
end

function LobbyLogic.nextUtcMidnight(now: number): number
	return (LobbyLogic.utcDay(now) + 1) * SECONDS_PER_DAY
end

-- "5h 03m" / "12m" / "soon" for a wait in seconds.
function LobbyLogic.formatWait(seconds: number): string
	if seconds <= 0 then
		return "soon"
	end
	local hours = math.floor(seconds / 3600)
	local minutes = math.ceil((seconds - hours * 3600) / 60)
	if minutes == 60 then
		hours += 1
		minutes = 0
	end
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	end
	return `{minutes}m`
end

-- Leaderboard wire format: "name=score;name=score". Names are stripped of separators; capped at maxEntries.
function LobbyLogic.encodeBoard(entries: { BoardEntry }, maxEntries: number): string
	local parts: { string } = {}
	for i = 1, math.min(#entries, maxEntries) do
		local entry = entries[i]
		local name = string.gsub(entry.name, "[^%w_]", "")
		table.insert(parts, `{name}={math.floor(entry.score)}`)
	end
	return table.concat(parts, ";")
end

-- Tolerant decode of untrusted text: bad rows are skipped, scores clamped to >= 0.
function LobbyLogic.decodeBoard(text: unknown, maxEntries: number): { BoardEntry }
	local result: { BoardEntry } = {}
	if type(text) ~= "string" then
		return result
	end
	for row in string.gmatch(text, "[^;]+") do
		if #result >= maxEntries then
			break
		end
		local name, score = string.match(row, "^([%w_]+)=(%d+)$")
		local value = tonumber(score)
		if name ~= nil and value ~= nil then
			table.insert(result, { name = name, score = math.max(0, value) })
		end
	end
	return result
end

-- "frost_walker" -> "Frost Walker".
function LobbyLogic.achievementTitle(id: string): string
	local spaced = string.gsub(id, "_", " ")
	local titled = string.gsub(spaced, "%a[%w]*", function(word: string): string
		return string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
	end)
	return titled
end

-- Splits the comma-joined achievement attribute into ids (untrusted text).
function LobbyLogic.decodeAchievements(text: unknown): { string }
	local ids: { string } = {}
	if type(text) ~= "string" then
		return ids
	end
	for id in string.gmatch(text, "[^,]+") do
		table.insert(ids, id)
	end
	return ids
end

-- Defensive copy of a PartyState payload (untrusted shape). Pads sorted by index, at most maxPads;
-- members capped at the pad capacity. Bad pads are dropped.
function LobbyLogic.parsePads(payload: unknown, maxPads: number): { Pad }
	local result: { Pad } = {}
	if type(payload) ~= "table" then
		return result
	end
	local list = (payload :: any).pads
	if type(list) ~= "table" then
		return result
	end
	for _, raw in list do
		if type(raw) == "table" and #result < maxPads then
			local index, capacity = raw.index, raw.capacity
			if
				type(index) == "number"
				and type(capacity) == "number"
				and index >= 1
				and capacity >= 1
			then
				local members: { number } = {}
				if type(raw.memberIds) == "table" then
					for _, id in raw.memberIds do
						if type(id) == "number" and #members < capacity then
							table.insert(members, id)
						end
					end
				end
				table.insert(result, {
					index = index,
					capacity = capacity,
					mode = if type(raw.mode) == "string" then raw.mode else "",
					hostId = if type(raw.hostId) == "number" then raw.hostId else nil,
					memberIds = members,
					endsAt = if type(raw.endsAt) == "number" then raw.endsAt else nil,
					launching = raw.launching == true,
				})
			end
		end
	end
	table.sort(result, function(a: Pad, b: Pad)
		return a.index < b.index
	end)
	return result
end

return LobbyLogic
