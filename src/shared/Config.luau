--!strict

export type DebugConfig = {
	CommandRateInterval: number,
	MaxDay: number,
	MaxClockSpeed: number,
	RingCount: number,
	WorldDayAttribute: string,
	WorldClockSpeedAttribute: string,
	WorldBlizzardAttribute: string,
	WorldDarkEventAttribute: string,
	WorldStalkerAttribute: string,
	PlayerInvincibleAttribute: string,
	PlayerRingAttribute: string,
	DarkEvents: { string },
}

export type Config = {
	Debug: DebugConfig,
	RemoteFolderName: string,
	DefaultRateLimitInterval: number,
	ProfileStoreName: string,
	ProfileKeyPrefix: string,
	AutoSavePeriod: number,
	SchemaVersion: number,
	StartingCoins: number,
	MaxCoins: number,
	LoadFailKickMessage: string,
	SessionEndKickMessage: string,
	DebugForceLoadFailure: boolean,
	QAForceFailureAttribute: string,
	QAForceData: string,
	QAForceSpawn: string,
	DEBUG_DATA: boolean,
	DATA_LOAD_TIMEOUT: number,
	LoadFailKickDelay: number,
	ReadyAttribute: string,
	LoadFailedAttribute: string,
	SPAWN_LOAD_RETRIES: number,
	SPAWN_RETRY_DELAY: number,
	SPAWN_HUMANOID_WAIT: number,
	VOID_KILL_Y: number,
	VOID_CHECK_INTERVAL: number,
	WALK_SPEED: number,
	SpawnPointName: string,
}

local Config: Config = {
	-- Studio-only DebugService. Attributes live on Workspace (world state) or the Player.
	Debug = {
		CommandRateInterval = 0.2,
		MaxDay = 1000,
		MaxClockSpeed = 1000,
		RingCount = 4,
		WorldDayAttribute = "DebugDay",
		WorldClockSpeedAttribute = "DebugClockSpeed",
		WorldBlizzardAttribute = "DebugForceBlizzard",
		WorldDarkEventAttribute = "DebugForceDarkEvent",
		WorldStalkerAttribute = "DebugStalkerSummoned",
		PlayerInvincibleAttribute = "DebugInvincible",
		PlayerRingAttribute = "DebugTeleportRing",
		DarkEvents = { "FalseNight", "TheQuiet", "DeepFreeze" },
	},
	RemoteFolderName = "Remotes",
	DefaultRateLimitInterval = 0.1,
	ProfileStoreName = "PlayerProfiles",
	ProfileKeyPrefix = "Player_",
	AutoSavePeriod = 60,
	SchemaVersion = 1,
	StartingCoins = 0,
	MaxCoins = 1e15,
	LoadFailKickMessage = "Your data could not be loaded. Please rejoin in a moment.",
	SessionEndKickMessage = "Your session ended because you joined another server.",
	-- Studio-only test switch: simulates a failed profile load.
	DebugForceLoadFailure = false,
	-- Studio-only QA hook: set this ReplicatedStorage attribute to QAForceData (profile load fails) or
	-- QAForceSpawn (every LoadCharacterAsync attempt fails). Ignored outside Studio.
	QAForceFailureAttribute = "QAForceLoadFailure",
	QAForceData = "data",
	QAForceSpawn = "spawn",
	-- Verbose [Data] logging in DataService.
	DEBUG_DATA = true,
	-- Hard cap (seconds) on loading one player's profile before they are kicked.
	DATA_LOAD_TIMEOUT = 30,
	-- Seconds to let LoadFailed replicate before the kick.
	LoadFailKickDelay = 1,
	-- Player Attributes read by the client: true once the character is placed / if loading failed.
	ReadyAttribute = "Ready",
	LoadFailedAttribute = "LoadFailed",
	SPAWN_LOAD_RETRIES = 2,
	SPAWN_RETRY_DELAY = 1,
	SPAWN_HUMANOID_WAIT = 5,
	VOID_KILL_Y = -200,
	VOID_CHECK_INTERVAL = 0.5,
	WALK_SPEED = 16,
	SpawnPointName = "SpawnPoint",
}

return Config
