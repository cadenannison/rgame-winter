--!strict
-- Tests for LobbyLogic: pad status/join checks, countdown, UTC-day daily check, leaderboard codec.

local LobbyLogic = require("../src/shared/logic/LobbyLogic")

local function pad(
	index: number,
	members: { number },
	mode: string?,
	launching: boolean?
): LobbyLogic.Pad
	return {
		index = index,
		capacity = index,
		mode = mode or "open",
		hostId = members[1],
		memberIds = members,
		endsAt = nil,
		launching = launching == true,
	}
end

return function(check: (string, boolean) -> ())
	check("lobby countdown none", LobbyLogic.secondsLeft(nil, 10) == nil)
	check("lobby countdown rounds up", LobbyLogic.secondsLeft(15.2, 10) == 6)
	check("lobby countdown never negative", LobbyLogic.secondsLeft(5, 10) == 0)

	check("lobby pad empty", LobbyLogic.padStatus(pad(2, {}), "friends") == "Empty")
	check("lobby pad open", LobbyLogic.padStatus(pad(4, { 1, 2 }), "friends") == "2/4 open")
	check(
		"lobby pad friends",
		LobbyLogic.padStatus(pad(3, { 1 }, "friends"), "friends") == "1/3 friends"
	)
	check(
		"lobby pad launching",
		LobbyLogic.padStatus(pad(3, { 1 }, nil, true), "friends") == "Launching"
	)

	check("lobby canJoin ok", (LobbyLogic.canJoin(pad(2, { 1 }), 9)))
	check("lobby canJoin full", not (LobbyLogic.canJoin(pad(1, { 1 }), 9)))
	check("lobby canJoin member", not (LobbyLogic.canJoin(pad(3, { 9 }), 9)))
	check("lobby canJoin launching", not (LobbyLogic.canJoin(pad(3, {}, nil, true), 9)))

	check(
		"lobby requeue prefers empty",
		LobbyLogic.pickRequeuePad({ pad(1, { 5 }), pad(2, { 5 }), pad(3, {}) }, 9) == 3
	)
	check(
		"lobby requeue falls back to open",
		LobbyLogic.pickRequeuePad({ pad(1, { 5 }), pad(2, { 5 }) }, 9) == 2
	)
	check(
		"lobby requeue skips friends pads",
		LobbyLogic.pickRequeuePad({ pad(2, { 5 }, "friends") }, 9) == nil
	)

	local noon = 86400 * 100 + 43200
	check("daily never claimed", LobbyLogic.canClaimDaily(0, noon))
	check("daily same utc day", not LobbyLogic.canClaimDaily(86400 * 100 + 10, noon))
	check("daily next utc day", LobbyLogic.canClaimDaily(86400 * 99 + 86399, noon))
	check("daily next midnight", LobbyLogic.nextUtcMidnight(noon) == 86400 * 101)
	check("wait format hours", LobbyLogic.formatWait(3 * 3600 + 120) == "3h 02m")
	check("wait format minutes", LobbyLogic.formatWait(600) == "10m")
	check("wait format soon", LobbyLogic.formatWait(0) == "soon")

	local board = LobbyLogic.encodeBoard(
		{ { name = "Ann", score = 12 }, { name = "B;ob=x", score = 3.7 } },
		5
	)
	check("board encode strips separators", board == "Ann=12;Bobx=3")
	local decoded = LobbyLogic.decodeBoard(board, 5)
	check("board roundtrip", #decoded == 2 and decoded[1].name == "Ann" and decoded[2].score == 3)
	check("board decode skips junk", #LobbyLogic.decodeBoard("a=1;;bad;c=x;d=2", 5) == 2)
	check("board decode caps", #LobbyLogic.decodeBoard("a=1;b=2;c=3", 2) == 2)
	check("board decode non-string", #LobbyLogic.decodeBoard(42, 5) == 0)

	local rows: { any } = {
		{
			index = 2,
			capacity = 2,
			mode = "open",
			memberIds = { 1, 2, 3, "x" :: any },
			launching = false,
		},
		{
			index = 1,
			capacity = 1,
			mode = "friends",
			hostId = 7,
			memberIds = { 7 },
			endsAt = 5,
			launching = true,
		},
		{ index = "bad" },
	}
	local parsed = LobbyLogic.parsePads({ pads = rows }, 6)
	check("pads parse drops bad and sorts", #parsed == 2 and parsed[1].index == 1)
	check("pads parse caps members", #parsed[2].memberIds == 2)
	check(
		"pads parse fields",
		parsed[1].hostId == 7 and parsed[1].endsAt == 5 and parsed[1].launching
	)
	check(
		"pads parse junk",
		#LobbyLogic.parsePads("x", 6) == 0 and #LobbyLogic.parsePads({ pads = 1 }, 6) == 0
	)

	check("achievement title", LobbyLogic.achievementTitle("frost_walker") == "Frost Walker")
	check("achievement decode", #LobbyLogic.decodeAchievements("a,b,c") == 3)
	check("achievement decode non-string", #LobbyLogic.decodeAchievements(nil) == 0)
end
