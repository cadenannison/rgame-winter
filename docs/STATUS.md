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
- Items/HUD: equipment persists across runs (`clearEquipment` unused, decision pending); worn gear not shown on the character; hotbar row not draggable; Tab may toggle the Roblox player list; no gamepad; SpawnService auto-respawn bypasses spectate and may double-load with `SurvivalService.respawn`; torch/flare never merge (durability); black death panel's root cause unidentified (visibility now state-driven).
- Loot: epic/legendary items sparse; loot remotes not headless-tested; no ambient/chest sound ids; giant bare trunks capped ~18 by gather-node reach.
- Run/meta: lobby does not resend summary after return; held player who never rejoins loses payout; `RunSummary.rankChange` nil; Robux flow hand-test only (`Meta.ProductIds` 0).
- Studio: after an MCP "not reachable" error, stop_play then start_play before re-running a scenario. RUN-mode QA needs Workspace `ServerMode="run"` or `/debug mode run`.
- Full list: docs/KNOWN_ISSUES.md.

## Next
- PM: hand-test docs/HAND_TESTS_ROUND.md, then the Phase 1-4 human gate.
- Optional follow-ups from the token round: split other large files (listed in docs/INDEX.md) when a task touches them.
