--!strict
-- Lurker kinds (pure data). Owner: brief 15 (StalkerService/Dread). Consumers: 13 (biome lurkerKind), 18.
-- Lurkers never attack. Density, counts and distances: Config.Lurkers (hard caps).

local Types = require("./Types")

local Lurkers = {}

Lurkers.List = {
	{
		kind = "TreeWatcher",
		biome = "SnowyForest",
		behavior = "watch",
		dreadOnSight = 6,
		vanishDistance = 45,
	},
	{
		kind = "IceScratcher",
		biome = "FrozenLake",
		behavior = "scratch",
		dreadOnSight = 4,
		vanishDistance = 30,
		thinIceWarmthLoss = 25,
	},
	{
		kind = "EyesInDark",
		biome = "MountainsCaves",
		behavior = "eyes",
		dreadOnSight = 8,
		vanishDistance = 20,
		torchRetreatRadius = 18,
	},
} :: { Types.LurkerDef }

-- Behavior tuning shared by every kind (data, inside Config.Lurkers caps). Server-side only effect values.
Lurkers.Tuning = {
	KindAttribute = "LurkerKind", -- visible model attribute (client visuals pick a look); not a metric
	ThinIcePatchRadius = 7, -- studs: stepping inside cracks the patch
	ThinIceWarnRadius = 16, -- studs: IceCrack cue as a player nears a patch
	ThinIceOffset = 14, -- studs from the scratcher toward the player where its patch forms
	EyesCloseInSpeed = 6, -- studs/s eyes advance on a player with no light
	EyesRetreatSpeed = 10, -- studs/s eyes back off from torchlight
	EyesTorchRetreatMultiplier = 3, -- eyes keep torchRetreatRadius * this away from a light
}

-- Placeholder look (art pending: docs/ART.md). Sizes in studs; colors RGB 0-255.
Lurkers.Visuals = {
	TreeWatcher = {
		size = { 1.6, 11, 1.2 },
		color = { 30, 30, 34 },
		transparency = 0.15,
		glow = false,
	},
	IceScratcher = {
		size = { 3, 0.4, 3 },
		color = { 40, 50, 70 },
		transparency = 0.5,
		glow = false,
	},
	EyesInDark = {
		size = { 1.4, 0.4, 0.2 },
		color = { 255, 230, 140 },
		transparency = 0,
		glow = true,
	},
	ThinIce = { color = { 190, 220, 240 }, transparency = 0.45, thickness = 0.2 },
	Stalker = { size = { 2.4, 12, 1.6 }, color = { 225, 228, 235 }, transparency = 0, glow = false },
}

Lurkers.ByKind = {} :: { [string]: Types.LurkerDef }
for _, def in Lurkers.List do
	Lurkers.ByKind[def.kind] = def
end

return Lurkers
