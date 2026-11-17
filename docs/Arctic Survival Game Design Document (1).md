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

## Lobby and party flow

The lobby is the same place as the run server, started in lobby mode. It is an enclosed arctic lodge for up to 15 players per server, with a shop, a global max-days leaderboard, a personal stat and achievement board, a cosmetic preview mirror and emotes.

1. A player steps onto one of six glowing pads, marked 1 to 6 players. The first player on a pad is its host and sets it to friends-only or open-fill.
2. A 20-second timer starts when the first player steps on. It resets to 20 when another player joins. Stepping off removes the player, and an empty pad cancels the timer.
3. A friends-only pad accepts only Roblox friends of the host. An open-fill pad accepts anyone in the lobby until the timer ends.
4. When the timer ends, the server reserves a private server of the same place and teleports the party with teleport data: mode `run`, a world seed and the party member list. The run server validates that data and refuses anything else.
5. If teleporting fails, the party returns to the lobby and the pad resets.
6. When a run ends, everyone sees a summary screen (days survived, kills, coins earned), stats and achievements are saved, and the party is teleported back to the lobby.

## Run loop

A run starts with every player standing at the campfire on day 1, and ends when the whole party is down or dead. The day counter is the score.

- **Day and night.** One in-game day lasts about 6 minutes of real time. The day/night split is a Config constant. Gathering, hunting and scavenging happen by day, and hostile mobs come out at night.
- **Warmth.** Warmth drains whenever a player is outside the fire radius at night, during a blizzard, or in a cold far biome. Clothing tier reduces the drain. Standing in the fire radius or near a sleeping bag stops it.
- **Blizzards.** One hits every 4-5 days (the interval is randomized), announced by a warning period. Each blizzard lasts longer and is colder than the last, cuts visibility and brings extra mobs. Some blizzards bring the blizzard boss to camp. Players are expected to shelter inside the fire radius.
- **Down and revive.** At zero health a player is downed. A teammate can revive them inside a time limit. A solo player dies immediately.
- **Disconnects.** The character and inventory are held for about 5 minutes so the player can rejoin the same run. After that, they count as dead.
- **Run end.** When every player is down or dead, the run closes: final day count is recorded, coins are awarded, and the party returns to the lobby (see Lobby and party flow).
- **Fresh sessions.** Nothing from a run carries into the next one except the account-level stats, achievements, coins and unlocks.

## Survival systems

Three meters drive survival: health, warmth and hunger. Warmth and hunger tick down over time. Health falls when either reaches zero or when a player is attacked, and recovers slowly while both are healthy.

**Campfire.** It needs wood as fuel and goes out without it. Upgrades widen the warm radius and extend burn time. Most hostiles are repelled at the edge of the radius, though ranged and heavy mobs can break through. Extra campfires can be built elsewhere.

**Food.** Players hunt animals and forage for raw food. Cooking at a campfire or cooking station restores more hunger and adds a short buff. Raw food restores little or carries a downside.

**Gathering.** Trees, rocks and ore are resource nodes that need the right tool tier. Nodes respawn slowly. Far biomes hold higher-tier nodes.

**Crafting.** Crafting runs in workbench tiers: tier 0 by hand, tier 1 at the workbench, tier 2 at the forge. Recipes are shared by the whole party. Clothing comes in tiers that cut warmth drain, and the far biomes are cold enough that low tiers cannot survive there.

**Durability.** Tools and weapons wear out with use. Repair at a workbench costs materials.

**Inventory.** Each player has a small hotbar and limited slots. Placeable team chests at camp provide shared storage.

**Structures (about 12 in v1).**

1. Workbench
2. Forge
3. Cooking station
4. Storage chest
5. Wall
6. Door
7. Spike trap
8. Watchtower
9. Sleeping bag or bed, which stops warmth drain for players near it
10. Extra campfire
11. Campfire upgrades
12. Map table, which crafts the fog-of-war map

Structures snap to a grid. The server validates every placement.

## Combat, mobs and bosses

Combat is third-person with simple tool-based melee (spear, axe) and ranged (bow) weapons. Only projectiles can hit teammates. On mobile, one context action button attacks, gathers or interacts depending on the target, and ranged weapons get aim assist.

**Roster (proposed names, all tunable).**

| Type | Mobs |
| --- | --- |
| Huntable animals (3) | Arctic hare, caribou, fish |
| Hostiles (5) | Wolf, polar bear, ice wraith (ranged), snow lurker (ambusher), cave crawler |
| Mini-bosses (3) | One guardian in each far biome (frozen lake, mountains and caves, deep tundra). They spawn later in the run and can be killed |
| Blizzard boss (1) | Attacks camp during selected blizzards |

