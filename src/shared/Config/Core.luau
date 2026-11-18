--!strict
-- Config module: Core. Data/profile store, spawn and session constants (top-level Config keys).
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

export type Sections = {
	RemoteFolderName: string,
	DefaultRateLimitInterval: number,
	ProfileStoreName: string,
	ProfileKeyPrefix: string,
	StudioAssumeDead: number, -- Studio only: seconds of silence after which a session lock counts as a crashed Studio
	StudioStoreSuffix: string, -- appended to ProfileStoreName in Studio so tests never touch live profiles
	DataFallbackAttribute: string, -- Player attribute set (Studio only) when an in-memory profile is in use
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
	SpawnPadSize: { number }, -- {x, y, z} studs; -- camp spawn pad footprint (grounded with SiteGround.footprintTop)
}

local Sections: Sections = {
	RemoteFolderName = "Remotes",
	DefaultRateLimitInterval = 0.1,
	ProfileStoreName = "PlayerProfiles",
	ProfileKeyPrefix = "Player_",
	StudioAssumeDead = 90, -- ProfileStore default is 630s; autosave keeps live Studio locks fresh (AutoSavePeriod 60)
	StudioStoreSuffix = "_Studio",
	DataFallbackAttribute = "DataFallback",
	AutoSavePeriod = 60,
	SchemaVersion = 4, -- v2: Phase 2 stats; v3: Phase 4 meta; v4: equipment map
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
	SpawnPadSize = { 6, 1, 6 },
}

return Sections
