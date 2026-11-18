# DebugService
Tier: standard
Purpose: Studio-only commands to reach game states fast (day, clock, blizzard, dark event, Stalker, god mode, ring teleport). Inert on published servers.
Owner files: src/server/Debug/DebugService.luau, src/shared/logic/DebugCommands.luau, Config.Debug, Remotes.DebugCommand
Public API: DebugService.start/stop/isActive; DebugService.run(player, name, arg) -> ok, msg; DebugService.register(command, handler) -> unregister. Remote DebugCommand (client -> server): (name: string, arg: any). Commands: setDay(int), clockSpeed(number), blizzard(bool), darkEvent(name|""), stalker(bool), invincible(bool), teleportRing(int), give(itemId), spawnMob(kind). give/spawnMob are DebugCommands.ACTION_ONLY: no attribute, they need a registered handler (init.server).
Data touched: Workspace attributes (Config.Debug.World*Attribute); Player attributes DebugInvincible, DebugTeleportRing. Systems read these or register handlers.
Invariants: nothing runs and the remote is never created when RunService:IsStudio() is false; every arg is validated by DebugCommands.validate before state changes; handler errors are pcall-ed; connections and ForceFields are cleaned on stop/leave.
Exploit surface: published servers have no remote and run() rejects; in Studio the remote is rate limited (Guard) and validated.
Playtest checklist: 1. Studio play, fire DebugService.run from server console for each command. 2. Confirm attributes change and invalid args are rejected. Script: tools/qa/runner.luau (scenario debug).
Status: in progress

## Integration points
- Exposes: register(command, handler) (DayNight setDay/clockSpeed, Chunk teleportRing, Survival invincible), run, expose(name, api).
- QA bridge (Studio only): ServerStorage[Config.Debug.BridgeName] BindableFunction, Invoke(service, fn, ...) calls a live exposed service. Needed because MCP execute_luau runs in another VM and gets fresh module copies. init.server exposes Debug, Chunk, Survival, Fire, Gather, Inventory, Crafting, Placement, Mobs. Not created on published servers; ServerStorage is not client-visible.
- Client QA bridge (Studio only): src/client/HUD/QABridge.luau creates PlayerScripts[Config.Debug.ClientBridgeName]; MCP execute_luau on datamodel Client invokes the live HUD input handlers (see docs/systems/hud.md). Scenario tools/qa/player-path.luau uses it plus the DebugCommand remote (give, spawnMob).

## Items round commands (chat: `/debug <cmd> [arg]`, Studio only)
`structures` (5 nearest massive structures: key, ring, distance), `tp structure [n|Id]` / `tp ring <n>` / `tp <player>` (grounded, outside the footprint), `chest <rarity>` (a chest 8 studs ahead), `seed [n]` (print the world seed, or reset structures/loot with seed n; the world layout stays fixed per run), `respawn` (SurvivalService.respawn: the same transition as a real revive/respawn). All are ACTION_ONLY; arguments validated by `DebugCommands.validate` / `parseTp`; services are reached through `DebugService.expose` (Chunk, Survival from init.server; Massive, Loot from MassiveService).
