# Spawn
Tier: full
Purpose: Gated character spawn (after profile load), respawn on death, void kill, Ready attribute for the loading screen.
Owner files: src/server/Spawn/SpawnService.luau, src/first/LoadingScreen.client.luau
Public API: Spawn.start(), Spawn.stop()
Data touched: Player attributes Ready, LoadFailed
Invariants: CharacterAutoLoads=false; LoadCharacter only after profile loaded; failed spawn kicks with LoadFailed; no leaked connections on PlayerRemoving
Exploit surface: no remotes.
Playtest checklist: 1. tools/qa/spawn.luau (local player). 2. QAForceLoadFailure="spawn": LoadFailed then kick.
Status: in progress
