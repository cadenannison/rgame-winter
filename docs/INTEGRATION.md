# Integration contract (Phase 2)

Every name another brief must use. Brief 7 (contracts) owns the shared files this round:
`src/shared/Config.luau`, `src/shared/Remotes.luau`, `src/shared/logic/ProfileSchema.luau`,
`src/shared/logic/TeleportData.luau`, `src/server/Net/Guard.luau` and the `init.*` scripts.
Other briefs request changes to these through the PM; they do not edit them.

Briefs: 7 contracts, 8 party and teleport, 9 run lifecycle, 10 lobby world and UI, 11 integration.

Rules for consumers:
- Hidden metrics (anything not listed as shown) are never sent to or shown on the client.
- Asset ids are placeholders; list every new one in `docs/ART.md` and `shared/Assets.luau`.
- Real teleporting goes only through `TeleportAdapter` (fake in tests/Studio); the real path is hand-tested on a published place.
- Coin values in `Config.Meta` are placeholders pending balance.

## Modules

| name | owner brief | consumers |
|---|---|---|
| `src/shared/logic/TeleportData.luau` — `TeleportData.parse(data) -> (TeleportData?, reason?)`, `.build(mode, seed, partyIds) -> TeleportData?`, `.hasMember(data, userId) -> boolean` | 7 | 8, 9, 11 |
| `src/server/Net/Guard.luau` — `Guard.teleportData(player, data, expectedMode) -> TeleportData?` (run server refuses the player on nil) | 7 | 8, 9, 11 |
| `src/shared/logic/ProfileSchema.luau` — `Profile` type, `STAT_FIELDS`, `default`, `migrate`, `validate` | 7 | 9, 10 |
| `src/server/Data/DataService.luau` — `DataService.get(player) -> Profile?`, `DataService.onLoaded(cb)` (mutate the returned profile in place; never save elsewhere) | existing | 9, 10 |
| `src/server/Party/TeleportAdapter.luau` — `TeleportAdapter.teleportParty(players, data: TeleportData) -> (boolean, string?)`, `TeleportAdapter.setImpl(fake)` for tests | 8 | 9 (return to lobby), 11 |
| `src/server/Party/PartyService.luau` — pad state, timer, friends check, launch; fires `Remotes.PartyState` | 8 | 10, 11 |
| `src/shared/logic/PadLogic.luau` — pure pad state machine (join/leave/mode/timer) | 8 | 8, 10 |
| `src/server/Run/RunLifecycleService.luau` — run start from teleport data, rejoin window, run end, summary, stat save, return to lobby (not `RunService`: clashes with the Roblox service) | 9 | 11 |
| `src/shared/logic/RunPayout.luau` — pure coin payout from run results and `Config.Meta` | 9 | 9, 10 |
| `src/server/Meta/DailyRewardService.luau` — handles `DailyClaimRequest` using `profile.lastDailyClaim` | 9 | 10 |
| `tools/build_lobby.luau` — idempotent lodge + pads builder (tags pads `Config.Lobby.PadTag`) | 10 | 8, 11 |
| `src/client/Lobby/` — pad UI, party list, summary screen, daily claim button | 10 | 11 |
| `src/server/init.server.luau` — boots lobby vs run mode and sets `Workspace[Config.Teleport.ServerModeAttribute]` | 7 (file) / 11 (wiring) | all |

## Remotes (`src/shared/Remotes.luau`; payload types exported there)

| name | owner brief | consumers |
|---|---|---|
| `PadJoinRequest` client -> server, `PadJoinPayload { padIndex: number }` | 7 | 8 (handler), 10 (sender) |
| `PadLeaveRequest` client -> server, no payload | 7 | 8 (handler), 10 (sender) |
| `PadModeRequest` client -> server, `PadModePayload { mode: string }` (host only) | 7 | 8 (handler), 10 (sender) |
| `PartyState` server -> client, `PartyStatePayload { pads: { PadState } }` full snapshot on change, never per tick | 7 | 8 (sender), 10 (UI) |
| `PadState { index, capacity, mode, hostId?, memberIds, endsAt?, launching }` (`endsAt` = `workspace:GetServerTimeNow()` time) | 7 | 8, 10 |
| `RunSummary` server -> client, `RunSummaryPayload { daysSurvived, kills, bossKills, coinsEarned, personalBest, newAchievements, cause?, tip? }` | 7 | 9 (sender), 10 (UI) |
| `DailyClaimRequest` client -> server, no payload | 7 | 9 (handler), 10 (sender) |
| `DailyClaimResult` server -> client, `DailyClaimResultPayload { ok, coins, nextClaimAt }` | 7 | 9 (sender), 10 (UI) |
| `Notify` server -> client (kind, text) for generic errors such as "Teleport failed" | existing | 8, 9, 10 |

Handler order for every request: type-check -> range -> `Guard.rateLimit` (`Config.Net.*`) -> permission/state -> act.

## Config keys (`src/shared/Config.luau`)

| name | owner brief | consumers |
|---|---|---|
| `Lobby.MaxPlayers` (15), `Lobby.PadCount` (6; pad i holds i), `Lobby.PadTimerSeconds` (20) | 7 | 8, 10 |
| `Lobby.PadModeFriends` ("friends"), `Lobby.PadModeOpen` ("open"), `Lobby.DefaultPadMode` | 7 | 8, 10 |
| `Lobby.PadTag` (CollectionService tag), `Lobby.PadIndexAttribute` (pad part attr), `Lobby.PlayerPadAttribute` (Player attr, 0 = none) | 7 | 8, 10 |
| `Lobby.FriendCheckTimeout`, `Lobby.PollInterval`, `Lobby.PadEdgeMargin`, `Lobby.PadHeightMargin`, `Lobby.PadJoinLift`, `Lobby.LaunchHoldSeconds`, `Lobby.RootName`, `Lobby.SpawnName`, `Lobby.StatPublishSeconds`, `Lobby.Leaderboard*`, `Lobby.NameCacheMax` | 7 / 11 | 8, 10 |
| `Run.RejoinWindowSeconds` (300, single source; revive limit is `Downed.BleedoutSeconds`), `Run.SummarySeconds`, `Run.ReturnRetryCount`, `Run.PollInterval`, `Run.SeedWaitSeconds`, `Run.ReturnFailedMessage`, `Run.RefusedMessage`, `Run.DefaultCause` | 7 / 11 | 9 |
| `Teleport.DataVersion`, `Teleport.ModeRun` ("run"), `Teleport.ModeLobby` ("lobby"), `Teleport.MaxSeed`, `Teleport.MaxPartySize` | 7 | 8, 9 |
| `Teleport.ServerModeAttribute` (Workspace attr "ServerMode"), `Teleport.StudioDefaultMode`, `Teleport.ModeWaitSeconds`, `Teleport.RetryCount`, `Teleport.RetryDelay` | 7 / 11 | 8, 9, 10, 11 |
| `Meta.CoinsPerRun`, `Meta.CoinsPerDaySurvived`, `Meta.CoinsPerKill`, `Meta.CoinsPerBossKill`, `Meta.CoinsPerFriendInParty`, `Meta.MaxCoinsPerRun` (placeholders) | 7 | 9 |
| `Meta.DailyRewardCoins` (claim once per UTC day; interval key removed in brief 11) | 7 | 9, 10 |
| `Meta.MaxStatValue`, `Meta.MaxAchievements`, `Meta.MaxAchievementIdLength` | 7 | 9 |
| `Net.PadRateInterval`, `Net.PadModeRateInterval`, `Net.DailyClaimRateInterval` | 7 | 8, 9 |
| `SchemaVersion` (2), `MaxCoins` | 7 | 9 |

