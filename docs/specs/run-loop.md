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
- **Down and revive.** At zero health a player is downed. A teammate can revive them inside a time limit. A solo player dies immediately.
- **Disconnects.** The character and inventory are held for about 5 minutes so the player can rejoin the same run. After that, they count as dead.
- **Run end.** When every player is down or dead, the run closes: final day count is recorded, coins are awarded, and the party returns to the lobby (see Lobby and party flow).
- **Fresh sessions.** Nothing from a run carries into the next one except the account-level stats, achievements, coins and unlocks.
