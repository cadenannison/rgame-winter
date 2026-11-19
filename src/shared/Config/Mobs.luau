--!strict
-- Config module: Mobs. Mobs and combat: scaling, mob stats, night rules, combat, bosses, projectiles, wolf scaling.
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

local Constants = require("./Constants")

export type ScalingConfig = {
	MobBudgetPerDay: number,
	MobHealthPerDay: number,
	MobDamagePerDay: number,
	MobBudgetPerExtraPlayer: number,
	MaxMobHealthMultiplier: number,
	MaxMobDamageMultiplier: number,
	MaxMobBudgetMultiplier: number,
	-- Phase 3: depth (biome ring 0..3) and party scaling; every factor has a hard cap.
	MaxLiveMobs: number, -- absolute cap on live mobs in the run, after every multiplier
	MobBudgetPerRing: number,
	MaxRingBudgetMultiplier: number,
	MobHealthPerRing: number,
	MaxRingHealthMultiplier: number,
	MobDamagePerRing: number,
	MaxRingDamageMultiplier: number,
	MaxPartyBudgetMultiplier: number, -- cap on MobBudgetPerExtraPlayer scaling
	MobHealthPerExtraPlayer: number,
	MaxPartyHealthMultiplier: number,
	HotSpringSpawnBias: number, -- budget multiplier while a player is near a hot spring (springs attract mobs)
	HotSpringBiasRange: number, -- studs from a hot spring within which the bias applies
	MaxSpawnMultiplier: number, -- cap on event x hot-spring budget multipliers (MaxLiveMobs still applies)
}

export type MobStats = {
	Health: number,
	Damage: number,
	WalkSpeed: number,
	FleeSpeed: number,
	AggroRange: number,
	AttackRange: number,
	AttackCooldown: number,
	FleeRange: number,
	FleeBurstSeconds: number, -- flee runs in bursts of this length...
	FleeRestSeconds: number, -- ...separated by pauses of this length (0 = no pauses)
	HitRadius: number, -- extra melee reach for this mob (body size + generosity)
	NightOnly: boolean,
	Weight: number,
	DropId: string?, -- item given to the killer (ItemCatalog id)
	DropCount: number,
}

-- Art Pass 3 species table (docs/CREATURES_CONTRACT.md). Ring weights are indexed ring + 1:
-- SnowyForest, FrozenLake, MountainsCaves, DeepTundra.
export type DropRow = { id: string, min: number, max: number, chance: number }

export type SpeciesDef = {
	id: string,
	role: string, -- "passive" | "neutral" | "hostile" | "ambient"
	ringWeights: { number }, -- 4 entries (ring + 1)
	behaviors: { string }, -- MobBehaviors* machines the species module composes
	health: number,
	damage: number,
	walkSpeed: number,
	runSpeed: number, -- flee / chase / charge speed
	hitsToKill: number, -- ceil(health / Combat.ToolDamage) at day 1, ring 0, solo (tested)
	telegraphSeconds: number,
	drops: { DropRow },
	partCap: number, -- <= Creatures.PartCap
	spawnCap: number, -- live mobs of this species at once
	packSize: number?, -- herd / pack members spawned together
	aggroRange: number,
	attackRange: number,
	attackCooldown: number,
	fleeRange: number,
	hitRadius: number,
	hostileWeightPerRing: number?, -- extra spawn weight per ring (capped by Scaling.MaxRingBudgetMultiplier)
	cost: number, -- budget slots per mob (0 = ambient, bounded by spawnCap and MaxLiveMobs)
	minDay: number,
	nightOnly: boolean,
	breaksStructures: boolean,
	size: { number }, -- hitbox {x, y, z}
	color: { number }, -- stub body colour {r, g, b} 0-255
	tune: { [string]: number }, -- behavior knobs read by Species/<Kind>.luau
	fireSafe: boolean?, -- explicit Aggro override (nil = Aggro.FireSafeRoles decides): never aggroes a target inside a fire
}

