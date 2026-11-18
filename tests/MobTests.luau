--!strict

local MobAI = require("../src/shared/logic/MobAI")
local MobRules = require("../src/shared/logic/MobRules")
local MobScaling = require("../src/shared/logic/MobScaling")
local Projectile = require("../src/shared/logic/Projectile")
local Config = require("../src/shared/Config")
local Mobs = require("../src/shared/data/Mobs")

local function input(overrides: { [string]: any }): MobAI.Input
	local base: { [string]: any } = {
		behavior = "Hunt",
		nearestPlayerDist = 20,
		isNight = true,
		nightOnly = true,
		fleeRange = 0,
		aggroRange = 50,
		attackRange = 4,
		inFireRepel = false,
		canAttack = true,
	}
	for k, v in overrides do
		base[k] = v
	end
	return base :: any
end

return function(check: (string, boolean) -> ())
	-- Activation: no AI without a nearby player
	local mobs = { { x = 0, z = 0 }, { x = 500, z = 0 } }
	check("mob ai: no players -> none active", #MobRules.selectActive(mobs, {}, 200) == 0)
	check(
		"mob ai: far player -> none active",
		#MobRules.selectActive(mobs, { { x = 1000, z = 1000 } }, 200) == 0
	)
	local act = MobRules.selectActive(mobs, { { x = 10, z = 0 } }, 200)
	check("mob ai: near player activates only near mob", #act == 1 and act[1] == 1)
	check("mob despawn: no player", MobRules.shouldDespawn(nil, 260))
	check("mob despawn: far", MobRules.shouldDespawn(300, 260))
	check("mob despawn: near keeps", not MobRules.shouldDespawn(100, 260))

	-- Decisions
	check(
		"hare flees near player",
		MobAI.decide(input({ behavior = "Flee", nightOnly = false, fleeRange = 30 })) == "Flee"
	)
	check(
		"hare wanders when far",
		MobAI.decide(
			input({ behavior = "Flee", nightOnly = false, fleeRange = 30, nearestPlayerDist = 90 })
		) == "Wander"
	)
	check("wolf chases at night", MobAI.decide(input({})) == "Chase")
	check("wolf attacks in range", MobAI.decide(input({ nearestPlayerDist = 3 })) == "Attack")
	check(
		"wolf chases while on cooldown",
		MobAI.decide(input({ nearestPlayerDist = 3, canAttack = false })) == "Chase"
	)
	check("wolf leaves by day", MobAI.decide(input({ isNight = false })) == "Leave")
	check("wolf ignores far player", MobAI.decide(input({ nearestPlayerDist = 80 })) == "Wander")
	check(
		"wolf retreats at fire edge",
		MobAI.decide(input({ inFireRepel = true, nearestPlayerDist = 3 })) == "Retreat"
	)

	-- Rules
	check("scaled stat day 1 = base", MobRules.scaledStat(10, 0.04, 1, 4) == 10)
	check("scaled stat capped", MobRules.scaledStat(10, 0.5, 1000, 4) == 40)
	check("budget zero without players", MobRules.budget(12, 1, 0, false, 0.05, 0.35, 1.5, 4) == 0)
	check("budget base solo day", MobRules.budget(12, 1, 1, false, 0.05, 0.35, 1.5, 4) == 12)
	check("budget night bigger", MobRules.budget(12, 1, 1, true, 0.05, 0.35, 1.5, 4) == 18)
	check("budget party bigger", MobRules.budget(12, 1, 2, false, 0.05, 0.35, 1.5, 4) > 12)
	check("budget capped scale", MobRules.budget(10, 10000, 1, false, 0.05, 0, 1, 4) == 40)
	check("pickWeighted low roll", MobRules.pickWeighted({ 5, 2, 3 }, 0) == 1)
	check("pickWeighted high roll", MobRules.pickWeighted({ 5, 2, 3 }, 0.99) == 3)
	check("pickWeighted empty", MobRules.pickWeighted({ 0 }, 0.5) == nil)
	check("spawn ok", MobRules.spawnDistanceOk({ 100, 300 }, 60, 160))
	check("spawn too close", not MobRules.spawnDistanceOk({ 30, 300 }, 60, 160))
	check("spawn too far", not MobRules.spawnDistanceOk({ 200 }, 60, 160))
	check("melee in range", MobRules.canMelee(9, 7, 3))
	check("melee out of range", not MobRules.canMelee(11, 7, 3))
	check("melee nan rejected", not MobRules.canMelee(0 / 0, 7, 3))

	-- Brief 16: scaling caps, budget, spawn tables, bosses, projectiles
	local S = Config.Scaling
	local B = Config.Bosses
	local m1 = MobScaling.multipliers(1, 0, 1)
	check(
		"scaling: day1 ring0 solo is neutral",
		m1.budget == 1 and m1.health == 1 and m1.damage == 1
	)
	local mBig = MobScaling.multipliers(100000, 100, 100)
	check(
		"scaling: budget capped",
		mBig.budget
			<= S.MaxMobBudgetMultiplier
					* S.MaxRingBudgetMultiplier
					* S.MaxPartyBudgetMultiplier
				+ 1e-9
	)
	check(
		"scaling: health capped",
		mBig.health
			<= S.MaxMobHealthMultiplier
					* S.MaxRingHealthMultiplier
					* S.MaxPartyHealthMultiplier
				+ 1e-9
	)
	check(
		"scaling: damage capped",
		mBig.damage <= S.MaxMobDamageMultiplier * S.MaxRingDamageMultiplier + 1e-9
	)
	check(
		"scaling: monotonic by day, ring, party",
		MobScaling.multipliers(5, 0, 1).budget > m1.budget
			and MobScaling.multipliers(1, 2, 1).health > m1.health
			and MobScaling.multipliers(1, 0, 4).budget > m1.budget
	)
	check(
		"scaling: solo party gets no party bonus",
		MobScaling.multipliers(1, 0, 1).budget == MobScaling.multipliers(1, 0, 0).budget
	)
	check(
		"budget: MaxLiveMobs hard cap",
		MobScaling.liveBudget(1000, mBig, 6, true, 1.5) == S.MaxLiveMobs
	)
	check("budget: no players -> 0", MobScaling.liveBudget(12, m1, 0, true, 1.5) == 0)
	check("budget: night bigger", MobScaling.liveBudget(12, m1, 1, true, 1.5) == 18)

	-- Spawn tables: deterministic, biome/day/danger gated, no bosses, no Stalker
	local entries: { MobScaling.Entry } = {}
	for _, def in Mobs.List do
		table.insert(entries, {
			kind = def.kind,
			category = def.category,
			biomes = def.biomes,
			minDay = def.minDay,
			nightOnly = def.nightOnly,
			weight = def.weight,
		})
	end
	local function kinds(rows: { MobScaling.Row }): string
		local names = {}
		for _, r in rows do
			table.insert(names, r.kind)
		end
		return table.concat(names, ",")
	end
	check(
		"spawn table: deterministic",
		kinds(MobScaling.spawnTable(entries, "MountainsCaves", 5, true))
			== kinds(MobScaling.spawnTable(entries, "MountainsCaves", 5, true))
	)
	check(
		"spawn table: cave day has crawler only",
		kinds(MobScaling.spawnTable(entries, "MountainsCaves", 5, false)) == "CaveCrawler"
	)
	check(
		"spawn table: night adds bear and wraith in caves",
		kinds(MobScaling.spawnTable(entries, "MountainsCaves", 5, true))
			== "PolarBear,IceWraith,CaveCrawler"
	)
	check(
		"spawn table: day gate (bear needs day 2)",
		kinds(MobScaling.spawnTable(entries, "FrozenLake", 1, true)) == "Fish"
	)
	local noBoss = true
	for _, biome in { "SnowyForest", "FrozenLake", "MountainsCaves", "DeepTundra" } do
		for _, row in MobScaling.spawnTable(entries, biome, 99, true) do
			local def = Mobs.ByKind[row.kind]
			if def.category == "miniboss" or def.category == "boss" then
				noBoss = false
			end
		end
	end
	check("spawn table: bosses never in the normal budget", noBoss)

	-- Bosses
	local warden = Mobs.ByKind.IceWarden
	check("boss: solo health is base", MobScaling.bossHealth(warden.health, 1) == warden.health)
	check(
		"boss: health capped",
		MobScaling.bossHealth(warden.health, 1000) == warden.health * B.MaxHealthMultiplier
	)
	check(
		"boss: damage capped",
		MobScaling.bossDamage(warden.damage, 100000) == warden.damage * B.MaxDamageMultiplier
	)
	check(
		"boss: blizzard chance zero early",
		MobScaling.blizzardBossChance(B.BlizzardBossFirstDay - 1) == 0
	)
	check(
		"boss: blizzard chance capped",
		MobScaling.blizzardBossChance(100000) == B.MaxBlizzardBossChance
	)
	check(
		"boss: mini-boss not before first day",
		not MobScaling.miniBossDue(1, B.MiniBossFirstDay - 1, 0, nil)
	)
	check("boss: mini-boss due later", MobScaling.miniBossDue(6, 9, 0, nil))
	check("boss: mini-boss alive cap", not MobScaling.miniBossDue(6, 9, B.MiniBossMaxAlive, nil))
	check(
		"boss: mini-boss respawn cooldown",
		not MobScaling.miniBossDue(6, 9, 0, 9 - B.MiniBossRespawnDays + 1)
			and MobScaling.miniBossDue(6, 9, 0, 9 - B.MiniBossRespawnDays)
	)
	local bosses = 0
	local minis = 0
	local killable = true
	for _, def in Mobs.List do
		if def.category == "boss" then
			bosses += 1
		elseif def.category == "miniboss" then
			minis += 1
		end
		if def.health <= 0 then
			killable = false
		end
	end
	check("boss: 3 mini-boss kinds and 1 blizzard boss", minis == 3 and bosses == 1)
	check("boss: all mobs killable, Stalker absent", killable and Mobs.ByKind.Stalker == nil)

	-- Fairness: prey is catchable, melee reach bounded, ambusher telegraphs
	local fair = true
	for _, def in Mobs.List do
		if def.category == "animal" and def.fleeSpeed >= Config.WALK_SPEED then
			fair = false
		end
		if def.category ~= "animal" and def.attackRange > 12 and not def.ranged then
			fair = false
		end
	end
	check("fairness: prey flee speed below walk speed", fair)
	check("fairness: ambusher aggro range is short", Mobs.ByKind.SnowLurker.aggroRange <= 20)

	-- Projectiles
	check(
		"projectile: nan direction rejected",
		Projectile.cleanDirection({ x = 0 / 0, y = 0, z = 1 }) == nil
	)
	check(
		"projectile: zero direction rejected",
		Projectile.cleanDirection({ x = 0, y = 0, z = 0 }) == nil
	)
	check(
		"projectile: huge direction rejected",
		Projectile.cleanDirection({ x = 50, y = 0, z = 0 }) == nil
	)
	local clean = Projectile.cleanDirection({ x = 1.2, y = 0, z = 0 })
	check("projectile: direction normalized", clean ~= nil and math.abs(clean.x - 1) < 1e-9)
	check(
		"projectile: friendly fire is reduced",
		Projectile.playerDamage(14, Config.Projectile.FriendlyFireMultiplier) < 14
			and Config.Projectile.MeleeFriendlyFire == false
	)
	local assisted = Projectile.aimAssist(
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 1 },
		{ { x = 2, y = 0, z = 30 } },
		Config.Projectile.AimAssistDegrees
	)
	check("projectile: aim assist nudges toward near target", assisted.x > 0)
	local ignored = Projectile.aimAssist(
		{ x = 0, y = 0, z = 0 },
		{ x = 0, y = 0, z = 1 },
		{ { x = 30, y = 0, z = 30 } },
		Config.Projectile.AimAssistDegrees
	)
	check("projectile: aim assist ignores far-off targets", ignored.x == 0)
	check(
		"projectile: active cap",
		not Projectile.canFire(
			Config.Projectile.MaxActivePerPlayer,
			Config.Projectile.MaxActivePerPlayer
		)
	)
end
