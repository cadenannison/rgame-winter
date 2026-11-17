# Status
Phase: 1 (core loop, solo, 3 days). Gate: failed first human playtest (playability); UX pass done, AWAITING human re-playtest. Phase 2 must not start until the gate passes.
Built: Phase 0 (specs, DebugService, qa runner, sim harness); Phase 1 systems integrated (chunks/gather, survival, fire, items/crafting, placement, mobs, food, HUD, toast, camp spawn).
Passed: scripts/check.sh tier=full; player-path 9/9 via MCP (client datamodel); QA via MCP: day3-solo 10/10, debug 7/7 (scenarios use the Studio-only server QA bridge, so they bypass client input).
Failed in human playtest: hotbar could not be selected; hare could not be caught; no crafting UI; no gather feedback or prompts; no onboarding.
In progress: none. UX pass done: hotbar (keys/click/wheel/hand tool), CraftPanel (C), TargetPrompt, Feedback, onboarding chain, catchable hare/caribou (Config), client QA bridge, docs/PLAYABILITY.md. Causes found: selection was invisible (no hand item, raw id, wheel unbound); hare fled 24 vs player 16 with melee reach 7+3.
Open issues: human must supply ids in src/shared/Assets.luau (SwingAnimation, SwingSound, ChopSound, MobHitSound, CraftSound, DenySound); tree prompt visibility unconfirmed in screenshot; onboarding resets on rejoin; swing local-only; docs/KNOWN_ISSUES.md (chunk reload resets depleted nodes); starter Axe and wood-only Pickaxe are defaults to confirm; no ghost preview for placing; inventory not persisted; asset 203785492 warning is not ours; PLACE_ID in CLAUDE.md and docs/MCP_PLAYBOOK.md is still a placeholder (real placeId 130366229723914, only Studio open).
Rules in force: every phase ends with an integration brief; every system brief lists integration points exposed/consumed; client briefs must pass docs/PLAYABILITY.md.
Next step: human re-playtests Phase 1 (PC + phone emulation, solo, 3 days). If it passes: commit checkpoint, then Phase 2 contracts brief. If not: fix list from the human.
CHECKPOINT: no (nothing committed since Phase 0)