export type SpawningConfig = {
	MaxMobParts: number, -- parts all live mobs may hold together (counted with chunks against Perf.MaxLiveParts)
	PartHeadroom: number, -- keep chunk parts + mob parts below Perf.MaxLiveParts - this
	GroundTolerance: number, -- studs: spawn hit must be within this of the real terrain surface (else ungrounded)
	PackSpread: number, -- studs between pack / herd members at spawn
}

export type DreadSpawnConfig = {
	MinFactor: number, -- ambient weight factor floor (full groups)
	MaxFactor: number, -- ambient weight factor cap (lone players)
	FullGroupFactor: number, -- extra multiplier while the whole party is one cluster
	HazardLead: number, -- studs a wisp aims past a player toward a hazard
	ScatterStep: number, -- studs per scatter move
}

export type MobConfig = {
	Budget: number,
	SpawnMinDistance: number,
	SpawnMaxDistance: number,
	DespawnDistance: number,
	AIActiveRadius: number,
	AITickInterval: number,
	SpawnInterval: number,
	NightBudgetMultiplier: number,
	Tag: string,
	FolderName: string,
	KindAttribute: string,
	HealthAttribute: string,
	WanderRadius: number,
	WanderInterval: number,
	FleeStep: number,
	RetreatStep: number,
	DeathRemoveDelay: number,
	SpawnRayHeight: number,
	SpawnRayLength: number,
	SpawnLift: number,
	BuriedAttribute: string, -- mob model: snow lurker lies hidden until a player is close
	HeldRangedAttribute: string, -- Player: the selected item is a ranged weapon (client shows Shoot)
	BossAttribute: string, -- mob model on bosses (client may show a name plate)
	Hare: MobStats,
	Caribou: MobStats,
	Wolf: MobStats,
	Species: { [string]: SpeciesDef },
	SpeciesIds: { string },
	Spawning: SpawningConfig,
	Dread: DreadSpawnConfig,
	RingAggroPerRing: number, -- hostile aggro range grows this fraction per ring (capped by Scaling.MaxRingDamageMultiplier)
	DebugListRadius: number, -- studs: "/debug mobs" lists mobs within this
	DebugListMax: number, -- most rows "/debug mobs" prints
	AttackHoldSeconds: number, -- State stays Attack this long after a bite (client plays the swing)
	DisplayNames: { [string]: string }, -- kind id -> player-facing name (others: PascalCase split, MobNames)
}

export type CombatConfig = {
	WolfDamageFraction: number,
	WolfCooldownMultiplier: number,
	MeleeRange: number,
	MeleeCooldown: number,
	MeleeBaseDamage: number,
	SpearDamage: number,
	SpearRange: number,
	ToolDamage: number,
	LagCompensation: number,
	WeaponDurabilityPerHit: number,
	HareHitsMin: number, -- target: starting Axe kills a hare in HareHitsMin..HareHitsMax hits (tested)
	HareHitsMax: number,
	WolfHitsMin: number, -- target: starting Axe kills a wolf in WolfHitsMin..WolfHitsMax hits (tested)
	WolfHitsMax: number,
}

-- Night danger: wolf attack telegraph, dawn exit, bite feedback, campfire light. Owned by the night-danger work.
export type NightConfig = {
	WindupSeconds: number, -- wolf growl/telegraph before a bite lands
	StrikeLeeway: number, -- studs beyond AttackRange a target may stand when the bite lands (dodge margin)
	RepelMargin: number, -- studs added to a fire's WarmRadius for the wolf repel edge (wolves never enter WarmRadius)
	DawnLeaveSeconds: number, -- seconds a wolf runs off at dawn before it despawns
	WindupAttribute: string, -- mob model attribute: true during the growl windup (client plays sound/tint)
	BiteAttribute: string, -- Player attribute: counter bumped on every mob bite (client flash + sound)
	FlashColor: { number }, -- {r, g, b} 0-255 screen flash on a bite
	FlashTransparency: number, -- starting transparency of the bite flash
	FlashSeconds: number, -- fade-out length of the bite flash
	TelegraphColor: { number }, -- {r, g, b} wolf tint during windup (client only)
	WarmRadiusAttribute: string, -- fire attribute: warm radius studs (owned by the fire code; Fire.WarmRadius if absent)
	FireLightRange: number, -- fallback warm light range = WarmRadius * this (clamped to FireLightMaxRange)
	FireLightMaxRange: number, -- Roblox PointLight range cap
	FireLightBrightness: number,
	FireLightColor: { number }, -- {r, g, b} 0-255
	FireLightName: string, -- name of the client-made PointLight
	CueVolume: number, -- dusk/dawn cue volume
}

