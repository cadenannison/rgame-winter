# Status
History of every phase/round (check results, QA counts, hand-test lists): docs/archive/STATUS_HISTORY.md (do not read unless the task names it).
Nothing committed since Phase 0. Place ids: placeId 130366229723914 (Studio instance id changes per session). Hand-test list for the current round: docs/HAND_TESTS_ROUND.md.

## Current state (2026-11-18)
- Phases 1-4 built and integrated: core loop, lobby/party/teleport/run lifecycle, biomes/events/horror/mobs/bosses, meta/shop/atmosphere/perf; Phase 1-4 human gate still open (PM).
- Latest rounds (headless only, PM hand-tests): terrain voxels + forest + enterable POIs + fire radius 54/72/90 + downed/revive; loot chests + 6 massive structures + tree fixes; items/world/HUD (schema v4, 9-slot hotbar + 27-slot backpack, equipment, storage chests, SiteGround, death panel).
- Token-cost round (this round, no behavior change): check.sh/tests quiet by default (1 line, full log in .logs/check.log, `--verbose` for all); INTEGRATION.md 50k -> 12k chars, STATUS.md 12k -> <5k (history in docs/archive/); DECISIONS.md summary table; CLAUDE.md standing rules; docs/INDEX.md (doc map + task -> files); Config split into src/shared/Config/ (13 modules, public API identical, deep-compared to the old table: 0 diffs); HudController 1346 -> ~890 lines (+ HudKit, HudWidgets, HitWatch, HudTargeting, HudPrompt, HudInput); WorldProps 1428 -> 28-line facade + Art/Props/ (PropKit, TreeProps, RockProps, DecorProps, PoiProps); settings.json denies Read of .logs, docs/archive, build, .luau-types, roblox.yml.
- check.sh tier=full green (1372 headless checks). No playtest, QA scenario or MCP this round.

