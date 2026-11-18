--!strict
-- Config module: Art. Art values: hub art and world art (props, biome art).
-- Merged into Config by Config/init.luau; public API stays Config.<Section>.<Key>.

-- Art pass budgets and layout (docs/ART_PLAN.md). Layout numbers for the hub plaza live here so
-- swapping a prop or moving a building is one edit; asset ids live in shared/Assets.
export type HubArtConfig = {
	Origin: { number }, -- plaza centre {x,y,z} (high above the run map). Vectors and colours are plain number arrays (Config has no Roblox types); see shared/ArtKit
	GroundRadius: number,
	GroundThickness: number,
	BarrierRadius: number, -- invisible wall ring: players stay inside it
	BarrierHeight: number,
	CobbleRadius: number, -- central stone plaza
	SpawnPos: { number }, -- offset from Origin
	PadArcCenter: { number }, -- offset from Origin
	PadArcRadius: number,
	PadArcHalfDegrees: number,
	PadBase: number, -- pad 1 width in studs
	PadStep: number, -- extra width per party size
	PadThickness: number,
	ShopPos: { number },
	LeaderboardPos: { number },
	LocalBoardPos: { number },
	StatsPos: { number },
	MirrorPos: { number },
	FirePitPositions: { { number } },
	LampRingRadius: number,
	LampRingCount: number,
	ClearRadius: number, -- scatter props stay this far from buildings
	TreeCountInner: number,
	TreeCountOuter: number,
	TreeInnerMin: number,
	TreeOuterMax: number,
	RockCount: number,
	DriftCount: number,
	MountainCount: number,
	MountainRadius: number,
	SnowHeight: number,
	SnowRate: number,
	SnowAreaRadius: number,
	Seed: number,
	MaxParts: number, -- budget asserted by the builder and tools/qa/hub-art
	MaxLights: number,
	MaxEmitters: number,
	MaxParticleRate: number, -- sum of ParticleEmitter.Rate in the hub
	PromptDistance: number,
	PulseSpeed: number, -- pad pulse, radians per second
	FlickerSpeed: number,
	LampLight: { Range: number, Brightness: number }, -- lamp post lantern PointLight (warm, readable on snow at dusk)
	FireLight: { Range: number, Brightness: number }, -- fire pit / bonfire PointLight
	Tags: {
		Lamp: string,
		Shop: string,
		ShopPrompt: string,
		Stats: string,
		StatsPrompt: string,
		Mirror: string,
		MirrorPrompt: string,
		Leaderboard: string,
		LocalBoard: string,
		Pulse: string,
	},
	Ambient: {
		ClockTime: number,
		Brightness: number,
		FogEnd: number,
		FogColor: { number },
		Ambient: { number },
		OutdoorAmbient: { number },
		AtmosphereColor: { number },
		AtmosphereDecay: { number },
		AtmosphereDensity: number,
		AtmosphereHaze: number,
	},
	Palette: { [string]: { number } },
}

-- World art (pass 2): per-biome look. Biome ids match data/Biomes. Materials are Enum.Material names.
export type WorldBiomeArt = {
	Ground: { number }, -- chunk ground colour
	GroundAlt: { number }, -- colour of the ground patches
	Material: string,
	PatchMaterial: string,
	Atmosphere: {
		Color: { number },
		Decay: { number },
		Density: number,
		Haze: number,
		Glare: number,
	},
	Tint: { Color: { number }, Saturation: number, Contrast: number, Brightness: number },
	Snow: { Rate: number, Speed: number, Drift: number }, -- client falling snow (rate/s, fall speed, sideways)
	Wind: { Rate: number, Speed: number }, -- client wind streaks (horizontal)
	TreeSet: { string },
	RockSet: { string },
	Decor: { { kind: string, count: number } }, -- ground cover per chunk (ChunkDecorBudget caps the parts)
}

