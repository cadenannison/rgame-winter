--!strict
-- Tests for the client UX pure logic: onboarding chain, hotbar wheel, craft panel status, flee bursts,
-- and the catchability tuning (prey slower than the player, generous reach).

local Config = require("../src/shared/Config")
local Onboarding = require("../src/shared/logic/Onboarding")
local HudMath = require("../src/shared/logic/HudMath")
local Crafting = require("../src/shared/logic/Crafting")
local MobAI = require("../src/shared/logic/MobAI")

return function(check: (string, boolean) -> ())
	-- Onboarding: first not-done step shows; early actions are not asked again; finishes.
	local done: Onboarding.Done = {}
	check("onboarding starts at equipAxe", Onboarding.current(done) == "equipAxe")
	check("onboarding early eat counts", Onboarding.complete(done, "eat"))
	check("onboarding unknown step ignored", not Onboarding.complete(done, "fly"))
	check("onboarding still at equipAxe", Onboarding.current(done) == "equipAxe")
	Onboarding.complete(done, "equipAxe")
	check("onboarding advances to chop", Onboarding.current(done) == "chop")
	check("onboarding repeat is no-op", not Onboarding.complete(done, "equipAxe"))
	for _, id in Onboarding.STEPS do
		Onboarding.complete(done, id)
	end
	check("onboarding finished", Onboarding.finished(done) and Onboarding.current(done) == nil)

	-- Hotbar wheel wraps.
	check("wheel forward", HudMath.cycleSlot(1, 1, 9) == 2)
	check("wheel wraps forward", HudMath.cycleSlot(9, 1, 9) == 1)
	check("wheel wraps back", HudMath.cycleSlot(1, -1, 9) == 9)
	check("hotbar has 9 slots for keys 1-9", Config.Inventory.HotbarSize == 9)

	-- Craft panel status from counts.
	check("craft status missing", Crafting.status({}, "Campfire", {}) == "MissingMaterials")
	check("craft status ok", Crafting.status({ Wood = 5, Stone = 2 }, "Campfire", {}) == "Ok")
	check(
		"craft status needs workbench",
		Crafting.status({ Wood = 9, Stone = 9 }, "Spear", {}) == "NeedStation"
	)
	local list = Crafting.listForTier(Config.Craft.MaxTier)
	check(
		"craft list has tier 0 and 1",
		table.find(list, "Campfire") ~= nil and table.find(list, "Spear") ~= nil
	)
	check("craft list tier-sorted", list[#list] == "Spear")

	-- Flee bursts: sprint, rest, sprint.
	local b: MobAI.Burst = { burstEnd = 0, restEnd = 0 }
	check("burst starts moving", MobAI.fleeBurst(b, 0, 1, 2))
	check("burst moving mid sprint", MobAI.fleeBurst(b, 0.5, 1, 2))
	check("burst rests after sprint", not MobAI.fleeBurst(b, 1.1, 1, 2))
	check("burst still resting", not MobAI.fleeBurst(b, 2.5, 1, 2))
	check("burst sprints after rest", MobAI.fleeBurst(b, 3.2, 1, 2))
	check(
		"burst no rest config always moves",
		MobAI.fleeBurst({ burstEnd = 0, restEnd = 0 }, 9, 1, 0)
	)

	-- Catchability tuning: prey flee slower than the player walks and pause between sprints.
	for _, prey in { Config.Mobs.Hare, Config.Mobs.Caribou } do
		check("prey flee below walk speed", prey.FleeSpeed < Config.WALK_SPEED)
		check("prey pauses", prey.FleeRestSeconds > 0 and prey.FleeBurstSeconds > 0)
		check(
			"prey reach exceeds client pick range",
			Config.Combat.MeleeRange + prey.HitRadius >= Config.Feedback.PromptRange
		)
	end
	check("axe one-shots a day-1 hare", Config.Combat.ToolDamage >= Config.Mobs.Hare.Health)
end
