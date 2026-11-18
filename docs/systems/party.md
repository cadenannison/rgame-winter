# Party (lobby pads and teleport)
Tier: full
Purpose: Lobby pads 1..Config.Lobby.PadCount (pad i holds i), shared countdown, friends-only mode, reserved-server launch. Lobby mode only.
Owner files: src/server/Party/PartyService.luau, src/server/Party/TeleportAdapter.luau, src/server/Party/RunSetup.luau, src/shared/logic/PadLogic.luau, src/shared/logic/TeleportData.luau
Public API: PartyService.Start/Stop, join(player, padIndex), leave, setMode, onLaunch(cb(padIndex, players, data)), getPad, getPartyIds, setSeedFunction, debugJoinId (Studio only). TeleportAdapter.teleportParty(players, data) (run = reserved server, lobby = public server), setImpl(fake), getStudioLog/clearStudioLog (Studio fake). RunSetup.applyRunData(data) before ChunkService.start. Remotes PadJoinRequest {padIndex}, PadLeaveRequest, PadModeRequest {mode}, PartyState {pads}.
Data touched: Player attr Config.Lobby.PlayerPadAttribute; pad parts tagged Config.Lobby.PadTag with Config.Lobby.PadIndexAttribute; Workspace Config.World.SeedAttribute (run). Tuning in Config.Lobby (PollInterval, PadEdgeMargin, PadHeightMargin, PadJoinLift, LaunchHoldSeconds).
Invariants: a player is on at most one pad; a remote join puts the character on the pad, and walking off removes them; launch keeps only present members; a failed teleport resets the pad and toasts everyone; PartyState is sent on change only.
Exploit surface: pad index range-checked and rate-limited (Config.Net.PadRateInterval); mode is host-only and validated in PadLogic; friends-only uses IsFriendsWithAsync with a timeout; teleport data is built server-side and validated on arrival by Guard.teleportData.
Playtest checklist: tools/qa/lobby-to-run.luau (server, lobby mode) and tools/qa/lobby-player-path.luau (client, lobby mode). A plain Studio Test is lobby; run mode needs Workspace ServerMode = "run" (edit mode) or "/debug mode run".
Status: done (real teleport hand-tested on a published place only)
