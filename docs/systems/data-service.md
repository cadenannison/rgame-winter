# DataService
Tier: full
Purpose: Only module that reads or writes persistent data. Session-locked profile per player via ProfileStore.
Owner files: src/server/Data/DataService.luau, src/shared/logic/ProfileSchema.luau, src/shared/Config/Core.luau
Public API: DataService.start() (once), get(player), onLoaded(cb), failPlayer(player, msg); ProfileSchema.default/migrate/validate
Data touched: Profile schemaVersion 2 { schemaVersion, coins, maxDays, runs, kills, bossKills, crafted, achievements: {[id]=true}, lastDailyClaim } under key Config.ProfileKeyPrefix..UserId. v1 -> v2 migration fills stats (clamped to Config.Meta.MaxStatValue), achievements and lastDailyClaim and keeps coins (tests/ProfileTests). Writers: RunLifecycleService (RunPayout.apply at run end), DailyRewardService (daily claim); LobbyService publishes shown stats as attributes.
Invariants: load timeout 30s then kick; schema validated on every load; never overwrite after a failed load; string keys only; save on leave and BindToClose (ProfileStore); no double load
Exploit surface: no remotes; clients never write data. Other systems must not mutate profiles outside their own service.
Playtest checklist: 1. start_play, run tools/qa/spawn.luau. 2. Set QAForceLoadFailure="data" and rejoin: LoadFailed=true then kick. Read [Data] log lines.
Status: in progress