**Behavior.** Animals roam by day and flee. Hostiles hunt players at night and during blizzards. Fire radius repels most of them. Ranged and heavy mobs and the bosses can break through, so walls, traps and weapons matter.

**Spawning.** The server keeps a capped spawn budget around players. Mobs spawn and despawn near players, and their AI runs only when a player is close. Nothing is pre-spawned across the whole map.

**Scaling.** Mob count, health and spawn rate rise only gradually with days survived and distance from camp, and each has a ceiling so exploration never becomes impossible. A party-size factor keeps solo play fair and larger parties challenged. All constants live in Config.

## Horror and tension

The horror is subtle: dread, not gore. It stays PG with no blood, and a scare budget keeps the effects rare enough to stay unsettling.

**The Stalker.** Each run has one tall, pale snow creature that lurks beyond the firelight.

- A per-party Dread value rises when players are far from camp, alone, in the dark or in a blizzard, and falls near fire.
- Higher Dread raises the chance of a hunt. There are no hunts on day 1, and a cooldown follows every hunt.
- When a hunt starts, the Stalker picks its target by isolation: a player alone is the most likely, a pair is next, and players traveling in a large group are rarely chosen.
- It always telegraphs: wildlife goes silent, frost creeps in at the screen edges, snow crunches behind the player and nearby fires gutter. Players who read the signs can run for a warm spot or light a torch.
- It never enters a campfire radius or warm spot and backs off from torches and flares. A hit deals moderate damage, knocks the player back and drops warmth sharply, but never kills from full health. The Stalker then retreats for a short time, giving the player a window to run, and teammates can revive anyone who goes down.
- It can never be killed, unlike the later mini-bosses. It is a pressure system meant to scare players and push them back toward camp, much like the leviathans in Subnautica. Torches and flares end a hunt sooner.

**Small scares with no enemy.** Phantom footsteps behind you (audio only), a silhouette at the tree line that is gone when you look again, a shadow passing the edge of the fire at night, cracking ice on the frozen lake, whispers or radio static in the tundra ruins, and frozen campsites with found notes that hint at earlier survivors.

**Lurkers (always just out of sight).** Ambient creatures that are never seen clearly and never attack directly. They make the world feel watched, and each one changes how players move or light their way. They vanish when approached or looked at head-on.

- **Tree watchers (forest).** Tall shapes standing between distant trees. Seeing one raises Dread, so lingering far from camp makes a Stalker hunt more likely.
- **Ice scratchers (frozen lake).** Scratching and thumping from beneath the ice. Marked thin-ice patches near them crack and drop players into freezing water, which costs warmth, so players learn to route around them.
- **Eyes in the dark (caves).** Pairs of glowing eyes that back away from torchlight. If a torch runs out, they close in and Dread rises quickly, so players must carry fuel.

**Dark events.** Random events that change the rules for a few minutes. They never overlap with a blizzard, have a minimum gap between them, start no earlier than day 3 and become only slightly more frequent as the day count rises, up to a hard cap. Each has a short warning, such as birds falling silent or the light flickering.

- **False night.** The sky goes dark in the middle of the day. Night rules apply: faster warmth drain, night hostiles spawn, vision drops and Dread climbs. Players must rush back to camp or light lanterns.
- **The quiet.** All sound stops and wildlife vanishes for a minute, then the Stalker's hunt chance spikes. It is a cue to get near fire.
- **Deep freeze.** Fires burn fuel faster and warmth drains faster until it passes, so players need a stockpile of wood.

Surviving a dark event counts toward achievements and pays a small coin reward. Lanterns and torches are the counter-play.

**Scare budget.** Cooldowns and per-day caps limit the phantom effects. None fire while players shelter in a blizzard, and a setting reduces audio and visual scares. All frequencies live in Config.

**Gentle scaling.** Danger rises slowly, not steeply. Dread gain, Stalker hunt chance, dark-event frequency, lurker density and mob spawn rates grow only slightly with days survived and with depth into the world, and each has a hard cap in Config. The goal is pressure that deters progress and stretches a run out, not a wall that makes exploring impossible. Every scary system keeps its counter-play at every depth: warm spots, fuel, torches and the fire radius. The tuning rule is that a prepared party can always reach the deepest ring, and an unprepared one pays heavily for trying.

**Hidden metrics, cues only.** Dread, hunt chance, event timers and every other danger value are never shown to players. There is no bar and no number. Players read the world instead: as Dread rises, ambient sound thins and a low rumble builds, the screen edges desaturate and frost creeps in, wildlife goes quiet and fires gutter. Cues strengthen with danger and fade as it passes, and each dark event has its own audio and lighting tell.

