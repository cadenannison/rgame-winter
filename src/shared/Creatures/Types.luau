--!strict
-- Creature rig contract (Art Pass 3). Pure types: server builds parts + Motor6Ds named by the rig,
-- the client animates them procedurally from the replicated State attribute. See docs/CREATURES_CONTRACT.md.

export type State = "Idle" | "Walk" | "Run" | "Alert" | "Telegraph" | "Attack" | "Hurt" | "Death"

-- Passed to RigSpec.custom each animation step. `pose` writes are relative to each joint's rest C0.
export type AnimCtx = {
	model: Model,
	joints: { [string]: Motor6D }, -- keyed by PART name (joint is "J_<part>")
	state: State,
	t: number, -- seconds since bind
	dt: number,
	phase: number, -- gait phase, advanced by AnimKit from speed
	speed: number, -- studs/s of the root (client-measured)
	stateTime: number, -- seconds since State last changed
	telegraphLeft: number, -- seconds of wind-up left (0 if none)
	pose: (partName: string, offset: CFrame) -> (), -- set joint Transform = offset (rest pose is identity)
}

export type RigSpec = {
	kind: string,
	body: string, -- part name of the torso
	head: string?,
	legs: { string }, -- ordered pairs diagonal-first for quads: FL, BR, FR, BL (AnimKit alternates by index)
	tail: string?,
	wings: { string },
	attach: { string }, -- Attachment names built on parts (Mouth, Eye, Hit, Trail, Slam ...)
	gait: "Quad" | "Biped" | "Bird" | "Seal" | "Slither" | "Float" | "Flock" | "None",
	stride: number, -- radians of leg swing at Walk
	runScale: number, -- multiplier of stride/frequency at Run
	bob: number, -- studs of body bob
	idleSway: number, -- radians of idle breathing/sway
	telegraphPose: string?, -- named generic wind-up: "Rear" | "Slam" | "Crouch" | "Spread" | "Raise"
	attackPose: string?, -- "Lunge" | "Bite" | "SlamDown" | "Peck" | "Swipe"
	custom: ((AnimCtx) -> ())?, -- optional per-species motion layered AFTER the generic gait
}

export type Binding = {
	step: (dt: number) -> (),
	unbind: () -> (),
	hurt: () -> (), -- client-side flinch (CreatureAnim calls it on a MobHealth drop)
}

export type CreatureDef = {
	kind: string,
	rig: RigSpec,
	-- SERVER: add visual parts + Motor6Ds under `root` (root's own size = hitbox, made invisible by Registry).
	-- Use CreatureBuild.part for every part. Returns nothing; must stay <= Config.Creatures.PartCap parts.
	build: (root: BasePart) -> (),
}

return {}
