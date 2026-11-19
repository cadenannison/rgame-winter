--!strict
-- Config module: Meta. Lobby, run lifecycle, teleport and meta progression (coins, shop, achievements caps).
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

-- Phase 2 lobby: pads, party timer, lobby attributes. Owned by brief 7 (contracts); used by briefs 8 and 10.
export type LobbyConfig = {
	MaxPlayers: number, -- lobby server size
	PadCount: number, -- pads 1..PadCount; pad i holds up to i players
	PadTimerSeconds: number, -- countdown from first step; resets to this when someone joins
	PadModeFriends: string, -- host-only pad mode: Roblox friends of the host only
	PadModeOpen: string, -- open-fill: anyone in the lobby
	DefaultPadMode: string,
	PadTag: string, -- CollectionService tag on pad parts
	PadIndexAttribute: string, -- pad part attribute: 1..PadCount
	PlayerPadAttribute: string, -- Player attribute: pad index the player is on (0 = none)
	FriendCheckTimeout: number, -- seconds to wait on IsFriendsWith before refusing the join
	PollInterval: number, -- seconds between pad timer / off-pad checks (one loop for all pads)
	PadEdgeMargin: number, -- studs beyond the pad edge before a member counts as stepped off
	PadHeightMargin: number, -- studs above/below the pad that still count as on it
	LaunchHoldSeconds: number, -- pad stays locked after a successful teleport call, then resets
	PadJoinLift: number, -- studs above the pad top a remote join places the character root
	RootName: string, -- Workspace folder built by tools/build_lobby.luau
	SpawnName: string, -- SpawnLocation inside RootName; lobby players spawn here
	StatPublishSeconds: number, -- lobby stat attribute publish loop (one loop for every player)
	LeaderboardStoreName: string, -- OrderedDataStore for max days
	LeaderboardTopCount: number,
	LeaderboardRefreshSeconds: number, -- one GetSortedAsync per interval
	LeaderboardWriteIntervalSeconds: number, -- at most one UpdateAsync per interval
	LeaderboardMaxPending: number, -- cap on queued leaderboard writes
	LeaderboardRetryAfterFailSeconds: number,
	NameCacheMax: number, -- leaderboard display-name cache size
}

-- Phase 2 run lifecycle. Owned by brief 7; used by brief 9.
export type RunConfig = {
	RejoinWindowSeconds: number, -- single source: disconnected party member's run state is held this long (revive limit = Downed.BleedoutSeconds)
	SummarySeconds: number, -- seconds the run summary shows before the party is sent back to the lobby
	ReturnRetryCount: number, -- teleport-to-lobby retries before kicking with a message
	PollInterval: number, -- seconds between run roster polls (own cadence, not Meters.TickInterval)
	SeedWaitSeconds: number, -- run server boot waits this long for the first player's teleport data (seed)
	ReturnFailedMessage: string, -- kick text when returning to the lobby failed
	SummaryStateAttribute: string, -- LocalPlayer attribute (client-set): "" | "open" | "dismissed"
	ReturnStudioText: string, -- toast when Studio cannot teleport (fallback: lobby mode override)
	ReturnFailedToast: string, -- toast when a real return teleport failed after its retries
	ReturnNotifyKind: string, -- Remotes.Notify kind for those toasts
	ReturnButtonResetSeconds: number, -- Return button text resets after this long
	RefusedMessage: string, -- kick text for a player not in this run's party
	DefaultCause: string, -- summary "what got you" when nothing was recorded
}

-- Teleport data contract between lobby and run servers. Validated by shared/logic/TeleportData via Guard.
export type TeleportConfig = {
	DataVersion: number, -- bump on any TeleportData shape change
	ModeRun: string,
	ModeLobby: string,
	MaxSeed: number, -- seeds are integers in [0, MaxSeed]
	MaxPartySize: number,
	ServerModeAttribute: string, -- Workspace attribute: ModeRun or ModeLobby, set at server boot
	StudioDefaultMode: string, -- Studio play mode when no Workspace ServerMode preset and no /debug mode override
	ModeWaitSeconds: number, -- client waits this long for the ServerMode attribute before defaulting to run UI
	RetryCount: number,
	RetryDelay: number, -- seconds, doubled each retry
}