export type WolfScalingConfig = {
	StartDay: number, -- scaling begins after this day (day 1..StartDay = base wolf)
	DamagePerDay: number, -- fractional wolf damage added per day past StartDay (on top of Scaling.MobDamagePerDay)
	MaxDamageMultiplier: number, -- cap on that extra factor
	SpawnRatePerDay: number, -- fractional wolf spawn-budget added per day past StartDay
	MaxSpawnRateMultiplier: number, -- cap (Scaling.MaxLiveMobs still clamps the live total)
}

export type BossConfig = {
	MiniBossFirstDay: number,
	MiniBossMaxAlive: number,
	MiniBossRespawnDays: number,
	BlizzardBossFirstDay: number,
	BlizzardBossChance: number,
	BlizzardBossChancePerDay: number,
	MaxBlizzardBossChance: number,
	HealthPerExtraPlayer: number,
	MaxHealthMultiplier: number,
	DamagePerDay: number,
	MaxDamageMultiplier: number,
}

-- Projectiles (bow): the only way players can hurt each other.
export type ProjectileConfig = {
	Speed: number,
	MaxRange: number,
	MaxLifetime: number,
	MaxActivePerPlayer: number,
	AimAssistDegrees: number, -- mobile aim assist cone
	FriendlyFireMultiplier: number, -- damage a stray projectile deals to a teammate
	MeleeFriendlyFire: boolean, -- always false: melee never hurts players
}

-- Round contract (Agent A owns). Day wildlife density, replacement and aggro rules.
export type WildlifeConfig = {
	DayDensityMultiplier: number, -- scales day wildlife spawn weight/caps (0.5 = half the old density)
	OutsideFireOnly: boolean, -- day wildlife never spawns inside a fire's WarmRadius
	RespawnDays: { number }, -- {min, max}: a killed animal is replaced this many days later (by day counter)
	RespawnMinPlayerDistance: number, -- studs: replacement spawns at least this far from every player
	NearRadius: number, -- mob-count targets within this of a player (rings 1-4 = index 1-4); audit via /debug mobs
	TargetMin: { number },
	TargetMax: { number },
	LegacyCaps: { [string]: number }, -- live cap per legacy kind (they were uncapped and ate the whole budget)
	LegacyDefaultCap: number, -- cap for a legacy kind not listed in LegacyCaps
	UrgentAttempts: number, -- natural-spawn attempts per tick while under TargetMin near the player
	BudgetFloorFromTargets: boolean, -- live budget is at least the ring TargetMax x players (MaxLiveMobs still caps)
}

export type AggroConfig = {
	LeashDistance: number, -- studs: fireSafe hostile gives up beyond this from its target
	LoseSightSeconds: number, -- target out of sight this long = give up and wander
	FireSafeRoles: { string }, -- roles flagged fireSafe by default (non-horror hostiles)
	HitGraceSeconds: number, -- a target that hit the mob this recently may aggro it inside the fire radius
	SightEyeHeight: number, -- studs above the mob's root the line-of-sight ray starts
	FireSafeExclude: { string }, -- horror / ambush kinds never flagged fireSafe (they ignore fire rules)
}

export type PoiseConfig = {
	HeavyMobs: { string }, -- species whose telegraph/slam cannot be cancelled by hits (flinch visual only)
	StaggerOnlyBetweenAttacks: boolean,
}

