--!strict
-- Config module: ArtStructures. Art Pass 4 Agent C knobs: structure kits, interiors, chests, signs, gallery.
-- Owner: Agent C only. Merged into Config by init.luau (Config.ArtStructures.<Key>).

export type ArtStructuresConfig = {
	MaxSingleStoryRing: number, -- structures in rings <= this are ONE story (ring 2 -> rings 1 and 2)
	ChestGlowMaxStuds: number, -- glow particles stay within this distance of the chest
	ChestGlowEmitters: number, -- max glow ParticleEmitters per chest
	BeamMaxStuds: number, -- rare+ beam length cap
	BeamNearStuds: number, -- beams only render within this distance of the local player
	SignFace: string, -- SurfaceGui face used for sign text
	SignPixelsPerStud: number, -- SurfaceGui resolution
	SignMaxDistance: number, -- SurfaceGui MaxDistance for room signs
	NoteMaxDistance: number, -- SurfaceGui MaxDistance for notes
	MaxLandmarkParts: number, -- silhouette parts a structure may add on top of its plan shell
	Mood: { [string]: MoodDef }, -- per massive structure id: lighting mood + danger/loot clues (data-driven)
	DefaultMood: MoodDef,
	Landmarks: { [string]: { LandmarkDef } }, -- per massive structure id: roof-line silhouette parts
	GalleryRowGap: number, -- studs between gallery rows
}

-- Lighting mood. tint: colour lights are blended toward (nil = plan colours). flickerOff/flickerDim: per-update
-- chances (spooky variants flicker harder). dangerTint: colour for lights inside dread/dark rooms.
export type MoodDef = {
	tint: { number }?,
	tintAmount: number, -- 0..1 blend toward tint
	flickerOff: number,
	flickerDim: number, -- cumulative with flickerOff
	dangerTint: { number }?,
	spooky: boolean,
}

-- Silhouette part placed relative to the footprint centre at ground (x/z as a fraction of the half extents,
-- y absolute studs). Style names come from the adapter style tables.
export type LandmarkDef = {
	name: string,
	style: string,
	fx: number, -- fraction of half footprint X (-1..1)
	fz: number,
	y: number, -- centre height above ground
	sx: number,
	sy: number,
	sz: number,
}

export type Sections = { ArtStructures: ArtStructuresConfig }

local Sections: Sections = {
	ArtStructures = {
		MaxSingleStoryRing = 2,
		ChestGlowMaxStuds = 2,
		ChestGlowEmitters = 3,
		BeamMaxStuds = 14,
		BeamNearStuds = 40,
		SignFace = "Front",
		SignPixelsPerStud = 50,
		SignMaxDistance = 60,
		NoteMaxDistance = 14,
		MaxLandmarkParts = 3,
		GalleryRowGap = 60,
		DefaultMood = { tintAmount = 0, flickerOff = 0.15, flickerDim = 0.4, spooky = false },
		Mood = {
			ResearchStation = { -- sterile cold light that fails: the creepy lab
				tint = { 170, 220, 235 },
				tintAmount = 0.5,
				flickerOff = 0.25,
				flickerDim = 0.5,
				dangerTint = { 200, 60, 50 },
				spooky = true,
			},
			MineComplex = { -- weak amber lamps in a huge dark
				tint = { 255, 170, 80 },
				tintAmount = 0.4,
				flickerOff = 0.2,
				flickerDim = 0.45,
				dangerTint = { 200, 60, 50 },
				spooky = true,
			},
			FrozenShipwreck = {
				tint = { 120, 190, 230 },
				tintAmount = 0.4,
				flickerOff = 0.1,
				flickerDim = 0.3,
				spooky = false,
			},
			RuinedTemple = { -- crypt: sickly green-violet gutter
				tint = { 150, 120, 220 },
				tintAmount = 0.55,
				flickerOff = 0.3,
				flickerDim = 0.55,
				dangerTint = { 120, 230, 160 },
				spooky = true,
			},
			RangerLodge = {
				tint = { 255, 190, 110 },
				tintAmount = 0.5,
				flickerOff = 0.05,
				flickerDim = 0.2,
				spooky = false,
			},
			ExpandedRuins = {
				tint = { 170, 190, 210 },
				tintAmount = 0.35,
				flickerOff = 0.15,
				flickerDim = 0.4,
				spooky = false,
			},
		},
		Landmarks = {
			ResearchStation = {
				{
					name = "AntennaMast",
					style = "Mast",
					fx = 0.6,
					fz = -0.6,
					y = 30,
					sx = 1.2,
					sy = 60,
					sz = 1.2,
				},
				{
					name = "AntennaBar",
					style = "Mast",
					fx = 0.6,
					fz = -0.6,
					y = 52,
					sx = 12,
					sy = 0.8,
					sz = 0.8,
				},
			},
			MineComplex = {
				{
					name = "HeadframeA",
					style = "Wood",
					fx = -0.5,
					fz = 0.5,
					y = 20,
					sx = 2,
					sy = 40,
					sz = 2,
				},
				{
					name = "HeadframeB",
					style = "Wood",
					fx = -0.5,
					fz = 0.5,
					y = 38,
					sx = 14,
					sy = 2,
					sz = 2,
				},
			},
			FrozenShipwreck = {
				{
					name = "BrokenMast",
					style = "Wood",
					fx = 0,
					fz = 0,
					y = 26,
					sx = 1.6,
					sy = 52,
					sz = 1.6,
				},
				{ name = "Yard", style = "Wood", fx = 0, fz = 0, y = 40, sx = 16, sy = 1, sz = 1 },
			},
			RuinedTemple = {
				{
					name = "SpireL",
					style = "Stone",
					fx = -0.4,
					fz = -0.4,
					y = 24,
					sx = 4,
					sy = 48,
					sz = 4,
				},
				{
					name = "SpireR",
					style = "Stone",
					fx = 0.4,
					fz = -0.4,
					y = 18,
					sx = 4,
					sy = 36,
					sz = 4,
				},
			},
			RangerLodge = {
				{
					name = "Chimney",
					style = "Stone",
					fx = 0.5,
					fz = 0,
					y = 16,
					sx = 4,
					sy = 32,
					sz = 4,
				},
				{
					name = "FlagPole",
					style = "Wood",
					fx = -0.5,
					fz = 0.5,
					y = 18,
					sx = 0.8,
					sy = 36,
					sz = 0.8,
				},
			},
			ExpandedRuins = {
				{
					name = "BrokenTower",
					style = "Stone",
					fx = 0.5,
					fz = 0.5,
					y = 22,
					sx = 8,
					sy = 44,
					sz = 8,
				},
				{
					name = "BrokenArch",
					style = "Stone",
					fx = -0.5,
					fz = -0.5,
					y = 16,
					sx = 12,
					sy = 3,
					sz = 3,
				},
			},
		},
	},
}

return Sections
