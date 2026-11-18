# Docs index
Read CLAUDE.md first. Then only the files for your task type (table below). Never read docs/archive/, docs/GDD_full.md, docs/GDD.md or build/ unless the task names them.

## Task type -> read only these
| Task | Read (and nothing else unless the brief says so) |
|---|---|
| World gen / terrain / forest / biomes | docs/systems/world-gen.md, INTEGRATION.md "World", src/shared/Config/World.luau |
| Structures / POIs / massive structures | docs/systems/structures-a.md or structures-b.md, INTEGRATION.md "World", Config/World.luau |
| Loot / chests | docs/systems/loot.md, docs/systems/chest-art.md, INTEGRATION.md "Loot", Config/Loot.luau |
| Items / inventory / crafting / storage | docs/systems/items-crafting.md, INTEGRATION.md "Items", Config/Items.luau |
| HUD / UI / client input | docs/systems/hud.md, docs/PLAYABILITY.md, Config/Ui.luau, src/client/HUD/HudConfig.luau |
| Audio / atmosphere / cues | docs/systems/atmosphere.md, docs/ART.md, src/shared/data/AudioCues.luau, Config/Lighting.luau |
| Art / world props / hub | docs/ART.md, docs/ART_STATUS.md, Config/Art.luau, src/server/Art/ (props: Art/Props/) |
| Mobs / combat / events / horror | docs/systems/mobs.md, events.md or horror.md, INTEGRATION.md "Mobs", Config/Mobs.luau or Horror.luau |
| Survival / fire / downed | docs/systems/survival.md, INTEGRATION.md "Survival", Config/Survival.luau |
| Saves / data / teleport / run end | docs/systems/data-service.md, run-lifecycle.md, party.md, INTEGRATION.md "Teleport" + "Data", Config/Core.luau + Meta.luau |
| Meta / shop / achievements | docs/specs/meta-shop.md, INTEGRATION.md "Meta", Config/Meta.luau |
| Perf / part budget | INTEGRATION.md "Atmosphere, perf", Config/Perf.luau, tests/LivePartsTests.luau |
| Debug / QA tooling | docs/systems/debug-service.md, tools/qa/README.md, Config/Debug.luau |
| New system | docs/systems/_TEMPLATE.md, docs/ARCHITECTURE.md |

## Docs (one line each)
- CLAUDE.md: hard rules + standing agent rules. docs/STATUS.md: current state, open issues, next. docs/KNOWN_ISSUES.md: full issue list.
- docs/HAND_TESTS_ROUND.md: PM hand-test list for the current round. docs/HAND_TESTS.md: published-place hand tests.
- docs/INTEGRATION.md: live cross-system contracts (owner files, remotes, events, config). docs/ARCHITECTURE.md: system index.
- docs/DECISIONS.md: summary table + append-only log. docs/PLAYABILITY.md: client playability gate. docs/MCP_PLAYBOOK.md: Studio/MCP rules.
- docs/ART.md / ART_PLAN.md / ART_STATUS.md / CREDITS.md: asset ids, art passes, credits. docs/ROADMAP.md: milestones.
- docs/ORCHESTRATOR_PROMPT.md, docs/BRIEF_TEMPLATE.md: PM prompts (not for build agents).
- docs/systems/*.md: implementation spec per system. docs/specs/*.md: design specs. docs/GDD.md (index) / GDD_full.md: design docs, on request only.
- docs/archive/: INTEGRATION_HISTORY.md, STATUS_HISTORY.md (denied for Read; open only when the task names them).

## Config modules (src/shared/Config/, merged by init.luau; use `Config.<Section>.<Key>` as always)
| Module | Sections |
|---|---|
| init.luau | merges all modules, re-exports every type (`Config.MobStats` etc.) |
| Constants.luau | shared values (MAX_LIVE_MOBS, FIRE_R0, massive/part budgets, giant tree height) |
| Core.luau | top-level keys: data store, session, spawn, load timeouts |
| Debug.luau | Debug |
| Survival.luau | Time, Meters, Fire, FireRules, Food, Buffs, Downed, Durability, WarmSpot, Shelter, Clothing |
| World.luau | World, Terrain, Forest, Trees, Biome, Structures, Massive, SiteGround, Map, Shadows |
| Items.luau | Inventory, ToolTier, Gather, Craft, Build, Storage, Items, Equipment, Repair, Cooking, Ping |
| Loot.luau | Loot |
| Mobs.luau | Scaling, Mobs, Night, Combat, Bosses, Projectile, WolfScaling |
| Horror.luau | Events, Blizzard, Dread, Isolation, Stalker, Lurkers, Scares, Cue |
| Lighting.luau | Lighting |
| Perf.luau | Perf, Net |
| Meta.luau | Lobby, Run, Teleport, Meta |
| Ui.luau | Held, Feedback, Settings, Hints |
| Art.luau | Art (hub + world art) |
Each module starts with a header comment and exports `Sections` (its types + values). A key may live in only one module (init asserts).

## Split hot files
- HUD: src/client/HUD/HudController.luau (state + intents + remote handlers) with HudKit (helpers), HudWidgets (stats/day/compass/hotbar/Act button), HitWatch, HudTargeting, HudPrompt, HudInput.
- World props: src/server/Art/WorldProps.luau (facade, same API) over src/server/Art/Props/{PropKit,TreeProps,RockProps,DecorProps,PoiProps}.luau.

## Other large files (not split; read only the part you need)
src/shared/logic/StructurePlanKitA.luau (1044), src/server/Mobs/MobService.luau (1029), src/server/Art/HubProps.luau (1026), src/shared/logic/PlanKitB.luau (942), src/client/HUD/HudController.luau (884), src/client/Storage/BackpackPanel.luau (852), tests/sim.luau (805), src/shared/logic/PoiPlan.luau (777), src/server/World/ChunkService.luau (746), src/server/Art/Props/PoiProps.luau (685), src/client/Meta/MetaPanel.luau (649), src/server/World/Structures/StructureKitA.luau (637), src/server/Survival/SurvivalService.luau (634), src/shared/logic/MineComplexPlan.luau (620), tests/DataTests.luau (590).
