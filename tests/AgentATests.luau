--!strict
-- Combat and mobs round: wolf speed/damage/cooldown, armor, fire-safe aggro, day wildlife and replacement,
-- spawn-picker audit per ring, Frost Brute poise, display names. Pure (headless).

local Config = require("../src/shared/Config")
local ItemCatalog = require("../src/shared/ItemCatalog")
local MobAggro = require("../src/shared/logic/MobAggro")
local MobBehaviors = require("../src/shared/logic/MobBehaviors")
local MobDamage = require("../src/shared/logic/MobDamage")
local MobNames = require("../src/shared/logic/MobNames")
local MobPoise = require("../src/shared/logic/MobPoise")
local MobSpawnPick = require("../src/shared/logic/MobSpawnPick")
local MobWildlife = require("../src/shared/logic/MobWildlife")

local function lcg(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

return function(check: (string, boolean) -> ())
	local A = Config.Aggro

	-- Wolf ----------------------------------------------------------------------------------------------
	local walk = Config.WALK_SPEED
	local sprint = walk * Config.Sprint.SpeedMultiplier
	local chase = Config.Mobs.Wolf.FleeSpeed
	check("wolf: walk < chase < sprint", walk < chase and chase < sprint)
	check(
		"wolf: cooldown ~15% shorter",
		math.abs(MobDamage.cooldown("Wolf", 2) - 2 * Config.Combat.WolfCooldownMultiplier) < 1e-9
			and MobDamage.cooldown("Wolf", 2) < 2
			and MobDamage.cooldown("RimeWolverine", 4) == 4
	)
	check(
		"wolf: hit = 20% of target max health with no armor",
		math.abs(MobDamage.toPlayer("Wolf", 10, 100, 0) - 20) < 1e-9
			and math.abs(MobDamage.toPlayer("Wolf", 10, 150, 0) - 30) < 1e-9
	)
	check("non-wolf keeps its row damage", MobDamage.toPlayer("RimeWolverine", 14, 100, 0) == 14)

	-- Armor ---------------------------------------------------------------------------------------------
	local items = ItemCatalog.Items :: any
	items.__ArmorA = { id = "__ArmorA", armor = 0.25 }
	items.__ArmorB = { id = "__ArmorB", armor = 0.25 }
	items.__ArmorC = { id = "__ArmorC", armor = 0.25 }
	check("armor: unknown / unarmored item = 0", MobDamage.reduction({ "Wood", "__Nope" }) == 0)
	check(
		"armor: sums worn pieces",
		math.abs(MobDamage.reduction({ "__ArmorA", "__ArmorB" }) - 0.5) < 1e-9
	)
	check(
		"armor: capped at Config.Armor.MaxReduction",
		MobDamage.reduction({ "__ArmorA", "__ArmorB", "__ArmorC" }) == Config.Armor.MaxReduction
	)
	check(
		"armor: reduces wolf and normal damage, never negative",
		math.abs(MobDamage.toPlayer("Wolf", 10, 100, 0.5) - 10) < 1e-9
			and math.abs(MobDamage.toPlayer("PolarBear", 20, 100, 0.5) - 10) < 1e-9
			and MobDamage.toPlayer("Wolf", 10, 100, 5) >= 0
			and math.abs(
					MobDamage.toPlayer("PolarBear", 20, 100, 5)
						- 20 * (1 - Config.Armor.MaxReduction)
				)
				< 1e-9
	)
	check(
		"armor: equipment inventory sums only worn slots",
		math.abs(MobDamage.reductionOfEquipment({
			size = 3,
			slots = { [1] = { id = "__ArmorA", count = 1 }, [3] = { id = "__ArmorB", count = 1 } },
		}) - 0.5)
				< 1e-9
			and MobDamage.reductionOfEquipment(nil) == 0
	)
	items.__ArmorA, items.__ArmorB, items.__ArmorC = nil, nil, nil

	-- Fire-safe aggro -----------------------------------------------------------------------------------
	check(
		"aggro: wolf and non-horror hostiles are fireSafe; horror and passives are not",
		MobAggro.isFireSafe("Wolf", "hostile", nil, false)
			and MobAggro.isFireSafe("RimeWolverine", "hostile", nil, false)
			and not MobAggro.isFireSafe("SnowLurker", "hostile", nil, false)
			and not MobAggro.isFireSafe("IceWraith", "hostile", nil, false)
			and not MobAggro.isFireSafe("PolarBear", "hostile", nil, true)
			and not MobAggro.isFireSafe("ArcticHare", "animal", nil, false)
			and not MobAggro.isFireSafe("Wolf", "hostile", false, false)
	)
	local function input(over: { [string]: any }): MobAggro.Input
		local base: { [string]: any } = {
			fireSafe = true,
			dist = 30,
			aggroRange = 50,
			targetInFire = false,
			hitRecently = false,
			canSee = true,
		}
		for k, v in over do
			base[k] = v
		end
		return base :: any
	end
	local s0 = MobAggro.new()
	local s1, on1 = MobAggro.step(s0, input({}), 0.2)
	check("aggro: engages a visible target in range", on1 and s1.aggro)
	local _, onFire = MobAggro.step(s0, input({ targetInFire = true }), 0.2)
	check("aggro: never starts on a target inside a fire radius", not onFire)
	local sHit, onHit = MobAggro.step(s0, input({ targetInFire = true, hitRecently = true }), 0.2)
	check("aggro: a target that hit it first may aggro inside the fire", onHit and sHit.aggro)
	local _, stillOn = MobAggro.step(s1, input({}), 0.2)
	local sFire, dropFire = MobAggro.step(s1, input({ targetInFire = true }), 0.2)
	check(
		"aggro: de-aggros when the target steps into a fire",
		stillOn and not dropFire and not sFire.aggro
	)
	local _, leashOn =
		MobAggro.step(s1, input({ dist = A.LeashDistance - 1, aggroRange = 20 }), 0.2)
	local sLeash, leashOff = MobAggro.step(s1, input({ dist = A.LeashDistance + 1 }), 0.2)
	check(
		"aggro: chases to the leash, gives up beyond it",
		leashOn and not leashOff and not sLeash.aggro
	)
	local _, farStart =
		MobAggro.step(s0, input({ dist = A.LeashDistance - 1, aggroRange = 20 }), 0.2)
	check("aggro: no new aggro outside aggro range", not farStart)
	local blind, blindOn = s1, true
	local t = 0.0
	while blindOn and t < A.LoseSightSeconds * 3 do
		blind, blindOn = MobAggro.step(blind, input({ canSee = false }), 0.2)
		t += 0.2
	end
	check(
		"aggro: out of sight for LoseSightSeconds gives up",
		not blindOn and t >= A.LoseSightSeconds - 0.3 and t <= A.LoseSightSeconds + 0.3
	)
	local seen, seenOn = s1, true
	for i = 1, 40 do
		seen, seenOn = MobAggro.step(seen, input({ canSee = i % 5 ~= 0 }), 0.2)
	end
	check("aggro: brief sight loss does not drop it", seenOn)
	local _, plain =
		MobAggro.step(s0, input({ fireSafe = false, targetInFire = true, dist = 500 }), 0.2)
	check("aggro: non-fireSafe mobs are never filtered", plain)
	check(
		"aggro: hit grace window",
		MobAggro.hitRecently(10, 5)
			and not MobAggro.hitRecently(10 + A.HitGraceSeconds, 1)
			and not MobAggro.hitRecently(10, nil)
	)
	check(
		"aggro: fire radius test uses lit fire WarmRadius",
		MobAggro.targetInFire(5, 0, { { x = 0, z = 0, radius = 10 } })
			and not MobAggro.targetInFire(50, 0, { { x = 0, z = 0, radius = 10 } })
	)

	-- Wildlife density, targets, day fire exclusion, replacement ----------------------------------------
	local W = Config.Wildlife
	check(
		"wildlife: day density is DayDensityMultiplier, night full",
		MobWildlife.density(false) == W.DayDensityMultiplier and MobWildlife.density(true) == 1
	)
	local targetsOk = true
	for ring = 0, 3 do
		local tgt = MobWildlife.target(ring)
		targetsOk = targetsOk
			and tgt.min == W.TargetMin[ring + 1]
			and tgt.max == W.TargetMax[ring + 1]
			and tgt.min <= tgt.max
			and MobWildlife.scaledCap(4, false) < MobWildlife.scaledCap(4, true)
	end
	check("wildlife: ring targets; day density scales caps, not targets", targetsOk)
	check(
		"wildlife: attempts 0 at max, urgent under min",
		MobWildlife.attempts(W.TargetMax[1], 0) == 0
			and MobWildlife.attempts(0, 0) == W.UrgentAttempts
			and MobWildlife.attempts(W.TargetMax[1] - 1, 0) >= 1
	)
	local fires = { { x = 0, z = 0, radius = Config.Fire.WarmRadius } }
	check(
		"wildlife: day spawns stay outside fire radii, night rule is left to the hostile rule",
		MobWildlife.dayBlocked(false, 3, 3, fires)
			and not MobWildlife.dayBlocked(false, 500, 0, fires)
			and not MobWildlife.dayBlocked(true, 3, 3, fires)
	)
	local queue: { MobWildlife.Pending } = {}
	local day = 4
	local inRange = true
	for i = 0, 30 do
		local q: { MobWildlife.Pending } = {}
		MobWildlife.schedule(q, "ArcticHare", day, i / 31)
		local due = q[1].dueDay - day
		inRange = inRange and due >= W.RespawnDays[1] and due <= W.RespawnDays[2]
	end
	check("respawn: replacement due RespawnDays after the kill (by day counter)", inRange)
	MobWildlife.schedule(queue, "Caribou", 5, 0)
	MobWildlife.schedule(queue, "ArcticHare", 5, 0.999)
	check(
		"respawn: not due early, then due, removed once placed",
		MobWildlife.nextDue(queue, 5) == nil
			and MobWildlife.nextDue(queue, 5 + W.RespawnDays[1]) ~= nil
			and (function()
				local entry = MobWildlife.nextDue(queue, 5 + W.RespawnDays[2])
				if not entry then
					return false
				end
				MobWildlife.remove(queue, entry)
				return #queue == 1
			end)()
	)
	check(
		"respawn: only animals are replaced (no hostiles, ambient or bosses)",
		MobWildlife.replaces("passive", "animal")
			and MobWildlife.replaces("neutral", "animal")
			and not MobWildlife.replaces("ambient", "animal")
			and not MobWildlife.replaces("hostile", "hostile")
			and not MobWildlife.replaces("passive", "boss")
	)
	check(
		"respawn: point must be RespawnMinPlayerDistance from every player",
		not MobWildlife.respawnPointOk({ W.RespawnMinPlayerDistance - 1, 120 })
			and MobWildlife.respawnPointOk({ Config.Mobs.SpawnMaxDistance - 5 })
	)

	-- Spawn picker audit: fill level per ring (day and night), species presence, caps, parts ---------------
	local SEEDS = 24
	local TICKS = 120
	local presence: { [string]: number } = {}
	local fillOk, minOk, capOk, partsOk, varietyOk = true, true, true, true, true
	for ring = 0, 3 do
		for _, danger in { true, false } do
			local sumTotal, newSpecies = 0, 0
			for seed = 1, SEEDS do
				local live, total = MobSpawnPick.simulate({
					ring = ring,
					day = 6,
					danger = danger,
					ticks = TICKS,
					failChance = 0.5,
					rand = lcg(seed * 7919 + ring * 31),
					limits = true,
				})
				local target = MobWildlife.target(ring)
				fillOk = fillOk
					and total <= target.max + (Config.Mobs.Species.ScrapHound.packSize or 1)
				minOk = minOk and total >= target.min
				sumTotal += total
				local parts, kinds = 0, 0
				for name, n in live do
					capOk = capOk and n <= MobSpawnPick.cap(name, danger, true)
					local def = Config.Mobs.Species[name]
					if def then
						parts += def.partCap * n
						kinds += 1
						presence[name] = (presence[name] or 0) + 1
					end
				end
				partsOk = partsOk and parts <= Config.Mobs.Spawning.MaxMobParts
				newSpecies += kinds
			end
			-- At least one species-of-the-8 on average in every ring and time of day.
			varietyOk = varietyOk and newSpecies / SEEDS >= 1.5
		end
	end
	check("spawn audit: fills to the ring target (never past max + one pack)", fillOk)
	check("spawn audit: reaches the ring minimum in every ring, day and night", minOk)
	check("spawn audit: per-kind caps hold", capOk)
	check("spawn audit: species parts stay under Spawning.MaxMobParts", partsOk)
	check("spawn audit: the new species make up most of the mix", varietyOk)
	local allSeen = true
	for _, id in Config.Mobs.SpeciesIds do
		allSeen = allSeen and (presence[id] or 0) > 0
	end
	check("spawn audit: all 8 new species appear across rings", allSeen)
	local _, nightTotal = MobSpawnPick.simulate({
		ring = 3,
		day = 8,
		danger = true,
		ticks = 400,
		failChance = 0,
		rand = lcg(5),
		limits = true,
	})
	check("spawn audit: total stays under MaxLiveMobs", nightTotal <= Config.Scaling.MaxLiveMobs)
	local legacyEntries = MobSpawnPick.legacyEntries()
	local hasCore = 0
	for _, e in legacyEntries do
		if e.kind == "ArcticHare" or e.kind == "Caribou" or e.kind == "Wolf" then
			hasCore += 1
		end
	end
	check("spawn audit: legacy rows keep hare, caribou and wolf", hasCore == 3)

	-- Frost Brute poise ---------------------------------------------------------------------------------
	check(
		"poise: brute is heavy, wolf and hound are not",
		MobPoise.isHeavy("FrostboundBrute") and not MobPoise.isHeavy("Wolf")
	)
	check(
		"poise: heavy hits never cancel the telegraph; others may",
		not MobPoise.hitCancelsTelegraph(true) and MobPoise.hitCancelsTelegraph(false)
	)
	check(
		"poise: flinch only between heavy attacks",
		not MobPoise.flinchAllowed(true, true, false)
			and not MobPoise.flinchAllowed(true, false, true)
			and MobPoise.flinchAllowed(true, false, false)
			and MobPoise.flinchAllowed(false, true, false)
	)
	check(
		"poise: Hurt cannot replace Telegraph or Attack on a heavy mob",
		MobPoise.resolveState("Windup", 0.3, 0, true) == "Telegraph"
			and MobPoise.resolveState("Chase", 0.3, 0.2, true) == "Attack"
			and MobPoise.resolveState("Chase", 0.3, 0, true) == "Hurt"
			and MobPoise.resolveState("Windup", 0.3, 0, false) == "Hurt"
	)
	-- A hit stream during the telegraph: the Telegraph machine (the Brute's timer) is untouched by hits, so
	-- the slam lands on schedule while every replicated State read during the wind-up stays Telegraph.
	local Telegraph = MobBehaviors.Telegraph
	local brute = Config.Mobs.Species.FrostboundBrute
	local tele = Telegraph.new()
	local strikeAt, elapsed, stateOk = -1.0, 0.0, true
	local dt = 0.2
	for _ = 1, 20 do
		local newTele, out = Telegraph.step(
			tele,
			{ ready = true, inReach = true, seconds = brute.telegraphSeconds },
			dt
		)
		tele = newTele
		elapsed += dt
		if out.event == "Start" or out.event == "Wait" then
			stateOk = stateOk and MobPoise.resolveState("Windup", 0.35, 0, true) == "Telegraph"
		elseif out.event == "Strike" then
			strikeAt = elapsed
			break
		end
	end
	check(
		"poise: brute telegraph under a hit stream strikes on schedule",
		stateOk and strikeAt > 0 and math.abs(strikeAt - brute.telegraphSeconds) <= 2 * dt + 1e-6
	)

	-- Display names -------------------------------------------------------------------------------------
	check(
		"names: PascalCase ids split into words",
		MobNames.display("RimeWolverine") == "Rime Wolverine"
			and MobNames.display("FrostboundBrute") == "Frostbound Brute"
			and MobNames.display("SnowGrouse") == "Snow Grouse"
			and MobNames.display("AuroraWisp") == "Aurora Wisp"
	)
	check(
		"names: override table wins, single words unchanged",
		MobNames.display("ArcticHare") == "Hare" and MobNames.display("Wolf") == "Wolf"
	)
	local namesOk = true
	for _, id in Config.Mobs.SpeciesIds do
		namesOk = namesOk and not string.find(MobNames.display(id), "%l%u")
	end
	check("names: no species shows its raw id", namesOk)
end