**Lone players are the prey.** Isolation decides who the horror picks.

- Each player gets an isolation weight from how many teammates are within range. A player alone has the highest weight, a pair a lower one, and a larger group much lower.
- The Stalker, lurkers and phantom scares are weighted by isolation, so a lone player is the most likely target of all of them.
- A full group traveling together (the whole party within range) prevents the bigger events: Stalker hunts, false night and the quiet. Ambient scares such as phantom footsteps can still happen to a group, just rarely.
- Bigger events roll against the most isolated player, so they only fire when someone has strayed.
- In a one-player party, the isolation weight uses a reduced solo baseline from Config, so solo runs are tense but not harsher than a duo or a group.

**Build phase.** The Stalker, Dread and its tells land in Phase 3. The lurkers and dark events land in Phase 3 once Dread exists. The small scares and audio polish land in Phase 4.

## World generation

The world is a square of about 2-3k studs, built from roughly 64 hand-built modular chunks (an 8 by 8 grid, so about 300-400 studs per chunk) and assembled differently each run from a seed.

- **Seed.** The server picks one seed at run start. The same seed decides the chunk layout, camp site, points of interest and resource placement, so every player in the party sees the same world.
- **Biomes in rings.** Four biomes sit in concentric rings around the map center: snowy forest (start), frozen lake, mountains and caves, then deep tundra with ruins at the edge. Cold, mob strength and loot tier rise with each ring.
- **Chunks.** Each biome has several chunk variants with slots for resource nodes, points of interest and spawn zones. The generator picks variants by seed and rotates them to avoid repetition.
- **Streaming.** Chunks load around players and unload behind them, and Roblox StreamingEnabled handles replication to clients. The server never builds the whole map at once.
- **Camp.** The camp site is random inside the start forest, with guaranteed wood and food within a short walk.
- **Points of interest.** Each chunk can host slots for abandoned cabins, crashed planes, caves and similar. Loot quality scales with distance from camp.
- **Determinism.** Given the same seed, generation produces the same world, which makes bugs reproducible.

* **Warm-up spots.** Three kinds exist out in the world: abandoned cabins with a hearth that needs wood and gives a small warm radius; hot springs in the mountain and tundra rings that are always warm but attract mobs; and player-built extra campfires and sleeping bags. Each stops warmth drain, and the Stalker will not enter them.

## Meta-progression, shop and saves

Only account-level data persists between runs. Everything about a run itself is discarded when it ends.

- **Stats.** Max days survived, total runs, mobs killed, bosses defeated and items crafted. Max days feeds the global leaderboard, and stats show on the lobby board and above a player's head.
- **Achievements.** About 20-30 across days survived, kills, bosses, crafting and co-op feats. Each pays coins and some grant titles.
- **Coins.** Earned at run end from days survived and achievements. Coins buy shop items.
- **Unlockable starter gear.** Milestone-based permanent unlocks, such as better starting coats or tools.
- **Shop.** Cosmetics (outfits, trails, camp decorations, pets), starter gear tiers and run-start perks. A player equips one perk per run, and perks are capped so none trivializes survival.
- **Robux.** Three coin pack sizes and a few Robux-only cosmetics. All purchases are handled server-side through MarketplaceService receipts.
- **Daily login reward.** The only retention feature in v1.
- **Saves.** ProfileStore holds the profile with a versioned schema. Every gameplay action and purchase is validated on the server, and the client can only send requests.

## Engagement and reward loops

These are proposed defaults. They layer short, medium and long reward cycles so there is always a next thing within reach.

**Every few seconds.**

- Juicy feedback: hit sparks, a resource pop, a satisfying craft chime and small popups.
- Variable loot: points-of-interest chests roll a rarity tier, with a glow and sound for rare drops.

**Every few minutes.**

- Expeditions: farther biomes pay better loot, so every trip is a visible risk against reward.
- Exploration: each biome shows percent explored, with lore notes to find.
- Tech ladder: new workbench and forge recipes unlock steadily.

**Every day.**

- A dawn banner ("Day N survived") with a small fanfare. Beating your personal best triggers a bigger moment, and the HUD shows "2 days to your record" when you are close.
- Surviving a blizzard counts as a milestone with a reward.

**Every run.**

- A summary where coins pay out even on a bad run, plus "what got you" and one tip. A one-tap re-queue keeps the loop short.
- Personal best and leaderboard rank change shown on the summary.

**Across runs.**

- Achievements and titles, cosmetic sets to collect, starter gear tiers, and the daily reward.
- A small coin bonus per friend in the party.

**Social.**

- Roles emerge (hunter, builder, cook) with small synergies such as shared meal buffs.
- A party camp name and banner, and a shareable run card.