export type WorldArtConfig = {
	Seed: number,
	Biomes: { [string]: WorldBiomeArt },
	BlendStuds: number, -- client biome blend width either side of a ring border
	UpdateInterval: number, -- client blend refresh seconds
	ParticleTexture: string,
	ParticleHeight: number, -- emitter plate height above the camera
	ParticleArea: number, -- emitter plate side in studs
	MaxEmitters: number,
	MaxParticleRate: number, -- client total (snow + wind) cap
	MaxPartsPerTree: number,
	MaxPartsPerRock: number,
	MaxPartsPerPoi: number,
	ChunkDecorBudget: number, -- ground cover + patch parts per chunk
	ChunkPatchCount: number, -- ground colour patches per chunk
	PatchSize: { number }, -- min,max patch side studs
	DecorEdgeMargin: number, -- decor stays this far inside the chunk edge
	HearthLight: { Range: number, Brightness: number },
	SpringSteamRate: number,
	Palette: { [string]: { number } },
}

export type ArtConfig = {
	Hub: HubArtConfig,
	World: WorldArtConfig,
	AssetFolderName: string, -- ServerStorage folder holding sanitized Creator Store models (name = Assets key)
	GalleryRoot: string, -- Workspace folder for /debug gallery
	GallerySets: { string },
	GallerySpacing: number,
	GalleryDistance: number, -- studs in front of the caller
}

export type Sections = {
	Art: ArtConfig,
}