## Teleport data schema (`TeleportData`, version 1)

| name | owner brief | consumers |
|---|---|---|
| `mode: string` — `Teleport.ModeRun` or `Teleport.ModeLobby` | 7 | 8, 9 |
| `seed: number` — integer in [0, `Teleport.MaxSeed`] | 7 | 8 (generates), 9 (world seed) |
| `partyIds: { number }` — dense, unique, positive UserIds, 1..`Teleport.MaxPartySize` | 7 | 8, 9 |
| `version: number` — must equal `Teleport.DataVersion` | 7 | 8, 9 |

No other keys are allowed; extra keys are refused. Read it on arrival with `player:GetJoinData().TeleportData` and pass it straight to `Guard.teleportData`.

## Profile schema fields (`ProfileSchema.Profile`, schemaVersion 2)

| name | owner brief | consumers |
|---|---|---|
| `coins` | existing | 9, 10 |
| `maxDays`, `runs`, `kills`, `bossKills`, `crafted` (integers, clamped to `Meta.MaxStatValue`) | 7 | 9 (writes), 10 (board) |
| `achievements: { [string]: boolean }` (id -> true, max `Meta.MaxAchievements`) | 7 | 9 (writes), 10 (board) |
| `lastDailyClaim` (os.time seconds, 0 = never) | 7 | 9 |

Any further field needs a schemaVersion bump, a `migrate` block and a migration test (request through the PM).

## Attributes and tags

| name | owner brief | consumers |
|---|---|---|
| Workspace `ServerMode` (`Teleport.ServerModeAttribute`): "lobby" or "run" | 7 (name) / 11 (sets) | 8, 9, 10 |
| Player `PadIndex` (`Lobby.PlayerPadAttribute`): current pad, 0 = none | 7 (name) / 8 (sets) | 10 |
| Pad part `PadIndex` (`Lobby.PadIndexAttribute`) and tag `LobbyPad` (`Lobby.PadTag`) | 7 (name) / 10 (builds) | 8 |

## Events

| name | owner brief | consumers |
|---|---|---|
| `PartyService.onLaunch(callback(padIndex, players, data))` — fired after a successful teleport call | 8 | 11 |
| `RunLifecycleService.onRunEnded(callback(results))` — fired once at run end before summary | 9 | 11 |

## Phase 3/4 hooks

# Phase 3 contract (brief 12)

Briefs: 12 contracts, 13 WorldGen, 14 EventService, 15 StalkerService/Dread, 16 mobs/bosses, 17 structures/progression, 18 integration.
Brief 12 owned `Config.luau`, `Remotes.luau`, `ItemCatalog.luau`, `Assets.luau`, `data/Types.luau`, `init.*` this round. From now on, changes to those go through brief 18 or the PM. Briefs 13-17 never edit them. To add content, a brief edits the data file it owns, and `ItemCatalog` merges `data/Items`, `data/Recipes` and `data/Structures` at load.

Rules for every Phase 3 brief:
- **Hidden metrics stay on the server.** Dread, hunt chance, event timers, the lurker roll and the isolation weight must never appear in a remote payload, an Attribute, a client module or a print. The client only receives `Remotes.Cue` (a `kind`, plus an optional coarse `level` from 0 to `Cue.MaxLevel`, a `position` and an `event` id) and visible-state Attributes (`DarkEvent`, `Blizzard`, `BlizzardWarning`). `tests/DataTests.luau` checks the names.
- **Every scaling value has a hard cap in Config.** Scaling by day, ring or party size must clamp to its `Max*` key. Data files must stay inside the caps, and `DataTests` enforces this.
- **Players never damage each other**, with one exception: a stray projectile deals `Projectile.FriendlyFireMultiplier` times its damage. `Projectile.MeleeFriendlyFire` is false. Traps hurt only mobs.
- **Handler order** is type-check, then range check, then `Guard.rateLimit(Config.Net.*)`, then permission/state, then the action. Every request validates its Instance argument (tag, ancestry, distance).
- **Asset ids are placeholders** (`""`). They are listed in `docs/ART.md`.
- **Profile schema is unchanged** (still v2). Explored map cells, storage contents, buffs and Dread are per-run server state and are never saved.
- **Each brief has a server boot hook and a client boot hook.** Brief N fills its own `src/server/Phase3/<X>Boot.luau` and `src/client/Phase3/<X>Client.luau`. `init.*` already calls them in run mode.
- **Each brief owns one test file**, already registered in `tests/run.luau`.
- **Cross-brief calls go through the public APIs below.** A brief whose dependency is not there yet uses a nil-safe setter (`setXProvider(fn)`); brief 18 does the wiring.

## Exclusive file ownership (parallel-safe)

| brief | owns (edit only these; new files under these paths) |
|---|---|
| 13 WorldGen | `src/shared/data/Biomes.luau`, `src/shared/data/Chunks.luau`, `src/shared/logic/WorldLayout.luau`, new `src/shared/logic/BiomeLogic.luau`, new `src/shared/logic/FogMap.luau`, `src/server/World/*` (ChunkService, new BiomeService, new MapService), `src/server/Phase3/WorldGenBoot.luau`, `src/client/Phase3/WorldGenClient.luau`, new `src/client/Map/*`, `tests/WorldTests.luau`, `tests/BiomeTests.luau`, `docs/systems/world-gen.md`, new `tools/qa/biomes.luau` |
| 14 EventService | `src/shared/data/Events.luau`, new `src/shared/logic/EventSchedule.luau`, new `src/server/Events/*` (EventService: dark events + blizzard), `src/server/Phase3/EventsBoot.luau`, `src/client/Phase3/EventsClient.luau`, new `src/client/Events/*`, `tests/EventTests.luau`, new `docs/systems/events.md`, new `tools/qa/events.luau` |
| 15 Stalker/Dread | `src/shared/data/Lurkers.luau`, new `src/shared/logic/DreadLogic.luau`, new `src/shared/logic/Isolation.luau`, new `src/server/Horror/*` (DreadService, StalkerService, LurkerService), `src/server/Phase3/HorrorBoot.luau`, `src/client/Phase3/HorrorClient.luau`, new `src/client/Horror/*`, `tests/HorrorTests.luau`, new `docs/systems/horror.md`, new `tools/qa/horror.luau` |
| 16 mobs/bosses | `src/shared/data/Mobs.luau`, `src/shared/logic/MobAI.luau`, `src/shared/logic/MobRules.luau`, new `src/shared/logic/MobScaling.luau`, new `src/shared/logic/Projectile.luau`, `src/server/Mobs/*` (MobService, new BossService), new `src/server/Combat/*` (ProjectileService), `src/server/Phase3/MobsBoot.luau`, `src/client/Phase3/MobsClient.luau`, new `src/client/Combat/*`, `tests/MobTests.luau`, `tests/NightTests.luau`, `docs/systems/mobs.md`, new `tools/qa/mobs3.luau` |
| 17 structures/progression | `src/shared/data/Items.luau`, `Recipes.luau`, `Structures.luau`, `Clothing.luau`, `Food.luau`, `src/shared/logic/{Inventory,Crafting,Consume,Placement,ItemsGather}.luau`, new `src/shared/logic/{Storage,Repair,Cooking,Buffs,ClothingLogic,Ping}.luau`, `src/server/Items/*` (existing + new StorageService, RepairService, CookingService, BuffService, ClothingService, StructureService), new `src/server/Social/PingService.luau`, `src/server/Phase3/ProgressionBoot.luau`, `src/client/Phase3/ProgressionClient.luau`, `src/client/HUD/*`, new `src/client/Storage/*`, new `src/client/Ping/*`, `tests/{ItemTests,PlacementTests,ConsumeTests,ProgressionTests}.luau`, `docs/systems/items-crafting.md`, new `tools/qa/progression.luau` |
| 18 integration | everything else: `Config.luau`, `Remotes.luau`, `ItemCatalog.luau`, `Assets.luau`, `data/Types.luau`, `init.*`, `src/server/Survival/*` (SurvivalService, FireService, DayNightService), `src/server/Run/*`, `src/server/Debug/*`, `src/shared/logic/{SurvivalLogic,FireLogic,DayClock,LightingMath,RunPayout,DebugCommands,ProfileSchema}.luau`, `tests/{SimTests,FlowTests,PlayabilityTests,DataTests,run}.luau`, `tests/sim.luau`, `tools/qa/*` (existing), `docs/{STATUS,KNOWN_ISSUES,ARCHITECTURE,DECISIONS,ART}.md` |

