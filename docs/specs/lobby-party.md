# Spec: Lobby and party

- Enclosed lodge lobby (up to 15 players) with six pads for parties of 1-6.
- A 20s timer starts on the first step; friends-only or open-fill pads.
- On timer end the server reserves a private server and teleports the party; failure returns them to the lobby.

Source: split from docs/GDD.md. Index: docs/GDD.md.

## Lobby and party flow

The lobby is the same place as the run server, started in lobby mode. It is an enclosed arctic lodge for up to 15 players per server, with a shop, a global max-days leaderboard, a personal stat and achievement board, a cosmetic preview mirror and emotes.

1. A player steps onto one of six glowing pads, marked 1 to 6 players. The first player on a pad is its host and sets it to friends-only or open-fill.
2. A 20-second timer starts when the first player steps on. It resets to 20 when another player joins. Stepping off removes the player, and an empty pad cancels the timer.
3. A friends-only pad accepts only Roblox friends of the host. An open-fill pad accepts anyone in the lobby until the timer ends.
4. When the timer ends, the server reserves a private server of the same place and teleports the party with teleport data: mode `run`, a world seed and the party member list. The run server validates that data and refuses anything else.
5. If teleporting fails, the party returns to the lobby and the pad resets.
6. When a run ends, everyone sees a summary screen (days survived, kills, coins earned), stats and achievements are saved, and the party is teleported back to the lobby.
