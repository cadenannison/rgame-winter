--!strict
-- Shared types for the MobService modules (types only; no values).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MobAI = require(Shared.logic.MobAI)
local FireRepel = require(Shared.logic.FireRepel)

export type SpeciesDef = typeof(Config.Mobs.Species.SnowGrouse)

export type MobKind = {
	name: string,
	stats: Config.MobStats,
	behavior: MobAI.Behavior,
	size: Vector3,
	color: Color3,
	category: string, -- "animal" | "hostile" | "miniboss" | "boss"
	cost: number, -- budget slots (0 for bosses and ambient species)
	breaksFire: boolean, -- ignores the fire repel edge (heavy, ranged, bosses)
	breaksStructures: boolean,
	ambush: boolean,
	biomes: { string }?, -- set after the literal for Phase 1 kinds
	minDay: number,
	species: SpeciesDef?, -- Art Pass 3 species (Config.Mobs.Species); nil for the legacy kinds
}

export type MobRow = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	kind: MobKind,
	health: number,
	damage: number,
	nextAttackAt: number,
	wanderUntil: number,
	lastAction: string?,
	burst: MobAI.Burst,
	windup: MobAI.Windup,
	leaveDeadline: number?,
	isBoss: boolean,
	parts: number, -- BaseParts in the model (counted against the live part budget)
	ring: number, -- biome ring at spawn
	home: Vector3, -- spawn point (ReturnAfterFlee)
	groupId: number?, -- herd / pack id
	lastStepAt: number,
	sp: { [string]: any }, -- per-species state bag (species modules own it)
	-- Replicated creature attributes (written on change only by MobState)
	stateWritten: string?,
	targetWritten: number?,
	headingWritten: Vector3?,
	hurtUntil: number,
	attackUntil: number,
	telegraphSeconds: number, -- wind-up length of the telegraph in progress (TelegraphLeft)
	provoked: boolean, -- damaged since the last AI step (Retaliate)
}

export type PlayerInfo = { player: Player, root: BasePart, humanoid: Humanoid }

-- Per-AI-pass environment handed to every species step.
export type Env = {
	infos: { PlayerInfo },
	fires: { FireRepel.Fire },
	danger: boolean, -- night or blizzard
	now: number,
	dt: number, -- seconds since this mob last stepped (clamped)
	nearestInfo: PlayerInfo?,
	nearest: number?, -- flat distance to nearestInfo
}

export type Species = {
	-- Called once after the mob exists (init per-species state in row.sp).
	init: ((row: MobRow) -> ())?,
	step: (row: MobRow, env: Env) -> (),
}

return {}
