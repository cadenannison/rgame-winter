# Lobby (world and UI)
Tier: standard
Purpose: Lodge built by tools/build_lobby.luau, lobby stat attributes and leaderboard (server), pad HUD, side menu (stats, top days, shop placeholder, daily) and run summary (client).
Owner files: tools/build_lobby.luau, src/server/Lobby/LobbyService.luau, src/server/Lobby/LobbyLeaderboard.luau, src/client/Lobby/*.luau, src/shared/logic/LobbyLogic.luau
Public API: LobbyService.Start/Stop (lobby mode). LobbyController.Start() (client, both modes: pad/menu views show only in the lobby; in a run server only the summary appears). In a lobby server LobbyController owns the Studio client QA bridge: joinPad, leavePad, myPad, padPanelVisible, padTitle, claimDaily, dailyReady, requeue, summary, lastToast.
Data touched: Player attrs LobbyLogic.ATTR (coins, stats, achievements, lastDailyClaim); Workspace attr LobbyLogic.ATTR.Board; OrderedDataStore Config.Lobby.LeaderboardStoreName; Workspace folder Config.Lobby.RootName with spawn Config.Lobby.SpawnName (lobby spawn provider). Tuning in Config.Lobby (StatPublishSeconds, Leaderboard*), UI constants in src/client/Lobby/LobbyConfig.luau.
Invariants: client is display-only (sends PadJoin/Leave/Mode and DailyClaim intents); hidden metrics never published; run servers destroy the lodge folder at boot.
Exploit surface: none beyond Party and Daily remotes (see party.md, run-lifecycle.md).
Playtest checklist: tools/qa/lobby-player-path.luau (client, lobby mode): Join from the billboard, Leave, Daily claim once per UTC day, summary Queue again.
Status: done (run-server summary shows a countdown; "Queue again" is only actionable in the lobby — see KNOWN_ISSUES)
