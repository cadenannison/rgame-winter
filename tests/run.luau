--!strict
-- Headless tests for pure logic in src/shared/logic. Run: lune run tests/run

local Clamp = require("../src/shared/logic/Clamp")
local NumberFormat = require("../src/shared/logic/NumberFormat")

local failures = 0

local function check(name: string, ok: boolean)
	if ok then
		print(`ok   {name}`)
	else
		failures += 1
		print(`FAIL {name}`)
	end
end

check("clamp below", Clamp.clamp(-5, 0, 10) == 0)
check("clamp above", Clamp.clamp(50, 0, 10) == 10)
check("clamp inside", Clamp.clamp(5, 0, 10) == 5)
check("format small", NumberFormat.format(999) == "999")
check("format thousand", NumberFormat.format(1500) == "1.5K")

require("./ProfileTests")(check)
require("./SimTests")(check)

if failures > 0 then
	error(`{failures} test(s) failed`)
end
