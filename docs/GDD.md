# Arctic Survival: Game Design Document

Nov 17, 2026 · @Caden

## Overview

Arctic Survival is a co-op survival game for 1-6 players: gather, craft and fortify around a campfire in a freezing world, and last as many days as you can. Players queue from a 15-player lobby, are teleported to a private run server, and each run builds a new world from modular chunks.

Design pillars:

- **The fire is home.** Warmth, safety and crafting all radiate from the campfire, and keeping it fed is the central chore.
- **Greed against cold.** The best rewards sit far from camp, and the cold, the night and the mobs punish leaving unprepared.
- **Co-op first.** Shared recipes, shared chests, revives and pings. Players only hurt each other with stray projectiles.
- **Every run differs.** Chunk layout, camp site, points of interest and loot reshuffle from a seed.
- **Reliable before big.** The server decides everything, the target is 30+ FPS on a mid-range phone, and delivery is phased.

## Decisions at a glance

Every choice below is locked unless it appears under Open items.

| Area | Decision |
| --- | --- |
| Run goal | Endless. The score is max days survived |
| Day length | About 6 minutes of real time per in-game day |
| Blizzards | Every 4-5 days (randomized), with a warning period. Each is longer and colder than the last, with reduced visibility and extra mobs |
| Party | 1-6 players. Each pad is friends-only or open-fill |
| Death | Downed, and teammates can revive within a time limit. The run ends when everyone is down or dead. A solo run ends on death |
| Disconnect | Character held for about 5 minutes for rejoin, then counted as dead |
| Meters | Health, warmth, hunger |
| Campfire | Needs fuel. Upgrades widen the warm radius and extend burn time. It repels most hostiles at its edge |
| Food | Raw and cooked. Cooking at a fire or station restores more and adds a short buff |
| Gathering | Tool-gated resource nodes by tier, with slow respawn |
| Crafting | Workbench tiers. Recipes are shared by the whole party |
| Durability | Tools and weapons wear out and are repaired at a workbench with materials |
| Clothing | Tiers give cold resistance and gate the far biomes |
| Inventory | Personal hotbar plus placeable shared team chests |
| Building | Snap-to-grid placement, about 12 structures |
| Camera and combat | Third-person, simple melee and ranged. Mobile gets a context action button and aim assist |
| Friendly fire | Projectiles only |
| Mobs | 8+ types: day wildlife, night hostiles, mini-bosses in far biomes, a blizzard boss at camp |
| Difficulty | Scales with days survived and party size |
| World | About 2-3k studs square, \~64 chunks, 4 biomes in concentric rings, chunks assembled per run from a seed |
| Camp | Random site inside the start forest, with guaranteed nearby wood and food |
| Points of interest | Random per chunk, with loot tiers that rise with distance from camp |
| Lobby | Same place in lobby mode, 15 players, six pads (1-6), shared 20 s timer, global leaderboard and personal stat board, emotes, cosmetic mirror |
| Meta-progression | Stats, 20-30 achievements with coin rewards, coins, unlockable starter gear |
| Shop | Cosmetics, starter gear tiers, capped run-start perks (one equipped). Paid with coins or Robux packs, plus a few Robux-only cosmetics |
| Retention | Daily login reward only |
| Navigation and comms | Roblox chat plus a ping wheel, compass to camp, craftable fog-of-war map |
| Look and sound | Low-poly stylized parts. Wind, fire crackle, music cues, storm effects |
| Tutorial | Contextual hints during the first run |
| Data | ProfileStore, server-authoritative gameplay and purchases |
| Performance | 30+ FPS on a mid-range phone, with streaming and capped mob and part counts |

## System specs

Design detail lives in one spec per system (each starts with a 3-line summary):

- [Lobby and party](specs/lobby-party.md)
- [Run loop](specs/run-loop.md)
- [Survival systems](specs/survival.md)
- [Combat, mobs and bosses](specs/combat-mobs.md)
- [Horror and tension](specs/horror.md)
- [World generation](specs/world-gen.md)
- [Meta-progression, shop and engagement](specs/meta-shop.md)
- [UI, controls and performance](specs/ui-perf.md)

