--!strict

local MobAI = require("../src/shared/logic/MobAI")
local MobRules = require("../src/shared/logic/MobRules")

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
	check("wolf passive by day", MobAI.decide(input({ isNight = false })) == "Wander")
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
end
