--!strict
-- Headless tests: input gate (typing blocks hotkeys), ground correction, tool durability across drop/pickup.

local Inventory = require("../src/shared/logic/Inventory")
local InventoryMove = require("../src/shared/logic/InventoryMove")
local InputGate = require("../src/shared/logic/InputGate")
local GroundFix = require("../src/shared/logic/GroundFix")

return function(check: (string, boolean) -> ())
	check("input: free key passes", not InputGate.blocked(false, false))
	check("input: engine-processed blocked", InputGate.blocked(true, false))
	check("input: focused textbox blocks hotkeys", InputGate.blocked(false, true))

	check("ground: on surface needs no fix", GroundFix.correction(10, 10.1, 0.25) == nil)
	check("ground: buried part is lifted", GroundFix.correction(8, 10, 0.25) == 2)
	check("ground: floating part is lowered", GroundFix.correction(12, 10, 0.25) == -2)
	check("ground: lowering is clamped", GroundFix.clampedCorrection(30, 10, 0.25, 5) == -5)
	check("ground: lift not clamped", GroundFix.clampedCorrection(8, 10, 0.25, 5) == 2)

	local inv = Inventory.new(10)
	inv.slots[2] = { id = "Axe", count = 1, durability = 17 }
	local ok, _, id, n, dur = InventoryMove.drop(inv, 2, 1)
	check("drop: tool durability is carried", ok and id == "Axe" and n == 1 and dur == 17)
	local left = Inventory.add(inv, id :: string, n, 1, dur)
	local stack = inv.slots[1]
	check("pickup: durability restored", left == 0 and stack ~= nil and stack.durability == 17)
end