Implementation specs (per built system) live in docs/systems/.

## Architecture and build plan

The orchestrator builds in four phases, each ending at a playable gate. The kit's existing modules (Config, Assets, Remotes, Guard, DataService, ProfileSchema, SpawnService) are reused and extended.

**One place, two modes.** A `RunService` reads the teleport data at startup and starts either lobby mode or run mode, so one Rojo project and one place file cover both.

**Server services to add.** PartyService, ChunkService, DayNightService, SurvivalService, FireService, InventoryService, CraftingService, BuildingService, MobService, BossService, StalkerService, EventService, ShopService and AchievementService. Each owns its state and exposes validated requests through Remotes and Guard. The client renders state and sends requests only.

&#91;embedded content: build roadmap · 4 phases, 4 gates\]

Phase 1 is accented because it proves the core loop before anything depends on it. Phase 1 also includes the chunk system with forest chunks only, so the world architecture is right from the start.

## Build efficiency

Catch bugs with headless tests and debug commands, not playtests, and keep every agent's context small. This is Phase 0, and it comes before Phase 1.

- **Test without Studio.** Keep game logic in pure Luau modules with thin Roblox adapters so `tests/run.luau` can run it. Add a headless simulation (100 days, fixed seed) that asserts meters never go negative, caps hold and the same seed gives the same result. Each system adds its part to it as it lands.
- **Debug layer.** A Studio-only DebugService to set the day, fast-forward the clock, force a blizzard or dark event, summon the Stalker, go invincible and teleport to a ring. Scenarios in `tools/qa/` print 5 to 8 structured PASS/FAIL lines, so agents never need screenshots.
- **Small contexts.** One spec file per system under `docs/specs/`, with each brief naming only the specs it needs. Keep `CLAUDE.md` short and stable, cap reports at 8 lines and filter MCP output to errors and prints.
- **Right model per task.** The strongest model for architecture, the orchestrator and phase reviews. A mid-tier model for most implementation. The cheapest model for mechanical work such as adding rows to item, recipe and mob tables.
- **Data-driven content.** Mobs, items, recipes, achievements and shop entries are data tables with shared behaviors, so adding content means adding rows.
- **Avoid rework.** Contracts first (Config and Remotes), then parallel agents with exclusive file ownership. Each agent stops and reports after 3 failed check runs. One review per phase on the diff.
- **Human playtests.** A 15-minute hands-on playtest at each phase gate judges feel and fear. Agents run smoke tests only.
- **Delay costly work.** Block art and free assets until Phase 4, and delay the shop and Robux until the loop is proven fun.

**Phase 0 brief**

```
From: PM (coordinating agents). Do NOT commit or push.
Read CLAUDE.md and docs/GDD.md (Build efficiency) only.
Task:
1. Split docs/GDD.md into one spec file per system under docs/specs/ (lobby-party, run-loop, survival, combat-mobs, horror, world-gen, meta-shop, ui-perf), each starting with a 3-line summary. Keep GDD.md as the index and update CLAUDE.md to point at docs/specs/.
2. Add DebugService, active only in Studio and inert on published servers: set day, fast-forward clock, force blizzard, force dark event, summon and dismiss the Stalker, invincibility, teleport to a ring.
3. Extend tools/qa/ with a scenario runner that prints <=8 structured PASS/FAIL lines per scenario.
4. Add tests/sim.luau: a headless fixed-seed simulation harness with a clock and seeded RNG, ready for each system to plug into.
Done when: scripts/check.sh passes. Report <=8 lines.
```

## Phase 1 agent briefs

Save this document as `docs/GDD.md` in the repo first. Run brief 1 alone, because every other brief depends on its constants and remote names. Briefs 2 to 6 can then run in parallel, one agent each, and each must pass `scripts/check.sh` before reporting.

**Brief 1: contracts**