- Backpack grid fix: new pure src/shared/logic/SlotViewModel (decodeSlots + view + highlight) used by HUD hotbar, BackpackPanel (all slot types), InventoryMirror and StorageController; tests/SlotViewTests. check.sh green, 1730 checks.
- Hidden-wood round: new src/shared/logic/SlotLayout (single owner of slot ranges: hotbar 1-9, grid 10-36, equip, chest; areaOf, gridCellToSlot, slotToGridCell, validAddr, snapshot, strays, rescue). InventoryMove parse/resolve/quickMove/drop, InventoryService select/use, HudHotbarDrag and BackpackPanel all use it; the server rejects any index outside a valid area. Inventory/chest sync is now a dense array of entries carrying `slot` (decodeSlots prefers the entry's slot over its key). Rescue of out-of-area items runs on join/rejoin and profile load. `/debug inv` (server slots + client grid cells, warns on strays). Tests: tests/SlotLayoutTests (all 27 grid cells, chest, equipment, merge, rescue, string-keyed wire), stray invariant in the move property test. check.sh green, 1753 checks. Code reading found no out-of-range write path (grid drew and dropped 10..36 consistently); the only wire-level suspect was sparse numeric keys, now removed. Root cause in Studio NOT reproduced: use `/debug inv`.
- Round (combat/economy/weather/loot, 4 agents + orchestrator, headless only): see INTEGRATION.md "Round contracts" and HAND_TESTS_ROUND.md. Nothing played in Studio.

## Open issues
- Shop StarterIronAxe puts iron on day 1 (decide: remove / later unlock / keep). Studio Return-to-lobby only sets lobby mode for the next Test. Night-blizzard horizon seam, mob counts near the part budget and real teleport are hand-test only.
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
- Open: campfire root cause unconfirmed (use groundcheck); blizzard streak sign/whiteout/wind numbers untuned. (Forage coin credit, forage respawn, forage parts budget, Rope, StructureBeacon tag and lobby Leave key were fixed in the Bug-fix round 2 below.)
- Next: PM hand-test docs/HAND_TESTS_ROUND.md (new section at the end).

## Round: Art Pass 3 creatures + 8 new mobs (orchestrated, 3 agents; headless only)
- check.sh tier=full green (1621 checks). No playtest, QA or MCP; nothing seen in Studio (Motor6D hinge pivots, pose angles, silhouettes unverified).
- Done: MobService split (MobKinds/Registry/World/Spawner/Combat/State/Actions, Drivers/Legacy + SpeciesKit, Species/*); 8 species (SnowGrouse, RidgeStag, LakeSeal, RimeWolverine, ScrapHound, CarrionCrow, FrostboundBrute, AuroraWisp) with pure behaviors (logic/MobBehaviors*), ring-weighted spawns, caps, dread weighting (MobDread, AmbientCues); items Feather/Venison/Blubber/Claw/Fang/DenseHide/CrystalShard/AuroraDust + recipes InsulatedCoat, BlubberTorch, FangSpear, AuroraTorch; shared rig contract (docs/CREATURES_CONTRACT.md), AnimKit + client CreatureAnim (120-stud cull), CreatureFx (crow flock, brute slam ring, wisp glow/trail, <=4 lights); Defs for all 24 kinds (Stalker and lurkers attach via HorrorWorld.makeModel).
- Open: cancelled legacy windup now reports Chase not Attack; caribou/stag have no graze anim; wisp touch costs 4 warmth (cap 12/wisp); mob parts budget MaxMobParts 600 + 200 headroom under MaxLiveParts 6000 (unchanged); FX tuning constants local to CreatureFx.
- Next: PM hand-test docs/HAND_TESTS_ROUND.md (Art Pass 3 section). No SAVE NEEDED (no MCP).

## Bug-fix round 2 (PM brief, 9 items; headless only)
- check.sh tier=full green (1722 checks). No playtest, QA scenario or MCP; nothing seen in Studio.
- 1 HudMath.parseDebug: only setDay/clockSpeed/teleportRing are numeric; blizzard start|stop|intensity n now parses (was bool-only); forage/sprint/groundcheck and all string commands pass through. tests/DebugParseTests.luau covers every DebugCommands.NAMES entry with and without args, then validates.
- 2 Fuel is data-driven: Config.Items.Entries[id].fuelSeconds (Wood 120 = Fire.WoodFuelSeconds, Stick 40, Pinecone 30, Blubber 300), scaled per fire tier; FireLogic.fuelSeconds/pickFuel; AddFuelRequest(fire, itemId?) with the server choosing/validating the item; FireService.setFuelSpender replaces setWoodSpender; ActionPick hasFuel/selectedFuel; HUD prompt "Add <item>".
- 3 RunResult.forageCoins in RunPayout.coins (capped by MaxCoinsPerRun); RunLifecycleService claims ForageService.takeCoinCredit in settle (provider wired in init.server; forage PlayerRemoving clear is deferred so the leave-settle can still claim).
- 4 Verified: DayClock rolls Day over exactly where night ends and daylight starts (StartClockHour 8, phase 0), so the forage regrow trigger is correct. Extracted DayClock.isNewDay (used by ForageService) and tested it over 4 days.
- 5 ChunkService extra-parts providers are keyed ("massive", "forage"); chunk streaming allowance and Forage budgetOk (PerfBudget.hasPartRoom) count both. MaxLiveParts stays 6000.
- 6 Rope: StorageChest +1 Rope (Config.Storage.CraftRope), Bow +1 Rope (bowstring). Rope is hand-craftable from 3 FrozenReed.
- 7 Removed the dead "StructureBeacon" glow tag (nothing applied it; fires and warm spots still glow).
- 8 Slam radius = CreatureFxLogic.slamRadius(attackRange, strikeLeeway) = 10, used by the server hit test and the client ring. Source of truth for art root size is Config.Mobs.Species.FrostboundBrute.size (5x7x5); Def comment updated.
- 9 Lobby Leave key Q -> V (Q is Ping); prompt text derives from LobbyConfig.Keys.Leave; handler already goes through InputGuard.
- Note: Stick/Pinecone/Blubber are now fuel by id; Pinecone is also food, so selecting it still eats (fuel only via auto-pick when no Wood/Stick held). StorageChest/Bow now cost Rope: players need to forage reeds first.

## Round: Art Pass 4 items, worn gear, structures (orchestrated, 3 agents; headless only)
- check.sh tier=full green (1951). No playtest, QA or MCP; nothing seen in Studio. Details: docs/ART_STATUS.md "Pass 4".
- Orchestrator: Config modules ArtItems/ArtGear/ArtStructures, shared/IconAssets, GallerySets extended, HudController hotbar icon setItem.
- Open: gear/landmark/grip offsets are guesses; Config.Ui.HeldVisual type is legacy.
- Follow-up (PM brief): all 6 massive structures now Config.Massive Rings {2,3} (player rings 3-4; multi-floor plans unchanged), so rings 1-2 (internal 0-1) hold only single-story POIs. New small POI kinds `shed` (Woodshed/Smokehouse; SnowyForest chunks ForestClearing + ForestCreek) and `fishhut` (IceHut/BaitShack; FrozenLake chunks LakeOpen + LakeShore), data in PoiPlan/Chunks/LootTables. Per ring now: ring 1 = 4 kinds (cabin x3, campsite x2, plane x2, shed x2 = 9 variants, 1 chest max/structure); ring 2 = 4 kinds (cabin x2, plane x2, campsite x2, fishhut x2 = 8 variants + thin-ice hazard, planes up to 2 chests, others 1).
- Follow-up: 7 new gear items (HideLeggings, FurLeggings, HideGloves, FurMittens, FeatherScarf, FangCharm, AuroraAmulet) for Legs/Hands/Neck/Accessory x2 with warmth, armor, recipes (bench tier 1-3 / forge), ItemModels and gear looks (tiers Feather/Fang/Aurora). docs/systems/chest-art.md rewritten. check.sh green (1952).
- Balance note: worn resistance is a capped sum (12); Fur set (6) + all extras (up to 6) can now reach the tundra requirement 9 without Arctic. Retune extras or biome requirements if unwanted.
- Next: PM hand test (HAND_TESTS_ROUND.md "Art Pass 4"). No SAVE NEEDED (no MCP).
