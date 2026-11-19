--!strict
-- Headless handler tests for "/debug blizzard" (DebugCommands.runBlizzard) against a fake service.
-- Needs registering in tests/run.luau.

local DebugCommands = require("../src/shared/logic/DebugCommands")

return function(check: (string, boolean) -> ())
	local started, stopped, pinned = 0, 0, nil :: number?
	local startResult = true
	local api: DebugCommands.BlizzardApi = {
		DebugStart = function(): boolean
			started += 1
			return startResult
		end,
		DebugStop = function()
			stopped += 1
		end,
		DebugSetIntensity = function(v: number?)
			pinned = v
		end,
		DebugStatus = function(): string
			return "STATUS"
		end,
	}

	local msg = DebugCommands.runBlizzard({ action = "start" }, api)
	check("blizzardDebug: start calls the service", started == 1 and msg == "blizzard started")
	startResult = false
	msg = DebugCommands.runBlizzard({ action = "start" }, api)
	check(
		"blizzardDebug: refused start says why",
		started == 2 and string.find(msg, "dark event", 1, true) ~= nil
	)
	DebugCommands.runBlizzard({ action = "stop" }, api)
	check("blizzardDebug: stop calls the service", stopped == 1)
	DebugCommands.runBlizzard({ action = "intensity", value = 0.4 }, api)
	check("blizzardDebug: intensity pins the value", pinned == 0.4)
	check(
		"blizzardDebug: status prints the service line",
		DebugCommands.runBlizzard({ action = "status" }, api) == "STATUS"
	)
	msg = DebugCommands.runBlizzard({ action = "start" }, nil)
	check(
		"blizzardDebug: no weather service (lobby) answers with a message, not silence",
		msg ~= "" and string.find(msg, "lobby", 1, true) ~= nil
	)
	check("blizzardDebug: bad arg is a message", DebugCommands.runBlizzard("start", api) ~= "")
end
