--!strict
-- Headless tests for the downed state: down/revive/expire, revive channel rules, spectate cycling,
-- kill height, and run end when everyone is down or dead.

local Config = require("../src/shared/Config")
local DownedLogic = require("../src/shared/logic/DownedLogic")
local SurvivalLogic = require("../src/shared/logic/SurvivalLogic")
local World = require("../src/shared/logic/World")
local RunState = require("../src/server/Run/RunState")

local D = Config.Downed
local UP: DownedLogic.Actor = { downed = false, dead = false }
local DOWN: DownedLogic.Actor = { downed = true, dead = false }
local DEAD: DownedLogic.Actor = { downed = false, dead = true }

return function(check: (string, boolean) -> ())
	-- Down, revive window, expire (pure meters)
	local m = SurvivalLogic.new(Config.Meters)
	SurvivalLogic.down(m, D)
	check("down sets downed and window", m.downed and m.bleed == D.BleedoutSeconds)
	check(
		"window ticking does not expire early",
		not SurvivalLogic.tickDowned(m, D.BleedoutSeconds - 1)
	)
	check("window expires into death", SurvivalLogic.tickDowned(m, 1))
	SurvivalLogic.kill(m)
	check("kill clears downed", m.dead and not m.downed)
	check("dead cannot be revived", not SurvivalLogic.revive(m, Config.Meters, D))
	local r = SurvivalLogic.new(Config.Meters)
	SurvivalLogic.down(r, D)
	check(
		"revive restores health fraction",
		SurvivalLogic.revive(r, Config.Meters, D) and r.health > 0 and not r.downed
	)
	check("revive needs downed", not SurvivalLogic.revive(r, Config.Meters, D))

	-- Outcome at zero health
	check("solo zero health = dead", DownedLogic.onZeroHealth(false) == "dead")
	check("teammate able = downed", DownedLogic.onZeroHealth(true) == "down")

	-- Revive start rules
	check("can revive in range", DownedLogic.canStartRevive(UP, DOWN, D.ReviveRange, D.ReviveRange))
	check(
		"no revive out of range",
		not DownedLogic.canStartRevive(UP, DOWN, D.ReviveRange + 0.1, D.ReviveRange)
	)
	check("downed cannot revive", not DownedLogic.canStartRevive(DOWN, DOWN, 1, D.ReviveRange))
	check("dead cannot revive", not DownedLogic.canStartRevive(DEAD, DOWN, 1, D.ReviveRange))
	check("dead target not revivable", not DownedLogic.canStartRevive(UP, DEAD, 1, D.ReviveRange))
	check("standing target not revivable", not DownedLogic.canStartRevive(UP, UP, 1, D.ReviveRange))

	-- Channel: hold to completion, release, walk away
	local remaining = D.ReviveSeconds
	local verdict = "continue"
	local steps = 0
	while verdict == "continue" and steps < 1000 do
		steps += 1
		verdict, remaining = DownedLogic.channelStep(
			remaining,
			0.25,
			2,
			D.ReviveCancelRange,
			0.1,
			D.ReviveStaleSeconds,
			UP,
			DOWN
		)
	end
	check(
		"held channel completes after ReviveSeconds",
		verdict == "done" and steps == math.ceil(D.ReviveSeconds / 0.25)
	)
	check(
		"release (stale) cancels",
		(
			DownedLogic.channelStep(
				2,
				0.25,
				2,
				D.ReviveCancelRange,
				D.ReviveStaleSeconds + 0.1,
				D.ReviveStaleSeconds,
				UP,
				DOWN
			)
		) == "cancel"
	)
	check(
		"walking away cancels",
		(
			DownedLogic.channelStep(
				2,
				0.25,
				D.ReviveCancelRange + 1,
				D.ReviveCancelRange,
				0,
				D.ReviveStaleSeconds,
				UP,
				DOWN
			)
		) == "cancel"
	)
	check(
		"target died cancels",
		(
			DownedLogic.channelStep(
				2,
				0.25,
				2,
				D.ReviveCancelRange,
				0,
				D.ReviveStaleSeconds,
				UP,
				DEAD
			)
		) == "cancel"
	)
	check(
		"reviver downed cancels",
		(
			DownedLogic.channelStep(
				2,
				0.25,
				2,
				D.ReviveCancelRange,
				0,
				D.ReviveStaleSeconds,
				DOWN,
				DOWN
			)
		) == "cancel"
	)
	check("cancel range wider than revive range", D.ReviveCancelRange > D.ReviveRange)
	check("stale window beats refresh interval", D.ReviveStaleSeconds > D.ReviveRefreshSeconds)
	check(
		"progress 0 at start, 1 at end",
		DownedLogic.progress(D.ReviveSeconds, D.ReviveSeconds) == 0
			and DownedLogic.progress(0, D.ReviveSeconds) == 1
	)
	check(
		"bleed seconds rounds up, never negative",
		DownedLogic.bleedSeconds(0.2) == 1 and DownedLogic.bleedSeconds(-3) == 0
	)

	-- Client prompt pick
	local picked = DownedLogic.pickReviveTarget(UP, {
		{ id = 1, dist = 6, downed = true, dead = false },
		{ id = 2, dist = 3, downed = true, dead = false },
		{ id = 3, dist = 1, downed = false, dead = false },
		{ id = 4, dist = 2, downed = true, dead = true },
	}, D.ReviveRange)
	check("prompt picks nearest downed teammate", picked == 2)
	check(
		"no prompt out of range",
		DownedLogic.pickReviveTarget(
			UP,
			{ { id = 1, dist = 20, downed = true, dead = false } },
			D.ReviveRange
		) == nil
	)
	check(
		"no prompt for a downed viewer",
		DownedLogic.pickReviveTarget(
			DOWN,
			{ { id = 1, dist = 1, downed = true, dead = false } },
			D.ReviveRange
		) == nil
	)

	-- Spectate cycling
	check("spectate empty is nil", DownedLogic.nextSpectate({}, nil, 1) == nil)
	check("spectate starts at first", DownedLogic.nextSpectate({ 5, 7, 9 }, nil, 1) == 5)
	check("spectate next wraps", DownedLogic.nextSpectate({ 5, 7, 9 }, 9, 1) == 5)
	check("spectate prev wraps", DownedLogic.nextSpectate({ 5, 7, 9 }, 5, -1) == 9)
	check("spectate dropped target restarts", DownedLogic.nextSpectate({ 5, 7 }, 99, 1) == 5)

	-- Kill height: outright, not revivable
	check("kill height below", DownedLogic.fellOut(0, Config.Terrain.KillHeight - 1, 0))
	check("kill height above is safe", not DownedLogic.fellOut(0, Config.Terrain.BaseHeight + 5, 0))
	check("kill height matches World", World.belowKillHeight(Config.Terrain.KillHeight - 1))
	check("config sane", D.DownedJumpPower == 0 and D.DownedHealth > 0 and D.PoseDropY > 0)

	-- Run end: all down or dead ends the run; a revive reopens it
	local opts = { rejoinWindow = 300, reviveLimit = D.BleedoutSeconds }
	local run = RunState.new({ 1, 2, 3 }, opts)
	RunState.setDowned(run, 1, 0)
	RunState.setDead(run, 2)
	check("run open while one stands", not RunState.isOver(run))
	RunState.setDowned(run, 3, 0)
	check("all down or dead ends the run", RunState.isOver(run))
	local reopened = RunState.new({ 1, 2 }, opts)
	RunState.setDowned(reopened, 1, 0)
	check("revive in the window", RunState.revive(reopened, 1, D.BleedoutSeconds - 1))
	check("run open after revive", not RunState.isOver(reopened))
	RunState.setDowned(reopened, 1, 100)
	RunState.tick(reopened, 100 + D.BleedoutSeconds)
	check("expired window = dead", RunState.status(reopened, 1) == "dead")
	check("dead cannot be revived", not RunState.revive(reopened, 1, 100 + D.BleedoutSeconds))
	check(
		"last stander dead ends run",
		(function()
			RunState.setDead(reopened, 2)
			return RunState.isOver(reopened)
		end)()
	)
end
