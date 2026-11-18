--!strict
-- Tests for TeleportData (the lobby <-> run teleport data contract validated by Guard.teleportData).

local Config = require("../src/shared/Config")
local TeleportData = require("../src/shared/logic/TeleportData")

local RUN = Config.Teleport.ModeRun

local function valid(): any
	return {
		mode = RUN,
		seed = 12345,
		partyIds = { 101, 202 },
		version = Config.Teleport.DataVersion,
	}
end

local function rejects(mutate: (any) -> ()): boolean
	local data = valid()
	mutate(data)
	return TeleportData.parse(data) == nil
end

return function(check: (string, boolean) -> ())
	local parsed = TeleportData.parse(valid())
	check("teleport valid parses", parsed ~= nil and parsed.seed == 12345 and #parsed.partyIds == 2)
	check("teleport lobby mode parses", not rejects(function(d)
		d.mode = Config.Teleport.ModeLobby
	end))
	check("teleport parse copies ids", parsed ~= nil and parsed.partyIds ~= valid().partyIds)
	check(
		"teleport rejects non-table",
		TeleportData.parse("run") == nil and TeleportData.parse(nil) == nil
	)
	check(
		"teleport rejects old version",
		rejects(function(d)
			d.version = Config.Teleport.DataVersion - 1
		end)
	)
	check(
		"teleport rejects bad mode",
		rejects(function(d)
			d.mode = "admin"
		end)
	)
	check(
		"teleport rejects float seed",
		rejects(function(d)
			d.seed = 1.5
		end)
	)
	check(
		"teleport rejects negative seed",
		rejects(function(d)
			d.seed = -1
		end)
	)
	check(
		"teleport rejects huge seed",
		rejects(function(d)
			d.seed = Config.Teleport.MaxSeed + 1
		end)
	)
	check(
		"teleport rejects nan seed",
		rejects(function(d)
			d.seed = 0 / 0
		end)
	)
	check(
		"teleport rejects empty party",
		rejects(function(d)
			d.partyIds = {}
		end)
	)
	check(
		"teleport rejects oversize party",
		rejects(function(d)
			d.partyIds = { 1, 2, 3, 4, 5, 6, 7 }
		end)
	)
	check(
		"teleport rejects duplicate ids",
		rejects(function(d)
			d.partyIds = { 5, 5 }
		end)
	)
	check(
		"teleport rejects string ids",
		rejects(function(d)
			d.partyIds = { "101" }
		end)
	)
	check(
		"teleport rejects sparse ids",
		rejects(function(d)
			d.partyIds = { [1] = 1, [3] = 3 }
		end)
	)
	check(
		"teleport rejects non-positive id",
		rejects(function(d)
			d.partyIds = { 0 }
		end)
	)
	check(
		"teleport rejects extra key",
		rejects(function(d)
			d.isAdmin = true
		end)
	)

	local built = TeleportData.build(RUN, 7, { 9, 10 })
	check("teleport build parses", built ~= nil and built.version == Config.Teleport.DataVersion)
	check("teleport build refuses bad", TeleportData.build(RUN, -3, { 9 }) == nil)
	check(
		"teleport hasMember",
		built ~= nil and TeleportData.hasMember(built, 10) and not TeleportData.hasMember(built, 11)
	)
end
