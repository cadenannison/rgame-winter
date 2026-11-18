# Decisions (append-only: YYYY-MM-DD — decision — reason)
2026-11-17 — Rojo owns scripts, MCP owns instances — script Source set through MCP is overwritten by Rojo sync.
2026-11-17 — Place file kept out of git; world rebuilt by idempotent tools/ builders — place edits are not diffable and agents cannot save.
2026-11-17 — Tier system (light/standard/full), KIT_TIER overrides .kit-tier — match gate cost to risk; .kit-tier is full because tests exist.
2026-11-17 — Studio pinned by placeId, not name or file — the name changes after publish.
2026-11-17 — Wally package name is cadenannison/arctic-survival — Wally allows only lowercase letters, digits and hyphens.
2026-11-17 — Studio-only QA bridge (BindableFunction in ServerStorage, DebugService.expose) — MCP execute_luau runs in another VM, so required modules are fresh copies without live state.
2026-11-17 — Placement lives in the items system (PlacementService), structures cost one crafted placeable item — reuses crafting for material cost; no separate BuildingService until more structures land.
2026-11-17 — Mob drops go straight to the killer's inventory — no world pickup system yet.
2026-11-17 — Held item is a server-built visual Tool in the character; CoreGui Backpack disabled — replicates to everyone with the default hold pose while gameplay keeps reading the server's selected slot.
2026-11-17 — Client QA bridge is a Studio-only BindableFunction in PlayerScripts exposing the HUD input handlers — MCP Client execute_luau runs in another VM, and QA must exercise the real client path, not raw remotes.
2026-11-17 — Hit confirms come from replicated attributes (HitsLeft/Depleted/MobHealth), no new remote; killed mobs linger Mobs.DeathRemoveDelay so the confirm is seen.
2026-11-17 — Placement rules live in one pure shared module (shared/logic/Placement.validate -> {ok, reason}) used by the client ghost and the server place handler — the preview and the authority cannot disagree; server still re-validates with its own data.
2026-11-17 — Teleport data is a pure shared contract (shared/logic/TeleportData.parse, exact keys, version-checked) wrapped by Guard.teleportData — lobby build and run-server validation share one schema and it is testable in Lune.
2026-11-17 — Server mode comes from the server type: reserved server = run, public = lobby (Studio: Workspace ServerMode preset, default run) — one place hosts both and PartyService already reserves run servers; TeleportAdapter returns to the lobby via a public server.
2026-11-17 — Disconnect hold keeps meters and inventory by UserId (Config.Run.RejoinWindowSeconds = 300, single source), not the character model — Roblox removes the character on leave; a rejoin respawns at camp with the held state.
2026-11-17 — Party members who never arrive in a run are held from the start — otherwise an absent member counted as able to act and the run could never end.
2026-11-17 — A remote pad join (billboard Join, summary Queue again) moves the character onto the pad server-side — the off-pad check otherwise made every remote join a no-op.
2026-11-17 — Phase 3 content is split into pure data files under src/shared/data/, one owner brief each, and ItemCatalog merges Items/Recipes/Structures at load. This lets briefs 13-17 run in parallel without editing shared files. Caps live in Config, and tests/DataTests keeps the data inside them.
2026-11-17 — Phase 3 horror tuning constants live in the replicated Config, but the live values (Dread, hunt chance, event timers) are server-only. The client gets coarse Cue levels and visible-event Attributes only.
2026-11-17 — Biomes map one-to-one onto the 8x8 grid's four Chebyshev rings, so the start forest is ring 0 (World.StartForestRing 0, which puts the camp at the center). This matches the concentric design and debug teleportRing 1..4.
2026-11-17 — Phase 3 boot hooks live in src/server/Phase3/*Boot.luau and src/client/Phase3/*Client.luau, plus one reserved test file per brief. Each brief wires its own systems without touching init.* or tests/run.luau.
2026-11-17 — Worn clothing is the best piece per slot carried in the inventory, with no equip remote. Resistance is summed and capped.
2026-11-17 — EventSchedule is a pure, seeded state machine (same seed = same schedule); EventService only steps it and publishes coarse flags. The run seed (ChunkService) is passed via EventService.setSeed.
2026-11-17 — Gather-node depletion memory lives in ChunkService (wall-clock respawn), so unloading and reloading a chunk no longer resets nodes.
2026-11-17 — POI loot tier comes from distance to camp (BiomeLogic.lootTier), never decreasing outward.
2026-11-17 — Storage chests are shared by everyone on the run server by default (PartyLink defaults to all players; the run server is the party).
2026-11-17 — Cooked food grants its buff through a per-player cooked-food credit counter, so raw food eaten later cannot claim a cooked buff.
2026-11-17 — The watchtower is climbed with a TrussPart ladder beside it (no custom climbing code).
2026-11-17 — Phase 3 cross-system wiring lives in one module, src/server/Phase3/Wiring.luau, called by init.server after ChunkService.start and before the boot hooks; boot hooks stay per brief.
2026-11-17 — Total warmth drain (night x biome x clothing x event x buff) is clamped to Meters.MaxWarmthDrainMultiplier in SurvivalLogic; warm spots (lit hearth, hot spring, sleeping bag) stop drain like a fire.
2026-11-17 — False Night (nightRules) is applied by DayNightService.setForcedNight, so IsNight and every night rule (wolves, drain, Dread) follow it.
2026-11-17 — Event spawn multiplier and the hot-spring bias multiply the mob budget, clamped together to Scaling.MaxSpawnMultiplier, then MaxLiveMobs.
2026-11-17 — Dark-event survival coins are counted per member in RunState (alive at the event end) and paid through RunPayout (Meta.CoinsPerDarkEventSurvived), inside MaxCoinsPerRun.
2026-11-17 — Studio debug "give" grants at most one stack, so placeables (stack 1) do not flood the hotbar during QA.
2026-11-17 — Sleeping bag respawn point deferred (not trivial: needs a per-player spawn provider); documented in KNOWN_ISSUES.

2026-11-17 — Profile v3: Robux idempotency uses a string-keyed receipt log (PurchaseId -> grant time) capped at Meta.MaxProcessedReceipts, oldest evicted; validate checks shape only, ownership of equipped ids is repaired by the meta service on load (never a load failure).
2026-11-17 — Phase 4 boot hooks run in both server modes (ProcessReceipt must be bound on lobby and run servers); all profile writes (settings, hints, shop) are handled by brief 19's MetaService, brief 20 only sends requests and reads MetaState / Player attributes.
2026-11-17 — Live mob cap has one source (MAX_LIVE_MOBS in Config) shared by Scaling.MaxLiveMobs and Perf.MaxLiveMobs.
2026-11-17 — Perks are applied once per run: the run server captures MetaService.getEquippedPerk on each player's first profile load (Phase4/PerkModifiers) and never re-reads it. warmthDrain/hungerDrain/moveSpeed multiply the survival env per player (speed still clamped by Buffs.MaxSpeedBonus); fuelBurn is camp-wide, so the best fuelBurn perk among players present applies; gatherSpeed pays a fractional bonus yield (carry per player), not a faster swing, so the client swing cooldown and Guard rate limits are unchanged. Every multiplier is 1 +/- Meta.MaxPerkMagnitude (PerkLogic).
2026-11-17 — Perks share profile.ownedCosmetics (no ownedPerks field, no schema bump): safe because Shop ids are unique across categories (MetaTests), equipCosmetic requires category cosmetic and equipPerk requires category perk; perks count toward Meta.MaxOwnedCosmetics.
2026-11-17 — Meta progress is wired server-side in Phase4/Wiring.luau through nil-safe success hooks (CraftingService.setCraftedHandler, PlacementService.setPlacedHandler, CookingService.setCookedHandler, SurvivalService.setReviveHandler, GatherService.setYieldBonusProvider) plus EventService.onEventEnd (blizzardsSurvived / darkEventsSurvived) and BiomeService.onRingChanged (deepestRing). profile.crafted is counted live (MetaService.addStat); kills/bossKills/runs/maxDays stay settled once at run end by RunPayout.apply.
2026-11-17 — Robux grants call DataService.save (ProfileStore Profile:Save, non-yielding) right after the receipt is recorded, so a granted purchase is persisted before the next autosave. Real purchase flow stays a hand-test (ProductIds are 0).
2026-11-17 — RunSummary.rankChange stays nil: the leaderboard (OrderedDataStore) lives on lobby servers and a rank lookup from the run server is not cheap; the summary shows the record gap from previousBest, and the HUD toasts "N days to your record" (MetaSnapshot.recordHint, Player BestDays) once per day.
2026-11-17 — Hint timings/lookup range (Config.Hints) and the relayed-swing cap (Config.Perf.SwingMaxPerSecond) moved from client-local configs into Config; AtmosphereConfig/MetaUiConfig keep only layout, colours and copy (same rule as HudConfig/LobbyConfig).
2026-11-17 — Studio meta QA protects the real test profile: Debug/MetaQA backs up every meta field server-side and restores it after the scenario (the bridge copies tables, so QA cannot mutate profiles directly).

2026-11-17 — Massive structures B: rooms are axis-aligned rects with doors/ramps in a pure plan (PlanKitB); one adapter builds the large-part shell, carves Terrain voxels and spawns dressing near players.

2026-11-17 — Massive structures A: research station and mine complex are rooms plus stair halls (flat landing + ramp <= 30 degrees) in a pure plan (StructurePlanKitA); one server adapter carves Terrain, builds the large-part shell and spawns dressing near players; Horror hooks (lurker spots, cue spots, RoomAt) are server data on the Handle.
