# ArcticSurvival — Architecture
Pitch: Arctic survival game on Roblox (Luau + Rojo + Wally). Design details to be set via the intake questions in ROBLOX_KIT.md Part D.
Server-authoritative: client sends intent, server validates and acts.
World and art are built by idempotent scripts in tools/ (the place file is not in git).

## Systems
| name | tier | purpose | entry file |
|---|---|---|---|
| DataService | full | session-locked profile load/save (ProfileStore), schema validation, load timeout kick | src/server/Data/DataService.luau |
| SpawnService | full | gated character spawn at the camp pad (RespawnLocation), respawn, void kill, Ready signal | src/server/Spawn/SpawnService.luau |
| Guard | full | rate limits and payload validators for remote handlers | src/server/Net/Guard.luau |
| DebugService | standard | Studio-only debug commands + plug-in registry + QA bridge; inert when published | src/server/Debug/DebugService.luau |
| ChunkService (world-gen) | standard | seeded 8x8 layout, chunk streaming, camp fire, registers tree/rock gather nodes | src/server/World/ChunkService.luau |
| DayNight/Survival/Fire (survival) | standard | clock, meters, downed/revive, campfire fuel | src/server/Survival/*.luau |
| Inventory/Gather/Crafting/Placement (items-crafting) | full | inventory, held-item visual Tool, tier-gated nodes, crafting, grid-snapped structure placement | src/server/Items/*.luau (incl. FoodService eat handler, HeldItem) |
| MobService (mobs) | full | budgeted spawns, AI near players, fire repel, melee, drops | src/server/Mobs/MobService.luau |
| HUD | light | client bars, 9-slot hotbar (keys/click/wheel), compass, craft panel, target prompts, swing/hit feedback, onboarding chain, click/E/Act context action, Notify toast, Studio client QA bridge | src/client/HUD/HudController.luau |
| Party (party) | full | lobby pads, countdown, friends mode, reserved-server launch via TeleportAdapter (lobby mode) | src/server/Party/PartyService.luau |
| RunLifecycle (run-lifecycle) | full | run roster from teleport data, disconnect hold, run end, payout/stats, summary, return to lobby; daily claim | src/server/Run/RunLifecycleService.luau, src/server/Meta/DailyRewardService.luau |
| Lobby (lobby) | standard | lodge builder, stat attributes + leaderboard, pad HUD / menu / summary UI | src/server/Lobby/LobbyService.luau, src/client/Lobby/LobbyController.luau |
| LoadingScreen | light | ReplicatedFirst loading screen with failure message | src/first/LoadingScreen.client.luau |

## Wiring (src/server/init.server.luau)
- Server mode: live reserved servers (PrivateServerId set, no owner) are runs, public servers are the lobby; Studio uses a Workspace ServerMode preset (edit mode) else the Studio-only "/debug mode run|lobby|clear" override (DataStore, Debug/StudioMode) else Config.Teleport.StudioDefaultMode ("lobby"). Written to Workspace[Config.Teleport.ServerModeAttribute] at boot.
- Both modes: Remotes.createAll, Guard.cleanup on leave, DataService.start, DebugService.start; QA bridge exposes Debug, Teleport, Data, RunLifecycle.
- Lobby mode: Spawn provider = lodge spawn (Config.Lobby.RootName/SpawnName); PartyService, LobbyService, DailyRewardService, Spawn. Bridge adds Party, Lobby, Daily; Studio DebugCommand runSummary (solo run ended at once -> real RunSummary).
- Run mode: wait (Config.Run.SeedWaitSeconds) for the first player's teleport data -> Guard.teleportData -> RunSetup.applyRunData (seed) before ChunkService.start; destroy the lodge folder; FireService.setWoodSpender -> InventoryService.remove; Spawn provider -> ChunkService.getCampSpawnPosition; SurvivalService/InventoryService.setHoldPredicate -> RunLifecycleService.ShouldHold; SurvivalService.setCauseHandler -> RunLifecycleService.SetCause; MobService.setHitHandler -> SurvivalService.markHit (wolf bite = cause); MobService.setKillHandler -> RunLifecycleService.RecordKill; DebugService give/spawnMob.
- Run start order: Chunk, DayNight, Survival, Fire, Inventory, Crafting (+Gather), Placement, Mobs, RunLifecycle, Spawn (last).
- Client (src/client/init.client.luau): waits for the ServerMode attribute; lobby -> LobbyController; run -> HudController, NightFeedback, LobbyController (summary only). One Studio client QA bridge per mode (HUD in run, LobbyController in lobby).
- Direct requires across systems: ChunkService -> GatherService.registerNode; PlacementService -> CraftingService.registerWorkbench, FireService.register/count; MobService -> FireService.getLitPositions, InventoryService.getSelected/wearSelected/add; RunLifecycleService -> DataService, DayNightService, SurvivalService.getMeters, TeleportAdapter.

## Data model
Workspace is built by tools/map and tools/art builders (nothing in git) plus runtime folders Chunks, Camp, Structures, Mobs. Scripts live in src/ and sync via Rojo. Profile fields: see src/shared/logic/ProfileSchema.luau. All attribute names, tags and folder names are in src/shared/Config.luau.

## Networking map
| remote | direction | handler |
|---|---|---|
| Notify(kind, text) | server -> client | Toast (reason codes -> HudConfig.NotifyText; deny sound for craft, gather, build) |
| MetersUpdate | server -> client | HUD |
| InventoryUpdate | server -> client | HUD |
| CraftRequest(recipeId) | client -> server | CraftingService (HUD CraftPanel) |
| PlaceRequest(structureId, position, rotationY) | client -> server | PlacementService (HUD context action with a placeable held) |
| GatherRequest(node) | client -> server | GatherService |
| AttackRequest(target) | client -> server | MobService |
| SelectSlotRequest(slot) / UseItemRequest(slot) | client -> server | InventoryService |
| AddFuelRequest(fire) | client -> server | FireService (HUD context action near a fire) |
| ReviveRequest(target) | client -> server | SurvivalService |
| DebugCommand(name, arg) | client -> server, Studio only | DebugService |
| PadJoinRequest {padIndex} / PadLeaveRequest / PadModeRequest {mode} | client -> server | PartyService (lobby) |
| PartyState {pads} | server -> client | LobbyController PadHud (on change only) |
| RunSummary | server -> client | SummaryScreen |
| DailyClaimRequest / DailyClaimResult | client <-> server | DailyRewardService / MenuPanels |
