# Status
Done: kit bootstrap; Phase 0 (specs, debug layer, qa runner, sim harness); Phase 1 systems built and integrated: chunk tree/rock nodes -> GatherService, wood spender -> FireService, PlaceRequest (workbench, campfire), camp spawn via RespawnLocation, mobs use lit fires + weapon damage + drops, constants moved to Config. check.sh passes at tier=full; tools/qa/day3-solo.luau 8/8 PASS in Studio; tests/FlowTests.luau runs the 3-day solo flow headless.
In progress: none.
Next: client build/fuel UI (PlaceRequest, AddFuelRequest senders), food use handler (eat RawMeat; feed values in Config), inventory persistence, Phase 1 human playtest gate.
Open issues: no food use handler, so players starve on day 2-3 outside the sim; chunk unload/reload resets depleted nodes; starter Axe and wood-only Pickaxe are defaults to confirm; runner.luau debug scenario requires modules directly (separate VM) and should use the QA bridge; Studio warns about asset 203785492 (not referenced in src).
CHECKPOINT: no