Briefs 13-17 do not edit `docs/ART.md`, `DECISIONS.md` or `KNOWN_ISSUES.md`. They put those lines in their report, and brief 18 merges them. Each brief writes its new `docs/systems/<name>.md` before writing code.

## Data modules (`src/shared/data/`, pure, Lune-testable)

| name | owner brief | consumers |
|---|---|---|
| `data/Types.luau`: `ItemDef`, `Recipe`, `StructureDef`, `NodeDef`, `BiomeDef`, `ChunkVariant`, `EventDef`, `BlizzardDef`, `MobDef`, `LurkerDef`, `ClothingTier`, `BuffDef`, `CookDef`, `Stack` | 12 (18 after) | all |
| `data/Biomes.luau`: `List` (index = ring+1, rings 0..3: SnowyForest, FrozenLake, MountainsCaves, DeepTundra; Chebyshev radii, coldSeverity, requiredColdResistance 0/3/6/9), `ById`, `forRing(ring)` | 13 | 14, 15, 16, 17 |
| `data/Chunks.luau`: `Variants` (3 per biome), `forBiome(id)` | 13 | 16 (spawn zones) |
| `data/Events.luau`: `Dark` (FalseNight, TheQuiet, DeepFreeze), `Blizzard`, `ById` | 14 | 15, 16, 18 |
| `data/Lurkers.luau`: `List`, `ByKind` (TreeWatcher, IceScratcher, EyesInDark) | 15 | 13 |
| `data/Mobs.luau`: `List`, `ByKind` (Fish, PolarBear, IceWraith, SnowLurker, CaveCrawler, mini-bosses IceWarden/CaveMatriarch/RuinColossus, boss WhiteoutBeast), `LegacyKinds`, `LegacyBiomes` | 16 | 14 (boss), 18 (Debug.MobKinds) |
| `data/Items.luau`: `List`, `ById`, `Nodes` (IronOre). Merged into `ItemCatalog.Items`/`.Nodes` | 17 | 13 (IronOre slots), 16 (Bow/Arrow, drops) |
| `data/Recipes.luau`: `List` (key = output id). Merged into `ItemCatalog.Recipes` | 17 | 18 |
| `data/Structures.luau`: `List` (Forge, CookingStation, StorageChest, Wall, Door, SpikeTrap, Watchtower, SleepingBag, MapTable). Merged into `ItemCatalog.Structures` | 17 | 15 (bag = warm spot), 16 (walls/traps) |
| `data/Clothing.luau`: `Tiers`, `Pieces[tier][slot]`, `UnlocksBiome` | 17 | 13 |
| `data/Food.luau`: `Cook`, `Buffs`, `BuffById`, `EatBuffs` | 17 | 18 |
| `src/shared/Stalker` is not a mob: its constants are in `Config.Stalker` | 15 | 16 (no clash) |

## Proposed public APIs (implement in the owning brief; 18 wires)

| name | owner brief | consumers |
|---|---|---|
| `BiomeLogic.ringAt(x, z) -> number`, `.drainMultiplier(ring, resistance) -> number` (applies Biome.* caps) | 13 | 18 (SurvivalService) |
| `BiomeService.getRing(player) -> number` (also sets Player `BiomeRing`), `.getCampPosition` via ChunkService | 13 | 15, 16, 18 |
| `MapService` handles `MapRequest`, sends `MapData` (explored cells only), `.markExplored(position, radius)` (watchtower `viewBonus`) | 13 | 17 |
| `ChunkService` tags cabins/hot springs `WarmSpot.Tag` with `WarmSpot.RadiusAttribute`, and spawns IronOre slots | 13 | 15, 17 |
| `EventSchedule.chance(day)`, `.canStart(state) -> (boolean, reason)` (FirstDay, MinGap, MaxPerDay, blizzard buffer) | 14 | 14 |
| `EventService.getModifiers() -> { warmthDrain, fuelBurn, dreadGain, huntBonus, nightRules, silence }` (capped), `.isBlizzard()`, `.onBlizzardStart(cb)`, `.onEventStart(cb(id))`, `.onEventEnd(cb(id, survivors))`, `.setFullGroupPredicate(fn)` | 14 | 15, 16 (blizzard boss), 18 (Survival/Fire/DayNight, coins) |
| `DreadLogic.step(state, inputs, dt)`, `.cueLevel(dread)`, `.huntChance(dread, day, bonus)` (capped) | 15 | 15 |
| `Isolation.weights(positions, partySize) -> { [i]: weight }`, `.fullGroup(positions) -> boolean` | 15 | 14, 16 |
| `DreadService.addSighting(player)`, `StalkerService.isHunting() -> boolean` (server only), `StalkerService.onStrike(cb(player))` | 15 | 16, 18 |
| `MobScaling.multipliers(day, ring, partySize) -> { budget, health, damage }` (all capped, then `MaxLiveMobs`) | 16 | 16 |
| `MobService.damage(mob, amount, sourcePlayer?)` (traps, projectiles), `BossService.spawnBlizzardBoss(campPos)` | 16 | 17 (traps), 14 |
| `ProjectileService` handles `ShootRequest` and fires `ProjectileFired`. A player hit only by a projectile, and only `FriendlyFireMultiplier` times its damage | 16 | 17 (Bow/Arrow items) |
| `ClothingService` sets Player `ColdResistance` (capped `Clothing.MaxColdResistance`) | 17 | 13, 18 |
| `BuffService.getModifiers(player) -> { warmthDrain, hungerDrain, regenBonus, speed }` (capped) | 17 | 18 |
| `StorageService` (Storage* remotes), `RepairService` (`RepairRequest`), `CookingService` (`CookRequest`), `StructureService` (`DoorToggleRequest`, structure health, trap hits via `MobService.damage`), `PingService` (`PingRequest` -> `PingBroadcast` to party) | 17 | 18 |

## Remotes (`src/shared/Remotes.luau`; payload types exported there; all in `Remotes.all`)

| name | owner brief (handler/sender) | consumers |
|---|---|---|
| `PingRequest` c->s `PingPayload { kind, position }` / `PingBroadcast` s->party `PingBroadcastPayload { fromUserId, kind, position, expiresAt }`; rate `Net.PingRateInterval` | 17 | 17 client |
| `StorageOpenRequest` `{ chest }`, `StorageCloseRequest` (none), `StorageDepositRequest` `{ chest, slot, count }`, `StorageWithdrawRequest` `{ chest, chestSlot, count }` c->s; `StorageState` s->c `{ chest?, slots }` snapshot on change; rate `Net.StorageRateInterval`; chest is shared by the party | 17 | 17 client |
| `MapRequest` c->s (none; needs `Map.ItemId`), `MapData` s->c `{ cellSize, cellsPerSide, explored }` (explored cells only); rate `Net.MapRateInterval` | 13 | 17 (map table / Map item) |
| `RepairRequest` c->s `{ slot }`; rate `Net.RepairRateInterval` | 17 | — |
| `CookRequest` c->s `{ slot, station }`; rate `Net.CookRateInterval` | 17 | — |
| `ShootRequest` c->s `{ direction }`; `ProjectileFired` s->all `{ shooterId, origin, direction, speed }` (visual); rate `Net.ShootRateInterval` | 16 | — |
| `DoorToggleRequest` c->s `{ door }`; rate `Net.UseRateInterval` | 17 | — |
| `Cue` s->c `CuePayload { kind, level?, position?, event? }`. Send on change only, never per tick, at most one per `Cue.MinIntervalSeconds` per player per kind | see kinds | 14, 15 clients |

