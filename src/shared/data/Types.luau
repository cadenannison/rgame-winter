--!strict
-- Phase 3 data types (brief 12 contracts). Pure types: no Roblox APIs, no values.
-- Every table in src/shared/data/ is typed here so ItemCatalog and the owning briefs share one shape.
-- Owner: brief 12 (later changes go through brief 18 / the PM).

local Rarity = require("./Rarity")

export type Stack = { id: string, count: number }

export type ItemDef = {
	id: string,
	name: string,
	kind: string, -- "resource" | "tool" | "weapon" | "placeable" | "food" | "clothing" | "ammo" | "light" | "map"
	maxStack: number,
	toolType: string?, -- "axe" | "pickaxe" (gather tools)
	toolTier: number?,
	durability: number?, -- starting durability for tools, weapons and lights (lights: seconds of burn)
	damage: number?, -- weapons (ranged: per projectile)
	structureId: string?, -- placeables
	hunger: number?, -- food: hunger restored per item
	-- Phase 3 (all optional; nil = not applicable)
	ranged: boolean?, -- weapon fires projectiles via Remotes.ShootRequest
	ammoId: string?, -- item consumed per shot
	clothingSlot: string?, -- Config.Clothing.Slots entry
	clothingTier: number?, -- 1..Config.Clothing.MaxTier
	coldResistance: number?, -- resistance points while worn (stamped from Config.Items)
	category: string?, -- Config.Items category (stamped by ItemCatalog)
	equipSlot: string?, -- Config.Equipment.Slots entry it can be worn in (stamped by ItemCatalog)
	lightRadius: number?, -- light items: studs of light (torch/lantern/flare)
	repelsStalker: boolean?, -- lit light repels the Stalker (Config.Stalker.TorchRepelRadius / FlareRepelRadius)
	endsHunt: boolean?, -- using it ends an active hunt (flare)
	repairable: boolean?, -- can be repaired at Config.Repair.Station
	fuelSeconds: number?, -- campfire burn time per item at tier 1 (stamped from Config.Items; nil = not fuel)
	-- Loot round: stamped by ItemCatalog from data/Rarity.Tags (always set on ItemCatalog.Items entries)
	rarity: Rarity.Rarity?,
	lootCategory: Rarity.LootCategory?, -- nil = never found in loot chests
}

export type Recipe = {
	id: string,
	tier: number, -- panel ordering (0 = by hand, 1 = workbench, 2 = forge)
	station: string?, -- Config.Craft.Stations key required nearby (nil = by hand)
	inputs: { Stack },
	output: Stack,
}

-- Placeable structure (placed via PlaceRequest; costs one item of itemId). Size in studs.
export type StructureDef = {
	id: string,
	itemId: string,
	role: string, -- "workbench" | "campfire" | "forge" | "cooking" | "storage" | "wall" | "door" | "trap" | "watchtower" | "bed" | "maptable"
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	tier: number?, -- station tier
	station: string?, -- Config.Craft.Stations key this structure provides
	-- Phase 3 (optional)
	maxHealth: number?, -- breakable by heavy mobs/bosses (nil = indestructible)
	blocksPath: boolean?, -- walls, closed doors
	opensForParty: boolean?, -- door: any party member may toggle
	trapDamage: number?,
	trapCooldown: number?, -- seconds between trap hits
	storageSlots: number?, -- shared party chest
	restRadius: number?, -- sleeping bag: stops warmth drain within this many studs
	respawnPoint: boolean?, -- sleeping bag: party respawn option
	viewBonus: number?, -- watchtower: extra map explore radius (studs) while standing on it
}

-- Gather node kind (ItemCatalog.Nodes).
export type NodeDef = {
	kind: string,
	toolType: string,
	minTier: number,
	yieldId: string,
	yieldCount: number,
	verb: string, -- prompt / toast verb ("Chop", "Mine")
	toolId: string, -- item that harvests it (prompt "Chop: needs Axe")
}

-- Biome ring. ring matches WorldLayout.ringOf (0 = center). Radii are Chebyshev studs from the map center.
export type BiomeDef = {
	id: string,
	name: string,
	ring: number,
	innerRadius: number,
	outerRadius: number,
	coldSeverity: number, -- warmth drain multiplier (<= Config.Biome.MaxColdSeverity)
	requiredColdResistance: number, -- below this, Config.Biome.Underdressed* applies
	mobTier: number,
	lootTier: number,
	nodeKinds: { string }, -- ItemCatalog.Nodes kinds that appear here (new kinds added by brief 13/17)
	lurkerKind: string?, -- shared/data/Lurkers.luau kind
	hotSprings: boolean, -- hot-spring warm spots may appear
	color: { number }, -- {r, g, b} block-out ground color (Phase 4 art replaces)
}

-- One hand-built chunk variant. Slot counts are per chunk; the generator rotates variants by seed.
export type ChunkVariant = {
	id: string,
	biome: string, -- BiomeDef.id
	weight: number,
	trees: number,
	rocks: number,
	ore: number,
	food: number,
	spawnZones: number,
	poiSlots: number,
	poiKinds: { string }, -- "cabin" | "plane" | "cave" | "campsite" | "hotspring" | "ruin" | "thinice"
}

