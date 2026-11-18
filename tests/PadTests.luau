--!strict
-- Tests for PadLogic (pad join/leave/mode/timer/cancel) with a fake teleport adapter standing in
-- for PartyService's launch step.

local Config = require("../src/shared/Config")
local PadLogic = require("../src/shared/logic/PadLogic")
local TeleportData = require("../src/shared/logic/TeleportData")

local T = Config.Lobby.PadTimerSeconds
local FRIENDS = Config.Lobby.PadModeFriends
local OPEN = Config.Lobby.PadModeOpen

-- Fake adapter mirroring TeleportAdapter.teleportParty; records calls and can be made to fail.
type Fake = { calls: { { ids: { number }, data: TeleportData.TeleportData } }, succeed: boolean }

local function newFake(): Fake
	return { calls = {}, succeed = true }
end

-- Mirrors PartyService.launch: build data, call adapter, reset the pad on failure.
local function launch(pad: PadLogic.Pad, fake: Fake, seed: number): boolean
	local ids = PadLogic.members(pad)
	local data = TeleportData.build(Config.Teleport.ModeRun, seed, ids)
	if data == nil then
		PadLogic.reset(pad)
		return false
	end
	table.insert(fake.calls, { ids = ids, data = data })
	if not fake.succeed then
		PadLogic.reset(pad)
		return false
	end
	return true
end

return function(check: (string, boolean) -> ())
	-- timer starts on first join
	local pad = PadLogic.new(3, 3)
	check("pad idle at start", pad.endsAt == nil and pad.hostId == nil and not pad.launching)
	check("pad first join ok", (PadLogic.join(pad, 1, 100, false)))
	check("pad first joiner is host", pad.hostId == 1)
	check("pad timer starts", pad.endsAt == 100 + T)
	check("pad default mode", pad.mode == Config.Lobby.DefaultPadMode)

	-- timer resets on join
	check("pad tick before end", PadLogic.tick(pad, 100 + T - 1) == false)
	check("pad second join ok", (PadLogic.join(pad, 2, 110, true)))
	check("pad timer resets on join", pad.endsAt == 110 + T)
	check("pad old deadline passes", PadLogic.tick(pad, 100 + T) == false)

	-- join refusals
	local ok, reason = PadLogic.join(pad, 2, 111, true)
	check("pad refuses duplicate", not ok and reason == "already")
	PadLogic.join(pad, 3, 112, true)
	ok, reason = PadLogic.join(pad, 4, 113, true)
	check("pad refuses when full", not ok and reason == "full" and #pad.memberIds == 3)
	check("pad refusal keeps timer", pad.endsAt == 112 + T)

	-- timer end fires once and launches
	check("pad tick at end fires", PadLogic.tick(pad, 112 + T) == true)
	check("pad launching flag", pad.launching)
	check("pad tick fires once", PadLogic.tick(pad, 112 + T + 1) == false)
	ok, reason = PadLogic.join(pad, 9, 140, true)
	check("pad refuses join while launching", not ok and reason == "launching")
	check("pad refuses leave while launching", PadLogic.leave(pad, 1) == false)

	local fake = newFake()
	check("launch with fake adapter ok", launch(pad, fake, 777))
	check(
		"launch passes mode/seed/party",
		#fake.calls == 1
			and fake.calls[1].data.mode == Config.Teleport.ModeRun
			and fake.calls[1].data.seed == 777
			and #fake.calls[1].data.partyIds == 3
			and fake.calls[1].data.partyIds[1] == 1
	)

	-- failed teleport returns the party and resets the pad
	local failPad = PadLogic.new(2, 2)
	PadLogic.join(failPad, 5, 0, false)
	PadLogic.join(failPad, 6, 1, true)
	PadLogic.tick(failPad, 1 + T)
	local failing = newFake()
	failing.succeed = false
	check("launch failure reported", launch(failPad, failing, 1) == false)
	check(
		"pad resets after failed launch",
		failPad.hostId == nil
			and #failPad.memberIds == 0
			and failPad.endsAt == nil
			and not failPad.launching
	)
	check("pad reusable after failure", (PadLogic.join(failPad, 5, 50, false)))

	-- leave and cancel
	local p = PadLogic.new(2, 2)
	PadLogic.join(p, 1, 0, false)
	check("leave unknown player", PadLogic.leave(p, 99) == false)
	check(
		"leave last member cancels",
		PadLogic.leave(p, 1) == true and p.endsAt == nil and p.hostId == nil
	)
	check("cancelled pad never launches", PadLogic.tick(p, 1000) == false)
	PadLogic.join(p, 1, 0, false)
	PadLogic.join(p, 2, 5, true)
	PadLogic.leave(p, 1)
	check("host leaves passes host on", p.hostId == 2 and #p.memberIds == 1)
	check("leave keeps timer", p.endsAt == 5 + T)
	check("remaining member launches at timer", PadLogic.tick(p, 5 + T) == true)

	-- mode and friends rules
	local m = PadLogic.new(4, 4)
	PadLogic.join(m, 1, 0, false)
	ok, reason = PadLogic.setMode(m, 2, FRIENDS)
	check("mode non-host refused", not ok and reason == "not_host")
	ok, reason = PadLogic.setMode(m, 1, "bogus")
	check("mode invalid refused", not ok and reason == "bad_mode")
	check("mode host sets friends", (PadLogic.setMode(m, 1, FRIENDS)) and m.mode == FRIENDS)
	check("friends pad needs check for others", PadLogic.needsFriendCheck(m, 2))
	check("friends pad no check for host", PadLogic.needsFriendCheck(m, 1) == false)
	ok, reason = PadLogic.join(m, 2, 3, false)
	check(
		"friends pad refuses non-friend",
		not ok and reason == "friends_only" and #m.memberIds == 1
	)
	check("friends refusal keeps timer", m.endsAt == T)
	check("friends pad accepts friend", (PadLogic.join(m, 3, 4, true)))
	PadLogic.setMode(m, 1, OPEN)
	check("open pad accepts anyone", (PadLogic.join(m, 4, 5, false)))
	PadLogic.tick(m, 5 + T)
	ok, reason = PadLogic.setMode(m, 1, FRIENDS)
	check("mode locked while launching", not ok and reason == "launching")

	-- reset
	PadLogic.reset(m)
	check(
		"reset clears pad",
		#m.memberIds == 0 and m.hostId == nil and m.mode == Config.Lobby.DefaultPadMode
	)
end
