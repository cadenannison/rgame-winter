# ArcticSurvival — Architecture
Pitch: Arctic survival game on Roblox (Luau + Rojo + Wally). Design details to be set via the intake questions in ROBLOX_KIT.md Part D.
Server-authoritative: client sends intent, server validates and acts.
World and art are built by idempotent scripts in tools/ (the place file is not in git).

## Systems
| name | tier | purpose | entry file |
|---|---|---|---|
| DataService | full | session-locked profile load/save (ProfileStore), schema validation, load timeout kick | src/server/Data/DataService.luau |
| SpawnService | full | gated character spawn, respawn, void kill, Ready signal | src/server/Spawn/SpawnService.luau |
| Guard | full | rate limits and payload validators for remote handlers | src/server/Net/Guard.luau |
| LoadingScreen | light | ReplicatedFirst loading screen with failure message | src/first/LoadingScreen.client.luau |

## Data model
Workspace is built by tools/map and tools/art builders (nothing in git). Scripts live in src/ and sync via Rojo. Profile fields: see src/shared/logic/ProfileSchema.luau.

## Networking map
| remote | direction | handler |
|---|---|---|
| Notify | server -> client | (none yet; client listener to be added with the HUD) |