```
From: PM (coordinating agents). Do NOT commit or push.
Read CLAUDE.md and docs/GDD.md (Decisions at a glance) only.
Task: add all gameplay constants to Config (day length, day/night split, meter drain rates, fire radius and burn time, mob budget, scaling factors) with a comment per value. Declare every Phase 1 remote in Remotes: meters update, inventory update, craft request, place request, gather request, attack request.
Done when: scripts/check.sh passes. Report <=6 lines: names added, anything ambiguous.
```

**Brief 2: world generation**

```
From: PM (coordinating agents). Do NOT commit or push.
Read CLAUDE.md and docs/GDD.md (World generation) only.
Task: build ChunkService on the server. One seed -> deterministic layout on an 8x8 grid. Phase 1 uses start-forest chunk variants only, with slots for trees, rocks and spawn zones. Choose the camp site inside the forest ring with wood and food nearby. Stream chunks in and out around players.
Done when: scripts/check.sh passes and the same seed twice gives the same layout (add a test). Report <=8 lines.
```

**Brief 3: survival core**

```
From: PM (coordinating agents). Do NOT commit or push.
Read CLAUDE.md and docs/GDD.md (Run loop, Survival systems) only.
Task: server-side DayNightService (day counter, day and night) and SurvivalService (health, warmth, hunger per player, drains from Config). Campfire: fuel, burn time, warm radius, adding wood. Downed state and revive. Send meter updates through Remotes.
Done when: scripts/check.sh passes and tests cover warmth drain inside and outside the radius. Report <=8 lines.
```

**Brief 4: items, gathering and crafting**

```
From: PM (coordinating agents). Do NOT commit or push.
Read CLAUDE.md and docs/GDD.md (Survival systems) only.
Task: server-side InventoryService (hotbar plus slots), gathering nodes gated by tool tier with slow respawn, and CraftingService with workbench tiers 0 and 1. Include wood, stone, an axe, a pickaxe, a spear and the workbench. Validate every request on the server through Guard.
Done when: scripts/check.sh passes and tests cover crafting without enough materials. Report <=8 lines.
```

**Brief 5: mobs**

```
From: PM (coordinating agents). Do NOT commit or push.
Read CLAUDE.md and docs/GDD.md (Combat, mobs and bosses) only.
Task: MobService with a spawn budget near players, AI that runs only near players, and three mobs: arctic hare (flees), caribou (flees), wolf (hunts at night, repelled at the fire edge). Mob health, damage and spawn constants come from Config. Handle melee damage requests from players.
Done when: scripts/check.sh passes and no mob AI runs with no player nearby (add a test). Report <=8 lines.
```

**Brief 6: HUD**

```
From: PM (coordinating agents). Do NOT commit or push.
Read CLAUDE.md and docs/GDD.md (UI, controls and performance) only.
Task: client HUD with health, warmth and hunger bars, day counter, hotbar, compass to camp, and a mobile context action button. Contextual first-run hints. Read-only: the client only reads state from Remotes and sends requests.
Done when: scripts/check.sh passes. Report <=6 lines, including anything that needs a Studio check.
```

## Open items

These are not decided yet. The orchestrator should use sensible defaults, keep each one in Config or a data file, and flag it in its report.

- Day/night split within the 6-minute day.
- Whether a pad that fills to its chosen size starts early.
- Revive time limit and revive health.
- Mob stats, final names and the exact boss mechanics.
- The 20-30 achievements and their coin values.
- Coin payout formula per run, and shop prices.
- Robux pack sizes and prices, and which cosmetics are Robux-only.
- Perk list and the cap on what a perk can do.
- Exact chunk size and the number of variants per biome.
- Source of art and audio assets (own builds, free library or purchased).
- The list of first-run hints.
- Clothing tier count and the cold resistance each gives.

* Stalker tuning: hunt frequency, Dread rates, damage and knockback values, and retreat timing.
* Which engagement features beyond the daily reward, achievements and coins ship in v1.