`Cue.Kinds` senders: `DreadLevel`, `StalkerTell`, `Footsteps`, `FireGutter`, `StalkerRetreat`, `LurkerSighted` and `IceCrack` are sent by 15. `WarnBlizzard`, `WarnFalseNight`, `WarnTheQuiet`, `WarnDeepFreeze`, `EventStart` and `EventEnd` are sent by 14. `BossWarning` is sent by 16. Each brief's client connects to `Cue` and ignores kinds it does not own.

## Config keys (`src/shared/Config.luau`, Phase 3; caps marked Max*)

| name | owner brief | consumers |
|---|---|---|
| `World.StartForestRing` = 0 (camp in the center ring = SnowyForest; was 1) | 12 | 13 |
| `Biome.*`: `RingAttribute` "BiomeRing", `ColdResistanceAttribute` "ColdResistance", `MaxColdSeverity`, `MaxRequiredColdResistance`, `ResistanceDrainReductionPerPoint`, `MinDrainFraction`, `UnderdressedDrainPerPoint`, `MaxUnderdressedMultiplier`, `UpdateInterval` | 12 | 13, 17, 18 |
| `Clothing.Slots`/`MaxTier`/`MaxColdResistance` | 12 | 13, 17 |
| `Events.*`: `FirstDay` 3, `MinGapSeconds`, `CheckIntervalSeconds`, `BaseChancePerCheck`, `ChancePerDay`, `MaxChancePerCheck`, `MaxPerDay`, `BlizzardBufferSeconds`, `Min/MaxWarningSeconds`, `MaxDurationSeconds`, `MaxWarmthDrainMultiplier`, `MaxFuelBurnMultiplier`, `MaxDreadGainMultiplier`, `MaxHuntChanceBonus`, `ActiveAttribute` "DarkEvent" | 12 | 14, 15, 18 |
| `Blizzard.ActiveAttribute` "Blizzard", `.WarningAttribute` "BlizzardWarning" (cadence stays `Time.Blizzard*`) | 12 | 14, 16, 18 |
| `Dread.*` (gains, decay, `MaxDayGainMultiplier`, `MaxRingGainMultiplier`, `CueThresholds`) | 12 | 15 |
| `Isolation.*`, `Stalker.*` (`FirstHuntDay` 2, `MaxHuntChance`, `Damage` < MaxHealth, `ChaseSpeed` < WALK_SPEED, repel radii, `Tag`), `Lurkers.*` (`MaxDensity`, `MaxPerPlayer`, `MaxTotal`, `Tag`), `Scares.*` | 12 | 15 (Isolation also 14) |
| `Cue.Kinds`, `Cue.MaxLevel`, `Cue.MinIntervalSeconds` | 12 | 14, 15, 16 |
| `Scaling.MaxLiveMobs`, `MobBudget/Health/DamagePerRing` + `MaxRing*Multiplier`, `MaxPartyBudgetMultiplier`, `MobHealthPerExtraPlayer`, `MaxPartyHealthMultiplier` | 12 | 16 |
| `Bosses.*` (mini-boss first day / max alive / respawn, blizzard boss chance + `MaxBlizzardBossChance`, `MaxHealthMultiplier`, `MaxDamageMultiplier`) | 12 | 14, 16 |
| `Projectile.*` (`FriendlyFireMultiplier`, `MeleeFriendlyFire` false, `AimAssistDegrees`, `MaxActivePerPlayer`) | 12 | 16 |
| `Storage.*`, `Map.*`, `Ping.*`, `Repair.*`, `Cooking.*` (campfire cooking uses `Fire.CookRadius`), `Buffs.*` (`MaxActive`, `MaxDurationSeconds`, `Max*Reduction`, `ActiveAttribute` "Buffs"), `Durability.*` | 12 | 13 (Map), 17 |
| `Craft.Stations.forge`/`.cookingStation`/`.mapTable`, `Craft.MaxTier` = 2, `ToolTier.Metal` = 3 | 12 | 17 |
| `Build.HealthAttribute`, `.BlockerTag`, `.TrapTag`, `.StorageTag`, `.DoorOpenAttribute` | 12 | 16, 17 |
| `WarmSpot.Tag`, `.RadiusAttribute`, `.CabinRadius`, `.HotSpringRadius` | 12 | 13, 15, 17, 18 |
| `Net.PingRateInterval`, `StorageRateInterval`, `MapRateInterval`, `RepairRateInterval`, `CookRateInterval`, `ShootRateInterval` | 12 | 13, 16, 17 |
| `Meta.CoinsPerDarkEventSurvived` | 12 | 14 (reports), 18 (payout) |

## Attributes and tags (Phase 3; all visible state, none carry hidden metrics)

| name | owner brief (sets) | consumers |
|---|---|---|
| Player `BiomeRing`, Player `ColdResistance` | 13 / 17 | HUD, 18 |
| Workspace `DarkEvent` (id or ""), `Blizzard`, `BlizzardWarning` | 14 | 14 client, 16, 18 |
| Player `Buffs` (comma list), Player `OpenChest` | 17 | 17 client |
| Structure `StructureHealth`, `DoorOpen`; tags `StructureBlocker`, `SpikeTrap`, `StorageChest`, `WarmSpot` (+ `WarmSpotRadius`) | 17 (13 for cabins/springs) | 15, 16 |
| Tags `Stalker`, `Lurker` on their models (no Dread or hunt attributes) | 15 | client visuals |

# Phase 4 contract (brief 21)

Briefs: 21 contracts and integration, 19 meta (coins, achievements, titles, starter gear, perks, shop, Robux, leaderboard, summary hooks), 20 atmosphere and polish (audio/particle cues, UI effects, reduce-scares, first-run hints, swing for others, touch placement label, KNOWN_ISSUES, performance).
Brief 21 owns `Config.luau`, `Remotes.luau`, `Assets.luau`, `ItemCatalog.luau`, `data/Types.luau`, `logic/ProfileSchema.luau`, `server/Net/Guard.luau`, `init.*`, `tests/{run,ProfileTests,MetaTests,DataTests}.luau` and `docs/{STATUS,KNOWN_ISSUES,ARCHITECTURE,DECISIONS,ART,INTEGRATION}.md`. Briefs 19 and 20 never edit these; they put the requested change (key, value, reason) in their report and brief 21 merges it.

