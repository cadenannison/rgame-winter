--!strict
-- Brief 20 (atmosphere/perf) logic tests: cue -> audio mapping, reduce-scares scaling, particle caps,
-- first-run hint completion, interact pick and performance budget math. Registered in tests/run.luau.

local Assets = require("../src/shared/Assets")
local AudioCues = require("../src/shared/data/AudioCues")
local Config = require("../src/shared/Config")
local CueResolve = require("../src/shared/logic/CueResolve")
local PerfBudget = require("../src/shared/logic/PerfBudget")

return function(check: (string, boolean) -> ())
	local P = Config.Perf
	local reducedMult = Config.Settings.ReducedScareVisualMultiplier

	-- ===== cue -> audio mapping complete =====
	local missing: { string } = {}
	for _, kind in Config.Cue.Kinds do
		if AudioCues.ByKey[kind] == nil or CueResolve.resolve(kind, false) == nil then
			table.insert(missing, kind)
		end
	end
	check("atmos: every Config.Cue.Kinds has an AudioCues row", #missing == 0)
	local extras = {
		"Blizzard",
		"FalseNight",
		"TheQuiet",
		"DeepFreeze",
		"StalkerStrike",
		"AchievementUnlocked",
		"PurchaseSuccess",
		"PurchaseFailed",
		"Equip",
		"CoinGain",
		"PersonalBest",
		"DailyClaim",
	}
	local extrasOk = true
	for _, key in extras do
		extrasOk = extrasOk and AudioCues.ByKey[key] ~= nil
	end
	check("atmos: event/stalker/meta rows exist", extrasOk)

	local assetsOk, volumeOk, uniqueOk = true, true, true
	local seen: { [string]: boolean } = {}
	for _, row in AudioCues.List do
		for _, ref in { row.sound, row.particle } do
			if ref ~= nil and type((Assets :: any)[ref]) ~= "string" then
				assetsOk = false
			end
		end
		volumeOk = volumeOk and row.volume >= 0 and row.volume <= 1
		uniqueOk = uniqueOk and not seen[row.key]
		seen[row.key] = true
	end
	check("atmos: row sound/particle keys exist in Assets", assetsOk)
	check("atmos: row volumes in 0..1", volumeOk)
	check("atmos: row keys unique", uniqueOk)
	check("atmos: unknown key resolves to nil", CueResolve.resolve("NoSuchCue", false) == nil)

	-- A missing id falls back silently ("" sound, no error).
	local quiet = CueResolve.resolve("TheQuiet", false)
	check(
		"atmos: no-sound row is silent",
		quiet ~= nil and quiet.soundId == "" and quiet.volume == 0
	)
	local blizzard = CueResolve.resolve("Blizzard", false)
	check(
		"atmos: empty asset id stays empty",
		blizzard ~= nil and blizzard.soundId == Assets.BlizzardWindSound
	)

	-- ===== reduce-scares =====
	local scaryOk, nonScaryOk = true, true
	for _, row in AudioCues.List do
		local normal = CueResolve.resolve(row.key, false)
		local reduced = CueResolve.resolve(row.key, true)
		if normal and reduced then
			if row.scary and row.volume > 0 then
				scaryOk = scaryOk
					and reduced.volume < normal.volume
					and reduced.particleScale < normal.particleScale
					and normal.flash
					and not reduced.flash
			elseif not row.scary then
				nonScaryOk = nonScaryOk and reduced.volume == normal.volume and not normal.flash
			end
		end
	end
	check("atmos: reduce-scares lowers every scary row and removes flashes", scaryOk)
	check("atmos: reduce-scares leaves non-scary rows alone", nonScaryOk)
	check("atmos: reduce multiplier in (0,1)", reducedMult > 0 and reducedMult < 1)
	check("atmos: scale off = 1", CueResolve.scale(true, false) == 1)
	check("atmos: scale on = configured", CueResolve.scale(true, true) == reducedMult)
	check("atmos: non-scary never scaled", CueResolve.scale(false, true) == 1)
	local lurker = CueResolve.resolve("LurkerSighted", true)
	check("atmos: lurker sighting softer when reduced", lurker ~= nil and lurker.volume < 0.4)
	check(
		"atmos: horror sound ownership covers dread rumble",
		CueResolve.HorrorOwnsSound.DreadLevel == true
	)

	-- ===== particle / sound caps =====
	check(
		"atmos: rate clamps to cap",
		PerfBudget.clampRate(1000, P.MaxParticleRate) == P.MaxParticleRate
	)
	check("atmos: rate scales then clamps", PerfBudget.clampRate(10, 40, 0.5) == 5)
	check("atmos: rate never negative", PerfBudget.clampRate(-5, 40) == 0)
	check(
		"atmos: emitter cap blocks at limit",
		not PerfBudget.canAdd(P.MaxParticleEmitters, P.MaxParticleEmitters)
	)
	check(
		"atmos: emitter cap allows below",
		PerfBudget.canAdd(P.MaxParticleEmitters - 1, P.MaxParticleEmitters)
	)
	check(
		"atmos: sound cap blocks at limit",
		not PerfBudget.canAdd(P.MaxActiveSounds, P.MaxActiveSounds)
	)
	check(
		"atmos: caps are positive",
		P.MaxParticleEmitters > 0 and P.MaxParticleRate > 0 and P.MaxActiveSounds > 0
	)

	-- ===== hints =====
	local idsOk = true
	for _, def in CueResolve.HintDefs do
		idsOk = idsOk
			and table.find(Config.Hints.Ids, def.id) ~= nil
			and #def.done > 0
			and def.text ~= ""
	end
	check("atmos: every hint id is a Config.Hints.Ids entry", idsOk)
	local coverage = {}
	for _, def in CueResolve.HintDefs do
		coverage[def.id] = true
	end
	check(
		"atmos: hints cover events, stalker, clothing, chest, map, ping",
		coverage.Blizzard
				and coverage.DarkEvent
				and coverage.Stalker
				and coverage.Clothing
				and coverage.Storage
				and coverage.Map
				and coverage.Ping
			or false
	)
	local seenHints: { [string]: boolean } = {}
	local pick = CueResolve.nextHint(CueResolve.HintDefs, seenHints, { chestNearby = true })
	check("atmos: hint shows when its trigger holds", pick ~= nil and pick.id == "Storage")
	check(
		"atmos: no trigger, no hint",
		CueResolve.nextHint(CueResolve.HintDefs, seenHints, {}) == nil
	)
	check(
		"atmos: wrong action does not complete",
		#CueResolve.complete(CueResolve.HintDefs, seenHints, "mapOpened") == 1
			and seenHints.Storage == nil
	)
	local done = CueResolve.complete(CueResolve.HintDefs, seenHints, "chestOpened")
	check(
		"atmos: real action completes the hint",
		#done == 1 and done[1] == "Storage" and seenHints.Storage == true
	)
	check(
		"atmos: completed hint never shows again",
		CueResolve.nextHint(CueResolve.HintDefs, seenHints, { chestNearby = true }) == nil
	)
	check(
		"atmos: completion fires once",
		#CueResolve.complete(CueResolve.HintDefs, seenHints, "chestOpened") == 0
	)
	local fire = CueResolve.complete(CueResolve.HintDefs, {}, "reachedFire")
	check("atmos: reachedFire completes event and stalker hints", #fire == 3)

	-- ===== interact pick (E near tree vs chest) =====
	check("atmos: no gather target -> structure", CueResolve.structureBeatsGather(nil, false, 8))
	check("atmos: aimed gather wins", not CueResolve.structureBeatsGather(8, true, 3))
	check(
		"atmos: closer structure beats unaimed gather",
		CueResolve.structureBeatsGather(8, false, 3)
	)
	check(
		"atmos: closer unaimed gather beats structure",
		not CueResolve.structureBeatsGather(3, false, 8)
	)

	-- ===== budget math =====
	check("atmos: 30 fps frame budget", math.abs(PerfBudget.frameBudgetMs(30) - 1000 / 30) < 1e-9)
	check("atmos: target fps is 30+", P.TargetFps >= 30)
	check(
		"atmos: stream hysteresis (out > in)",
		Config.World.StreamOutRadius > Config.World.StreamInRadius
	)
	check("atmos: mob caps agree", P.MaxLiveMobs == Config.Scaling.MaxLiveMobs)
	check(
		"atmos: chunk budget positive",
		P.ChunkLoadBudgetPerFrame >= 1 and P.ChunkPartBudgetPerFrame > 0
	)
	check("atmos: allowance honours tick budget", PerfBudget.chunkAllowance(1, 0, 6000, 100) == 1)
	check(
		"atmos: allowance honours part headroom",
		PerfBudget.chunkAllowance(5, 5900, 6000, 100) == 1
	)
	check(
		"atmos: allowance zero at the part cap",
		PerfBudget.chunkAllowance(5, 6000, 6000, 100) == 0
	)
	check("atmos: allowance zero over the cap", PerfBudget.chunkAllowance(5, 7000, 6000, 100) == 0)
	local list = { 4, 2, 9 }
	check("atmos: take keeps priority order", table.concat(PerfBudget.take(list, 2), ",") == "4,2")
	check("atmos: take zero", #PerfBudget.take(list, 0) == 0)
	check("atmos: take more than list", #PerfBudget.take(list, 10) == 3)
	local world = Config.World
	local oneMax = PerfBudget.maxChunks(
		1,
		world.StreamOutRadius,
		world.ChunkSize,
		world.GridSize * world.GridSize
	)
	check(
		"atmos: one player holds fewer chunks than the world",
		oneMax <= world.GridSize * world.GridSize and oneMax >= 9
	)
	check(
		"atmos: chunk cap never exceeds the world",
		PerfBudget.maxChunks(50, world.StreamOutRadius, world.ChunkSize, 64) == 64
	)
	check(
		"atmos: averageMs",
		math.abs(PerfBudget.averageMs(1, 60) - 1000 / 60) < 1e-9 and PerfBudget.averageMs(1, 0) == 0
	)
	local caps: PerfBudget.Caps = {
		maxParts = P.MaxLiveParts,
		maxMobs = P.MaxLiveMobs,
		maxChunks = oneMax,
		maxHeartbeatMs = PerfBudget.frameBudgetMs(P.TargetFps),
	}
	check(
		"atmos: in-budget sample passes",
		#PerfBudget.check({ parts = 100, mobs = 3, chunks = 4, heartbeatMs = 16 }, caps) == 0
	)
	check(
		"atmos: over-cap parts fail",
		#PerfBudget.check(
				{ parts = P.MaxLiveParts + 1, mobs = 0, chunks = 0, heartbeatMs = 1 },
				caps
			) == 1
	)
	check(
		"atmos: over-cap mobs fail",
		#PerfBudget.check(
				{ parts = 0, mobs = P.MaxLiveMobs + 1, chunks = 0, heartbeatMs = 1 },
				caps
			) == 1
	)
	check(
		"atmos: slow heartbeat fails",
		#PerfBudget.check({ parts = 0, mobs = 0, chunks = 0, heartbeatMs = 50 }, caps) == 1
	)
end
