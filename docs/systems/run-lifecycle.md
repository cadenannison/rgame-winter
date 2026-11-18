# Run lifecycle
Tier: full
Purpose: Run server roster from teleport data, downed/dead mirror, disconnect hold, run end, payout and stats, summary, return to lobby. Run mode only.
Owner files: src/server/Run/RunLifecycleService.luau, src/server/Run/RunState.luau, src/shared/logic/RunPayout.luau, src/server/Meta/DailyRewardService.luau, src/server/Meta/DailyLogic.luau
Public API: RunLifecycleService.Start/Stop, RecordKill(player, isBoss) (MobService kill wiring), SetCause(cause) (SurvivalService cause wiring), ShouldHold(userId) (Survival/Inventory hold predicate), onRunEnded(cb), GetStatus, HasEnded, GetResults, debugBegin(data)/debugEnd() (Studio only). Remotes RunSummary (server -> client), DailyClaimRequest / DailyClaimResult.
Data touched: profile coins, maxDays, runs, kills, bossKills (RunPayout.apply), lastDailyClaim. Config.Run (RejoinWindowSeconds = 300, single source; revive limit = Config.Downed.BleedoutSeconds), Config.Meta.
Invariants: the run ends exactly once, when no member can act; party members who never arrive are held from the start and die when the window passes; a held member's meters and inventory survive in SurvivalService/InventoryService for RejoinWindowSeconds (character is not kept; rejoin respawns at camp); a held member who never rejoins gets no payout (accepted); friend bonus counts party members who are Roblox friends (IsFriendsWithAsync, pcall'd, cached per run); daily claim is once per UTC day on server and client (DailyLogic matches LobbyLogic.canClaimDaily, tested).
Return to lobby: Config.Downed.ReturnRemoteName request, allowed only for a dead member or after run end, rate-limited, one teleport in flight per player; leaving before the run ends settles that player's payout first (days so far). Studio: TeleportAdapter fake, no kick on failure.
Exploit surface: players not in teleport data are kicked (Config.Run.RefusedMessage); payout recomputed server-side; DailyClaimRequest carries no payload and is rate-limited.
Playtest checklist: tools/qa/lobby-to-run.luau (debugBegin/debugEnd on the real end path, fake TeleportAdapter); full run with a real death is hand-tested on a published place.
Status: done

## Respawn
- `RunState.respawn(run, userId)`: downed/dead -> alive (held and alive unchanged). RunLifecycleService.Start registers it as `SurvivalService.setRespawnHandler` so `SurvivalService.respawn(player)` (debug/tools) keeps run bookkeeping in step. Ignored after the run ended.
