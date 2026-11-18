# CLAUDE.md — ArcticSurvival
Roblox game. Luau + Rojo + Wally. A PM/orchestrator assigns one task at a time; you execute.

## Hard rules
- Do NOT commit or push. Never edit .git or hooks.
- Load only this file + docs/systems/<system>.md for the system you touch (design intent: docs/specs/<system>.md, index in docs/GDD.md; read only if the brief says so).
- Scripts live in src/ and sync via Rojo. Never write script Source through MCP. UI is built in code.
- Every Luau file starts with --!strict. No warnings.
- Done = scripts/check.sh passes. If behavior changed: scripted playtest (tools/qa), local player, filtered output, no errors.
- Client-facing work must also pass docs/PLAYABILITY.md (PC + mobile input, prompt, hint, feedback).
- After any MCP instance work, end your report with SAVE NEEDED (agents cannot save the place).
- Final report <=10 lines: files changed, check result, playtest result, open issues.

## Studio and MCP
- Act only on the Studio whose placeId is 130366229723914. Pass its studio id on every call. If more than one Studio is open, stop and ask.
- One agent at a time uses MCP. Playtest with a local player (start_play), never server-only.
- Query by exact path and shallow depth. Read code from disk, never through MCP. Batch edits into one call. No screenshots unless the brief asks (max 5).
- World/art/lighting come from idempotent scripts in tools/ run in one MCP call; leave no script in the place.

## Layout
src/server -> ServerScriptService.Server | src/client -> StarterPlayerScripts.Client | src/shared -> ReplicatedStorage.Shared | src/first -> ReplicatedFirst.Loading
Pure logic (no Roblox APIs) -> src/shared/logic/. System index: docs/ARCHITECTURE.md. Implementation specs: docs/systems/. Design specs: docs/specs/.

## Luau conventions
- PascalCase modules/classes/methods; camelCase locals; UPPER_SNAKE constants.
- Services via game:GetService at file top. task.wait/spawn/delay/defer only (never wait/spawn/delay).
- Instance.new(class), set properties, set Parent LAST.
- No magic numbers or asset IDs inline: shared/Config.luau and shared/Assets.luau.
- Replicated state: Attributes. Behavior groups: CollectionService tags. Never scan Workspace.
- Every connection/instance has an owner and cleanup (PlayerRemoving, Destroying). No leaks.
- Heartbeat for simulation; RenderStepped only for camera/visuals. One loop for all players, not a thread per object.
- Handle the PlayerAdded race (also loop Players:GetPlayers()). pcall anything external. Never yield unguarded in handlers.
- Per-tick visual feedback is client-side from Attributes; never a remote per tick.

## Networking and security
- All remotes come from shared/Remotes.luau; one per intent; typed payload.
- Server handler order: type-check -> range/sanity -> rate limit (Guard) -> permission/state/zone -> act.
- Never trust client values. Server recomputes prices, damage, positions. Validate at the action, not only at entry points.
- No InvokeClient. No server->client RemoteFunction.

## Data
- Persistence only through server/Data/DataService. Session locking, retry with backoff, hard load timeout (30s) then kick, validate schema on every load, never overwrite on a failed load.
- Saved tables use string keys. schemaVersion + migrations for every change. Save on PlayerRemoving AND BindToClose.

## Spawn
- Players.CharacterAutoLoads=false. LoadCharacter only after profile loaded and any per-player setup done; plot/spawn is Player.RespawnLocation; handle respawn after death. Custom loading screen in ReplicatedFirst.

## Process
- New system: docs/systems/<name>.md from _TEMPLATE.md first, then code. Architectural choice: one line in docs/DECISIONS.md.
- Shared files (Config, Catalog, Remotes, init.*, ProfileSchema) have one owner per round.
