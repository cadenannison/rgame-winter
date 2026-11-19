--!strict
-- Mob kind table: Phase 1 kinds (Config.Mobs), Phase 3 kinds (data/Mobs) and the Art Pass 3 species
-- (Config.Mobs.Species). Builds KIND_BY_NAME and the legacy spawn-table entries.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MobSpawnPick = require(Shared.logic.MobSpawnPick)
local MobData = require(Shared.data.Mobs)
local DataTypes = require(Shared.data.Types)
local Types = require(script.Parent.MobTypes)

type MobKind = Types.MobKind

local MobKinds = {}

-- Visual/behavior data rows. Stats come from Config.Mobs.
local KINDS: { MobKind } = {
	{
		name = "ArcticHare",
		stats = Config.Mobs.Hare,
		behavior = "Flee",
		size = Vector3.new(1.5, 1.5, 2),
		color = Color3.fromRGB(240, 240, 245),
		category = "animal",
		cost = 1,
		breaksFire = false,
		breaksStructures = false,
		ambush = false,
		minDay = 1,
	},
	{
		name = "Caribou",
		stats = Config.Mobs.Caribou,
		behavior = "Flee",
		size = Vector3.new(2.5, 4, 5),
		color = Color3.fromRGB(150, 120, 90),
		category = "animal",
		cost = 1,
		breaksFire = false,
		breaksStructures = false,
		ambush = false,
		minDay = 1,
	},
	{
		name = "Wolf",
		stats = Config.Mobs.Wolf,
		behavior = "Hunt",
		size = Vector3.new(2, 3, 4),
		color = Color3.fromRGB(90, 90, 100),
		category = "hostile",
		cost = 1,
		breaksFire = false,
		breaksStructures = false,
		ambush = false,
		minDay = 1,
	},
}
-- Phase 1 kinds spawn in the biomes listed in data/Mobs.
for _, kind in KINDS do
	kind.biomes = MobData.LegacyBiomes[kind.name] or {}
end

-- Visuals for Phase 3 kinds (stats come from data/Mobs).
local VISUALS: { [string]: { size: Vector3, color: Color3 } } = {
	Fish = { size = Vector3.new(1, 0.8, 2), color = Color3.fromRGB(150, 190, 210) },
	PolarBear = { size = Vector3.new(4, 5, 7), color = Color3.fromRGB(235, 235, 240) },
	IceWraith = { size = Vector3.new(2, 5, 2), color = Color3.fromRGB(150, 220, 255) },
	SnowLurker = { size = Vector3.new(2.5, 3, 2.5), color = Color3.fromRGB(205, 215, 225) },
	CaveCrawler = { size = Vector3.new(2, 1.5, 3.5), color = Color3.fromRGB(70, 60, 80) },
	IceWarden = { size = Vector3.new(6, 10, 6), color = Color3.fromRGB(120, 180, 230) },
	CaveMatriarch = { size = Vector3.new(7, 7, 11), color = Color3.fromRGB(80, 55, 90) },
	RuinColossus = { size = Vector3.new(8, 14, 8), color = Color3.fromRGB(120, 115, 110) },
	WhiteoutBeast = { size = Vector3.new(7, 9, 11), color = Color3.fromRGB(245, 245, 250) },
}

local function kindFromDef(def: DataTypes.MobDef): MobKind
	local look = VISUALS[def.kind]
	local hare = Config.Mobs.Hare
	local passive = def.category == "animal"
	return {
		name = def.kind,
		stats = {
			Health = def.health,
			Damage = def.damage,
			WalkSpeed = def.walkSpeed,
			-- MobService moves "Chase" at FleeSpeed, so hostiles use their chase speed here.
			FleeSpeed = if passive then def.fleeSpeed else def.chaseSpeed,
			AggroRange = def.aggroRange,
			AttackRange = def.attackRange,
			AttackCooldown = def.attackCooldown,
			FleeRange = def.fleeRange,
			FleeBurstSeconds = hare.FleeBurstSeconds,
			FleeRestSeconds = hare.FleeRestSeconds,
			HitRadius = def.hitRadius,
			NightOnly = def.nightOnly,
			Weight = def.weight,
			DropId = def.dropId,
			DropCount = def.dropCount,
		},
		behavior = if passive then "Flee" else "Hunt",
		size = if look then look.size else Vector3.new(3, 3, 3),
		color = if look then look.color else Color3.fromRGB(200, 200, 200),
		category = def.category,
		cost = def.budgetCost,
		breaksFire = def.breaksFireRadius,
		breaksStructures = def.breaksStructures,
		ambush = def.ambush,
		biomes = def.biomes,
		minDay = def.minDay,
	}
end

-- Art Pass 3 species: stats from Config.Mobs.Species; spawn weights come from ringWeights, not biomes.
local function kindFromSpecies(def: Types.SpeciesDef): MobKind
	local hare = Config.Mobs.Hare
	local hostile = def.role == "hostile"
	return {
		name = def.id,
		stats = {
			Health = def.health,
			Damage = def.damage,
			WalkSpeed = def.walkSpeed,
			FleeSpeed = def.runSpeed,
			AggroRange = def.aggroRange,
			AttackRange = def.attackRange,
			AttackCooldown = def.attackCooldown,
			FleeRange = def.fleeRange,
			FleeBurstSeconds = hare.FleeBurstSeconds,
			FleeRestSeconds = hare.FleeRestSeconds,
			HitRadius = def.hitRadius,
			NightOnly = def.nightOnly,
			Weight = 0,
			DropId = nil,
			DropCount = 0,
		},
		behavior = if hostile then "Hunt" else "Flee",
		size = Vector3.new(def.size[1], def.size[2], def.size[3]),
		color = Color3.fromRGB(def.color[1], def.color[2], def.color[3]),
		category = if hostile then "hostile" else "animal",
		cost = def.cost,
		breaksFire = false,
		breaksStructures = def.breaksStructures,
		ambush = false,
		biomes = {},
		minDay = def.minDay,
		species = def,
	}
end

MobKinds.ByName = {} :: { [string]: MobKind }
for _, kind in KINDS do
	MobKinds.ByName[kind.name] = kind
end
for _, def in MobData.List do
	MobKinds.ByName[def.kind] = kindFromDef(def)
end
for _, id in Config.Mobs.SpeciesIds do
	local def = Config.Mobs.Species[id]
	assert(def ~= nil and MobKinds.ByName[id] == nil, `MobKinds: bad or duplicate species {id}`)
	MobKinds.ByName[id] = kindFromSpecies(def)
end

-- Legacy spawn table source (pure: MobSpawnPick.legacyEntries; species use ringWeights through MobSpecies).
MobKinds.SpawnEntries = MobSpawnPick.legacyEntries()

-- Species kinds in config order (spawn picks iterate this for a stable table).
MobKinds.SpeciesKinds = {} :: { MobKind }
for _, id in Config.Mobs.SpeciesIds do
	table.insert(MobKinds.SpeciesKinds, MobKinds.ByName[id])
end

return MobKinds