-- Dark event. Effects are multipliers; caps in Config.Events.
export type EventDef = {
	id: string, -- Config.Debug.DarkEvents entry
	name: string,
	minDay: number, -- >= Config.Events.FirstDay
	weight: number,
	warningSeconds: number,
	durationSeconds: number,
	warningCue: string, -- Config.Cue.Kinds entry
	blockedByFullGroup: boolean, -- big events need someone isolated
	nightRules: boolean, -- false night: night drain, night spawns, vision drop
	silence: boolean, -- the quiet: ambient audio and wildlife stop
	warmthDrainMultiplier: number,
	fuelBurnMultiplier: number,
	dreadGainMultiplier: number,
	huntChanceBonus: number, -- added to the Stalker hunt chance (still capped by Stalker.MaxHuntChance)
}

export type BlizzardDef = {
	warningSeconds: number,
	durationSeconds: number,
	warmthDrainMultiplier: number,
	dreadGainMultiplier: number,
	fogEnd: number, -- studs (client lighting)
	warningCue: string,
}

-- Mob. Phase 1 kinds (ArcticHare, Caribou, Wolf) stay in Config.Mobs; Phase 3 kinds live here.
export type MobDef = {
	kind: string,
	name: string,
	category: string, -- "animal" | "hostile" | "miniboss" | "boss"
	biomes: { string }, -- BiomeDef ids it spawns in (boss: where it attacks)
	minDay: number,
	health: number,
	damage: number,
	walkSpeed: number,
	chaseSpeed: number,
	fleeSpeed: number,
	aggroRange: number,
	attackRange: number,
	attackCooldown: number,
	fleeRange: number,
	hitRadius: number,
	nightOnly: boolean, -- hostiles also hunt during blizzards
	weight: number, -- spawn weight inside its biome budget (0 = never in the normal budget)
	budgetCost: number, -- budget slots it uses
	dropId: string?,
	dropCount: number,
	ranged: boolean,
	projectileRange: number?,
	breaksFireRadius: boolean, -- ranged/heavy/bosses ignore the fire repel edge
	breaksStructures: boolean,
	ambush: boolean, -- snow lurker: hides until close
	aquatic: boolean, -- fish: only in frozen-lake water slots
}

export type LurkerDef = {
	kind: string,
	biome: string,
	behavior: string, -- "watch" | "scratch" | "eyes"
	dreadOnSight: number, -- <= Config.Dread.Max
	vanishDistance: number,
	thinIceWarmthLoss: number?, -- scratchers: falling through marked thin ice
	torchRetreatRadius: number?, -- eyes: back away from torchlight
}

export type ClothingTier = {
	tier: number,
	label: string,
	resistancePerPiece: number,
}

export type BuffDef = {
	id: string,
	name: string,
	durationSeconds: number,
	warmthDrainMultiplier: number, -- 1 = none
	hungerDrainMultiplier: number,
	healthRegenBonus: number, -- per second
	speedMultiplier: number,
	debuff: boolean,
}

export type CookDef = {
	rawId: string,
	cookedId: string,
	stationOnly: boolean, -- true = needs the cooking station (not a campfire)
}

-- ===== Phase 4 (brief 21 contracts) =====

-- Condition as data: unlocked when ProfileSchema.getStat(profile, stat) >= atLeast.
export type StatCondition = {
	stat: string, -- ProfileSchema.STAT_FIELDS or PROGRESS_FIELDS entry
	atLeast: number,
}

export type AchievementDef = {
	id: string, -- saved in profile.achievements (<= Meta.MaxAchievementIdLength)
	name: string,
	description: string,
	condition: StatCondition,
	coins: number, -- 0..Meta.MaxAchievementCoinReward, paid once on unlock
	title: string?, -- TitleDef id granted on unlock
}

export type TitleDef = {
	id: string, -- saved in profile.titles
	name: string, -- shown above the head (Meta.TitleAttribute)
}

export type PerkEffect = {
	stat: string, -- Meta.PerkStats entry
	amount: number, -- signed fraction, |amount| <= Meta.MaxPerkMagnitude
}

export type GearGrant = {
	itemId: string, -- ItemCatalog.Items id granted at run start
	count: number, -- 1..Meta.MaxStarterGearCount (and <= the item's maxStack)
}

-- One shop entry. No entry is ever random: every purchase grants exactly what is listed.
export type ShopItemDef = {
	id: string, -- saved id (<= Meta.MaxItemIdLength)
	name: string,
	category: string, -- "cosmetic" | "perk" | "gear" | "coinPack"
	currency: string, -- "coins" | "robux"
	price: number, -- coins: Meta.MinCoinPrice..MaxCoinPrice; robux: display price only (<= MaxRobuxPrice)
	productKey: string?, -- robux only: Config.Meta.ProductIds key
	cosmeticSlot: string?, -- cosmetics: "outfit" | "trail" | "camp" | "pet"
	perk: PerkEffect?, -- perks
	gear: GearGrant?, -- starter gear
	requires: StatCondition?, -- milestone gate (starter gear tiers)
	coins: number?, -- coin packs: coins granted (<= Meta.MaxCoinPackCoins)
}

-- Presentation for one cue: a sound and/or particle Assets key. Pure data (client plays it).
export type AudioCueDef = {
	key: string, -- Config.Cue.Kinds entry, or an extra key (event/stalker/world/ui)
	group: string, -- "horror" | "event" | "world" | "combat" | "ui" | "meta"
	sound: string?, -- Assets key ("" id = silent until supplied)
	particle: string?, -- Assets key (particle texture)
	volume: number, -- 0..1
	loop: boolean,
	scary: boolean, -- scaled by Settings.ReducedScareVisualMultiplier when reduceScares is on
}

return {}
