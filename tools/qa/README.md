# tools/qa
One self-contained snippet per system: `tools/qa/<system>.luau`, run in one MCP call during Play (local player, start_play), printing `PASS name` / `FAIL name: reason` lines. No helper code written through MCP. Target <10K tokens per playtest.

Load-failure hook (Studio only): set ReplicatedStorage attribute QAForceLoadFailure = "data" (before the player's profile loads) or "spawn" (at runtime, then kill the character) to force the LoadFailed path with no src edit. Expect Player attribute LoadFailed=true, the client message, and a kick after ~1s.

Scenario runner: tools/qa/runner.luau runs a SCENARIOS list (one function per scenario) and prints at most 8 lines per scenario as `PASS scenario/check` or `FAIL scenario/check: reason` (FAILs first; extra passes collapse into one summary line). Add a scenario by appending to SCENARIOS. Built-in: debug (DebugService via the QA bridge, Studio only).

Scenario day3-solo: tools/qa/day3-solo.luau (runner style, 8 lines): spawn at camp, gather wood, fuel the camp fire, craft + place a workbench, 3 days at clockSpeed, wolf retreats at the fire edge. MCP code runs in a separate VM (fresh module copies), so QA reaches live services through DebugService's Studio-only bridge (ServerStorage[Config.Debug.BridgeName]:Invoke(service, fn, ...)). The older runner.luau debug scenario still requires modules directly and should move to the bridge.

Scenario build-range: tools/qa/build-range.luau (CLIENT datamodel, fresh run, 9 lines): bench refused beyond / allowed within the tier-1 build radius, Spear refused away from the bench (raw CraftRequest) and allowed at it, "craft" context action at the bench, upgrade prompt shows cost, upgrade raises Tier/WarmRadius/BuildRadius/LightRange, a bench placed beyond the old radius now works, WarmRadius attribute follows the tier.

Scenario player-path: tools/qa/player-path.luau runs on the CLIENT datamodel (execute_luau datamodel_type Client, local player). It drives the real HUD input handlers through the Studio-only client bridge (PlayerScripts[Config.Debug.ClientBridgeName]:Invoke(fn, ...)) and tops up materials / spawns a hare with the Studio-only DebugCommand remote (give, spawnMob). Checks: select_axe, prompt_tool, chop, craft_campfire, place_campfire, add_wood, catch_hare, eat, onboarding_done (<= 10 lines).

Scenario night-danger: tools/qa/night-danger.luau (runner style, server datamodel, <= 10 lines): force night via clockSpeed, wolf near an exposed player outside the camp fire -> Windup attribute then bite (BiteSeq + health drop) -> player shelters, wolf never within the fire's WarmRadius -> dawn, wolf leaves and despawns. Needs the Studio QA bridge services Chunk, Mobs, Debug.