**Guardrails.** Many players are young, so skip paid random boxes (Roblox also requires odds disclosure for them), avoid countdown pressure to buy, and keep every reward earnable by playing.

## UI, controls and performance

- **HUD.** Health, warmth and hunger bars, a day counter, a hotbar, a compass that always points to camp, and short contextual hints during a player's first run.
- **Map.** A craftable fog-of-war map reveals explored areas.
- **Comms.** Roblox chat plus a ping wheel with quick calls such as need wood, danger and help.
- **Mobile controls.** One large context action button (attack, gather or interact based on the target) and a tappable hotbar. Ranged weapons get aim assist.
- **Look and sound.** Low-poly stylized parts in a consistent cold palette. Ambient wind, fire crackle, music cues, snow particles, fog and lighting changes for night and blizzards.
- **Performance target.** 30+ FPS on a mid-range phone. StreamingEnabled is on, mob and part counts are capped, and chunks load and unload around players. Agents test against these limits.

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

## Phase 2 agent briefs

Phase 2 adds the lobby, parties, teleporting, run end and saves. Run brief 7 alone first, then briefs 8 to 10 in parallel, then the integration brief. Real teleporting cannot be tested in Studio, so briefs use a teleport adapter with a fake for tests, and the real teleport is checked by hand on a published place.

**Brief 7: contracts**

```
From: PM (coordinating agents). Do NOT commit or push.
Read CLAUDE.md and docs/specs/lobby-party.md, docs/specs/meta-shop.md only.
Task: add Phase 2 constants to Config (pad count 6, timer 20, rejoin window, revive time limit, coin payout placeholders). Declare remotes: pad join/leave, party state, run summary, daily claim. Extend ProfileSchema with maxDays, runs, kills, bossKills, crafted, coins, achievements, lastDailyClaim, with a version bump and a migration test. Define the teleport data schema (mode, seed, partyIds, version) and validate it in Guard.
Integration points: list every name other briefs must use in docs/INTEGRATION.md.
Done when: scripts/check.sh passes. Report <=6 lines.
```

**Brief 8: party and teleport**

```
From: PM (coordinating agents). Do NOT commit or push.
Read CLAUDE.md, docs/specs/lobby-party.md and docs/INTEGRATION.md only.
Task: RunService (reads teleport data at startup, starts lobby or run mode) and PartyService (six pads, shared timer that resets on join, friends-only or open-fill, reserved-server teleport behind a TeleportAdapter, return to lobby on failure). Run mode passes the seed to ChunkService.
Integration points: consumes the pad remotes; exposes RunService.mode and the party member list; calls ChunkService with the seed.
Done when: scripts/check.sh passes and tests cover the timer, join, leave and cancel logic with a fake adapter. Report <=8 lines.
```

**Brief 9: run lifecycle**

```
From: PM (coordinating agents). Do NOT commit or push.
Read CLAUDE.md, docs/specs/run-loop.md, docs/specs/survival.md and docs/INTEGRATION.md only.
Task: detect run end (all players down or dead), compute the summary (days, kills, coins) from Config, save stats through DataService, and send everyone back to the lobby via TeleportAdapter. Add revive with a time limit and the 5-minute disconnect hold and rejoin.
Integration points: consumes SurvivalService downed state and DayNightService day; exposes a RunEnded event.
Done when: scripts/check.sh passes and the sim covers a run ending with a mix of downed, dead and rejoined players. Report <=8 lines.
```

**Brief 10: lobby world and UI**

```
From: PM (coordinating agents). Do NOT commit or push.
Read CLAUDE.md, docs/specs/lobby-party.md, docs/specs/ui-perf.md and docs/INTEGRATION.md only.
Task: block-placeholder lobby lodge with six pads, a stat board, a max-days leaderboard (OrderedDataStore), a shop placeholder, and the daily reward claim with a UTC-day check. Client: pad and timer UI, run summary screen with a re-queue button, daily reward toast. Read-only client.
Integration points: consumes party state and summary remotes and ProfileSchema fields; exposes nothing new.
Done when: scripts/check.sh passes. Report <=8 lines, listing what needs a Studio check.
```

**Brief 11: integration**

```
From: PM (coordinating agents). Do NOT commit or push.
Run after briefs 8 to 10. Read CLAUDE.md and docs/INTEGRATION.md only.
Task: wire every integration point in docs/INTEGRATION.md end to end, with no new features. Add a tools/qa scenario "lobby-to-run" using the fake teleport adapter: queue a 2-player party, start a run, end it, check stats saved and both players returned. Move any leftover local constants to Config.
Done when: scripts/check.sh passes and the scenario passes via MCP. Report <=10 lines, including what needs a hand test on a published place.
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