Rules for every Phase 4 brief:
- **Hidden metrics stay on the server** (Dread, hunt chance, event timers, lurker roll, isolation weight). No Phase 4 payload, Attribute, AudioCues row or client module carries them; `MetaTests` checks the new names.
- **The client sends ids only.** The server recomputes prices, ownership, milestones and caps from `data/Shop`, `data/Achievements` and `Config.Meta`. Handler order: type-check -> range (id length, known id) -> `Guard.rateLimit(Config.Net.*)` -> permission/state (lobby only for buy/perk, owned, milestone met, enough coins) -> act.
- **Robux.** Developer products only, keyed by `Config.Meta.ProductIds` (0 = placeholder: never prompt). `MarketplaceService.ProcessReceipt` is set in both server modes. Grants are idempotent: if `ProfileSchema.hasReceipt(profile, receipt.PurchaseId)` return `PurchaseGranted` without granting; else grant, `ProfileSchema.recordReceipt(profile, id, os.time())`, return `PurchaseGranted`. Profile not loaded (or failed) -> `NotProcessedYet`. A Robux-only cosmetic already owned is still recorded and granted nothing. No random or paid-random item exists (tested). No countdown pressure to buy.
- **Perks.** One equipped (`Meta.MaxEquippedPerks`), changed in the lobby only, applied once at run start; each effect is `|amount| <= Meta.MaxPerkMagnitude` on a `Meta.PerkStats` modifier.
- **Profile v3** fields below are validated for shape on load; ownership of equipped ids is re-checked by brief 19 on load (unequip what is not owned). All profile writes go through `DataService.get(player)` (mutate in place).
- **Every brief has a server and a client boot hook**, called by `init.*` in BOTH modes with `mode` (`Teleport.ModeLobby` / `ModeRun`), after that mode's services and before `Spawn.start()`. Must not yield.
- **Each brief owns one test file**, already registered in `tests/run.luau`.
- Asset ids are placeholders (`""`), listed in `docs/ART.md`. A new asset key is requested from brief 21.

## Exclusive file ownership (parallel-safe)

| brief | owns (edit only these; new files under these paths) |
|---|---|
| 19 meta | `src/shared/data/Achievements.luau`, `src/shared/data/Shop.luau` (content inside the Config caps), `src/shared/logic/RunPayout.luau`, new `src/shared/logic/{AchievementLogic,ShopLogic,PerkLogic,MetaSnapshot}.luau`, `src/server/Meta/*` (DailyRewardService, DailyLogic, new MetaService, ShopService, ReceiptService, AchievementService, PerkService, CosmeticService), `src/server/Run/*`, `src/server/Lobby/*`, `src/client/Lobby/*`, new `src/client/Meta/*`, `src/server/Phase4/MetaBoot.luau`, `src/client/Phase4/MetaClient.luau`, `tests/{MetaLogicTests,RunTests,LobbyTests}.luau`, new `docs/systems/meta.md`, new `tools/qa/meta.luau` |
| 20 atmosphere/perf | `src/shared/data/AudioCues.luau` (rows; keys must exist in Assets), new `src/shared/logic/{CueResolve,PerfBudget}.luau`, new `src/client/Atmosphere/*`, `src/client/HUD/*`, `src/client/Horror/*`, `src/client/Events/*`, `src/client/Fire/*`, `src/server/Horror/*` (reduce-scares only), `src/server/World/ChunkService.luau` (load budget), `src/server/Mobs/MobService.luau` + `src/server/Items/GatherService.luau` (one `SwingRelay.notify` call each; perf caps), new `src/server/Atmosphere/*`, `src/server/Phase4/AtmosphereBoot.luau`, `src/client/Phase4/AtmosphereClient.luau`, `tests/AtmosphereTests.luau`, new `docs/systems/atmosphere.md`, new `tools/apply_perf.luau` (idempotent: StreamingEnabled and radii from `Config.Perf`), new `tools/qa/{perf,atmosphere}.luau` |
| 21 contracts/integration | everything else (see above) |

Neither brief edits a file in the other's row. Cross-brief needs go through the APIs below; a missing dependency uses a nil-safe setter and brief 21 wires it.

## Modules and APIs

| name | owner brief | consumers |
|---|---|---|
| `data/Types.luau`: `StatCondition`, `AchievementDef`, `TitleDef`, `PerkEffect`, `GearGrant`, `ShopItemDef`, `AudioCueDef` | 21 | 19, 20 |
| `data/Achievements.luau`: `List` (27; `MinAchievementDefs..MaxAchievementDefs`), `ById`, `Titles`, `TitleById`. Condition: `ProfileSchema.getStat(profile, stat) >= atLeast` | 19 | 20 (toast fx) |
| `data/Shop.luau`: `List`, `ById`, `ByProductKey`. Categories `cosmetic` (slots outfit/trail/camp/pet; coins or Robux-only), `perk` (coins), `gear` (coins, `requires` milestone, granted every run start), `coinPack` (Robux; 3 packs) | 19 | 20 (cosmetic visuals via `Assets.Cosmetic<Id>`) |
| `data/AudioCues.luau`: `List`, `ByKey`, `Groups`. One row per `Config.Cue.Kinds` entry plus events (`Blizzard`, `FalseNight`, `TheQuiet`, `DeepFreeze`), `StalkerStrike`, world, combat, ui and meta keys (`AchievementUnlocked`, `PurchaseSuccess`, `PurchaseFailed`, `Equip`, `CoinGain`, `PersonalBest`, `DailyClaim`) | 20 | 19 (play meta keys through `AtmosphereFx.play`) |
| `ProfileSchema`: `PROGRESS_FIELDS`, `isStatField(name)`, `getStat(profile, name)`, `hasReceipt(profile, purchaseId)`, `recordReceipt(profile, purchaseId, now) -> boolean` | 21 | 19 |
| `MetaService.addProgress(player, field, amount)`, `.raiseProgress(player, field, value)` (max, e.g. `deepestRing`), `.pushState(player)` (sends `MetaState`), `.getEquippedPerk(player) -> ShopItemDef?` (run server), `.onAchievement(cb(player, def))` | 19 | 20, 21 (wiring progress sources: EventService.onEventEnd, Player `BiomeRing`, revive/place/cook hooks) |
| `src/client/Atmosphere/AtmosphereFx.luau`: `play(key, position?)` (looks up AudioCues, applies reduce-scares and `Perf.MaxActiveSounds` / `MaxParticleEmitters`), `reduceScares() -> boolean` (from Player `ReduceScares`) | 20 | 19 client (nil-safe: require inside pcall or a setter) |
| `src/server/Atmosphere/SwingRelay.luau`: `notify(player)` -> `SwingBroadcast` to players within `Perf.SwingBroadcastRange` (rate-capped by the accepted swing itself) | 20 | 20 (Gather/Mob call sites) |

## Remotes (Phase 4; payload types in `Remotes.luau`; all in `Remotes.all`)

| name | owner brief (handler/sender) | consumers |
|---|---|---|
| `ShopBuyRequest` c->s `ShopBuyPayload { itemId }` (coins; lobby); rate `Net.ShopRateInterval` | 19 | 19 client |
| `RobuxPurchaseRequest` c->s `RobuxPurchasePayload { itemId }` (server calls `PromptProductPurchase`); rate `Net.RobuxPromptRateInterval` | 19 | 19 client |
| `PurchaseResult` s->c `PurchaseResultPayload { ok, itemId, coins, reason? }` (reason: owned, coins, locked, unavailable, cancelled, failed) | 19 | 19, 20 client (fx) |
| `EquipCosmeticRequest`, `EquipPerkRequest` (lobby only), `EquipTitleRequest` c->s `EquipPayload { id }` ("" = unequip); rate `Net.EquipRateInterval` | 19 | 19 client |
| `SettingsSetRequest` c->s `SettingsSetPayload { key, value }` (key in `Settings.Keys`); rate `Net.SettingsRateInterval`; server writes `profile.settings` and Player `ReduceScares` | 19 (handler) | 20 (settings UI sender) |
| `HintSeenRequest` c->s `HintSeenPayload { hintId }` (in `Hints.Ids`); rate `Net.HintRateInterval`; server writes `profile.hintsSeen` | 19 (handler) | 20 (hints sender) |
| `MetaStateRequest` c->s (none); rate `Net.MetaStateRateInterval` / `MetaState` s->c `MetaStatePayload` full snapshot on load and on change (never receipts) | 19 | 19, 20 (hintsSeen, settings) |
| `AchievementUnlocked` s->c `AchievementUnlockedPayload { id, coins, title? }` once per unlock | 19 | 19 toast, 20 fx |
| `RunSummaryPayload` gains optional `previousBest`, `rankChange` ("2 days to your record" / rank change); `cause` stays "what got you" | 19 | 19 |
| `SwingBroadcast` s->nearby clients `SwingPayload { userId }` once per accepted swing (visual) | 20 | 20 client |

