--!strict
-- Pure poise rules (no Roblox APIs). Heavy mobs (Config.Poise.HeavyMobs, e.g. the Frost Brute) are never
-- staggered out of a telegraph or slam: hits only play a flinch, and only between attacks. Non-heavy mobs
-- keep the plain Hurt precedence of MobStateMap.

local Config = require("../Config")
local MobStateMap = require("./MobStateMap")

local MobPoise = {}

function MobPoise.isHeavy(kindName: string): boolean
	return table.find(Config.Poise.HeavyMobs, kindName) ~= nil
end

-- A hit may show the flinch (Hurt state) now. winding = telegraph in progress; attacking = strike hold.
function MobPoise.flinchAllowed(heavy: boolean, winding: boolean, attacking: boolean): boolean
	if not heavy or not Config.Poise.StaggerOnlyBetweenAttacks then
		return true
	end
	return not (winding or attacking)
end

-- A hit may reset or cancel the telegraph / slam timer. Never for heavy mobs.
function MobPoise.hitCancelsTelegraph(heavy: boolean): boolean
	return not heavy
end

-- Final replicated State: like MobStateMap.resolve, but a heavy mob mid-telegraph or mid-strike ignores Hurt.
function MobPoise.resolveState(
	action: string?,
	hurtLeft: number,
	attackLeft: number,
	heavy: boolean
): string
	local winding = MobStateMap.stateFor(action) == "Telegraph"
	if hurtLeft > 0 and not MobPoise.flinchAllowed(heavy, winding, attackLeft > 0) then
		hurtLeft = 0
	end
	return MobStateMap.resolve(action, hurtLeft, attackLeft, false)
end

return MobPoise
