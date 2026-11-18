# Status
Run: PM-ordered multi-phase run, STOP_AFTER Phase 4. Nothing committed since Phase 0 (CHECKPOINT: no). Briefs for Phase 2 live in "docs/Arctic Survival Game Design Document (1).md" (not GDD_full.md; that file does not exist).

## Phase 1 (core loop, solo): built, human gate NOT confirmed
Systems: chunks/gather, survival, fire (tiers, meter, ring), items/crafting, placement (ghost), mobs (night wolves), food, HUD, toast, camp spawn, client UX pass. The PM ordered Phase 2 to start before the human re-playtest passed; the gate is still open. Human must supply ids in src/shared/Assets.luau (see docs/ART.md). PLACE_ID in CLAUDE.md / docs/MCP_PLAYBOOK.md is still a placeholder (real placeId 130366229723914; Studio instance id changes per Studio session, last 4bc3068e-40b4-4633-88f6-25bf95960e68).
Phase 1 hand-test: place bench near/far from fire; upgrade fire; night wolf bite + dawn retreat; ghost green/red and R rotate; phone emulation ghost at screen centre; fire meter drain and pulse.
Rule: after an MCP "not reachable" error, stop_play then start_play before re-running a scenario (never retry on a dirty session).

## Phase 2 (lobby, party, teleport, run end, saves): DONE, 2026-11-17
check.sh tier=full OK. MCP regression (local player, fresh play each): debug 7/7, day3-solo 10/10, player-path 9/9, night-danger 6/6, build-range 9/9, placement-preview 9/9, lobby-to-run 7/7, lobby-player-path 8/8.
Built: schema v2 (maxDays, runs, kills, bossKills, crafted, coins, achievements, lastDailyClaim) with migration; TeleportData + Guard.teleportData; PartyService (6 pads, timer, friends/open), TeleportAdapter (real + fake), RunSetup; RunLifecycleService (run end, revive limit, disconnect hold 300s, summary, stat save, return to a public lobby), RunPayout, DailyRewardService (UTC-day); lobby lodge (tools/build_lobby.luau, run once, 6 pads), client Lobby UI, leaderboard, summary screen. Contract: docs/INTEGRATION.md. System pages in docs/systems/.
Open: lobby does not resend summary after return (Queue again only works in lobby); hold keeps meters/inventory but not the character; held player who never rejoins loses payout (accepted); no boss mob kinds yet so isBoss always false; second player in lobby-to-run is a simulated UserId; shop items are placeholders; test profile "cannison" has extra runs/kills/coins.
Hand-test on a published place: real TeleportAsync to reserved run server and back to public lobby with seed carried; 2+ player party with real disconnect/rejoin inside 5 min; friend bonus; leaderboard OrderedDataStore (needs Studio API access); run end from a real death; Robux/ProfileStore checks (later phases).
SAVE NEEDED (place changes from build_lobby; agents cannot save the place).

## Phase 3 (biomes, events, horror, mobs/bosses, progression): integrated (brief 18), 2026-11-17
check.sh tier=full OK (adds a 100-day fixed-seed Phase 3 sim: caps for events/dread/hunt/mobs/warmth, meter bounds, determinism). MCP (local player, fresh play each): new blizzard-survival 6/6 (server 4 + client 2), stalker-hunt 6/6 (4 + 2), far-biome 4/4, progression-player-path 6/6; regression debug 7/7, day3-solo 10/10, player-path 9/9, night-danger 6/6, build-range 9/9, placement-preview 9/9, lobby-to-run 7/7, lobby-player-path 8/8.
Wiring: src/server/Phase3/Wiring.luau (events seed/full-group/mob budget/night rules/coins/blizzard boss/fuel burn; survival env = biome x clothing x event x buffs + warm spots; mob ring + hot-spring bias; thin ice warmth + IceCrack; Horror camp/event/light providers; Stalker strike feedback). ProgressionBoot wires MobService.damage / MapService.markExplored directly.
Hand-test: blizzard and False Night feel (look, wind silent until assets), Stalker hunt pacing with a real 2+ party, clothing gate on a long trip to the tundra, phone layout (Map button now under Craft, clear of Ping/Shoot/Act/jump), cooking/repair/ping on mobile.

## Phase 4 (meta, atmosphere, perf): integrated (brief 21), 2026-11-17
check.sh tier=full OK (adds a 100-day Phase 4 meta sim: progress/stat/coin caps, perk magnitude, achievements granted once, profile valid daily; perk/hint/namespacing tests in MetaTests). MCP (local player, fresh play each): new meta-shop 7/7 (lobby), settings-player-path 6/6 (server 1 + client 3 + server 2); perf 7/7 (parts 230/6000, mobs 6/40, chunks 9/26, server heartbeat 16.7/33.3 ms); regression debug 7/7, day3-solo 10/10, player-path 9/9, night-danger 6/6, build-range 9/9, placement-preview 9/9, lobby-to-run 7/7 (coin check now includes run-end achievement coins), lobby-player-path 8/8, blizzard-survival 6/6, stalker-hunt 6/6, far-biome 4/4, progression-player-path 6/6.
Wiring: src/server/Phase4/Wiring.luau (meta progress: blizzards/dark events survived, structures placed, meals cooked, revives, crafted, deepestRing) and Phase4/PerkModifiers.luau (perk captured once per run; survival/fire/gather multipliers capped). Forge first-run hint (completes on a real forge placement). Meta cues through AtmosphereFx; HUD record toast from Player BestDays; Robux grant force-saves.
Hand-test: real Robux purchase + ProcessReceipt on a published place (fill Config.Meta.ProductIds), apply tools/apply_perf.luau then re-run client QA with streaming, phone layout of the Settings button / meta panel, reduce-scares feel, cosmetic tags with real art.
SAVE NEEDED (brief 21 only set and cleared the Workspace ServerMode preset; no scripts left in the place).

## Next
PM: human gate for Phases 1-4 (STOP_AFTER Phase 4).
