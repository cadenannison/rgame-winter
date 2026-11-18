--!strict
-- Tests for run end (RunState, RunPayout, DailyLogic) and the sim run-end scenario.

local Config = require("../src/shared/Config")
local ProfileSchema = require("../src/shared/logic/ProfileSchema")
local RunPayout = require("../src/shared/logic/RunPayout")
local DailyLogic = require("../src/server/Meta/DailyLogic")
local LobbyLogic = require("../src/shared/logic/LobbyLogic")
local RunState = require("../src/server/Run/RunState")
local Sim = require("./sim")

local OPTS = { rejoinWindow = 120, reviveLimit = 60 } -- fixed values for the pure RunState unit checks

return function(check: (string, boolean) -> ())
	-- RunState
	local run = RunState.new({ 1, 2, 2, 3 }, OPTS)
	check("run dedupes members", #run.order == 3)
	check("run not over at start", not RunState.isOver(run))
	RunState.setDowned(run, 1, 0)
	RunState.setDowned(run, 2, 0)
	check("run continues while one can act", not RunState.isOver(run))
	RunState.setDowned(run, 3, 0)
	check("all downed ends run", RunState.isOver(run))
	check("revive inside limit", RunState.revive(run, 1, 59))
	check("revive after limit refused", not RunState.revive(run, 2, 60))
	RunState.tick(run, 60)
	check("bleedout kills downed", RunState.status(run, 2) == "dead")

	local held = RunState.new({ 1, 2 }, OPTS)
	RunState.setDead(held, 1)
	RunState.disconnect(held, 2, 0)
	check("held alive keeps run open", not RunState.isOver(held))
	check("rejoin inside window", RunState.rejoin(held, 2, 119))
	check("rejoined is alive", RunState.status(held, 2) == "alive")
	RunState.disconnect(held, 2, 200)
	RunState.tick(held, 320)
	check("hold expiry counts as dead", RunState.status(held, 2) == "dead")
	check("run over after hold expiry", RunState.isOver(held))
	check("rejoin after window refused", not RunState.rejoin(held, 2, 320))
	check("stranger cannot rejoin", not RunState.rejoin(held, 99, 1))

	local dh = RunState.new({ 1, 2 }, OPTS)
	RunState.setDowned(dh, 1, 0)
	RunState.disconnect(dh, 1, 10)
	check(
		"rejoin downed past limit dies",
		RunState.rejoin(dh, 1, 100) and RunState.status(dh, 1) == "dead"
	)
	RunState.recordKill(dh, 2, false)
	RunState.recordKill(dh, 2, true)
	RunState.recordKill(dh, 77, false)
	local kills, boss = RunState.totals(dh)
	check("kill totals ignore strangers", kills == 1 and boss == 1)

	-- RunPayout
	local base = RunPayout.coins({ daysSurvived = 0, kills = 0, bossKills = 0, partners = 0 })
	check("bad run still pays CoinsPerRun", base == Config.Meta.CoinsPerRun)
	local r = { daysSurvived = 3, kills = 4, bossKills = 1, partners = 2 }
	local meta = Config.Meta
	check(
		"payout formula",
		RunPayout.coins(r)
			== meta.CoinsPerRun
				+ 3 * meta.CoinsPerDaySurvived
				+ 4 * meta.CoinsPerKill
				+ meta.CoinsPerBossKill
				+ 2 * meta.CoinsPerFriendInParty
	)
	check(
		"payout capped",
		RunPayout.coins({ daysSurvived = 1e9, kills = 1e9, bossKills = 1e9, partners = 5 })
			<= meta.MaxCoinsPerRun
	)
	check(
		"payout rejects NaN and negatives",
		RunPayout.coins({ daysSurvived = 0 / 0, kills = -5, bossKills = -1, partners = -3 }) == base
	)
	local profile = ProfileSchema.default()
	profile.maxDays = 2
	local summary = RunPayout.summarize(r, profile.maxDays)
	check("personal best detected", summary.personalBest)
	RunPayout.apply(profile, summary)
	check(
		"apply updates stats",
		profile.runs == 1 and profile.maxDays == 3 and profile.kills == 4 and profile.bossKills == 1
	)
	check("apply pays coins", profile.coins == Config.StartingCoins + summary.coinsEarned)
	check("applied profile validates", ProfileSchema.validate(profile))
	check("no best when lower", not RunPayout.summarize(r, 10).personalBest)

	-- DailyLogic: one claim per UTC day, same rule as the client (LobbyLogic.canClaimDaily)
	local day = 86400
	local noon = 20000 * day + day / 2
	check("daily first claim", (DailyLogic.check(0, noon)))
	check("daily same utc day blocked", not (DailyLogic.check(noon, noon + day / 2 - 1)))
	check("daily after utc midnight", (DailyLogic.check(noon, noon + day / 2)))
	check("daily future claim blocked", not (DailyLogic.check(noon + day, noon)))
	check("daily next time is midnight", select(2, DailyLogic.check(noon, noon)) == 20001 * day)
	local agree = true
	for _, pair in { { 0, noon }, { noon, noon + 10 }, { noon, noon + day }, { noon - day, noon } } do
		if (DailyLogic.check(pair[1], pair[2])) ~= LobbyLogic.canClaimDaily(pair[1], pair[2]) then
			agree = false
		end
	end
	check("daily server rule matches client", agree)

	-- Sim: downed, revived, dead, disconnected and rejoined players, then run end
	local function plug(sim: Sim.Sim): ()
		local system = Sim.runEndSystem()
		sim:addSystem(system)
	end
	local sim = Sim.new({ seed = 9 })
	local system, stats = Sim.runEndSystem()
	sim:addSystem(system)
	-- Long enough for the 5-minute hold to expire after the t=70 disconnect.
	sim:runDays(math.ceil((70 + Config.Run.RejoinWindowSeconds + 1) / Config.Time.DayLengthSeconds))
	check("sim revive in time", stats.revivedOk)
	check("sim rejoin in window", stats.rejoinedOk)
	check("sim late revive refused", stats.lateReviveRefused)
	check("sim run ends exactly once", stats.endCount == 1 and stats.endedAt > 0)
	check(
		"sim end waits for held player expiry",
		stats.endedAt == 70 + Config.Run.RejoinWindowSeconds
	)
	check(
		"sim final statuses dead",
		stats.finalStatuses[1] == "dead"
			and stats.finalStatuses[2] == "dead"
			and stats.finalStatuses[3] == "dead"
			and stats.finalStatuses[4] == "dead"
	)
	check("sim deterministic", (Sim.determinism(9, 1, plug)))
end
