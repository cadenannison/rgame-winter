# Spec: Run loop

- A run starts at the campfire on day 1 and ends when the whole party is down or dead.
- Covers day/night, warmth, blizzards, down and revive, disconnects, run end.
- Nothing but account-level data carries between runs.

Source: split from docs/GDD.md. Index: docs/GDD.md.

## Run loop

A run starts with every player standing at the campfire on day 1, and ends when the whole party is down or dead. The day counter is the score.

- **Day and night.** One in-game day lasts about 6 minutes of real time. The day/night split is a Config constant. Gathering, hunting and scavenging happen by day, and hostile mobs come out at night.
- **Warmth.** Warmth drains whenever a player is outside the fire radius at night, during a blizzard, or in a cold far biome. Clothing tier reduces the drain. Standing in the fire radius or near a sleeping bag stops it.
- **Blizzards.** One hits every 4-5 days (the interval is randomized), announced by a warning period. Each blizzard lasts longer and is colder than the last, cuts visibility and brings extra mobs. Some blizzards bring the blizzard boss to camp. Players are expected to shelter inside the fire radius.
- **Down and revive.** At zero health a player is downed if a teammate can still act; a solo player (or the last one standing) dies immediately. A downed player lies prone and crawls slowly (no ragdoll, no joints break, no jumping) with a Config.Downed.BleedoutSeconds window. A teammate within Config.Downed.ReviveRange holds the Revive prompt (hold E on PC, hold the on-screen button on phone) for Config.Downed.ReviveSeconds; letting go, walking off, or either side going down/dead cancels it. Revive restores a fraction of health.
- **Death and spectating.** When the window expires, or no teammate is left to revive them, the player is dead: the body stays where it fell and the player spectates living teammates (Prev/Next, Z). Falling below Terrain.KillHeight (or the world edge, via SurvivalService.killOutright) ends a player outright: no downed window, not revivable.
- **After death.** A "Return to lobby" button is always available once dead (leaving early pays out the run so far). At run end the summary offers "Play again" and "Return to lobby"; both go through the TeleportAdapter (in Studio the call is recorded and the player stays).
- **Disconnects.** The character and inventory are held for about 5 minutes so the player can rejoin the same run. After that, they count as dead.
- **Run end.** When every player is down or dead, the run closes: final day count is recorded, coins are awarded, and the party returns to the lobby (see Lobby and party flow).
- **Fresh sessions.** Nothing from a run carries into the next one except the account-level stats, achievements, coins and unlocks.
