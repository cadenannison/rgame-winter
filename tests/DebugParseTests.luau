--!strict
-- Headless tests: every DebugService command string goes through HudMath.parseDebug and then DebugCommands.validate.

local Config = require("../src/shared/Config")
local DebugCommands = require("../src/shared/logic/DebugCommands")
local HudMath = require("../src/shared/logic/HudMath")

return function(check: (string, boolean) -> ())
	local limits: DebugCommands.Limits = {
		maxDay = Config.Debug.MaxDay,
		maxClockSpeed = Config.Debug.MaxClockSpeed,
		ringCount = Config.Debug.RingCount,
		darkEvents = Config.Debug.DarkEvents,
		itemIds = { "Wood" },
		mobKinds = Config.Debug.MobKinds,
		gallerySets = { "clear" },
	}
	local mobKind = Config.Debug.MobKinds[1] or "Wolf"
	-- { command text, expected parsed value or "string"/"nil-ok" marker }
	local cases: { { text: string, name: string, expect: unknown } } = {
		{ text = "setDay 5", name = "setDay", expect = 5 },
		{ text = "clockSpeed 2.5", name = "clockSpeed", expect = 2.5 },
		{ text = "blizzard on", name = "blizzard", expect = true },
		{ text = "blizzard off", name = "blizzard", expect = false },
		{ text = "blizzard start", name = "blizzard", expect = "start" },
		{ text = "blizzard stop", name = "blizzard", expect = "stop" },
		{ text = "blizzard intensity 0.5", name = "blizzard", expect = "intensity 0.5" },
		{ text = "darkEvent", name = "darkEvent", expect = "" },
		{ text = "stalker on", name = "stalker", expect = true },
		{ text = "invincible off", name = "invincible", expect = false },
		{ text = "teleportRing 2", name = "teleportRing", expect = 2 },
		{ text = "give Wood", name = "give", expect = "Wood" },
		{ text = "spawnMob " .. mobKind, name = "spawnMob", expect = mobKind },
		{ text = "runSummary", name = "runSummary", expect = "" },
		{ text = "mode lobby", name = "mode", expect = "lobby" },
		{ text = "gallery clear", name = "gallery", expect = "clear" },
		{ text = "structures", name = "structures", expect = "" },
		{ text = "tp structure 2", name = "tp", expect = "structure 2" },
		{ text = "tp ring 1", name = "tp", expect = "ring 1" },
		{ text = "chest rare", name = "chest", expect = "rare" },
		{ text = "seed", name = "seed", expect = "" },
		{ text = "seed 42", name = "seed", expect = "42" },
		{ text = "respawn", name = "respawn", expect = "" },
		{ text = "groundcheck", name = "groundcheck", expect = "" },
		{ text = "forage", name = "forage", expect = "" },
		{ text = "sprint", name = "sprint", expect = "" },
		{ text = "sprint on", name = "sprint", expect = "on" },
		{ text = "sprint off", name = "sprint", expect = "off" },
		{ text = "mob " .. mobKind, name = "mob", expect = mobKind },
		{ text = "mobs", name = "mobs", expect = "" },
	}
	local covered: { [string]: boolean } = {}
	for _, c in cases do
		covered[c.name] = true
		local ok, name, arg = HudMath.parseDebug(c.text, DebugCommands.NAMES)
		check(`debugParse: "{c.text}" parses`, ok and name == c.name and arg == c.expect)
		local valid = DebugCommands.validate(c.name, arg, limits)
		-- structures/respawn/etc. accept an empty string; "seed" too
		check(`debugParse: "{c.text}" validates`, valid)
	end
	local all = true
	for _, n in DebugCommands.NAMES do
		all = all and covered[n] == true
	end
	check("debugParse: every DebugCommands.NAMES entry is covered", all)

	-- bare commands (no argument) never mis-parse as "needs a number"
	for _, n in
		{ "forage", "sprint", "groundcheck", "respawn", "structures", "mobs", "runSummary", "seed" }
	do
		local ok, name = HudMath.parseDebug(n, DebugCommands.NAMES)
		check(`debugParse: bare {n} parses`, ok and name == n)
	end
	check(
		"debugParse: number commands still reject no arg",
		not (HudMath.parseDebug("setDay", DebugCommands.NAMES))
	)
	check(
		"debugParse: unknown command rejected",
		not (HudMath.parseDebug("nope", DebugCommands.NAMES))
	)
end