## Config keys (Phase 4)

| name | owner brief | consumers |
|---|---|---|
| `Meta.MinAchievementDefs`/`MaxAchievementDefs` (20/30), `MaxAchievementCoinReward`, `MaxProgressEntries`, `MaxOwnedCosmetics`, `MaxUnlockedGear`, `MaxTitles`, `MaxHintsSeen`, `MaxItemIdLength` | 21 | 19 |
| `Meta.MaxEquippedPerks` (1), `PerkStats` (warmthDrain, hungerDrain, fuelBurn, gatherSpeed, moveSpeed), `MaxPerkMagnitude` (0.15) | 21 | 19 (and 21 wiring perk modifiers into Survival/Fire/Gather) |
| `Meta.MinCoinPrice`/`MaxCoinPrice`, `MaxRobuxPrice`, `MaxCoinPackCoins`, `MaxStarterGearCount`, `ProductIds` (placeholders 0), `MaxProcessedReceipts` (100), `MaxReceiptIdLength` | 21 | 19 |
| `Meta.RecordHintDays` (2), `BestDaysAttribute` "BestDays", `TitleAttribute` "Title", `CosmeticAttribute` "Cosmetic", `MaxFriendBonusFriends` | 21 | 19, 20 (HUD record hint) |
| `Perf.TargetFps` (30), `FpsSampleSeconds`, `MaxLiveParts`, `MaxLiveMobs` (= `Scaling.MaxLiveMobs`), `ChunkLoadBudgetPerFrame`, `ChunkPartBudgetPerFrame`, `MaxParticleEmitters`, `MaxParticleRate`, `MaxActiveSounds`, `StreamingEnabled`, `StreamingTargetRadius`, `StreamingMinRadius`, `SwingBroadcastRange` | 21 | 20 |
| `Settings.Keys`, `ReduceScares` "reduceScares", `ReduceScaresAttribute` "ReduceScares", `DefaultReduceScares`, `ReducedScareVisualMultiplier`; server scare budget keeps `Scares.ReducedSettingMultiplier` | 21 | 19 (persist), 20 (apply) |
| `Hints.Ids` (first-run hint ids) | 21 | 19 (persist), 20 (show) |
| `Net.ShopRateInterval`, `RobuxPromptRateInterval`, `EquipRateInterval`, `SettingsRateInterval`, `MetaStateRateInterval`, `HintRateInterval` | 21 | 19 |
| `SchemaVersion` = 3 | 21 | 19 |

## Profile schema fields (`ProfileSchema.Profile`, schemaVersion 3; all string keys, capped, validated on load)

| name | owner brief (writes) | consumers |
|---|---|---|
| `achievementProgress: { [string]: number }` (`PROGRESS_FIELDS`: blizzardsSurvived, darkEventsSurvived, revivesGiven, structuresPlaced, mealsCooked, partyRuns, friendRuns, deepestRing, dailyClaims; cap `MaxProgressEntries`, values `MaxStatValue`) | 19 | 19 |
| `ownedCosmetics`, `unlockedGear`, `titles`, `hintsSeen`: `{ [string]: boolean }` (caps `MaxOwnedCosmetics`, `MaxUnlockedGear`, `MaxTitles`, `MaxHintsSeen`) | 19 | 19, 20 (hintsSeen via MetaState) |
| `equippedCosmetic`, `equippedPerk`, `equippedTitle`: string ("" = none) | 19 | 19 |
| `settings: { reduceScares: boolean }` (only `Settings.Keys`) | 19 | 20 (via Player `ReduceScares`) |
| `processedReceipts: { [PurchaseId]: os.time() }` capped log (oldest evicted) | 19 (via `recordReceipt`) | 19 |

## Attributes (Phase 4; visible state only)

| name | owner brief (sets) | consumers |
|---|---|---|
| Player `ReduceScares` (bool), `Title` (display name), `Cosmetic` (id), `BestDays` (run server; saved maxDays) | 19 | 20 (scares, HUD record hint), all clients (title/cosmetic) |

## Phase 4 integration (brief 21, done)
| name | owner | consumers |
|---|---|---|
| `src/server/Phase4/Wiring.luau` — `apply(mode)` run mode only: meta progress sources + perk capture | 21 | init.server |
| `src/server/Phase4/PerkModifiers.luau` — `capture`, `multiplier(player, stat)`, `teamMultiplier(stat)`, `gatherBonus(player, base)` | 21 | Phase3 Wiring (survival env, fuel burn), GatherService |
| `PerkLogic.multiplier`, `.lowestMultiplier`, `.bonusYield` (pure, capped) | 21 | PerkModifiers, sim |
| `MetaService.addStat(player, "crafted", n)`, `.handleEquipPerk`, `.handleSettingsSet`; `ShopService.handleBuy/handleRobux` (return outcome); `ReceiptService.processItem` | 21 | wiring, Studio QA |
| Success hooks: `CraftingService.setCraftedHandler`, `PlacementService.setPlacedHandler`, `CookingService.setCookedHandler`, `SurvivalService.setReviveHandler`, `GatherService.setYieldBonusProvider` | 21 | Phase4 Wiring |
| `DataService.save(player)` (non-yielding Profile:Save) | 21 | ReceiptService |
| Config: `Blizzard.EventId`, `Meta.StarterGear{Wait,Poll}Seconds`, `Meta.CosmeticTagPrefix/CosmeticSlots`, `Hints.Ids` + "Forge", `Hints.ShowSeconds/CheckInterval/LookupRange/WarnWindowSeconds`, `Perf.SwingMaxPerSecond` | 21 | 19, 20 |
| Studio-only: `Debug/MetaQA.luau` (bridge "MetaQA": backup/restore/read/setCoins/clearOwned/clearAchievement/clearHint/setStat) | 21 | tools/qa |


## Round: terrain/forest/structures/fire/death/balance contracts
Owner: contracts agent (done). Agents: A terrain, B trees/shadows, C structures, D fire radius, E death/revive, F balance. Config is frozen for this round except by its owner.

### World (pure, `src/shared/logic/World.luau`; test skeleton `tests/TerrainContractTests.luau`, A extends)
| name | semantics | consumers |
|---|---|---|
| `World.heightAt(seed, x, z, flatX?, flatZ?): number` | Block top Y, pure/deterministic. Flat (=`Terrain.BaseHeight`) within `CampFlatRadius` of the flat centre (default origin; pass camp x,z), ramps over `CampRampWidth` | A, B (tree Y), C (structure Y), E |
| `World.blockHeight(seed, ix, iz, flatX?, flatZ?)`, `World.blockIndex(x,z) -> ix,iz`, `World.blockCenter(ix,iz) -> x,z`, `World.blockOrigin(x,z) -> x,z` (min corner) | Block grid helpers (size `Terrain.BlockSize`) | A, B |
| `World.biomeAt(x,z): string` (Biomes id), `World.ringAt(x,z)`, `World.amplitudeAt(x,z)` | Biome lookups / blended amplitude | A, B |
| `World.halfExtent()`, `World.isPastEdge(x,z)`, `World.belowKillHeight(y)`, `World.shouldKill(x,y,z)` | Fell-off checks (edge uses `Terrain.EdgeMargin`) | A (edge wall), E |

