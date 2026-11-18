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
}

export type CombatConfig = {
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

export type Sections = {
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
			FleeSpeed = 20, -- chase speed
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
	Combat = {
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
