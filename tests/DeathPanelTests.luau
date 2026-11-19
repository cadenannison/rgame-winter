--!strict
-- Headless tests for the death-panel state mapping (alive hides, downed/dead/summary show, respawn hides).

local DeathPanelState = require("../src/shared/logic/DeathPanelState")
local RunState = require("../src/server/Run/RunState")

local function input(overrides: { [string]: any }): DeathPanelState.Input
	local base: { [string]: any } = {
		aliveTeammates = 1,
		downed = false,
		dead = false,
		runEnded = false,
		hasSummary = false,
		inLobby = false,
		dismissed = false,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base :: any
end

return function(check: (string, boolean) -> ())
	local alive = DeathPanelState.resolve(input({}))
	check("deathpanel: alive hides", alive.mode == "hidden" and not alive.visible)
	check("deathpanel: hidden never blocks input", not alive.blocksInput and not alive.opaque)

	local downed = DeathPanelState.resolve(input({ downed = true }))
	check("deathpanel: downed shows revive UI", downed.mode == "downed" and downed.showRevive)
	check("deathpanel: downed is not opaque", not downed.opaque and not downed.showReturn)

	local dead = DeathPanelState.resolve(input({ dead = true }))
	check(
		"deathpanel: dead shows spectate and return",
		dead.mode == "dead" and dead.showSpectate and dead.showReturn
	)
	check("deathpanel: dead panel not opaque", not dead.opaque)

	local ended =
		DeathPanelState.resolve(input({ dead = true, runEnded = true, hasSummary = true }))
	check(
		"deathpanel: run end shows opaque summary with play again",
		ended.mode == "summary" and ended.opaque and ended.showPlayAgain and ended.showReturn
	)
	local empty = DeathPanelState.resolve(input({ dead = true, runEnded = true }))
	check("deathpanel: no summary data never shows opaque", not empty.opaque)

	local respawned = DeathPanelState.resolve(input({ runEnded = true, hasSummary = true }))
	check("deathpanel: respawn after run end hides summary", respawned.mode == "hidden")
	local lobby =
		DeathPanelState.resolve(input({ runEnded = true, hasSummary = true, inLobby = true }))
	check("deathpanel: lobby shows summary to living players", lobby.mode == "summary")
	local closed = DeathPanelState.resolve(
		input({ dead = true, runEnded = true, hasSummary = true, dismissed = true })
	)
	check("deathpanel: dismissed summary falls back to dead bar", closed.mode == "dead")

	-- One panel at a time: spectate only while a teammate lives, the run summary otherwise.
	local alone = DeathPanelState.resolve(input({ dead = true, aliveTeammates = 0 }))
	check(
		"deathpanel: dead with nobody alive has no spectate controls",
		alone.mode == "dead" and not alone.showSpectate and alone.showDeadBar and alone.showReturn
	)
	local aloneEnded = DeathPanelState.resolve(
		input({ dead = true, aliveTeammates = 0, runEnded = true, hasSummary = true })
	)
	check(
		"deathpanel: nobody alive + run end shows only the summary",
		aloneEnded.mode == "summary" and not aloneEnded.showDeadBar and not aloneEnded.showSpectate
	)
	local withMates =
		DeathPanelState.resolve(input({ dead = true, aliveTeammates = 2, runEnded = false }))
	check(
		"deathpanel: teammate alive shows spectate, not the summary",
		withMates.showSpectate and withMates.showDeadBar and not withMates.opaque
	)
	local matesEnded = DeathPanelState.resolve(
		input({ dead = true, aliveTeammates = 2, runEnded = true, hasSummary = true })
	)
	check(
		"deathpanel: summary and dead bar are never both shown",
		matesEnded.mode == "summary" and not matesEnded.showDeadBar and not matesEnded.showSpectate
	)
	local aloneClosed = DeathPanelState.resolve(input({
		dead = true,
		aliveTeammates = 0,
		runEnded = true,
		hasSummary = true,
		dismissed = true,
	}))
	check(
		"deathpanel: closed summary leaves a Return-only bar",
		aloneClosed.showDeadBar and aloneClosed.showReturn and not aloneClosed.showSpectate
	)

	-- Respawn bookkeeping in the run roster.
	local run = RunState.new({ 1, 2 }, { rejoinWindow = 60, reviveLimit = 60 })
	RunState.setDead(run, 1)
	check("deathpanel: respawn revives a dead member", RunState.respawn(run, 1))
	check("deathpanel: respawned member is alive", RunState.status(run, 1) == "alive")
	check("deathpanel: respawn of an alive member is a no-op", not RunState.respawn(run, 2))
end