export type Sections = {
	Wildlife: WildlifeConfig,
	Aggro: AggroConfig,
	Poise: PoiseConfig,
	Scaling: ScalingConfig,
	Mobs: MobConfig,
	Night: NightConfig,
	Combat: CombatConfig,
	Bosses: BossConfig,
	Projectile: ProjectileConfig,
	WolfScaling: WolfScalingConfig,
}

local MAX_LIVE_MOBS = Constants.MAX_LIVE_MOBS

local Sections: Sections = {
	Scaling = {
		MobBudgetPerDay = 0.05, -- fractional mob budget added per day survived
		MobHealthPerDay = 0.04, -- fractional mob health added per day
		MobDamagePerDay = 0.03, -- fractional mob damage added per day
		MobBudgetPerExtraPlayer = 0.35, -- fractional budget added per player beyond the first
		MaxMobHealthMultiplier = 4, -- cap on health scaling
		MaxMobDamageMultiplier = 3, -- cap on damage scaling
		MaxMobBudgetMultiplier = 3, -- cap on day scaling of the mob budget
		MaxLiveMobs = MAX_LIVE_MOBS, -- absolute cap on live mobs (all multipliers applied, then clamped)
		MobBudgetPerRing = 0.1, -- budget added per biome ring out from the start forest
		MaxRingBudgetMultiplier = 1.4,
		MobHealthPerRing = 0.15,
		MaxRingHealthMultiplier = 1.6,
		MobDamagePerRing = 0.1,
		MaxRingDamageMultiplier = 1.4,
		MaxPartyBudgetMultiplier = 2.5, -- cap on the party-size budget factor (6 players)
		MobHealthPerExtraPlayer = 0.1,
		MaxPartyHealthMultiplier = 1.5,
		HotSpringSpawnBias = 1.25, -- hot springs attract mobs: slightly larger budget near one
		HotSpringBiasRange = 60,
		MaxSpawnMultiplier = 2, -- event x hot-spring budget cap (then MaxLiveMobs)
	},
	Mobs = {
		Budget = 12, -- base max live mobs near players (before scaling)
		SpawnMinDistance = 60, -- studs from every player at which mobs may spawn
		SpawnMaxDistance = 160, -- studs from a player beyond which no spawn
		DespawnDistance = 260, -- studs from all players beyond which a mob despawns
		AIActiveRadius = 200, -- AI runs only within this many studs of a player
		AITickInterval = 0.2, -- seconds between AI steps (one loop for all mobs)
		SpawnInterval = 3, -- seconds between spawn attempts
		NightBudgetMultiplier = 1.5, -- budget multiplier at night
		Tag = "Mob", -- CollectionService tag
		FolderName = "Mobs", -- Workspace folder for mob models
		KindAttribute = "MobKind", -- mob model attribute: kind name
		HealthAttribute = "MobHealth", -- mob model attribute: replicated health
		WanderRadius = 18, -- studs per wander step
		WanderInterval = 4, -- mean seconds between wander targets
		FleeStep = 24, -- studs per flee step
		RetreatStep = 20, -- studs per retreat step away from a fire
		DeathRemoveDelay = 0.4, -- seconds a killed mob stays (unattackable) so clients see the hit confirm
		SpawnRayHeight = 120, -- spawn ground raycast starts this far above the anchor
		SpawnRayLength = 300, -- spawn ground raycast length
		SpawnLift = 1, -- studs above ground a mob spawns
		BuriedAttribute = "Buried",
		HeldRangedAttribute = "HeldRanged",
		BossAttribute = "BossKind",
		Hare = {
			Health = 20, -- hit points (3 starting-axe hits at ToolDamage 8; Combat.HareHitsMin/Max)
			Damage = 0, -- passive
			WalkSpeed = 6, -- wander speed
			FleeSpeed = 12, -- flee speed (below player WALK_SPEED 16, so a hare is catchable)
			AggroRange = 0, -- never aggroes
			AttackRange = 0, -- no attack
			AttackCooldown = 0, -- no attack
			FleeRange = 18, -- flees when a player is closer than this
			FleeBurstSeconds = 1.2, -- seconds of each flee sprint
			FleeRestSeconds = 1.4, -- seconds it freezes between sprints
			HitRadius = 4, -- extra melee reach (generous: small target)
			NightOnly = false, -- active during the day
			Weight = 5, -- relative spawn weight
			DropId = "RawMeat", -- drop on kill
			DropCount = 1, -- drop amount
		},
		Caribou = {
			Health = 24, -- hit points (3 axe hits on day 1)
			Damage = 0, -- passive
			WalkSpeed = 8, -- wander speed
			FleeSpeed = 13, -- flee speed (below player WALK_SPEED 16)
			AggroRange = 0, -- never aggroes
			AttackRange = 0, -- no attack
			AttackCooldown = 0, -- no attack
			FleeRange = 22, -- flees when a player is closer than this
			FleeBurstSeconds = 1.6, -- seconds of each flee sprint
			FleeRestSeconds = 1.0, -- seconds it stops between sprints
			HitRadius = 4, -- extra melee reach (large body)
			NightOnly = false, -- active during the day
			Weight = 2, -- relative spawn weight
			DropId = "RawMeat", -- drop on kill
			DropCount = 3, -- drop amount
		},
		Wolf = {
			Health = 35, -- hit points
			Damage = 10, -- damage per bite
			WalkSpeed = 12, -- patrol speed
			FleeSpeed = 19, -- chase speed: above walk 16, below sprint 16 x Sprint.SpeedMultiplier (tested)
			AggroRange = 50, -- studs at which it starts hunting
			AttackRange = 4, -- studs to bite
			AttackCooldown = 2, -- seconds between bites (windup included)
			FleeRange = 0, -- does not flee (retreats only at fire edge)
			FleeBurstSeconds = 0, -- unused (no flee)
			FleeRestSeconds = 0, -- unused (no flee)
			HitRadius = 2, -- extra melee reach
			NightOnly = true, -- hunts at night
			Weight = 3, -- relative spawn weight
			DropId = "Hide", -- drop on kill
			DropCount = 1, -- drop amount
		},
		Species = {
			SnowGrouse = {
				id = "SnowGrouse",
				role = "passive",
				ringWeights = { 5, 2, 0, 0 },
				behaviors = { "Flee", "ReturnAfterFlee" },
				health = 12,
				damage = 0,
				walkSpeed = 4,
				runSpeed = 14, -- below player WALK_SPEED 16: catchable
				hitsToKill = 2, -- ToolDamage 8
				telegraphSeconds = 0,
				drops = {
					{ id = "Feather", min = 1, max = 3, chance = 0.9 },
					{ id = "RawMeat", min = 1, max = 1, chance = 0.4 },
				},
				partCap = 12,
				spawnCap = 4,
				aggroRange = 0,
				attackRange = 0,
				attackCooldown = 0,
				fleeRange = 20,
				hitRadius = 3,
				cost = 1,
				minDay = 1,
				nightOnly = false,
				breaksStructures = false,
				size = { 1.2, 1.2, 1.8 },
				color = { 235, 235, 240 },
				tune = { burstSeconds = 0.9, restSeconds = 0.8, returnDelay = 6, homeRadius = 14 },
			},
			RidgeStag = {
				id = "RidgeStag",
				role = "neutral",
				ringWeights = { 2, 3, 1, 0 },
				behaviors = { "HerdAlert", "Retaliate", "Telegraph" },
				health = 28,
				damage = 9,
				walkSpeed = 6,
				runSpeed = 15,
				hitsToKill = 4,
				telegraphSeconds = 0.6,
				drops = {
					{ id = "Venison", min = 2, max = 3, chance = 1 },
					{ id = "Hide", min = 1, max = 2, chance = 0.7 },
					{ id = "Bone", min = 1, max = 1, chance = 0.3 },
				},
				partCap = 22,
				spawnCap = 5,
				packSize = 2,
				aggroRange = 0,
				attackRange = 5,
				attackCooldown = 2.5,
				fleeRange = 0,
				hitRadius = 4,
				cost = 1,
				minDay = 1,
				nightOnly = false,
				breaksStructures = false,
				size = { 2.5, 4, 5 },
				color = { 120, 95, 75 },
				tune = {
					alertRange = 30,
					alertRadius = 40,
					alertSeconds = 6,
					retaliateSeconds = 10,
					leash = 45,
				},
			},
			LakeSeal = {
				id = "LakeSeal",
				role = "neutral",
				ringWeights = { 0, 4, 1, 0 },
				behaviors = { "TerritorialWarn", "Telegraph" },
				health = 31,
				damage = 8,
				walkSpeed = 3,
				runSpeed = 9,
				hitsToKill = 4,
				telegraphSeconds = 0.6,
				drops = {
					{ id = "Blubber", min = 1, max = 2, chance = 1 },
					{ id = "RawFish", min = 1, max = 1, chance = 0.5 },
					{ id = "Hide", min = 1, max = 1, chance = 0.3 },
				},
				partCap = 14,
				spawnCap = 4,
				aggroRange = 0,
				attackRange = 4.5,
				attackCooldown = 2.5,
				fleeRange = 0,
				hitRadius = 4,
				cost = 1,
				minDay = 1,
				nightOnly = false,
				breaksStructures = false,
				size = { 2, 1.6, 4 },
				color = { 95, 100, 110 },
				tune = {
					warnRange = 20,
					warnSeconds = 2.5,
					commitRange = 9,
					attackSeconds = 5,
					cooldownSeconds = 8,
					loseRange = 30,
				},
			},
			RimeWolverine = {
				id = "RimeWolverine",
				role = "hostile",
				ringWeights = { 0, 3, 2, 1 },
				behaviors = { "Telegraph" },
				health = 34,
				damage = 14,
				walkSpeed = 7,
				runSpeed = 20, -- charge speed
				hitsToKill = 5,
				telegraphSeconds = 0.8,
				drops = {
					{ id = "Claw", min = 1, max = 2, chance = 0.8 },
					{ id = "Hide", min = 1, max = 1, chance = 0.6 },
					{ id = "Fang", min = 1, max = 1, chance = 0.25 },
				},
				partCap = 16,
				spawnCap = 3,
				aggroRange = 36,
				attackRange = 5,
				attackCooldown = 4,
				fleeRange = 0,
				hitRadius = 3,
				hostileWeightPerRing = 0.2,
				cost = 2,
				minDay = 1,
				nightOnly = false,
				breaksStructures = false,
				size = { 2, 2, 3.5 },
				color = { 60, 62, 70 },
				tune = { chargeRange = 22, chargeSeconds = 1.2 },
			},
			ScrapHound = {
				id = "ScrapHound",
				role = "hostile",
				ringWeights = { 0, 0, 4, 1 },
				behaviors = { "PackFlank", "Telegraph" },
				health = 48,
				damage = 9,
				walkSpeed = 9,
				runSpeed = 17,
				hitsToKill = 6,
				telegraphSeconds = 0.5,
				drops = {
					{ id = "Fang", min = 1, max = 1, chance = 0.6 },
					{ id = "Bone", min = 1, max = 2, chance = 0.7 },
					{ id = "Claw", min = 1, max = 1, chance = 0.3 },
				},
				partCap = 18,
				spawnCap = 6,
				packSize = 3,
				aggroRange = 55,
				attackRange = 4,
				attackCooldown = 2.2,
				fleeRange = 0,
				hitRadius = 3,
				hostileWeightPerRing = 0.25,
				cost = 1,
				minDay = 2,
				nightOnly = true,
				breaksStructures = false,
				size = { 2, 2.6, 4 },
				color = { 110, 80, 60 },
				tune = { flankRadius = 14, engageSeconds = 4, slotTolerance = 5 },
			},
			CarrionCrow = {
				id = "CarrionCrow",
				role = "ambient",
				ringWeights = { 2, 3, 2, 1 },
				behaviors = { "Circle" },
				health = 6,
				damage = 0,
				walkSpeed = 6,
				runSpeed = 18,
				hitsToKill = 1,
				telegraphSeconds = 0,
				drops = { { id = "Feather", min = 1, max = 1, chance = 0.2 } },
				partCap = 10,
				spawnCap = 3,
				aggroRange = 0,
				attackRange = 0,
				attackCooldown = 0,
				fleeRange = 0,
				hitRadius = 5,
				cost = 0,
				minDay = 1,
				nightOnly = false,
				breaksStructures = false,
				size = { 1.2, 1.2, 1.6 },
				color = { 25, 25, 30 },
				tune = {
					circleRadius = 14,
					circleSpeed = 1.1,
					scatterRange = 16,
					scatterSeconds = 5,
					centerRange = 40,
				},
			},
			FrostboundBrute = {
				id = "FrostboundBrute",
				role = "hostile",
				ringWeights = { 0, 0, 0, 3 },
				behaviors = { "Telegraph" },
				health = 160,
				damage = 28,
				walkSpeed = 5,
				runSpeed = 8,
				hitsToKill = 20,
				telegraphSeconds = 1.6,
				drops = {
					{ id = "DenseHide", min = 1, max = 2, chance = 1 },
					{ id = "Bone", min = 2, max = 3, chance = 0.8 },
					{ id = "Fang", min = 1, max = 1, chance = 0.4 },
					{ id = "CrystalShard", min = 1, max = 1, chance = 0.3 },
				},
				partCap = 24,
				spawnCap = 1,
				aggroRange = 45,
				attackRange = 8,
				attackCooldown = 4.5,
				fleeRange = 0,
				hitRadius = 6,
				hostileWeightPerRing = 0.3,
				cost = 3,
				minDay = 3,
				nightOnly = false,
				breaksStructures = true,
				size = { 5, 7, 5 },
				color = { 150, 190, 215 },
				tune = { strikeLeeway = 2 },
			},
			AuroraWisp = {
				id = "AuroraWisp",
				role = "ambient",
				ringWeights = { 1, 2, 2, 3 },
				behaviors = { "Lure" },
				health = 10,
				damage = 0,
				walkSpeed = 3,
				runSpeed = 6,
				hitsToKill = 2,
				telegraphSeconds = 0,
				drops = {
					{ id = "AuroraDust", min = 1, max = 1, chance = 0.25 },
					{ id = "CrystalShard", min = 1, max = 1, chance = 0.05 },
				},
				partCap = 8,
				spawnCap = 2,
				aggroRange = 0,
				attackRange = 0,
				attackCooldown = 0,
				fleeRange = 0,
				hitRadius = 4,
				cost = 0,
				minDay = 1,
				nightOnly = true,
				breaksStructures = false,
				size = { 2, 2, 2 },
				color = { 120, 255, 200 },
				tune = {
					lureRange = 45,
					leadDistance = 22,
					touchRange = 3,
					drainCooldown = 6,
					drainWarmth = 4,
					drainCap = 12,
				},
			},
		},
		SpeciesIds = {
			"SnowGrouse",
			"RidgeStag",
			"LakeSeal",
			"RimeWolverine",
			"ScrapHound",
			"CarrionCrow",
			"FrostboundBrute",
			"AuroraWisp",
		},
		Spawning = {
			MaxMobParts = 600, -- all live mob parts together (counted with chunk parts against Perf.MaxLiveParts)
			PartHeadroom = 200, -- chunk parts + mob parts stay below Perf.MaxLiveParts - this
			GroundTolerance = 4, -- spawn hit must be within this of real terrain (else the site is ungrounded)
			PackSpread = 7, -- studs between pack / herd members at spawn
		},
		Dread = {
			MinFactor = 0.15, -- ambient weight factor floor (full groups)
			MaxFactor = 2, -- ambient weight factor cap (lone players)
			FullGroupFactor = 0.5, -- extra multiplier while the whole party is one cluster
			HazardLead = 22, -- studs a wisp aims past a player toward a hazard
			ScatterStep = 30, -- studs per scatter move
		},
		RingAggroPerRing = 0.08, -- hostile aggro range per ring (capped by Scaling.MaxRingDamageMultiplier)
		DebugListRadius = 150,
		DebugListMax = 12,
		AttackHoldSeconds = 0.35, -- State stays Attack this long after a bite
		DisplayNames = { ArcticHare = "Hare" },
	},
	Night = {
		WindupSeconds = 0.7,
		StrikeLeeway = 2,
		RepelMargin = 6,
		DawnLeaveSeconds = 8,
		WindupAttribute = "Windup",
		BiteAttribute = "BiteSeq",
		FlashColor = { 200, 20, 20 },
		FlashTransparency = 0.45,
		FlashSeconds = 0.45,
		TelegraphColor = { 200, 50, 40 },
		WarmRadiusAttribute = "WarmRadius",
		FireLightRange = 1.4,
		FireLightMaxRange = 60,
		FireLightBrightness = 1.6,
		FireLightColor = { 255, 150, 70 },
		FireLightName = "WarmLight",
		CueVolume = 0.4,
	},
	Wildlife = {
		DayDensityMultiplier = 0.5,
		OutsideFireOnly = true,
		RespawnDays = { 1, 3 },
		RespawnMinPlayerDistance = 70,
		NearRadius = 150,
		TargetMin = { 3, 3, 5, 5 },
		TargetMax = { 6, 6, 9, 9 },
		LegacyCaps = { ArcticHare = 2, Caribou = 2, Fish = 2, Wolf = 6 },
		LegacyDefaultCap = 2,
		UrgentAttempts = 4,
		BudgetFloorFromTargets = true,
	},
	Aggro = {
		LeashDistance = 50,
		LoseSightSeconds = 4,
		FireSafeRoles = { "hostile" },
		HitGraceSeconds = 8,
		SightEyeHeight = 2,
		FireSafeExclude = { "SnowLurker", "IceWraith" },
	},
	Poise = {
		HeavyMobs = { "FrostboundBrute" },
		StaggerOnlyBetweenAttacks = true,
	},
	Combat = {
		WolfDamageFraction = 0.2, -- wolf hit = this share of the target's max health before armor
		WolfCooldownMultiplier = 0.85, -- wolf attack cooldown x this (~15% shorter)
		MeleeRange = 8, -- base studs player to target center for a hit (plus MobStats.HitRadius and LagCompensation)
		MeleeCooldown = 0.5, -- seconds between swings
		MeleeBaseDamage = 4, -- fist / non-weapon damage (weapons use ItemCatalog damage)
		SpearDamage = 12, -- spear damage
		SpearRange = 9, -- spear reach in studs
		ToolDamage = 8, -- damage of a gather tool (axe/pickaxe) used as a melee weapon
		LagCompensation = 3, -- extra studs of tolerance for latency
		WeaponDurabilityPerHit = 1, -- durability lost per hit
		HareHitsMin = 2, -- hare: ToolDamage 8 vs Mobs.Hare.Health 20 = 3 hits
		HareHitsMax = 3,
		WolfHitsMin = 4, -- wolf: ToolDamage 8 vs Mobs.Wolf.Health 35 = 5 hits
		WolfHitsMax = 5,
	},
	Bosses = {
		MiniBossFirstDay = 6,
		MiniBossMaxAlive = 1,
		MiniBossRespawnDays = 4,
		BlizzardBossFirstDay = 8,
		BlizzardBossChance = 0.35,
		BlizzardBossChancePerDay = 0.02,
		MaxBlizzardBossChance = 0.6,
		HealthPerExtraPlayer = 0.3,
		MaxHealthMultiplier = 2.5,
		DamagePerDay = 0.02,
		MaxDamageMultiplier = 1.5,
	},
	Projectile = {
		Speed = 140,
		MaxRange = 180,
		MaxLifetime = 2,
		MaxActivePerPlayer = 4,
		AimAssistDegrees = 6,
		FriendlyFireMultiplier = 0.5,
		MeleeFriendlyFire = false,
	},
	WolfScaling = {
		StartDay = 2,
		DamagePerDay = 0.05,
		MaxDamageMultiplier = 2,
		SpawnRatePerDay = 0.06,
		MaxSpawnRateMultiplier = 2,
	},
}

return Sections
