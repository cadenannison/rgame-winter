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
| Inventory/Gather/Crafting/Placement (items-crafting) | full | inventory, tier-gated nodes, crafting, grid-snapped structure placement | src/server/Items/*.luau |
| MobService (mobs) | full | budgeted spawns, AI near players, fire repel, melee, drops | src/server/Mobs/MobService.luau |
| HUD | light | client bars, hotbar, compass, hints, mobile action button | src/client/HUD/HudController.luau |
| LoadingScreen | light | ReplicatedFirst loading screen with failure message | src/first/LoadingScreen.client.luau |

## Wiring (src/server/init.server.luau)
- FireService.setWoodSpender -> InventoryService.remove(player, "Wood", n).
- Spawn.setSpawnProvider -> ChunkService.getCampSpawnPosition.
- DebugService.expose for the Studio-only QA bridge (Debug, Chunk, Fire, Gather, Inventory, Crafting, Placement, Mobs).
- Start order: Data, Debug, Chunk, DayNight, Survival, Fire, Inventory, Crafting (+Gather), Placement, Mobs, Spawn (last, so no character loads before the world and systems exist).
- Direct requires across systems: ChunkService -> GatherService.registerNode; PlacementService -> CraftingService.registerWorkbench, FireService.register/count; MobService -> FireService.getLitPositions, InventoryService.getSelected/wearSelected/add.

## Data model
Workspace is built by tools/map and tools/art builders (nothing in git) plus runtime folders Chunks, Camp, Structures, Mobs. Scripts live in src/ and sync via Rojo. Profile fields: see src/shared/logic/ProfileSchema.luau. All attribute names, tags and folder names are in src/shared/Config.luau.

## Networking map
| remote | direction | handler |
|---|---|---|
| Notify(kind, text) | server -> client | no client listener yet (kinds: craft, gather, build) |
| MetersUpdate | server -> client | HUD |
| InventoryUpdate | server -> client | HUD |
| CraftRequest(recipeId) | client -> server | CraftingService |
| PlaceRequest(structureId, position, rotationY) | client -> server | PlacementService (no client sender yet) |
| GatherRequest(node) | client -> server | GatherService |
| AttackRequest(target) | client -> server | MobService |
| SelectSlotRequest(slot) / UseItemRequest(slot) | client -> server | InventoryService |
| AddFuelRequest(fire) | client -> server | FireService (no client sender yet) |
| ReviveRequest(target) | client -> server | SurvivalService |
| DebugCommand(name, arg) | client -> server, Studio only | DebugService |