local Sections: Sections = {
	Art = {
		AssetFolderName = "ArtAssets",
		GalleryRoot = "Gallery",
		GallerySets = { "hub", "world", "clear" },
		GallerySpacing = 40,
		GalleryDistance = 40,
		World = {
			Seed = 7741,
			BlendStuds = 70,
			UpdateInterval = 0.2,
			ParticleTexture = "rbxasset://textures/particles/sparkles_main.dds",
			ParticleHeight = 28,
			ParticleArea = 90,
			MaxEmitters = 2,
			MaxParticleRate = 40,
			MaxPartsPerTree = 9,
			MaxPartsPerRock = 6,
			MaxPartsPerPoi = 60,
			ChunkDecorBudget = 16, -- lowered (was 48) so massive structures fit Perf.MaxLiveParts
			ChunkPatchCount = 4,
			PatchSize = { 40, 90 },
			DecorEdgeMargin = 12,
			HearthLight = { Range = 26, Brightness = 2.2 },
			SpringSteamRate = 5,
			Biomes = {
				SnowyForest = {
					Ground = { 232, 240, 248 },
					GroundAlt = { 206, 222, 240 },
					Material = "Snow",
					PatchMaterial = "Snow",
					Atmosphere = {
						Color = { 190, 205, 225 },
						Decay = { 120, 140, 175 },
						Density = 0.3,
						Haze = 1.4,
						Glare = 0,
					},
					Tint = {
						Color = { 238, 244, 255 },
						Saturation = -0.03,
						Contrast = 0.04,
						Brightness = 0,
					},
					Snow = { Rate = 14, Speed = 6, Drift = 1.5 },
					Wind = { Rate = 0, Speed = 30 },
					TreeSet = { "PineTall", "PineFat", "PineYoung" },
					RockSet = { "Boulder", "Slab" },
					Decor = {
						{ kind = "Drift", count = 10 },
						{ kind = "Bush", count = 8 },
						{ kind = "Stump", count = 4 },
						{ kind = "Tuft", count = 5 },
					},
				},
				FrozenLake = {
					Ground = { 170, 214, 238 },
					GroundAlt = { 120, 176, 216 },
					Material = "Ice",
					PatchMaterial = "Glacier",
					Atmosphere = {
						Color = { 170, 205, 232 },
						Decay = { 90, 130, 180 },
						Density = 0.26,
						Haze = 0.9,
						Glare = 0.2,
					},
					Tint = {
						Color = { 220, 238, 255 },
						Saturation = 0.04,
						Contrast = 0.06,
						Brightness = 0.02,
					},
					Snow = { Rate = 6, Speed = 5, Drift = 2 },
					Wind = { Rate = 6, Speed = 36 },
					TreeSet = { "PineFrost", "DeadTree" },
					RockSet = { "IceRock", "Boulder" },
					Decor = {
						{ kind = "Crack", count = 12 },
						{ kind = "Shard", count = 8 },
						{ kind = "Reeds", count = 9 },
						{ kind = "Drift", count = 4 },
					},
				},
				MountainsCaves = {
					Ground = { 112, 118, 132 },
					GroundAlt = { 78, 84, 100 },
					Material = "Slate",
					PatchMaterial = "Rock",
					Atmosphere = {
						Color = { 140, 150, 172 },
						Decay = { 84, 92, 120 },
						Density = 0.36,
						Haze = 1.8,
						Glare = 0,
					},
					Tint = {
						Color = { 210, 220, 242 },
						Saturation = -0.12,
						Contrast = 0.1,
						Brightness = -0.02,
					},
					Snow = { Rate = 8, Speed = 8, Drift = 6 },
					Wind = { Rate = 12, Speed = 48 },
					TreeSet = { "PineYoung", "DeadTree" },
					RockSet = { "DarkBoulder", "Slab", "DarkBoulder" },
					Decor = {
						{ kind = "Scree", count = 14 },
						{ kind = "Crystal", count = 6 },
						{ kind = "Drift", count = 5 },
						{ kind = "Rubble", count = 5 },
					},
				},
				DeepTundra = {
					Ground = { 148, 150, 156 },
					GroundAlt = { 218, 224, 232 },
					Material = "Ground",
					PatchMaterial = "Snow",
					Atmosphere = {
						Color = { 205, 208, 218 },
						Decay = { 120, 116, 124 },
						Density = 0.4,
						Haze = 2.4,
						Glare = 0.5,
					},
					Tint = {
						Color = { 255, 246, 236 },
						Saturation = -0.2,
						Contrast = 0.18,
						Brightness = 0.03,
					},
					Snow = { Rate = 4, Speed = 10, Drift = 14 },
					Wind = { Rate = 24, Speed = 70 },
					TreeSet = { "DeadTree", "DeadTwisted" },
					RockSet = { "DarkSlab", "DarkBoulder" },
					Decor = {
						{ kind = "Rubble", count = 12 },
						{ kind = "Tuft", count = 12 },
						{ kind = "Scree", count = 8 },
						{ kind = "Drift", count = 4 },
					},
				},
			},
			Palette = {
				Snow = { 238, 245, 252 },
				SnowShade = { 205, 220, 238 },
				Bark = { 92, 66, 46 },
				BarkDark = { 62, 44, 34 },
				BarkDead = { 84, 76, 70 },
				Needle = { 44, 86, 78 },
				NeedleDeep = { 34, 66, 64 },
				NeedleFrost = { 112, 160, 170 },
				Rock = { 118, 124, 134 },
				RockDark = { 62, 68, 82 },
				RockWarm = { 98, 90, 88 },
				Ice = { 168, 218, 246 },
				IceDeep = { 96, 160, 212 },
				Crystal = { 120, 220, 255 },
				CrystalDeep = { 150, 120, 255 },
				Ore = { 214, 120, 60 },
				OreGlint = { 255, 170, 90 },
				Reed = { 150, 140, 104 },
				Wood = { 120, 84, 56 },
				WoodDark = { 68, 48, 36 },
				Roof = { 74, 80, 98 },
				Window = { 255, 190, 110 },
				Metal = { 160, 168, 178 },
				MetalDark = { 90, 96, 106 },
				Scorch = { 40, 36, 38 },
				Tent = { 176, 102, 54 },
				TentAlt = { 214, 196, 160 },
				Spring = { 110, 200, 226 },
				Cave = { 22, 24, 32 },
				Rune = { 120, 230, 255 },
				Ruin = { 132, 128, 124 },
				RuinDark = { 86, 82, 80 },
			},
		},
		Hub = {
			Origin = { 0, 500, 0 },
			GroundRadius = 340,
			GroundThickness = 4,
			BarrierRadius = 135,
			BarrierHeight = 60,
			CobbleRadius = 26,
			SpawnPos = { 0, 0.5, 96 },
			PadArcCenter = { 0, 0, 20 },
			PadArcRadius = 58,
			PadArcHalfDegrees = 62,
			PadBase = 11,
			PadStep = 1.5,
			PadThickness = 0.6,
			ShopPos = { -84, 0, 28 },
			LeaderboardPos = { 86, 0, 6 },
			LocalBoardPos = { 86, 0, 44 },
			StatsPos = { -54, 0, 84 },
			MirrorPos = { 54, 0, 84 },
			FirePitPositions = {
				{ 0, 0, 22 },
				{ -38, 0, 62 },
				{ 38, 0, 62 },
				{ 0, 0, -66 },
			},
			LampRingRadius = 100,
			LampRingCount = 12,
			ClearRadius = 22,
			TreeCountInner = 36,
			TreeCountOuter = 56,
			TreeInnerMin = 112,
			TreeOuterMax = 230,
			RockCount = 36,
			DriftCount = 22,
			MountainCount = 22,
			MountainRadius = 430,
			SnowHeight = 70,
			SnowRate = 45,
			SnowAreaRadius = 150,
			Seed = 1337,
			MaxParts = 1200,
			MaxLights = 44,
			MaxEmitters = 8,
			MaxParticleRate = 120,
			PromptDistance = 14,
			PulseSpeed = 2.4,
			FlickerSpeed = 7,
			LampLight = { Range = 44, Brightness = 3.6 }, -- was 30 / 1.8: weak on snow at dusk
			FireLight = { Range = 52, Brightness = 5 }, -- was 38 / 2.4 (scaled by fire size)
			Tags = {
				Lamp = "HubLight",
				Shop = "LobbyShop",
				ShopPrompt = "LobbyShopPrompt",
				Stats = "LobbyStatBoard",
				StatsPrompt = "LobbyStatsPrompt",
				Mirror = "LobbyMirror",
				MirrorPrompt = "LobbyMirrorPrompt",
				Leaderboard = "LobbyLeaderboard",
				LocalBoard = "LobbyLocalBoard",
				Pulse = "HubPulse",
			},
			Ambient = {
				ClockTime = 18.1,
				Brightness = 1.3,
				FogEnd = 760,
				FogColor = { 150, 170, 200 },
				Ambient = { 70, 84, 112 },
				OutdoorAmbient = { 100, 116, 146 },
				AtmosphereColor = { 170, 190, 220 },
				AtmosphereDecay = { 96, 112, 150 },
				AtmosphereDensity = 0.32,
				AtmosphereHaze = 1.6,
			},
			Palette = {
				Snow = { 236, 243, 250 },
				SnowShade = { 205, 220, 238 },
				Cobble = { 128, 140, 156 },
				Path = { 176, 190, 206 },
				Rock = { 86, 94, 108 },
				MountainRock = { 70, 80, 100 },
				Wood = { 104, 72, 48 },
				WoodDark = { 68, 46, 32 },
				Roof = { 58, 64, 84 },
				Iron = { 46, 52, 62 },
				Warm = { 255, 176, 90 },
				Fire = { 255, 140, 50 },
				Ice = { 120, 205, 245 },
				PadEmpty = { 90, 205, 255 },
				PadActive = { 255, 196, 96 },
				PadLaunch = { 255, 255, 255 },
				Board = { 22, 32, 46 },
				Awning = { 70, 130, 190 },
				AwningAlt = { 230, 240, 250 },
				Text = { 232, 242, 250 },
			},
		},
	},
}

return Sections
