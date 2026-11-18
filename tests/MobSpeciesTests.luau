--!strict
-- Art Pass 3 species: behavior state machines, ring spawn weights, drops, scaling caps, dread weighting,
-- toughness order, state mapping, item uses and debug command validation. Pure (headless).

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local Behaviors = require("../src/shared/logic/MobBehaviors")
local DebugCommands = require("../src/shared/logic/DebugCommands")
local MobDread = require("../src/shared/logic/MobDread")
local MobScaling = require("../src/shared/logic/MobScaling")
local MobSpecies = require("../src/shared/logic/MobSpecies")
local MobStateMap = require("../src/shared/logic/MobStateMap")

local Flee = Behaviors.Flee
local Return = Behaviors.ReturnAfterFlee
local Retaliate = Behaviors.Retaliate
local Warn = Behaviors.TerritorialWarn
local Herd = Behaviors.HerdAlert
local Telegraph = Behaviors.Telegraph
local Flank = Behaviors.PackFlank
local Circle = Behaviors.Circle
local Lure = Behaviors.Lure

local function species(id: string): MobSpecies.Species
	local def = MobSpecies.get(id)
	assert(def, id)
	return def
end

return function(check: (string, boolean) -> ())
	local M = Config.Mobs
	local ids = MobSpecies.ids()

	-- Roster and schema ---------------------------------------------------------------------------------
	check("species: the 8 new kinds", #ids == 8)
	local schemaOk, capsOk, noTame = true, true, true
	local partSum = 0
	for _, id in ids do
		local d = species(id)
		schemaOk = schemaOk
			and d.id == id
			and #d.ringWeights == 4
			and #d.behaviors >= 1
			and d.spawnCap >= 1
			and d.health > 0
			and #d.size == 3
			and #d.color == 3
		capsOk = capsOk and d.partCap <= Config.Creatures.PartCap and d.partCap >= 1
		partSum += d.partCap * d.spawnCap
		for _, b in d.behaviors do
			noTame = noTame and b ~= "Tame" and Behaviors[b] ~= nil
		end
	end
	check("species: schema complete", schemaOk)
	check("species: part cap per mob <= Creatures.PartCap (25)", capsOk)
	check("species: no taming; every behavior has a machine", noTame)
	check(
		"species: worst-case live species parts fit Spawning.MaxMobParts",
		partSum <= M.Spawning.MaxMobParts
	)
	check("perf: MaxLiveParts untouched", Config.Perf.MaxLiveParts == 6000)
	check(
		"species: roles",
		species("SnowGrouse").role == "passive"
			and species("RidgeStag").role == "neutral"
			and species("LakeSeal").role == "neutral"
			and species("RimeWolverine").role == "hostile"
			and species("ScrapHound").role == "hostile"
			and species("CarrionCrow").role == "ambient"
			and species("FrostboundBrute").role == "hostile"
			and species("AuroraWisp").role == "ambient"
	)
	check(
		"species: hounds pack of 3, stags herd",
		species("ScrapHound").packSize == 3 and (species("RidgeStag").packSize or 0) >= 2
	)
	check(
		"species: ambient mobs deal no damage",
		species("CarrionCrow").damage == 0 and species("AuroraWisp").damage == 0
	)

	-- Toughness order -------------------------------------------------------------------------------------
	local tool = Config.Combat.ToolDamage
	local order = {
		species("SnowGrouse").health,
		M.Hare.Health,
		species("RidgeStag").health,
		species("LakeSeal").health,
		species("RimeWolverine").health,
		M.Wolf.Health,
		species("ScrapHound").health,
		species("FrostboundBrute").health,
	}
	local strict = true
	for i = 2, #order do
		strict = strict and order[i] > order[i - 1]
	end
	check("toughness: grouse < hare < stag < seal < wolverine < wolf < hounds < brute", strict)
	local hitsOk = true
	local lastHits = 0
	for _, hp in order do
		local hits = math.ceil(hp / tool)
		hitsOk = hitsOk and hits >= lastHits
		lastHits = hits
	end
	check("toughness: starting-tool hits never decrease along the order", hitsOk)
	local tunedOk = true
	for _, id in ids do
		tunedOk = tunedOk and MobSpecies.hitsToKill(species(id), tool) == species(id).hitsToKill
	end
	check("toughness: hitsToKill matches health / ToolDamage", tunedOk)
	check(
		"toughness: grouse needs fewer hits than hare, brute more than hounds",
		species("SnowGrouse").hitsToKill < math.ceil(M.Hare.Health / tool)
			and species("FrostboundBrute").hitsToKill > species("ScrapHound").hitsToKill
	)

	-- Ring spawn weights (index ring + 1) ---------------------------------------------------------------
	check(
		"ring: grouse only in the forest and lake",
		MobSpecies.ringWeight(species("SnowGrouse"), 0) > 0
			and MobSpecies.ringWeight(species("SnowGrouse"), 2) == 0
	)
	check(
		"ring: seal favours the lake",
		MobSpecies.ringWeight(species("LakeSeal"), 1)
			> MobSpecies.ringWeight(species("LakeSeal"), 0)
	)
	check(
		"ring: hounds in ring 3 (MountainsCaves) not the forest",
		MobSpecies.ringWeight(species("ScrapHound"), 2) > 0
			and MobSpecies.ringWeight(species("ScrapHound"), 0) == 0
	)
	check(
		"ring: brute only in ring 4 (DeepTundra)",
		MobSpecies.ringWeight(species("FrostboundBrute"), 3) > 0
			and MobSpecies.ringWeight(species("FrostboundBrute"), 2) == 0
	)
	check(
		"ring: out of range rings clamp",
		MobSpecies.ringWeight(species("CarrionCrow"), 99) == species("CarrionCrow").ringWeights[4]
			and MobSpecies.ringWeight(species("CarrionCrow"), -3)
				== species("CarrionCrow").ringWeights[1]
	)
	check(
		"spawn: nothing before minDay, night-only needs danger",
		MobSpecies.spawnWeight(species("FrostboundBrute"), 3, 1, true) == 0
			and MobSpecies.spawnWeight(species("ScrapHound"), 2, 10, false) == 0
			and MobSpecies.spawnWeight(species("ScrapHound"), 2, 10, true) > 0
	)
	-- Outer rings are meaner (more hostile weight + aggression), capped by the existing Scaling caps.
	local wolverine = species("RimeWolverine")
	local meaner, capped = true, true
	for ring = 1, 3 do
		meaner = meaner
			and MobSpecies.hostileFactor(wolverine, ring)
				>= MobSpecies.hostileFactor(wolverine, ring - 1)
		capped = capped
			and MobSpecies.hostileFactor(wolverine, ring) <= Config.Scaling.MaxRingBudgetMultiplier
			and MobSpecies.aggroScale(wolverine, ring) <= Config.Scaling.MaxRingDamageMultiplier
	end
	check(
		"ring: hostile weight and aggro grow outward",
		meaner and MobSpecies.aggroScale(wolverine, 3) > MobSpecies.aggroScale(wolverine, 0)
	)
	check(
		"ring: meanness capped by Scaling.MaxRing*Multiplier",
		capped
			and MobSpecies.hostileFactor(wolverine, 100) == Config.Scaling.MaxRingBudgetMultiplier
			and MobSpecies.aggroScale(wolverine, 100) == Config.Scaling.MaxRingDamageMultiplier
	)
	check(
		"ring: passive species are not meaner",
		MobSpecies.hostileFactor(species("SnowGrouse"), 3) == 1
			and MobSpecies.aggroScale(species("RidgeStag"), 3) == 1
	)

	-- Scaling caps / live caps ---------------------------------------------------------------------------
	local mult = MobScaling.multipliers(10000, 100, 100)
	check(
		"scaling: every factor still capped",
		mult.health
				<= Config.Scaling.MaxMobHealthMultiplier * Config.Scaling.MaxRingHealthMultiplier * Config.Scaling.MaxPartyHealthMultiplier
			and mult.damage
				<= Config.Scaling.MaxMobDamageMultiplier * Config.Scaling.MaxRingDamageMultiplier
	)
	check("scaling: MaxLiveMobs stays 40", Config.Scaling.MaxLiveMobs == 40)
	local hp, dmg = MobScaling.mobStats(
		"FrostboundBrute",
		species("FrostboundBrute").health,
		species("FrostboundBrute").damage,
		10000,
		100,
		100
	)
	check(
		"scaling: species health/damage bounded",
		hp <= species("FrostboundBrute").health * 4 * 1.6 * 1.5 + 1e-6
			and dmg <= species("FrostboundBrute").damage * 3 * 1.4 + 1e-6
	)
	check(
		"spawn caps: per-species cap",
		MobSpecies.underCap(species("FrostboundBrute"), 0)
			and not MobSpecies.underCap(species("FrostboundBrute"), 1)
	)
	check(
		"spawn caps: pack never past the cap",
		MobSpecies.groupSize(species("ScrapHound"), 0) == 3
			and MobSpecies.groupSize(species("ScrapHound"), 5) == 1
			and MobSpecies.groupSize(species("ScrapHound"), 6) == 0
	)
	check(
		"parts: mob + chunk parts counted against the live cap",
		MobSpecies.partsOk(0, 20, 100)
			and not MobSpecies.partsOk(M.Spawning.MaxMobParts, 1, nil)
			and not MobSpecies.partsOk(0, 20, Config.Perf.MaxLiveParts - M.Spawning.PartHeadroom)
	)
	check(
		"ground: spawn hit must match real terrain",
		MobSpecies.groundedOk(10, 11)
			and not MobSpecies.groundedOk(nil, 11)
			and not MobSpecies.groundedOk(10, 10 + M.Spawning.GroundTolerance + 1)
	)

	-- Drops ------------------------------------------------------------------------------------------------
	local dropsOk, usesOk = true, true
	local used: { [string]: boolean } = {}
	for _, recipe in ItemCatalog.Recipes do
		for _, input in recipe.inputs do
			used[input.id] = true
		end
	end
	for _, id in ids do
		for _, row in species(id).drops do
			local item = ItemCatalog.Items[row.id]
			dropsOk = dropsOk
				and item ~= nil
				and row.min >= 1
				and row.max >= row.min
				and row.chance > 0
				and row.chance <= 1
			usesOk = usesOk and item ~= nil and (item.kind == "food" or used[row.id] == true)
		end
	end
	check("drops: every drop id is a real item with sane counts", dropsOk)
	check("drops: every dropped item has a use (food or recipe input)", usesOk)
	local all = MobSpecies.rollDrops(species("RidgeStag").drops, function()
		return 0
	end)
	local none = MobSpecies.rollDrops(species("RidgeStag").drops, function()
		return 0.9999
	end)
	check(
		"drops: roll 0 gives every row at min, high roll only sure drops",
		#all == 3
			and all[1].count == 2
			and #none == 1
			and none[1].id == "Venison"
			and none[1].count == 3
	)
	check(
		"drops: crow feather is rare",
		species("CarrionCrow").drops[1].id == "Feather"
			and species("CarrionCrow").drops[1].chance <= 0.25
	)
	check(
		"drops: wisp dust is rare",
		species("AuroraWisp").drops[1].id == "AuroraDust"
			and species("AuroraWisp").drops[1].chance <= 0.3
	)
	local stackOk = true
	local stacks: { [string]: number } = {
		Feather = 20,
		Venison = 10,
		Blubber = 10,
		Claw = 10,
		Fang = 10,
		Bone = 10,
		DenseHide = 10,
		CrystalShard = 10,
		AuroraDust = 10,
	}
	for id, stack in stacks do
		stackOk = stackOk and ItemCatalog.Items[id] ~= nil and ItemCatalog.stackOf(id) == stack
	end
	check("items: new drop stacks (Feather 20, the rest 10)", stackOk)
	check(
		"items: venison is food",
		ItemCatalog.Items.Venison.kind == "food" and (ItemCatalog.Items.Venison.hunger or 0) > 0
	)
	local recipes = { "InsulatedCoat", "BlubberTorch", "FangSpear", "AuroraTorch" }
	local recipesOk = true
	for _, rid in recipes do
		local r = ItemCatalog.Recipes[rid]
		recipesOk = recipesOk and r ~= nil and ItemCatalog.Items[r.output.id] ~= nil
		if r then
			for _, input in r.inputs do
				recipesOk = recipesOk and ItemCatalog.Items[input.id] ~= nil
			end
		end
	end
	check("items: 4 creature recipes resolve", recipesOk)
	check(
		"items: insulated coat is worn gear",
		ItemCatalog.Items.InsulatedCoat.equipSlot == "Body"
			and (ItemCatalog.Items.InsulatedCoat.coldResistance or 0) > 0
	)

	-- Behavior: Flee / ReturnAfterFlee --------------------------------------------------------------------
	local fs = Flee.new()
	local out
	fs, out = Flee.step(fs, { dist = 10, fleeRange = 20, burstSeconds = 1, restSeconds = 1 }, 0.25)
	check("flee: runs when a threat is close", out.fleeing and out.moving)
	for _ = 1, 4 do
		fs, out =
			Flee.step(fs, { dist = 10, fleeRange = 20, burstSeconds = 1, restSeconds = 1 }, 0.25)
	end
	check("flee: pauses after a burst", out.fleeing and not out.moving)
	for _ = 1, 4 do
		fs, out =
			Flee.step(fs, { dist = 10, fleeRange = 20, burstSeconds = 1, restSeconds = 1 }, 0.25)
	end
	check("flee: sprints again after the pause", out.moving)
	fs, out = Flee.step(fs, { dist = 40, fleeRange = 20, burstSeconds = 1, restSeconds = 1 }, 0.2)
	check("flee: calm when the threat is far or absent", not out.fleeing and not fs.fleeing)
	local _, noRest =
		Flee.step(Flee.new(), { dist = 5, fleeRange = 20, burstSeconds = 1, restSeconds = 0 }, 5)
	check("flee: restSeconds 0 never pauses", noRest.moving)
	local rs = Return.new()
	local ro
	rs, ro =
		Return.step(rs, { fleeing = true, homeDist = 30, returnDelay = 3, homeRadius = 10 }, 0.2)
	check("return: away while fleeing", ro.phase == "Away" and not ro.goHome)
	rs, ro =
		Return.step(rs, { fleeing = false, homeDist = 30, returnDelay = 3, homeRadius = 10 }, 1)
	check("return: waits for calm", not ro.goHome)
	rs, ro =
		Return.step(rs, { fleeing = false, homeDist = 30, returnDelay = 3, homeRadius = 10 }, 3)
	check("return: heads home after the delay", ro.goHome and ro.phase == "Returning")
	rs, ro =
		Return.step(rs, { fleeing = false, homeDist = 5, returnDelay = 3, homeRadius = 10 }, 0.2)
	check("return: settles home", ro.phase == "Home" and not ro.goHome)

	-- Behavior: Retaliate ----------------------------------------------------------------------------------
	local rt = Retaliate.new()
	local rout
	local input = {
		hit = false,
		dist = 5 :: number?,
		attackRange = 5,
		canAttack = true,
		leash = 40,
		retaliateSeconds = 4,
	}
	rt, rout = Retaliate.step(rt, input, 0.2)
	check("retaliate: idle until hit", rout.action == "Idle" and not rout.angry)
	input.hit = true
	rt, rout = Retaliate.step(rt, input, 0.2)
	check("retaliate: hit -> attacks in range", rout.action == "Attack" and rout.angry)
	input.hit = false
	input.dist = 20
	rt, rout = Retaliate.step(rt, input, 0.2)
	check("retaliate: chases while angry", rout.action == "Chase")
	input.canAttack = false
	input.dist = 4
	rt, rout = Retaliate.step(rt, input, 0.2)
	check("retaliate: on cooldown keeps chasing", rout.action == "Chase")
	rt, rout = Retaliate.step(rt, input, 5)
	check("retaliate: calms after retaliateSeconds", rout.action == "Idle")
	rt, rout = Retaliate.step(rt, {
		hit = true,
		dist = 90,
		attackRange = 5,
		canAttack = true,
		leash = 40,
		retaliateSeconds = 4,
	}, 0.2)
	check("retaliate: gives up beyond the leash", rout.action == "Idle")

	-- Behavior: TerritorialWarn ----------------------------------------------------------------------------
	local wi = {
		dist = 15 :: number?,
		hit = false,
		warnRange = 20,
		warnSeconds = 2,
		commitRange = 8,
		attackSeconds = 3,
		cooldownSeconds = 4,
		loseRange = 30,
	}
	local ws = Warn.new()
	local wout
	ws, wout = Warn.step(ws, wi, 0.2)
	check(
		"warn: posture when a player enters warnRange",
		wout.phase == "Warn" and wout.warnLeft > 0
	)
	ws, wout = Warn.step(ws, wi, 2)
	check("warn: no attack while the player stays outside commitRange", wout.phase == "Warn")
	wi.dist = 25
	ws, wout = Warn.step(ws, wi, 0.2)
	check("warn: still warning at 25", wout.phase == "Warn")
	wi.dist = 40
	ws, wout = Warn.step(ws, wi, 0.2)
	check("warn: backs down when the player leaves", wout.phase == "Calm")
	wi.dist = 15
	ws, wout = Warn.step(ws, wi, 0.2)
	wi.dist = 6
	ws, wout = Warn.step(ws, wi, 0.2)
	check("warn: no attack before the warning ends", wout.phase == "Warn")
	ws, wout = Warn.step(ws, wi, 2)
	check("warn: attacks when the player keeps coming", wout.phase == "Attack")
	ws, wout = Warn.step(ws, wi, 3)
	check("warn: cools off after the attack", wout.phase == "Cool")
	ws, wout = Warn.step(ws, wi, 4)
	check("warn: back to calm", wout.phase == "Calm")
	wi.hit = true
	ws, wout = Warn.step(ws, wi, 0.2)
	check("warn: being hit skips the warning", wout.phase == "Attack")

	-- Behavior: HerdAlert ----------------------------------------------------------------------------------
	local hs = Herd.new()
	local hout
	hs, hout = Herd.step(hs, { threat = false, neighborAlert = false, alertSeconds = 3 }, 0.2)
	check("herd: calm without a threat", not hout.alerted)
	hs, hout = Herd.step(hs, { threat = true, neighborAlert = false, alertSeconds = 3 }, 0.2)
	check("herd: alert on a threat", hout.alerted)
	hs, hout = Herd.step(hs, { threat = false, neighborAlert = false, alertSeconds = 3 }, 3.1)
	check("herd: alert wears off", not hout.alerted)
	hs, hout = Herd.step(hs, { threat = false, neighborAlert = true, alertSeconds = 3 }, 0.2)
	check("herd: a neighbour's alert spreads", hout.alerted)
	local herd = {
		{ x = 10, z = 0, alerted = true },
		{ x = 100, z = 0, alerted = true },
		{ x = 5, z = 0, alerted = false },
	}
	check(
		"herd: only alerted members within radius count",
		Herd.neighborAlerted({ x = 0, z = 0 }, herd, 20)
			and not Herd.neighborAlerted({ x = 0, z = 0 }, { herd[2], herd[3] }, 20)
	)

	-- Behavior: Telegraph ------------------------------------------------------------------------------------
	local ts = Telegraph.new()
	local tout
	ts, tout = Telegraph.step(ts, { ready = false, inReach = true, seconds = 1 }, 0.2)
	check("telegraph: idle when not ready", tout.event == "Idle")
	ts, tout = Telegraph.step(ts, { ready = true, inReach = true, seconds = 1 }, 0.2)
	check("telegraph: starts with the full wind-up", tout.event == "Start" and tout.left == 1)
	ts, tout = Telegraph.step(ts, { ready = true, inReach = true, seconds = 1 }, 0.5)
	check("telegraph: waits", tout.event == "Wait" and tout.left > 0 and tout.left < 1)
	local ts2, cancel = Telegraph.step(ts, { ready = true, inReach = false, seconds = 1 }, 0.1)
	check(
		"telegraph: target left reach -> cancelled (dodgeable)",
		cancel.event == "Cancel" and ts2.left == nil
	)
	ts, tout = Telegraph.step(ts, { ready = true, inReach = true, seconds = 1 }, 0.6)
	check("telegraph: strikes after the full wind-up", tout.event == "Strike" and ts.left == nil)
	local _, instant =
		Telegraph.step(Telegraph.new(), { ready = true, inReach = true, seconds = 0 }, 0.2)
	check("telegraph: zero seconds strikes at once", instant.event == "Strike")
	check(
		"telegraph: species wind-ups are long enough to dodge",
		species("FrostboundBrute").telegraphSeconds >= 1.2
			and species("RimeWolverine").telegraphSeconds >= Config.Night.WindupSeconds
	)

	-- Behavior: PackFlank ---------------------------------------------------------------------------------------
	local members = { { x = 30, z = 0 }, { x = 32, z = 3 }, { x = 28, z = -3 } }
	local slots = Flank.slots(members, { x = 0, z = 0 }, 14)
	local radiiOk = true
	for _, s in slots do
		radiiOk = radiiOk and math.abs(math.sqrt(s.x * s.x + s.z * s.z) - 14) < 1e-6
	end
	local spread = math.atan2(slots[1].z, slots[1].x) - math.atan2(slots[2].z, slots[2].x)
	check(
		"flank: slots on the flank ring, spread round the target",
		#slots == 3 and radiiOk and math.abs(spread) > 0.5
	)
	local fl = Flank.new()
	local fout
	fl, fout = Flank.step(fl, {
		members = members,
		target = { x = 0, z = 0 },
		radius = 14,
		engageSeconds = 4,
		slotTolerance = 2,
	}, 0.2)
	check("flank: surrounds first", fout.phase == "Surround" and #fout.slots == 3)
	fl, fout = Flank.step(fl, {
		members = members,
		target = { x = 0, z = 0 },
		radius = 14,
		engageSeconds = 4,
		slotTolerance = 2,
	}, 4)
	check(
		"flank: rushes after engageSeconds, every slot is the target",
		fout.phase == "Rush" and fout.slots[1].x == 0 and fout.slots[3].z == 0
	)
	local onSlots = Flank.slots(members, { x = 0, z = 0 }, 14)
	local fl2 = Flank.new()
	fl2, fout = Flank.step(fl2, {
		members = onSlots,
		target = { x = 0, z = 0 },
		radius = 14,
		engageSeconds = 99,
		slotTolerance = 2,
	}, 0.2)
	check("flank: rushes as soon as everyone holds a slot", fout.phase == "Rush")
	fl, fout = Flank.step(
		fl,
		{ members = members, target = nil, radius = 14, engageSeconds = 4, slotTolerance = 2 },
		0.2
	)
	check("flank: resets when the target is lost", fout.phase == "Surround" and fl.t == 0)

	-- Behavior: Circle ----------------------------------------------------------------------------------------------
	local cs = Circle.new(0)
	local cout
	local ci = {
		self = { x = 0, z = 0 },
		center = { x = 0, z = 0 },
		radius = 10,
		angularSpeed = 1,
		scatter = false,
		scatterDir = { x = 0, z = 1 },
		scatterSeconds = 2,
		scatterStep = 30,
	}
	cs, cout = Circle.step(cs, ci, 0.5)
	check(
		"circle: orbits at the radius",
		cout.phase == "Circle"
			and math.abs(math.sqrt(cout.goal.x ^ 2 + cout.goal.z ^ 2) - 10) < 1e-6
	)
	ci.scatter = true
	cs, cout = Circle.step(cs, ci, 0.5)
	check(
		"circle: scatters along the given direction (Heading)",
		cout.phase == "Scatter" and cout.heading.z == 1 and cout.goal.z > 0
	)
	ci.scatter = false
	cs, cout = Circle.step(cs, ci, 0.5)
	check("circle: stays scattering once started", cout.phase == "Scatter")
	cs, cout = Circle.step(cs, ci, 2)
	check("circle: gone after scatterSeconds", cout.phase == "Gone")

	-- Behavior: Lure ---------------------------------------------------------------------------------------------------
	local lu = Lure.new()
	local lout
	local li = {
		self = { x = 0, z = 0 },
		player = { x = 20, z = 0 } :: { x: number, z: number }?,
		hazard = { x = 20, z = 50 } :: { x: number, z: number }?,
		lureRange = 45,
		leadDistance = 22,
		touchRange = 3,
		drainCooldown = 6,
		drainAmount = 4,
		drainCap = 8,
	}
	lu, lout = Lure.step(lu, li, 0.2)
	check(
		"lure: hovers ahead of the player on the hazard side",
		lout.mode == "Lure" and lout.goal ~= nil and lout.goal.z > 10 and lout.drain == 0
	)
	li.player = { x = 1, z = 0 }
	lu, lout = Lure.step(lu, li, 0.2)
	check("lure: touch drains a small amount", lout.mode == "Touch" and lout.drain == 4)
	lu, lout = Lure.step(lu, li, 0.2)
	check("lure: drain has a cooldown", lout.drain == 0)
	lu, lout = Lure.step(lu, li, 7)
	check("lure: second touch drains again", lout.drain == 4)
	lu, lout = Lure.step(lu, li, 7)
	check(
		"lure: total drain capped, wisp is spent",
		lout.mode == "Spent" and lout.drain == 0 and lu.drained == 8
	)
	local _, far = Lure.step(Lure.new(), {
		self = { x = 0, z = 0 },
		player = nil,
		hazard = { x = 5, z = 5 },
		lureRange = 45,
		leadDistance = 22,
		touchRange = 3,
		drainCooldown = 6,
		drainAmount = 4,
		drainCap = 8,
	}, 0.2)
	check(
		"lure: drifts toward a hazard with no player near",
		far.mode == "Drift" and far.goal ~= nil and far.goal.x == 5
	)
	check(
		"lure: wisp drain config is small and capped",
		species("AuroraWisp").tune.drainWarmth <= 5 and species("AuroraWisp").tune.drainCap <= 15
	)

	-- Dread weighting -------------------------------------------------------------------------------------------------
	local lone = { { x = 0, z = 0 }, { x = 500, z = 0 } }
	local group = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 5, z = 5 } }
	local solo = { { x = 0, z = 0 } }
	local loneFactor = MobDread.factor(lone, 1, 2)
	local groupFactor = MobDread.factor(group, 1, 3)
	local soloFactor = MobDread.factor(solo, 1, 1)
	check("dread: lone player attracts more than a solo baseline", loneFactor > soloFactor)
	check("dread: full groups suppress", groupFactor < soloFactor and groupFactor < loneFactor)
	check(
		"dread: factor stays inside Dread.MinFactor..MaxFactor",
		loneFactor <= M.Dread.MaxFactor and groupFactor >= M.Dread.MinFactor
	)
	check(
		"dread: only ambient weights move",
		MobDread.weight("ambient", 4, 2) == 8
			and MobDread.weight("hostile", 4, 2) == 4
			and MobDread.weight("passive", 4, 0.1) == 4
	)
	local pair = { { x = 0, z = 0 }, { x = 20, z = 0 } }
	check(
		"dread: pair between alone and group",
		MobDread.factor(pair, 1, 2) < loneFactor and MobDread.factor(pair, 1, 2) > groupFactor
	)
	local stalkerDir = MobDread.scatterDir({ x = 0, z = 0 }, { x = 5, z = 0 }, { x = 0, z = 100 })
	check("dread: crows scatter toward the Stalker", stalkerDir.z > 0.99)
	local awayDir = MobDread.scatterDir({ x = 10, z = 0 }, { x = 0, z = 0 }, nil)
	check("dread: with no hunt crows scatter away from the player", awayDir.x > 0.99)
	local hz = MobDread.hazardPoint({ x = 50, z = 0 }, { x = 0, z = 0 }, nil, 22)
	check("dread: wisp hazard lies beyond the player, away from the fire", hz ~= nil and hz.x > 50)
	check(
		"dread: Stalker is the hazard when it hunts",
		MobDread.hazardPoint({ x = 0, z = 0 }, nil, { x = 7, z = 7 }, 22) ~= nil
	)

	-- State mapping (attrs per contract) --------------------------------------------------------------------------------
	local map: { [string]: string } = {
		Rest = "Idle",
		Idle = "Idle",
		Wander = "Walk",
		Flee = "Run",
		Chase = "Run",
		Windup = "Telegraph",
		Attack = "Attack",
		Alert = "Alert",
		Hurt = "Hurt",
		Death = "Death",
	}
	local mapOk = true
	for action, state in map do
		mapOk = mapOk and MobStateMap.stateFor(action) == state
	end
	check(
		"state map: legacy actions -> contract States",
		mapOk and MobStateMap.stateFor(nil) == "Idle"
	)
	local validStates = true
	for _, a in
		{
			"Rest",
			"Idle",
			"Hold",
			"Wander",
			"Return",
			"Circle",
			"Drift",
			"Flee",
			"Chase",
			"Retreat",
			"Leave",
			"Charge",
			"Rush",
			"Scatter",
			"Alert",
			"Warn",
			"Windup",
			"Telegraph",
			"Attack",
			"Strike",
		}
	do
		validStates = validStates
			and table.find(Config.Creatures.States, MobStateMap.stateFor(a)) ~= nil
	end
	check("state map: every action maps to a Config.Creatures.States entry", validStates)
	check(
		"state map: Death > Hurt > Attack > action",
		MobStateMap.resolve("Chase", 0.1, 0.1, true) == "Death"
			and MobStateMap.resolve("Chase", 0.1, 0.1, false) == "Hurt"
			and MobStateMap.resolve("Chase", 0, 0.1, false) == "Attack"
			and MobStateMap.resolve("Chase", 0, 0, false) == "Run"
	)
	check(
		"state map: telegraphing/charging mobs carry a Target",
		MobStateMap.hasTarget("Windup")
			and MobStateMap.hasTarget("Charge")
			and not MobStateMap.hasTarget("Wander")
	)

	-- Debug commands --------------------------------------------------------------------------------------------------------
	local kinds = table.clone(Config.Debug.MobKinds)
	for _, id in ids do
		table.insert(kinds, id)
	end
	local limits: DebugCommands.Limits =
		{ maxDay = 30, maxClockSpeed = 100, ringCount = 4, darkEvents = {}, mobKinds = kinds }
	local okMob, canon = DebugCommands.validate("mob", "snowgrouse", limits)
	check(
		"debug: /debug mob accepts any kind, case-insensitive",
		okMob and canon == "SnowGrouse" and (DebugCommands.validate("mob", "Wolf", limits))
	)
	check(
		"debug: /debug mob rejects unknown, empty and non-string",
		not DebugCommands.validate("mob", "Dragon", limits)
			and not DebugCommands.validate("mob", "", limits)
			and not DebugCommands.validate("mob", 5, limits)
	)
	check("debug: /debug mobs takes no arg", (DebugCommands.validate("mobs", nil, limits)))
	check(
		"debug: mob and mobs are action-only commands",
		DebugCommands.ACTION_ONLY.mob == true
			and DebugCommands.ACTION_ONLY.mobs == true
			and table.find(DebugCommands.NAMES, "mob") ~= nil
			and table.find(DebugCommands.NAMES, "mobs") ~= nil
	)
	local allKinds = true
	for _, id in ids do
		allKinds = allKinds and (DebugCommands.validate("mob", id, limits))
	end
	check("debug: all 8 new kinds spawnable", allKinds)
end
