# DebugService
Tier: standard
Purpose: Studio-only commands to reach game states fast (day, clock, blizzard, dark event, Stalker, god mode, ring teleport). Inert on published servers.
Owner files: src/server/Debug/DebugService.luau, src/shared/logic/DebugCommands.luau, Config.Debug, Remotes.DebugCommand
Public API: DebugService.start/stop/isActive; DebugService.run(player, name, arg) -> ok, msg; DebugService.register(command, handler) -> unregister. Remote DebugCommand (client -> server): (name: string, arg: any). Commands: setDay(int), clockSpeed(number), blizzard(bool), darkEvent(name|""), stalker(bool), invincible(bool), teleportRing(int).
Data touched: Workspace attributes (Config.Debug.World*Attribute); Player attributes DebugInvincible, DebugTeleportRing. Systems read these or register handlers.
Invariants: nothing runs and the remote is never created when RunService:IsStudio() is false; every arg is validated by DebugCommands.validate before state changes; handler errors are pcall-ed; connections and ForceFields are cleaned on stop/leave.
Exploit surface: published servers have no remote and run() rejects; in Studio the remote is rate limited (Guard) and validated.
Playtest checklist: 1. Studio play, fire DebugService.run from server console for each command. 2. Confirm attributes change and invalid args are rejected. Script: tools/qa/runner.luau (scenario debug).
Status: in progress
