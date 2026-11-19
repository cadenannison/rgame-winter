--!strict
-- Headless tests for pure logic in src/shared/logic. Run: lune run tests/run [-- --verbose]

local Clamp = require("../src/shared/logic/Clamp")
local NumberFormat = require("../src/shared/logic/NumberFormat")

-- Lune-only module; indirect so luau-analyze (no lune definitions) does not resolve it.
local lunePath = "@lune/process"
local lune: (string) -> any = require :: any
local verbose = table.find(lune(lunePath).args, "--verbose") ~= nil
local failures = 0
local passes = 0

local function check(name: string, ok: boolean)
	if ok then
		passes += 1
		if verbose then
			print(`ok   {name}`)
		end
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
require("./TerrainContractTests")(check)
require("./TerrainTests")(check)
require("./SurvivalTests")(check)
require("./ForageTests")(check)
require("./ItemTests")(check)
require("./MobTests")(check)
require("./MobSpeciesTests")(check) -- Art Pass 3: species behaviors, ring weights, drops, dread
require("./NightTests")(check)
require("./PlacementTests")(check)
require("./ConsumeTests")(check)
require("./FlowTests")(check)
require("./PlayabilityTests")(check)
require("./TeleportTests")(check)
require("./RunTests")(check)
require("./DownedTests")(check) -- death/downed/revive (round: death)
require("./DeathPanelTests")(check)
require("./PadTests")(check)
require("./LobbyTests")(check)
require("./DataTests")(check) -- brief 12 (Phase 3 data)
require("./BiomeTests")(check) -- brief 13
require("./EventTests")(check) -- brief 14
require("./HorrorTests")(check) -- brief 15
require("./GearTests")(check) -- Art Pass 4: worn gear plan
require("./ProgressionTests")(check) -- brief 17 (brief 16 uses MobTests)
require("./MetaTests")(check) -- brief 21 (Phase 4 contract data)
require("./MetaLogicTests")(check) -- brief 19
require("./AtmosphereTests")(check) -- brief 20
require("./LivePartsTests")(check)
require("./PoiTests")(check) -- agent C enterable structures
require("./WorldSessionTests")(check) -- tp resolver, camp grounding, moonlight
require("./LootTests")(check) -- contracts round: loot, massive structures, trees
require("./ChestTests")(check) -- chest looks and loot-only gear (agent I)
require("./LootServiceTests")(check) -- loot server (agent H)
require("./StructureBTests")(check) -- massive structures B (agent K)
require("./StructureATests")(check) -- massive structures A (agent J)
require("./MassiveWiringTests")(check) -- integration: massive placement + chunk hooks
require("./SiteGroundTests")(check) -- items round: terrain grounding (agent A)
require("./ChestCountsTests")(check) -- items round: chest counts, beacon top rarity, beams (agent A)
require("./InventoryTests")(check) -- items round: move path, stacks, chests, migration (agent B)
require("./SlotViewTests")(check) -- backpack slot view-model
require("./EconomyCraftTests")(check)
require("./BlizzardDebugTests")(check)
require("./ReturnPlanTests")(check)
require("./AgentATests")(check)
require("./ItemModelsCoverage")(check) -- Art Pass 4: item model recipes, tooltips, backpack header layout
require("./SlotLayoutTests")(check) -- slot layout: areas, strict move validation, end-to-end mapping, rescue
require("./EquipmentTests")(check) -- items round: equipment slots and worn resistance (agent B)
require("./BlizzardTests")(check) -- blizzard rework: wind, whiteout, duration
require("./InputGroundTests")(check) -- bug-fix round: input gate, ground fix, drop durability
require("./AnimKitTests")(check) -- art pass 3: creature pose math
require("./CreatureFxTests")(check) -- art pass 3 (creature fx helpers)
require("./BugfixRoundTests")(check) -- bug-fix round: fuel, forage respawn, rope, payouts, budgets
require("./DebugParseTests")(check) -- bug-fix round: every /debug command through the parser

print(`tests: {passes} passed, {failures} failed`)
if failures > 0 then
	error(`{failures} test(s) failed`)
end
