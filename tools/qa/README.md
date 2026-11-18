# tools/qa
One self-contained snippet per system: `tools/qa/<system>.luau`, run in one MCP call during Play (local player, start_play), printing `PASS name` / `FAIL name: reason` lines. No helper code written through MCP. Target <10K tokens per playtest.

Load-failure hook (Studio only): set ReplicatedStorage attribute QAForceLoadFailure = "data" (before the player's profile loads) or "spawn" (at runtime, then kill the character) to force the LoadFailed path with no src edit. Expect Player attribute LoadFailed=true, the client message, and a kick after ~1s.

Scenario runner: tools/qa/runner.luau runs a SCENARIOS list (one function per scenario) and prints at most 8 lines per scenario as `PASS scenario/check` or `FAIL scenario/check: reason` (FAILs first; extra passes collapse into one summary line). Add a scenario by appending to SCENARIOS. Built-in: debug (DebugService via the QA bridge, Studio only).

Scenario day3-solo: tools/qa/day3-solo.luau (runner style, 8 lines): spawn at camp, gather wood, fuel the camp fire, craft + place a workbench, 3 days at clockSpeed, wolf retreats at the fire edge. MCP code runs in a separate VM (fresh module copies), so QA reaches live services through DebugService's Studio-only bridge (ServerStorage[Config.Debug.BridgeName]:Invoke(service, fn, ...)). The older runner.luau debug scenario still requires modules directly and should move to the bridge.

Scenario build-range: tools/qa/build-range.luau (CLIENT datamodel, fresh run, 9 lines): bench refused beyond / allowed within the tier-1 build radius, Spear refused away from the bench (raw CraftRequest) and allowed at it, "craft" context action at the bench, upgrade prompt shows cost, upgrade raises Tier/WarmRadius/BuildRadius/LightRange, a bench placed beyond the old radius now works, WarmRadius attribute follows the tier.

Scenario player-path: tools/qa/player-path.luau runs on the CLIENT datamodel (execute_luau datamodel_type Client, local player). It drives the real HUD input handlers through the Studio-only client bridge (PlayerScripts[Config.Debug.ClientBridgeName]:Invoke(fn, ...)) and tops up materials / spawns a hare with the Studio-only DebugCommand remote (give, spawnMob). Checks: select_axe, prompt_tool, chop, craft_campfire, place_campfire, add_wood, catch_hare, eat, onboarding_done (<= 10 lines).

Scenario night-danger: tools/qa/night-danger.luau (runner style, server datamodel, <= 10 lines): force night via clockSpeed, wolf near an exposed player outside the camp fire -> Windup attribute then bite (BiteSeq + health drop) -> player shelters, wolf never within the fire's WarmRadius -> dawn, wolf leaves and despawns. Needs the Studio QA bridge services Chunk, Mobs, Debug.

Scenario placement-preview: tools/qa/placement-preview.luau (CLIENT datamodel, daytime, lit camp fire, 9 lines): ghost on select / inert / green in range / red out of range / red "Too far from the fire" / rotate / gone on deselect / fire meter tracks FuelFraction / ring dots under Config.Fire.Ring.DayVisibilityMaxTransparency. Uses client bridge ghostAim/ghostState/ghostRotate.

Studio server mode: a plain Studio Test is now the LOBBY (Config.Teleport.StudioDefaultMode). Every RUN-mode scenario (all scenarios above except the lobby/meta ones) needs Workspace attribute ServerMode = "run" set in edit mode before start_play (clear it afterwards), or `/debug mode run` typed in chat in a Test (saves a Studio-only override read by the next Test; `/debug mode clear` removes it). Studio profiles use the separate store PlayerProfiles_Studio; on a load failure/timeout Studio falls back to an in-memory profile (Player attribute DataFallback, nothing saved).

Scenario studio-test-boot: tools/qa/studio-test-boot.luau (SERVER, plain Studio Test, ~35 s, 6 lines): lobby mode by default, profile loaded (not the in-memory fallback), Ready, still connected after 30 s. The lodge comes from tools/build_lobby.luau (run once via MCP; run servers destroy it at boot).

Scenario lobby-to-run: tools/qa/lobby-to-run.luau (SERVER datamodel, lobby mode, 7 lines): local player on pad 2 + simulated second member (Party.debugJoinId) -> pad timer launch through the Studio fake TeleportAdapter (mode run) -> RunLifecycle.debugBegin with both ids (absent one held) -> kill -> debugEnd -> profile runs/kills/coins updated, held member gets no payout -> fake teleport back to the lobby with both party ids.

Scenario lobby-player-path: tools/qa/lobby-player-path.luau (CLIENT datamodel, lobby mode, 8 lines): drives the LobbyController bridge (joinPad from the spawn, leavePad, claimDaily twice, Studio DebugCommand runSummary -> summary shown, requeue joins a pad).

Phase 3 (brief 18). Two-part files branch on RunService:IsServer(): run the same file on the SERVER datamodel, then on the CLIENT datamodel (same play session).
Scenario blizzard-survival: tools/qa/blizzard-survival.luau (server 4 + client 2 lines): forced blizzard (warning skipped with clockSpeed) -> warmth drains faster, mob budget multiplier > 1 and capped, live mobs <= MaxLiveMobs, warmth recovers at the fire; client sees the Blizzard flag and EventAtmosphere density, no hidden attribute.
Scenario stalker-hunt: tools/qa/stalker-hunt.luau (server ~60 s, 4 + client 2 lines): lone vs grouped isolation weight, forced hunt strikes once from full health and never kills, hunt ends after retreat, a sheltering target keeps the Stalker outside the fire's warm radius; client sees no Dread/hunt attribute or remote.
Scenario far-biome: tools/qa/far-biome.luau (server, 4 lines): ring 0 vs deep tundra drain underdressed (> 2x), tier-3 clothing sets ColdResistance to the ring requirement and drops the drain to a survivable rate (>= 120 s of warmth).
Scenario progression-player-path: tools/qa/progression-player-path.luau (client, 6 lines): Forge and StorageChest placed through the ghost + E/Act, chest opened with E/Act (empty hand; chest spot chosen away from gather nodes), Raw Meat cooked at the camp fire, Axe repaired at a workbench, ping through the wheel handler (bridge pingOpen(aim) / pingSend). Storage/ping handlers reach the bridge via HudController.addQA.

Phase 4 (brief 21).
Scenario meta-shop: tools/qa/meta-shop.luau (SERVER, lobby mode, 7 lines): coin buy uses the server price (a client price field is ignored), duplicate buy refused, one perk equipped (unowned refused), achievement unlocks and pays once, a fake receipt processed twice grants once, NotProcessedYet with no profile and no prompt while ProductIds are 0. Backs up and restores the test profile through the Studio bridge MetaQA.
Scenario settings-player-path: tools/qa/settings-player-path.luau (RUN mode, same session: SERVER setup -> CLIENT -> SERVER verify, 6 lines): reduce-scares toggle via the real Settings handler (server writes the profile and mirrors ReduceScares), Forge hint completes on a real ghost + E/Act forge placement and persists to profile.hintsSeen, touch placement label (no "[R] Rotate", Rotate button) vs PC. Client bridge hooks: settingsToggle, settingsState, hintSeen, hintReset, ghostTouch.
Scenario perf: tools/qa/perf.luau (SERVER, run mode): reads the Studio-only Perf* samples from AtmosphereBoot against Config.Perf caps; does not need tools/apply_perf.luau.


Art pass 1.
Scenario hub-art: tools/qa/hub-art.luau (CLIENT, lobby mode, 9 lines): hub budgets from Config.Art.Hub, spawn + 6 tagged pads with indexes + no scripts, three live boards, local board lists the player, shop/stats/mirror prompts exist, stats and shop prompts open the real panels through the lobby bridge (triggerPrompt/panelOpen), pad billboards carry the timer label. Rebuild the hub first with tools/build_lobby.luau.
Studio note: modules required from execute_luau stay cached for the whole Studio session; after editing src/shared or src/server/Art, clone ReplicatedStorage.Shared (rename the original) and the Art folder before requiring, or restart Studio.
