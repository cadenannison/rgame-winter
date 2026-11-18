--!strict
-- Index of the pure mob behavior state machines (contract: docs/CREATURES_CONTRACT.md).
local Prey = require("./MobBehaviorsFlee")
local Combat = require("./MobBehaviorsCombat")
local Ambient = require("./MobBehaviorsAmbient")

return {
	Flee = Prey.Flee,
	ReturnAfterFlee = Prey.ReturnAfterFlee,
	Retaliate = Combat.Retaliate,
	TerritorialWarn = Combat.TerritorialWarn,
	HerdAlert = Combat.HerdAlert,
	Telegraph = Combat.Telegraph,
	PackFlank = Combat.PackFlank,
	Circle = Ambient.Circle,
	Lure = Ambient.Lure,
}
