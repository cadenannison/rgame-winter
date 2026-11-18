--!strict
-- Config module: Creatures. Shared creature rig/animation knobs (Art Pass 3). Per-species dimensions and
-- palettes live at the top of each src/shared/Creatures/Defs/<Kind>.luau (plain data tables).
-- Merged into Config by Config/init.luau; public API stays Config.Creatures.<Key>.

export type CreaturesConfig = {
	Tag: string, -- CollectionService tag set by Registry.attach on every creature model (server)
	KindAttribute: string, -- model attr: creature kind (Registry key)
	StateAttribute: string, -- model attr: Idle|Walk|Run|Alert|Telegraph|Attack|Hurt|Death (SERVER writes)
	TargetAttribute: string, -- model attr: Player.UserId being targeted (number), absent when none
	HeadingAttribute: string, -- model attr: Vector3 world direction (crow scatter, wisp drift); optional
	TelegraphAttribute: string, -- model attr: seconds of wind-up remaining at the moment State became Telegraph
	States: { string },
	PartCap: number, -- max BaseParts per creature model including root (hard rule from the PM brief)
	AnimRadius: number, -- studs from the camera: only creatures inside it animate, others freeze
	AnimHz: number, -- animation step rate for creatures beyond NearRadius (cheap tier)
	NearRadius: number, -- studs: full-rate animation inside this radius
	MaxAnimated: number, -- hard cap on creatures animated per frame (nearest first)
	HurtSeconds: number, -- how long the client plays Hurt before returning to the server state
	DeathFadeSeconds: number,
	MaxWispLights: number, -- PointLights alive at once on the client (<= 1 per wisp, nearby only)
	WispLightRadius: number,
}

export type Sections = {
	Creatures: CreaturesConfig,
}

local Sections: Sections = {
	Creatures = {
		Tag = "Creature",
		KindAttribute = "CreatureKind",
		StateAttribute = "State",
		TargetAttribute = "Target",
		HeadingAttribute = "Heading",
		TelegraphAttribute = "TelegraphLeft",
		States = { "Idle", "Walk", "Run", "Alert", "Telegraph", "Attack", "Hurt", "Death" },
		PartCap = 25,
		AnimRadius = 120,
		AnimHz = 20,
		NearRadius = 60,
		MaxAnimated = 40,
		HurtSeconds = 0.35,
		DeathFadeSeconds = 1.2,
		MaxWispLights = 4,
		WispLightRadius = 70,
	},
}

return Sections
