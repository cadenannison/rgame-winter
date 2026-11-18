# Integration contracts (live only)
History, ownership tables and round-by-round notes: docs/archive/INTEGRATION_HISTORY.md (do not read unless the task names it).
Config is split into `src/shared/Config/<Module>.luau` (which module holds which section: docs/INDEX.md; Config keys named below are `Config.<Section>.<Key>`). Remotes: `src/shared/Remotes.luau` (all in `Remotes.all`, payload types exported there).

## Global rules
- Hidden metrics (Dread, hunt chance, event timers, lurker roll, isolation weight, loot weights) never reach a remote, Attribute, client module or print. Client gets `Remotes.Cue` (kind, coarse `level`, position, event id) and visible Attributes.
- Every scaling value is capped by a `Max*` Config key; data files stay inside the caps (`tests/DataTests`).
- Players never damage each other except a stray projectile at `Projectile.FriendlyFireMultiplier`; traps hurt only mobs.
- Handler order: type-check -> range -> `Guard.rateLimit(Config.Net.*)` -> permission/state -> act. Validate Instance args (tag, ancestry, distance). Client sends ids only; server recomputes prices, damage, positions.
- Asset ids live in `shared/Assets.luau` (list new ones in `docs/ART.md`). `Perf.MaxLiveParts` = 6000, never raised.
- Shared files (Config/*, Remotes, ItemCatalog, Assets, data/Types, init.*, ProfileSchema, Guard) have one owner per round. Cross-system calls use nil-safe setters (`setXHandler/Provider`).

## Teleport, party, run lifecycle (docs/systems/run-lifecycle.md, party.md, lobby.md)
- Owner files: `logic/{TeleportData,PadLogic,RunPayout}`, `server/{Net/Guard,Party/*,Run/*}`, `server/Meta/DailyRewardService`, `tools/build_lobby.luau`, `client/Lobby/*`.
- `TeleportData` v1 keys exactly: `mode` ("run"|"lobby"), `seed` int [0,`Teleport.MaxSeed`], `partyIds` dense unique positive UserIds 1..`Teleport.MaxPartySize`, `version`=`Teleport.DataVersion`; extra keys refused. Read `player:GetJoinData().TeleportData` then `Guard.teleportData(player, data, expectedMode)`.
- Teleport only via `TeleportAdapter.teleportParty(players, data)` (`setImpl(fake)` in tests). Server mode: Workspace attr `Teleport.ServerModeAttribute` ("lobby"|"run"); reserved server = run.
- Remotes: `PadJoinRequest{padIndex}`, `PadLeaveRequest`, `PadModeRequest{mode}` (host), `PartyState{pads:{PadState}}` (snapshot on change; `PadState{index,capacity,mode,hostId?,memberIds,endsAt?,launching}`), `RunSummary{daysSurvived,kills,bossKills,coinsEarned,personalBest,newAchievements,cause?,tip?,previousBest?,rankChange?}`, `DailyClaimRequest`/`DailyClaimResult{ok,coins,nextClaimAt}`, `ReturnToLobbyRequest`, `Notify(kind,text)`.
- Events: `PartyService.onLaunch(cb(padIndex,players,data))`, `RunLifecycleService.onRunEnded(cb(results))`. Rejoin hold keeps meters/inventory by UserId for `Run.RejoinWindowSeconds` (300).
- Attributes/tags: Player `PadIndex` (`Lobby.PlayerPadAttribute`), pad part `PadIndex` + tag `LobbyPad` (`Lobby.PadTag`).

## Data and profile (docs/systems/data-service.md)
- Persistence only via `server/Data/DataService` (`get(player)` mutate in place, `onLoaded(cb)`, `save(player)` non-yielding). `Config.SchemaVersion` = 4 (Config/Core.luau); `logic/ProfileSchema` (`Profile`, `default`, `migrate`, `validate`, `PROGRESS_FIELDS`, `isStatField`, `getStat`, `hasReceipt`, `recordReceipt`). Any new field needs a version bump, a `migrate` block and a migration test.
- Fields: v2 `coins,maxDays,runs,kills,bossKills,crafted,achievements,lastDailyClaim`; v3 `achievementProgress,ownedCosmetics,unlockedGear,titles,hintsSeen,equipped{Cosmetic,Perk,Title},settings{reduceScares},processedReceipts`; v4 `equipment`. Map, storage, buffs, Dread are per-run, never saved.
- Studio: store `PlayerProfiles_Studio`, in-memory fallback on load failure (attr `DataFallback`); published servers kick.

## Survival, fire, downed (docs/systems/survival.md)
- Owner files: `server/Survival/*`, `logic/{SurvivalLogic,Fire*,DayClock,DownedLogic,LightingMath}`, `client/Fire/*`, `client/HUD/DownedUi`.
- Hooks: `SurvivalService.killOutright(player, cause?)` (fall path: `ChunkService.setFallHandler`), `.respawn(player)` (same as revive; `/debug respawn`), `.setReviveHandler`. Revive: client resends `ReviveRequest(target)` every `Downed.ReviveRefreshSeconds` while holding; server cancels after `ReviveStaleSeconds`, beyond `ReviveCancelRange` or invalid side. Player attrs `RunDead` (`Downed.DeadAttribute`), `DownedBleed`, `ReviveProgress`.
- Fire: warm radius 54/72/90, build 90/126/162, light 72/90/108 (Config/Survival.luau, `FIRE_R0`=18); `PointLight` clamps to `Night.FireLightMaxRange` 60. Mobs never spawn inside a lit fire's repel circle (`FireRules`). Warmth drain total clamped by `Meters.MaxWarmthDrainMultiplier`; warm spots (tag `WarmSpot` + `WarmSpotRadius`: lit hearth, hot spring, sleeping bag) stop drain.

## World: terrain, forest, POIs, massive structures (docs/systems/world-gen.md, structures-a.md, structures-b.md)
- Owner files: `logic/{World*,Biome*,TerrainPlan,ForestPlacement,TreeRules,PoiPlan,SiteGround,Massive*,FogMap,*Plan,PlanKitB}`, `server/World/*` (+Structures/StructureKitA|B), `server/Art/*`, `data/{Biomes,Chunks}`.
- `World.heightAt(seed,x,z,flatX?,flatZ?)` block-top Y (camp-aware, pure); `blockHeight/blockIndex/blockCenter/blockOrigin`, `biomeAt`, `ringAt`, `halfExtent`, `isPastEdge`, `belowKillHeight`, `shouldKill`. Ground Y everywhere uses `World.heightAt`; placement rays include `Workspace.Terrain`. Terrain is Roblox Terrain voxels (FillBlock, BlockSize 4), not parts.
- Rings: Biomes.List 0..3 SnowyForest, FrozenLake, MountainsCaves, DeepTundra (`World.StartForestRing` 0). `BiomeService.getRing(player)` sets Player `BiomeRing`; `MapService` handles `MapRequest` -> `MapData{cellSize,cellsPerSide,explored}`, `.markExplored(pos,radius)`; `ChunkService` tags warm spots, spawns IronOre slots, owns node memory (wall-clock respawn). Trees: `ForestPlacement.poiClears` uses `PoiPlan.kindFootprint(kind)`; fires placed after load do not clear trees. POI part budget <= `Art.World.MaxPartsPerPoi`.
- Massive: ids from `Config.Massive.Ids`; `MassiveRules.footprintRadius/ringAllowed/validatePlan`; one structure live at a time (`MaxLiveStructures` 1, `MaxLiveParts` 1000 inside the 6000 total); `MobService.setSpawnBlocker` excludes footprints; plans pure, adapters build shell + carve Terrain.

## Items, inventory, crafting, storage (docs/systems/items-crafting.md)
- Owner files: `ItemCatalog` (merges `data/{Items,Recipes,Structures,Clothing,Food,Rarity}`), `logic/{Inventory*,Equipment,Crafting,Consume,Placement,ItemsGather,Storage,Repair,Cooking,Buffs,ClothingLogic,Ping}`, `server/Items/*`, `server/Social/PingService`, `client/{Storage,Ping}/*`.
- Remotes: `CraftRequest, PlaceRequest, GatherRequest, AttackRequest, SelectSlotRequest, UseItemRequest, AddFuelRequest, UpgradeFireRequest, RepairRequest{slot}, CookRequest{slot,station}, DoorToggleRequest{door}, InventoryMove/InventoryMoveResult, InventoryUpdate, MetersUpdate`; storage `StorageOpenRequest{chest}, StorageCloseRequest, StorageDepositRequest{chest,slot,count}, StorageWithdrawRequest{chest,chestSlot,count}, StorageState{chest?,slots}` (shared by party; `Storage.MaxPerPlayer` 4, 9 slots; `PlacementService` asks `StorageService.placeRefusal`); ping `PingRequest{kind,position}` -> `PingBroadcast`.
- Server grants via `InventoryService.grant(player,id,count)` (overflow drops at feet). Worn (equipped) gear alone feeds Player `ColdResistance` (`ClothingLogic.equipped`, cap `Clothing.MaxColdResistance`); `clearEquipment` exists but is not called at run end. `ItemCatalog.isUnbreakable` (Axe) skips durability. Every new item needs a `Rarity.Tags` entry.
- Success hooks: `CraftingService.setCraftedHandler`, `PlacementService.setPlacedHandler`, `CookingService.setCookedHandler`, `GatherService.setYieldBonusProvider`. `BuffService.getModifiers(player)` (capped). Attrs/tags: `StructureHealth`, `DoorOpen`, Player `Buffs`, `OpenChest`; tags `StructureBlocker, SpikeTrap, StorageChest`.

## Loot (docs/systems/loot.md, chest-art.md)
- Owner files: `data/Rarity`, `logic/{LootRoll,LootChests,ChestStyle}`, `server/Loot/{LootService,LootTables}` (weights SERVER-ONLY, never require from shared/client), `server/Art/ChestArt`, `client/Loot/*`.
- Remotes: `LootOpenRequest{chest}` (tag `Loot.ChestTag`, range <= `ServerOpenRange`, rate `OpenRateInterval`, not yet looted) -> `LootOpened{chest,rarity,items,overflow}`. Chest attrs `ChestRarity, LootStructure, LootDepth, LootOpened`. Structure keys `cabin, plane, cave, ruin, campsite` + `Config.Massive.Ids`; counts via `LootChests.ruleOf`.

## Mobs, events, horror (docs/systems/mobs.md, events.md, horror.md)
- Owner files: `data/{Mobs,Events,Lurkers}`, `logic/{Mob*,Projectile,EventSchedule,DreadLogic,Isolation}`, `server/{Mobs,Combat,Events,Horror}/*`, `client/{Events,Horror,Combat}/*`.
- APIs: `MobService.damage(mob,amount,source?)`, `.setSpawnBlocker`; `BossService.spawnBlizzardBoss(campPos)`; `MobScaling.multipliers(day,ring,party)` + `wolfDamageFactor/wolfSpawnFactor`, all capped then `MaxLiveMobs` (40); `EventService.getModifiers()`, `.isBlizzard()`, `.onBlizzardStart/.onEventStart/.onEventEnd`, `.setSeed`, `.setFullGroupPredicate`; `DreadService.addSighting`, `StalkerService.isHunting()/onStrike` (server only). Remotes: `ShootRequest{direction}` -> `ProjectileFired{shooterId,origin,direction,speed}`; `Cue` (on change only, rate-limited per kind).
- Cue senders: Horror (DreadLevel, StalkerTell, Footsteps, FireGutter, StalkerRetreat, LurkerSighted, IceCrack), Events (Warn*, EventStart/End), Boss (BossWarning). Tags `Stalker`, `Lurker`; Workspace attrs `DarkEvent`, `Blizzard`, `BlizzardWarning`.
- Wiring: `server/Phase3/Wiring.luau` (+ `*Boot.luau` / `*Client.luau`); False Night = `DayNightService.setForcedNight`.

## Meta, shop, achievements (docs/specs/meta-shop.md)
- Owner files: `data/{Achievements,Shop}`, `logic/{AchievementLogic,ShopLogic,PerkLogic,MetaSnapshot}`, `server/Meta/*`, `server/Phase4/{Wiring,PerkModifiers}`, `client/Meta/*`.
- Remotes: `ShopBuyRequest{itemId}` (lobby), `RobuxPurchaseRequest{itemId}`, `PurchaseResult{ok,itemId,coins,reason?}`, `EquipCosmeticRequest/EquipPerkRequest(lobby)/EquipTitleRequest{id}`, `SettingsSetRequest{key,value}`, `HintSeenRequest{hintId}`, `MetaStateRequest`/`MetaState` (never receipts), `AchievementUnlocked{id,coins,title?}`.
- Rules: server recomputes price/ownership/milestones from `data/Shop`, `data/Achievements`, `Config.Meta`. Robux = developer products by `Meta.ProductIds` (0 = never prompt); `ProcessReceipt` bound in both modes; grant idempotent via `hasReceipt/recordReceipt`, then `DataService.save`; profile not loaded -> `NotProcessedYet`; no random or paid-random items. One equipped perk (`Meta.MaxEquippedPerks`), changed in lobby, captured once at run start (`PerkModifiers.capture/multiplier/teamMultiplier/gatherBonus`), `|amount| <= Meta.MaxPerkMagnitude`; perks share `ownedCosmetics`. API: `MetaService.addProgress/raiseProgress/addStat/pushState/getEquippedPerk/onAchievement`. Progress sources wired in Phase4/Wiring (EventService.onEventEnd, `BiomeService.onRingChanged`, revive/place/cook/craft hooks). `RunSummary.rankChange` stays nil.
- Player attrs: `ReduceScares`, `Title`, `Cosmetic`, `BestDays`.

## Atmosphere, perf, HUD (docs/systems/atmosphere.md, hud.md)
- `client/Atmosphere/AtmosphereFx.play(key, position?)` (looks up `data/AudioCues`, applies reduce-scares and `Perf.MaxActiveSounds/MaxParticleEmitters`); `reduceScares()`. `server/Atmosphere/SwingRelay.notify(player)` -> `SwingBroadcast{userId}` within `Perf.SwingBroadcastRange`, cap `Perf.SwingMaxPerSecond`. `logic/{CueResolve,PerfBudget}`; `tools/apply_perf.luau`.
- HUD: `client/HUD/HudController` (public: `start, setInteractHook, addQA, currentAction`; parts: HudKit, HudWidgets, HitWatch, HudTargeting, HudPrompt, HudInput). Right column = `HudConfig.RightStack`; `DeathPanelState` (pure) drives DownedUi + SummaryScreen. Per-tick visuals read Attributes, no per-tick remotes.

## Debug and QA (docs/systems/debug-service.md)
- `server/Debug/DebugService` (Studio-only, `Remotes.DebugCommand`, `logic/DebugCommands`). QA scenarios `tools/qa/*` (README there); RUN-mode needs Workspace `ServerMode="run"` or `/debug mode run`.

## Input, ground, sprint, forage, blizzard (round: bugfix + sprint/forage + blizzard)
- Input: every client input handler calls `src/client/Input/InputGuard.blocked(gameProcessed)` first (logic in shared/logic/InputGate). Drop = G (`Config.Ui.DropKeyName`), Ping = Q. Deny/craft sounds muted via `Config.Ui.MutedSounds`.
- Ground: `server/World/GroundProbe.groundY(x, z, fallbackY)` raycasts real terrain (heightAt = headless fallback); used by camp fire (re-verified 6 Heartbeats, shared/logic/GroundFix), spawn pad, StructureKitA/B grounding, forage spawns. `/debug groundcheck`.
- Drop/pickup carries durability: `ItemDrop.spawn` and `InventoryService.add` take optional durability.
- Sprint: remote `SprintRequest` (Remotes.luau); server `SurvivalService` gates (hunger, downed, dead), sets speed, attribute `Sprinting`; logic shared/logic/SprintLogic; client src/client/Sprint/SprintClient; `Config.Sprint` (Survival.luau). `/debug sprint on|off` -> `SurvivalService.DebugSetSprint`.
- Forage: `server/Forage/ForageService` (started by GatherService; lazy, pooled, part-capped), data shared/data/Forage, plan shared/logic/ForagePlan; `Config.Forage` (Items.luau); items/nodes/recipes merged in ItemCatalog. Forage picked with E via GatherRequest (toolType "hand"). `/debug forage` -> `ForageService.DebugSpawnNear`. `ForageService.takeCoinCredit(player)` NOT yet paid out in RunPayout.
- Blizzard: `server/Events/BlizzardService` (duration = Config.Blizzard.DurationDays x day length; Workspace attr `BlizzardIntensity`); client `Atmosphere/BlizzardFx` (snow emitters, whiteout, fire highlights), math shared/logic/BlizzardWind. No overlay; vignette <= 0.08. `/debug blizzard start|stop|intensity <0..1>` (true/false still toggles the attribute). Debug services reach DebugService via `DebugService.expose` ("Blizzard", "Forage", "Survival"), never static require.
