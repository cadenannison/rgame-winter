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
require("./WorldTests")(check)
require("./SurvivalTests")(check)
require("./ItemTests")(check)
require("./MobTests")(check)
require("./NightTests")(check)
require("./PlacementTests")(check)
require("./ConsumeTests")(check)
require("./FlowTests")(check)
require("./PlayabilityTests")(check)
require("./TeleportTests")(check)
require("./RunTests")(check)
require("./PadTests")(check)
require("./LobbyTests")(check)
require("./DataTests")(check) -- brief 12 (Phase 3 data)
require("./BiomeTests")(check) -- brief 13
require("./EventTests")(check) -- brief 14
require("./HorrorTests")(check) -- brief 15
require("./ProgressionTests")(check) -- brief 17 (brief 16 uses MobTests)
require("./MetaTests")(check) -- brief 21 (Phase 4 contract data)
require("./MetaLogicTests")(check) -- brief 19
require("./AtmosphereTests")(check) -- brief 20
require("./LivePartsTests")(check)

if failures > 0 then
	error(`{failures} test(s) failed`)
end