### Config
| path | value / meaning | consumers |
|---|---|---|
| `Terrain.BlockSize`=4, `HeightQuantum`=1, `MaxStep`=4 (hard cap, scan-tested), `BlendWidth`, `LowWavelength`, `HighWavelength`, `LowShare` | block grid + noise shape | A |
| `Terrain.Biomes[id] = {Amplitude, MaxStep}` ids SnowyForest 6, FrozenLake 1 (near flat), MountainsCaves 36, DeepTundra 12 | per-biome relief | A, B |
| `Terrain.CampFlatRadius`=40, `CampRampWidth`=80, `BaseHeight`=0, `FloorY`=-80 | flat camp, column floor | A, B, C |
| `Terrain.KillHeight`=-120, `EdgeMargin`=48, `EdgeWallHeight`=60, `MaxBlocksPerChunkBuild` | kill/edge/build budget | A, E |
| `Forest.Classes[]` = `{Id,Weight,Height{min,max},TrunkRadius,CanopyRadius,MinSpacing,Gatherable,WoodYield}` Small/Medium/Large/Giant | tree size classes | B, F |
| `Forest.TreesPerChunk`=80, `RingDensity`={1,.35,.5,.2}, `MaxPartsPerTree`=4, `GiantMaxPerChunk`=3, `PlacementAttempts`, `TagAttribute` | density/perf | B |
| `Forest.SpawnClearRadius`=10, `FireClearRadius`=12, `NearCampRadius`=54, `NearCampDensity`=0.4, `CampEdgeRadius`=110, `CampEdgeDensity`=1.3 | density near spawn/camp, clearing at fire | B |
| `Fire.BaseRadius`=R0=18; `Fire.WarmRadius`=54 (3 R0); `Fire.Tiers[i]` (i=1 is spec tier 0): WarmRadius 54/72/90, BuildRadius 90/126/162, LightRange 72/90/108 | each upgrade adds R0 | D, C (build range), all fire readers |
| Mob repel radius | unchanged formula: warm + `Night.RepelMargin` (6) (`FireRepel.repelRadius`); `Fire.RepelRadius`=58 is only the fallback | D |
| `Fire.Ring`: DotDiameter 1.8, Spacing 10, MinDots 24, MaxDotsPerLayer 110, MaxDotsTotal 220, FadeStart 30, FadeEnd 110, RayLength 200; `Fire.Meter.ShowRange`=100 | scaled for 3x radii | D |
| `Durability.UnbreakableItems = { Axe = true }` | ids that never lose durability (apply at the durability decrement, server) | F (or E/gather owner) |
| `Combat.HareHitsMin/Max`=2/3, `WolfHitsMin/Max`=4/5; `Mobs.Hare.Health` 8 -> 20 (3 hits at `ToolDamage` 8); Wolf 35 (5 hits) | hits-to-kill targets | F |
| `Downed.BleedoutSeconds`=60 (revive window), `ReviveSeconds`=4 (hold), `ReviveRange`=8, `DownedWalkSpeed`=3 (existing); new `DownedJumpPower`=0, `SpectateOnDeath`=true, `SpectateCycleInterval`=0.4, `ReviveBarHoldRequired`=true, `ReviveCancelRange`=12, `DownedHealth`=1 | death/revive | E |
| `Shelter.InteriorWidth/Depth`=14, `CeilingHeight`=9, `DoorWidth`=5, `DoorHeight`=8, `WallThickness`=1, `WatchtowerHeight`=28, `WatchtowerPlatformSize`=10, `WatchtowerRailHeight`=3.5, `StairWidth`=5, `StairRise`=1.5, `StairRun`=2, `LadderWidth`=3 | structure minimums | C |
| `Shadows.GlobalShadows`, `TreesCastShadows`, `ShadowSoftness`=0.3, `ForestFloorDarkness`=0.35, `ForestFloorDarknessNight`=0.15, `CanopyShadeRadiusFactor`=1.2, `NightMinAmbient`, `NightMinOutdoorAmbient`, `NightMinBrightness`, `MaxShadeDiscs`=120 | plain tuning values | B |
| `Perf.MaxLiveTrees`=700, `Perf.TerrainCountsTowardParts`=false | `MaxLiveParts` (6000) unchanged. Terrain MUST be Roblox Terrain voxels (FillBlock, voxel = BlockSize 4), not parts: 6400 blocks per chunk would blow the budget | A, B |

Notes: heightAt returns block tops sampled at block centres; `MaxStep` between edge-adjacent blocks is scan-tested over a 12-stud sample grid, A should extend to all blocks. Old fire literals in tests (e.g. NightTests with 18/22) use explicit args, not Config. Tier-0 naming: Config indices are 1-based, `Tiers[1]` is the spec's tier 0.