-- Coin payouts and meta caps. ALL VALUES ARE PLACEHOLDERS pending balance. Owned by brief 7; used by brief 9.
export type MetaConfig = {
	CoinsPerRun: number, -- paid on every run end, even a bad one
	CoinsPerDaySurvived: number,
	CoinsPerKill: number,
	CoinsPerBossKill: number,
	CoinsPerFriendInParty: number, -- small social bonus per friend in the party
	MaxCoinsPerRun: number, -- hard cap on one run's payout
	DailyRewardCoins: number,
	MaxStatValue: number, -- clamp for every saved stat counter
	MaxAchievements: number, -- max entries in profile.achievements
	MaxAchievementIdLength: number,
	CoinsPerDarkEventSurvived: number, -- Phase 3: paid per dark event a player is alive at the end of
	-- Phase 4 (brief 21 contracts; consumers 19 meta, 20 atmosphere). Every saved table has a cap here.
	MinAchievementDefs: number, -- data/Achievements.luau holds MinAchievementDefs..MaxAchievementDefs entries
	MaxAchievementDefs: number, -- (<= MaxAchievements, the saved cap)
	MaxAchievementCoinReward: number, -- cap on one achievement's coin reward
	MaxProgressEntries: number, -- max entries in profile.achievementProgress
	MaxOwnedCosmetics: number, -- max entries in profile.ownedCosmetics
	MaxUnlockedGear: number, -- max entries in profile.unlockedGear
	MaxTitles: number, -- max entries in profile.titles
	MaxHintsSeen: number, -- max entries in profile.hintsSeen
	MaxItemIdLength: number, -- cosmetic / perk / gear / title / hint / progress key length cap
	MaxEquippedPerks: number, -- one perk equipped (and applied) per run
	PerkStats: { string }, -- the only modifiers a perk may change (fractions)
	MaxPerkMagnitude: number, -- cap on any perk's |amount| so none trivializes survival
	MinCoinPrice: number, -- coin shop price bounds
	MaxCoinPrice: number,
	MaxRobuxPrice: number, -- sanity cap on displayed Robux prices (the charged price is the product's)
	MaxCoinPackCoins: number, -- cap on coins one coin pack grants
	MaxStarterGearCount: number, -- cap on one starter gear grant at run start
	StarterGearWaitSeconds: number, -- run start: bounded wait for the inventory before granting gear
	StarterGearPollSeconds: number,
	CosmeticTagPrefix: string, -- character tag prefix (+ slot) for the equipped cosmetic
	CosmeticSlots: { string },
	ProductIds: { [string]: number }, -- developer product id by Shop productKey; 0 = placeholder (never prompted)
	MaxProcessedReceipts: number, -- receipt log cap (oldest evicted); grants are idempotent by PurchaseId
	MaxReceiptIdLength: number,
	RecordHintDays: number, -- HUD shows "N days to your record" when within this many days of maxDays
	BestDaysAttribute: string, -- Player attribute (run server): saved maxDays, for the record hint
	TitleAttribute: string, -- Player attribute: equipped title display name ("" = none), visible to all
	CosmeticAttribute: string, -- Player attribute: equipped cosmetic id ("" = none), visible to all
	MaxFriendBonusFriends: number, -- cap on friends counted for CoinsPerFriendInParty
}

export type Sections = {
	Lobby: LobbyConfig,
	Run: RunConfig,
	Teleport: TeleportConfig,
	Meta: MetaConfig,
}

local Sections: Sections = {
	Lobby = {
		MaxPlayers = 15,
		PadCount = 6,
		PadTimerSeconds = 20,
		PadModeFriends = "friends",
		PadModeOpen = "open",
		DefaultPadMode = "open",
		PadTag = "LobbyPad",
		PadIndexAttribute = "PadIndex",
		PlayerPadAttribute = "PadIndex",
		FriendCheckTimeout = 5,
		PollInterval = 0.25,
		PadEdgeMargin = 2,
		PadHeightMargin = 8,
		LaunchHoldSeconds = 30,
		PadJoinLift = 3,
		RootName = "Lobby",
		SpawnName = "LobbySpawn",
		StatPublishSeconds = 2,
		LeaderboardStoreName = "ArcticMaxDays_v1",
		LeaderboardTopCount = 10,
		LeaderboardRefreshSeconds = 60,
		LeaderboardWriteIntervalSeconds = 6,
		LeaderboardMaxPending = 30,
		LeaderboardRetryAfterFailSeconds = 30,
		NameCacheMax = 200,
	},
	Run = {
		RejoinWindowSeconds = 300, -- design: 5-minute disconnect hold
		SummarySeconds = 15,
		ReturnRetryCount = 3,
		PollInterval = 0.5,
		SeedWaitSeconds = 20,
		ReturnFailedMessage = "Could not return to the lobby. Please rejoin.",
		SummaryStateAttribute = "SummaryState",
		ReturnStudioText = "Studio cannot teleport. Lobby mode is set: Stop, then press Test again.",
		ReturnFailedToast = "Could not reach the lobby. Try again in a moment.",
		ReturnNotifyKind = "error",
		ReturnButtonResetSeconds = 8, -- the Return button text resets if nothing happened
		RefusedMessage = "This run is not available to you.",
		DefaultCause = "Cold",
	},
	Teleport = {
		DataVersion = 1,
		ModeRun = "run",
		ModeLobby = "lobby",
		MaxSeed = 2147483647,
		MaxPartySize = 6,
		ServerModeAttribute = "ServerMode",
		StudioDefaultMode = "lobby", -- plain Studio Test = lobby; Workspace.ServerMode preset or "/debug mode run" for a run
		ModeWaitSeconds = 10,
		RetryCount = 3,
		RetryDelay = 1,
	},
	-- Placeholder payouts (balance pass later). Coins are earned only by playing.
	Meta = {
		CoinsPerRun = 5,
		CoinsPerDaySurvived = 10,
		CoinsPerKill = 1,
		CoinsPerBossKill = 25,
		CoinsPerFriendInParty = 2,
		MaxCoinsPerRun = 5000,
		DailyRewardCoins = 50,
		MaxStatValue = 1e9,
		MaxAchievements = 64,
		MaxAchievementIdLength = 32,
		CoinsPerDarkEventSurvived = 3,
		-- Phase 4 caps and placeholders (balance pass later).
		MinAchievementDefs = 20,
		MaxAchievementDefs = 30,
		MaxAchievementCoinReward = 500,
		MaxProgressEntries = 32,
		MaxOwnedCosmetics = 128,
		MaxUnlockedGear = 32,
		MaxTitles = 64,
		MaxHintsSeen = 64,
		MaxItemIdLength = 32,
		MaxEquippedPerks = 1,
		PerkStats = { "warmthDrain", "hungerDrain", "fuelBurn", "gatherSpeed", "moveSpeed" },
		MaxPerkMagnitude = 0.15,
		MinCoinPrice = 25,
		MaxCoinPrice = 20000,
		MaxRobuxPrice = 1000,
		MaxCoinPackCoins = 10000,
		MaxStarterGearCount = 5,
		StarterGearWaitSeconds = 15, -- run start: bounded wait for the inventory before granting gear
		StarterGearPollSeconds = 0.25,
		CosmeticTagPrefix = "Cosmetic_", -- + slot: character CollectionService tag for the equipped cosmetic
		CosmeticSlots = { "outfit", "trail", "camp", "pet" },
		-- Placeholders: 0 = not configured yet (the server refuses to prompt). Fill from the Creator Dashboard.
		ProductIds = {
			CoinPackSmall = 0,
			CoinPackMedium = 0,
			CoinPackLarge = 0,
			AuroraParka = 0,
			NorthernLightsTrail = 0,
			HuskyPup = 0,
		},
		MaxProcessedReceipts = 100,
		MaxReceiptIdLength = 64,
		RecordHintDays = 2,
		BestDaysAttribute = "BestDays",
		TitleAttribute = "Title",
		CosmeticAttribute = "Cosmetic",
		MaxFriendBonusFriends = 5,
	},
}

return Sections
