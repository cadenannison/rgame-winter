--!strict
-- Config module: Debug. Studio-only DebugService settings (Config.Debug).
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

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
	BridgeName: string,
	ClientBridgeName: string,
	ModeStoreName: string, -- Studio-only DataStore holding the "/debug mode" override
	ModeStoreKey: string,
	ModeReadTimeout: number, -- seconds boot waits for that read before using the default mode
	GiveCount: number,
	MobKinds: { string },
	SpawnMobDistance: number,
	SpawnMobDrop: number,
	TeleportLogMax: number,
	-- Items round (agent A): structures / tp / chest / seed commands
	NearestListMax: number, -- structures listed by /debug structures
	TeleportStructureGap: number, -- studs outside a structure footprint that /debug tp lands
	TeleportLift: number, -- studs above the ground height a /debug tp places the character
	TeleportPlayerOffset: number, -- studs beside the target player
	TeleportWaitSeconds: number, -- max wait for the destination chunk terrain before giving up (no move)
	TeleportBodySize: number, -- footprint (studs) grounded with SiteGround.footprintTop for a tp landing
	TpAliases: { [string]: string }, -- squashed fuzzy word -> massive structure id for /debug tp
	ChestSpawnDistance: number, -- studs in front of the player a /debug chest appears
	MaxSeed: number, -- /debug seed argument upper bound
}

export type Sections = {
	Debug: DebugConfig,
}

local Sections: Sections = {
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
		BridgeName = "DebugBridge", -- Studio-only ServerStorage BindableFunction for tools/qa (another VM)
		ModeStoreName = "StudioDebug",
		ModeStoreKey = "ServerMode",
		ModeReadTimeout = 3,
		ClientBridgeName = "ClientQABridge", -- Studio-only PlayerScripts BindableFunction: real client input handlers
		GiveCount = 10, -- items granted by the Studio-only "give" command
		-- valid "spawnMob" args (MobService kind names; Phase 1 + data/Mobs)
		MobKinds = {
			"ArcticHare",
			"Caribou",
			"Wolf",
			"Fish",
			"PolarBear",
			"IceWraith",
			"SnowLurker",
			"CaveCrawler",
			"IceWarden",
			"CaveMatriarch",
			"RuinColossus",
			"WhiteoutBeast",
		},
		SpawnMobDistance = 10, -- studs in front of the player a "spawnMob" mob appears
		SpawnMobDrop = 3, -- studs below the player root used as the spawn ground height
		TeleportLogMax = 20, -- Studio fake TeleportAdapter: recorded calls kept for QA (oldest dropped)
		NearestListMax = 5,
		TeleportStructureGap = 14,
		TeleportLift = 6,
		TeleportPlayerOffset = 5,
		TeleportWaitSeconds = 10,
		TeleportBodySize = 4,
		TpAliases = {
			research = "ResearchStation",
			beacon = "ResearchStation",
			station = "ResearchStation",
			mine = "MineComplex",
			mines = "MineComplex",
			complex = "MineComplex",
			ship = "FrozenShipwreck",
			shipwreck = "FrozenShipwreck",
			wreck = "FrozenShipwreck",
			temple = "RuinedTemple",
			lodge = "RangerLodge",
			ranger = "RangerLodge",
			ruins = "ExpandedRuins",
		},
		ChestSpawnDistance = 8,
		MaxSeed = 2147483646,
	},
}

return Sections