### Appended note: death / downed / revive (agent E)
- Server hook for A's world edge: `SurvivalService.killOutright(player, cause?)` ends a player outright (no downed window, not revivable, cause "Fall"). Call it where `World.shouldKill(x, y, z)` is true; Survival's own Heartbeat already applies `World.shouldKill` (kill height and edge) to every living or downed player each tick via `DownedLogic.fellOut`.
- Pure logic: `src/shared/logic/DownedLogic.luau` (onZeroHealth, canStartRevive, channelStep, progress, nextSpectate, pickReviveTarget, fellOut). Tests: `tests/DownedTests.luau`.
- Config.Downed additions (E): `DeadAttribute` ("RunDead" Player attribute, spectator), `BleedAttribute` ("DownedBleed", seconds left), `ReviveProgressAttribute` ("ReviveProgress" on the downed player), `ReviveRefreshSeconds`, `ReviveStaleSeconds`, `PoseDropY`, `PoseTiltDegrees`, `PoseJointName`, `ReturnRemoteName`.
- Revive protocol: client resends `ReviveRequest(target)` every `ReviveRefreshSeconds` while holding; the server cancels after `ReviveStaleSeconds` without a refresh (release), beyond `ReviveCancelRange`, or if either side stops being valid.
- New remote `Config.Downed.ReturnRemoteName` ("ReturnToLobbyRequest", no payload) is created lazily by RunLifecycleService.Start. NOT added to `Remotes.luau` (not E's file): the Remotes owner should add `Remotes.ReturnToLobbyRequest = "ReturnToLobbyRequest"` and its entry in `Remotes.all`, and switch the two callers (RunLifecycleService, SummaryScreen/DownedUi) to it.
- Client: `src/client/HUD/DownedUi.luau` (started from init.client in run mode); summary screen restyled in `src/client/Lobby/SummaryScreen.luau`.


### C footprints (enterable structures)
Exclusion radii in studs from the POI position (include `Shelter.FootprintMargin` = 6; apron steps on steep ground may reach ~10 further, ignore). Source of truth: `PoiPlan.kindFootprint(kind)` (`src/shared/logic/PoiPlan.luau`); trees/camp/spawn exclusion should call it rather than copy numbers.
| kind | radius | notes |
|---|---|---|
| cabin | 23 | LogCabin 21, Lodge 23, Trapper 22 |
| plane | 38 | Airliner 38, Cargo 36 (long fuselage plus wing/scorch) |
| cave | 28 | Cavern 28, Grotto 26 |
| ruin | 31 | Vault 26, TwinChambers 31 |
| campsite | 22 | Tent 21, Watchtower 22 (tower is the `campsite` kind, variant `Watchtower`) |
| hotspring | 14 | `PoiPlan.PropFootprints` |
Placement: floor Y = highest terrain under the footprint (`PoiPlan.siteFloor`), foundation fills below, door yaw is the cardinal facing the lowest ground, variant = `PoiPlan.pickVariant(seed, poi.id, kind, biome)`. Doors are open (no scripted doors); mobs can path through. Part budget per POI <= `Art.World.MaxPartsPerPoi` (tested).

### Appended note: integration pass (terrain/forest/structures/fire/death/balance)
- Fall path is single: `ChunkService.setFallHandler` -> `SurvivalService.killOutright(player, "Fall")` (wired in Phase3 Wiring); Survival's own Heartbeat fell-out check was removed. MobService despawns mobs where `World.shouldKill`.
- Ground Y: ChunkService (slots, camp fire, spawn, teleport) and WorldArt.decorChunk use `World.heightAt` (camp-aware). Placement/ghost/ring ground rays now include `Workspace.Terrain` (not only the chunk folder); `Placement.GroundRayHeight/Length` = 40/100 for slopes.
- Trees: `ForestPlacement.poiClears(layout, chunk)` gives per-POI exclusion radii (`PoiPlan.kindFootprint`) including neighbour chunks. Fires placed after a chunk loads do not clear trees (tree set must stay deterministic for node memory); only the camp clearing applies.
- Mobs never spawn inside a lit fire's repel circle. Fire PointLights clamp to `Night.FireLightMaxRange` (60, the Roblox cap); `Tiers[i].LightRange` is informational.
- `Remotes.ReturnToLobbyRequest` is registered in Remotes.all. `InventoryService.wearSelected` skips `ItemCatalog.isUnbreakable` items.


## Round: loot + massive structures + trees
Owner: contracts agent (shared files frozen for later agents H/I/J/K/L/M; ask the PM for changes). Tests: `tests/LootTests.luau`.

### Rarity (shared, replicated, no weights)
- `src/shared/data/Rarity.luau`: types `Rarity` ("common"|"uncommon"|"rare"|"epic"|"legendary"), `LootCategory` ("gear"|"tool"|"weapon"|"clothing"|"material"|"food"); `Rarity.List`, `Rarity.Categories`, `Rarity.rank(r): number`, `Rarity.isRarity(v): boolean`, `Rarity.Colors[r] = {r,g,b}`, `Rarity.Tags[itemId] = { rarity, category? }` (category nil = never in loot). Add a Tags entry for every new item (ItemCatalog asserts at load).
- `ItemDef.rarity: Rarity?` and `ItemDef.lootCategory: LootCategory?` (stamped on every `ItemCatalog.Items` entry); `ItemCatalog.rarityOf(id): Rarity`; types `ItemCatalog.Rarity`, `ItemCatalog.LootCategory`.

### Loot (config split)
- Public `Config.Loot`: `ChestTag` "LootChest", `Rarities`, attributes `ChestRarityAttribute` "ChestRarity", `ChestStructureAttribute` "LootStructure", `ChestDepthAttribute` "LootDepth", `ChestOpenedAttribute` "LootOpened", `MaxDepthTier` 4, `OpenRange` 10, `ServerOpenRange` 14, `OpenRateInterval` 0.3, `OpenedFadeSeconds` 20.
- SERVER-ONLY weights: `src/server/Loot/LootTables.luau` (under src/server = ServerScriptService.Server, never replicated; has no requires; do NOT require from shared/client). Contents: `ringWeights[ring+1]` (chest rarity by ring), `structureWeights[type]` (multipliers), `structureChests[type]` ({min,max} chests per structure), `depth` ({PerTier, MaxTier}), `chests[chestRarity]` ({items={min,max}, categoryWeights, rarityWeights}), `stackCounts[category]`. Structure type keys: small POIs `cabin, plane, cave, ruin, campsite`; massive ids from `Config.Massive.Ids`.
- Pure rolling `src/shared/logic/LootRoll.luau` (pass `LootTables` as `LootRoll.Tables`; `rng: () -> number` in [0,1)): `buildPool(ItemCatalog.Items)`, `chestWeights(t, ring, structureType, depthTier)`, `pickChestRarity(t, ring, structureType, depthTier, rng): string`, `chestCount(t, structureType, rng): number`, `rollChest(t, pool, chestRarity, rng): {Stack}`, `weightedPick`, `bucket`, `randomInt`. Depth: deeper chests (depthTier 0..4) multiply higher rarities by `(1 + PerTier*tier)^(rank-1)`. Empty item buckets fall back to the next lower rarity.
- Remotes (`shared/Remotes.luau`, both in `Remotes.all`): `Remotes.LootOpenRequest` client->server `LootOpenPayload = { chest: Instance }` (handler order: type-check Instance with ChestTag, range <= ServerOpenRange, Guard at `OpenRateInterval`, state not yet looted, then roll/grant); `Remotes.LootOpened` server->client `LootOpenedPayload = { chest, rarity: string, items: {ItemStack}, overflow: boolean }`.

### Massive structures (`Config.Massive`, helper `src/shared/logic/MassiveRules.luau`)
- `Ids` = ResearchStation, MineComplex, FrozenShipwreck, RuinedTemple, RangerLodge, ExpandedRuins; `Structures[id]`: `MinFootprintX/Z, MinRooms, MinLevels, UndergroundDepth, Rings, CountMin, CountMax, Budget {Parts, DressingParts, Lights, Particles}`.
- Globals: `CorridorWidthMin` 6, `CeilingHeightMin` 10, `DoorWidthMin` 5, `DoorHeightMin` 8, `StairWidthMin` 5, `MaxLiveStructures` 2, `MinSeparation` 400, `FootprintMargin` 10, `DressingSpawnRadius` 90, `DressingDespawnRadius` 130, `DressingCheckInterval` 0.5, `DressingPartsPerTick` 40, `MaxLiveParts` 2000.
- `MassiveRules.footprintRadius(id)`, `ringAllowed(id, ring)`, `validatePlan(PlanSummary): {string}` (empty = OK; use in tests for plans). `Config.Perf.MaxLiveParts` stays 6000 (PM: never raise); integration lowers decor density to fit massive structures.
- Massive types also key `LootTables` (see above).

### Trees (`Config.Trees`, helper `src/shared/logic/TreeRules.luau`)
- `HeadHeight` 5.5, `CanopyClearance` 2, `MinCanopyBottom` 7.5, `MinFoliageThickness` 6, `MinTotalHeight` 18, `SizeClasses` {Small,Medium,Large,Giant}, `GiantHeightMin/Max` 70/100. `Forest.Classes` Small height is now {18,24}.
- `TreeRules.minCanopyBottom()`, `foliageBottom(height, wantedFraction)`, `canopyOk(height, foliageBottom)`.

### For L (fixes)
- `Config.FireRules`: `SpawnExcludeCategories` {hostile,miniboss,boss}, `SpawnExcludeSpecials` {Stalker,Lurker}, `SpawnMargin` 6, `RepelCategories`, `ClearLiveTrees`, `TreeClearRadius` 12, `TreeClearPerTier` 4, `TreeClearMaxRadius` 24.
- `Config.Terrain.BuildBlocksPerTick` 400 and `BuildMsPerTick` 3 (yield when either is hit; `MaxBlocksPerChunkBuild` stays the old chunk cap).
- `Config.WolfScaling` (`StartDay`, `DamagePerDay`, `MaxDamageMultiplier`, `SpawnRatePerDay`, `MaxSpawnRateMultiplier`); `MobScaling.wolfDamageFactor(day)` and `MobScaling.wolfSpawnFactor(day)` multiply onto `MobScaling.multipliers`.
