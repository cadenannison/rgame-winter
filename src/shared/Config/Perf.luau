--!strict
-- Config module: Perf. Performance budgets (MaxLiveParts etc.) and network rate limits.
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

local Constants = require("./Constants")

export type NetConfig = {
	CraftRateInterval: number,
	PlaceRateInterval: number,
	GatherRateInterval: number,
	AttackRateInterval: number,
	UseRateInterval: number,
	SelectRateInterval: number,
	PadRateInterval: number,
	PadModeRateInterval: number,
	DailyClaimRateInterval: number,
	-- Phase 3
	PingRateInterval: number,
	StorageRateInterval: number,
	MapRateInterval: number,
	RepairRateInterval: number,
	CookRateInterval: number,
	ShootRateInterval: number,
	-- Phase 4
	ShopRateInterval: number,
	RobuxPromptRateInterval: number,
	EquipRateInterval: number,
	SettingsRateInterval: number,
	MetaStateRateInterval: number,
	HintRateInterval: number,
}

-- Phase 4 performance budgets (brief 20). Target: 30+ FPS on a mid-range phone.
export type PerfConfig = {
	TargetFps: number,
	FpsSampleSeconds: number, -- client FPS sample window for the measurable check (tools/qa)
	MaxLiveParts: number, -- cap on BaseParts under the run world (chunks + structures + mobs + effects)
	MaxLiveMobs: number, -- same value as Scaling.MaxLiveMobs (single source MAX_LIVE_MOBS)
	ChunkLoadBudgetPerFrame: number, -- chunks built or unloaded per Heartbeat
	ChunkPartBudgetPerFrame: number, -- parts created per Heartbeat while a chunk builds
	MaxParticleEmitters: number, -- cap on enabled ParticleEmitters on one client
	MaxParticleRate: number, -- cap on any emitter's Rate
	MaxActiveSounds: number, -- cap on concurrently playing one-shot cue sounds on one client
	StreamingEnabled: boolean,
	StreamingTargetRadius: number,
	StreamingMinRadius: number,
	SwingBroadcastRange: number, -- studs: SwingBroadcast goes only to players this close to the swinger
	SwingMaxPerSecond: number, -- client cap on relayed swings animated per second
	MaxLiveTrees: number, -- cap on streamed tree models alive at once (each <= Forest.MaxPartsPerTree parts)
	TerrainCountsTowardParts: boolean, -- false: terrain is built as Roblox Terrain voxels (FillBlock), NOT parts
}

export type Sections = {
	Net: NetConfig,
	Perf: PerfConfig,
}

local BASE_LIVE_PARTS = Constants.BASE_LIVE_PARTS
local MAX_LIVE_MOBS = Constants.MAX_LIVE_MOBS

local Sections: Sections = {
	-- Minimum seconds between accepted requests per player, by remote (used with Guard).
	Net = {
		CraftRateInterval = 0.3, -- CraftRequest
		PlaceRateInterval = 0.5, -- PlaceRequest
		GatherRateInterval = 0.5, -- GatherRequest
		AttackRateInterval = 0.25, -- AttackRequest (single source; Combat.MeleeCooldown is the swing gate)
		UseRateInterval = 0.3, -- UseItemRequest, AddFuelRequest, ReviveRequest
		SelectRateInterval = 0.1, -- SelectSlotRequest
		PadRateInterval = 0.5, -- PadJoinRequest, PadLeaveRequest
		PadModeRateInterval = 1, -- PadModeRequest
		DailyClaimRateInterval = 2, -- DailyClaimRequest
		PingRateInterval = 0.5, -- PingRequest
		StorageRateInterval = 0.2, -- StorageOpenRequest, StorageDepositRequest, StorageWithdrawRequest
		MapRateInterval = 2, -- MapRequest
		RepairRateInterval = 0.5, -- RepairRequest
		CookRateInterval = 0.3, -- CookRequest
		ShootRateInterval = 0.4, -- ShootRequest
		ShopRateInterval = 1, -- ShopBuyRequest
		RobuxPromptRateInterval = 3, -- RobuxPurchaseRequest
		EquipRateInterval = 0.5, -- EquipCosmeticRequest, EquipPerkRequest, EquipTitleRequest
		SettingsRateInterval = 0.5, -- SettingsSetRequest
		MetaStateRateInterval = 2, -- MetaStateRequest
		HintRateInterval = 0.5, -- HintSeenRequest
	},
	-- Phase 4 (brief 20 consumes; brief 21 owns the values).
	Perf = {
		TargetFps = 30,
		FpsSampleSeconds = 5,
		MaxLiveParts = BASE_LIVE_PARTS, -- 6000: never raised (PM rule); massive structures must fit inside it
		MaxLiveMobs = MAX_LIVE_MOBS,
		ChunkLoadBudgetPerFrame = 1,
		ChunkPartBudgetPerFrame = 150,
		MaxParticleEmitters = 24,
		MaxParticleRate = 40,
		MaxActiveSounds = 12,
		StreamingEnabled = true,
		StreamingTargetRadius = 384,
		StreamingMinRadius = 96,
		SwingBroadcastRange = 150,
		SwingMaxPerSecond = 12, -- client cap on relayed swings animated per second
		MaxLiveTrees = 420, -- 420 trees * 3 parts = 1260 of the 6000 part budget; terrain blocks are voxels, not parts
		TerrainCountsTowardParts = false, -- 6400 blocks per chunk would blow MaxLiveParts as parts: use Terrain voxels
	},
}

return Sections
