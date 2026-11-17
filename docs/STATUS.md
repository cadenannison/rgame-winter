# Status
Done: kit bootstrap; Phase 0 (specs, debug layer, qa runner, sim harness); Phase 1 systems built and integrated: chunk tree/rock nodes -> GatherService, wood spender -> FireService, PlaceRequest (workbench, campfire), camp spawn via RespawnLocation, mobs use lit fires + weapon damage + drops, constants moved to Config. check.sh passes at tier=full; tools/qa/day3-solo.luau 8/8 PASS in Studio; tests/FlowTests.luau runs the 3-day solo flow headless.
In progress: none.
Done (round 3): eat via UseItemRequest (FoodService), client senders (place, fuel, gather, eat) on one context action, Notify toast, debug scenario on the QA bridge. Next: crafting UI, inventory persistence, Phase 1 human playtest gate.
Open issues: see docs/KNOWN_ISSUES.md (chunk reload resets depleted nodes); starter Axe and wood-only Pickaxe are defaults to confirm; Studio warns about asset 203785492 (not in src or any place script/instance property checked; not ours).
CHECKPOINT: no
