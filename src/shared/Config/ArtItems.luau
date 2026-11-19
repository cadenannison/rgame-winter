--!strict
-- Config module: ArtItems. Art Pass 4 Agent A knobs: item models, icons, tooltips, backpack look, dropped
-- and held visuals. Owner: Agent A only. Merged into Config by init.luau (Config.ArtItems.<Key>).

export type ArtItemsConfig = {
	ModelMaxParts: number, -- ItemModels.build part cap (icon + held)
	DropMaxParts: number, -- dropped world item part cap
	MaxLiveViewports: number, -- hard cap on live ViewportFrames; beyond it slots show a text fallback
	IconCameraFov: number,
	IconCameraDistanceScale: number, -- camera distance = model bounding radius * this
	IconCameraDirection: { number }, -- {x, y, z} direction from the model centre to the camera (normalised in use)
	IconAmbient: { number }, -- {r, g, b} 0-255 viewport ambient light
	IconLightColor: { number }, -- {r, g, b} 0-255 viewport directional light
	IconLightDirection: { number }, -- {x, y, z} viewport light direction
	IconSweepSeconds: number, -- one shared loop re-checks slot visibility this often
	IconImagePaddingScale: number, -- ImageLabel icon inset (fraction of the frame on each side)
	FallbackTileColor: { number }, -- {r, g, b} text-fallback tile background
	FallbackTileTransparency: number,
	FallbackLetters: number, -- letters shown on a text-fallback tile
	DropScale: number, -- dropped item models are built this much larger than the icon recipe
	HeldScale: number, -- held (in-hand) item model scale
}

export type Sections = { ArtItems: ArtItemsConfig }

local Sections: Sections = {
	ArtItems = {
		ModelMaxParts = 6,
		DropMaxParts = 3,
		MaxLiveViewports = 36,
		IconCameraFov = 30,
		IconCameraDistanceScale = 3.3,
		IconCameraDirection = { 0.35, 0.3, 1 },
		IconAmbient = { 170, 175, 190 },
		IconLightColor = { 255, 248, 235 },
		IconLightDirection = { -0.5, -0.8, -0.6 },
		IconSweepSeconds = 0.25,
		IconImagePaddingScale = 0.04,
		FallbackTileColor = { 60, 84, 108 },
		FallbackTileTransparency = 0.2,
		FallbackLetters = 2,
		DropScale = 1.25,
		HeldScale = 1,
	},
}

return Sections
