# Status
History of every phase/round (check results, QA counts, hand-test lists): docs/archive/STATUS_HISTORY.md (do not read unless the task names it).
Nothing committed since Phase 0. Place ids: placeId 130366229723914 (Studio instance id changes per session). Hand-test list for the current round: docs/HAND_TESTS_ROUND.md.

## Current state (2026-11-18)
- Phases 1-4 built and integrated: core loop, lobby/party/teleport/run lifecycle, biomes/events/horror/mobs/bosses, meta/shop/atmosphere/perf; Phase 1-4 human gate still open (PM).
- Latest rounds (headless only, PM hand-tests): terrain voxels + forest + enterable POIs + fire radius 54/72/90 + downed/revive; loot chests + 6 massive structures + tree fixes; items/world/HUD (schema v4, 9-slot hotbar + 27-slot backpack, equipment, storage chests, SiteGround, death panel).
- Token-cost round (this round, no behavior change): check.sh/tests quiet by default (1 line, full log in .logs/check.log, `--verbose` for all); INTEGRATION.md 50k -> 12k chars, STATUS.md 12k -> <5k (history in docs/archive/); DECISIONS.md summary table; CLAUDE.md standing rules; docs/INDEX.md (doc map + task -> files); Config split into src/shared/Config/ (13 modules, public API identical, deep-compared to the old table: 0 diffs); HudController 1346 -> ~890 lines (+ HudKit, HudWidgets, HitWatch, HudTargeting, HudPrompt, HudInput); WorldProps 1428 -> 28-line facade + Art/Props/ (PropKit, TreeProps, RockProps, DecorProps, PoiProps); settings.json denies Read of .logs, docs/archive, build, .luau-types, roblox.yml.
- check.sh tier=full green (1372 headless checks). No playtest, QA scenario or MCP this round.

## Open issues
- Phase 1 hand-test never confirmed by a human; Assets.luau ids still placeholders (docs/ART.md).
- Parts margin thin: core 3x3 + one structure 3574 of 6000 (`Perf.MaxLiveParts` stays 6000); terrain chunk build is one synchronous FillBlock pass (hitch risk).
- Fires placed after a chunk loads do not clear trees; Boss/Lurker/Stalker spawns ignore the fire repel circle; fire PointLight clamped to 60 studs.
- Massive: LurkerSpots/CueSpots unwired; Kit B chest height vs Kit A floor point; Beacon assumed = ResearchStation (confirm); POIs not on SiteGround.
- Items/HUD: equipment persists across runs (`clearEquipment` unused, decision pending); worn gear not shown on the character; no gamepad; SpawnService auto-respawn bypasses spectate and may double-load with `SurvivalService.respawn`; torch/flare never merge (durability); black death panel's root cause unidentified (visibility now state-driven).
- Loot: epic/legendary items sparse; loot remotes not headless-tested; no ambient/chest sound ids; giant bare trunks capped ~18 by gather-node reach.
- Run/meta: lobby does not resend summary after return; held player who never rejoins loses payout; `RunSummary.rankChange` nil; Robux flow hand-test only (`Meta.ProductIds` 0).
- Studio: after an MCP "not reachable" error, stop_play then start_play before re-running a scenario. RUN-mode QA needs Workspace `ServerMode="run"` or `/debug mode run`.
- Full list: docs/KNOWN_ISSUES.md.

## Next
- PM: hand-test docs/HAND_TESTS_ROUND.md, then the Phase 1-4 human gate.
- Optional follow-ups from the token round: split other large files (listed in docs/INDEX.md) when a task touches them.

## Inventory UI round (Agent 1; headless only)
- Drag ending on an invalid target, outside the panel or on panel close cancels (nothing sent, item stays). New remote DropItemRequest {slot, count} (server: type, range, Guard, alive, then InventoryMove.drop + ItemDrop) is the only way items leave the inventory; Drop button or Q (Q sunk while the Backpack is open so Ping does not fire). Refused moves resync the client from server state.
- Slot highlights (Config.InventoryUi: focus / held / target / hover) in Backpack, chest grid, equipment and HUD hotbar; HUD hotbar draggable (src/client/HUD/HudHotbarDrag.luau); Backpack toggle is B only.
- Tests: property test (random valid/invalid/cancelled moves conserve counts) + drop cases in tests/InventoryTests.luau.
- Hand tests: drop outside panel and close panel mid-drag (item returns); highlight on every slot type; HUD hotbar drag; B-only toggle.

## World and session round (Agent 2; headless only)
- `/debug tp`: pure resolver shared/logic/TpResolve (fuzzy structure names/aliases from Config.Debug.TpAliases, `ring N`, player prefix, clear errors). Cause of "does not teleport": `research` fell through to the player-name branch, and ring/structure tp moved the character before the chunk's terrain voxels were built. Now ChunkService.teleportGrounded waits for terrain (re-requests the chunk while waiting), grounds with SiteGround.footprintTop, PivotTo, and prints name + coordinates.
- Camp fire, spawn pad and POI floors use SiteGround.footprintTop (highest terrain under the footprint). Pad size is Config.SpawnPadSize. Test: tests/WorldSessionTests.luau (50 seeds, dense footprint samples).
- SpawnService: Spawn.setAutoRespawn(false) on run servers (dead stay spectating); the only reload path is Spawn.respawn (used by SurvivalService.respawn), guarded by inFlight against double load. Run end calls InventoryService.clearEquipment for every player (init.server).
- Night: Config.Lighting.MoonAmbient / MoonOutdoorAmbient / MoonBrightness / MoonExposure are the readable-night floors (DayNightService); events may still darken below.
- Interaction audio muted via Config.Feedback.MutedSounds (swing, chop, mob hit) and no CraftSound on structure interact; hook points listed in docs/ART.md.
- Not verified in Studio: voxel top vs heightAt mismatch (if the camp is still buried, raycast Terrain at the footprint).

## Round: bug fixes + sprint/forage + blizzard (orchestrated; headless only)
- check.sh tier=full green (1464 checks). No playtest, QA scenario or MCP.
- Done: InputGuard on all handlers; GroundProbe (campfire/spawn/structures) + `/debug groundcheck`; Drop on G; deny/craft sounds muted; durability kept on drop; sprint; forage/nodes/relics + 3 recipes (13 items); blizzard rework (1.5 days, no overlay, wind snow, 60-stud whiteout); `/debug forage|sprint|blizzard`.
- Open: campfire root cause unconfirmed (use groundcheck); coin credit from nodes/relics not wired into RunPayout; forage respawn assumes Day increments at dawn; forage parts not counted by ChunkService (headroom only); Rope has no use; "StructureBeacon" glow tag unused; blizzard streak sign/whiteout/wind numbers untuned; lobby Leave key still Q.
- Next: PM hand-test docs/HAND_TESTS_ROUND.md (new section at the end).
