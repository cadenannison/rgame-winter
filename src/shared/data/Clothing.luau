--!strict
-- Clothing tiers (pure data). Owner: brief 17 (structures/progression). Consumers: 13 (biome gating), 18.
-- Worn resistance = sum over Config.Clothing.Slots of the best carried piece, capped at
-- Config.Clothing.MaxColdResistance. A full set of tier t must meet the requiredColdResistance of the
-- biome it unlocks (tested): tier 1 -> FrozenLake, tier 2 -> MountainsCaves, tier 3 -> DeepTundra.

local Types = require("./Types")

local Clothing = {}

Clothing.Tiers = {
	{ tier = 1, label = "Hide", resistancePerPiece = 1 },
	{ tier = 2, label = "Fur-lined", resistancePerPiece = 2 },
	{ tier = 3, label = "Arctic", resistancePerPiece = 4 },
} :: { Types.ClothingTier }

-- Biome a full set of each tier is meant to unlock (index = tier).
Clothing.UnlocksBiome = { "FrozenLake", "MountainsCaves", "DeepTundra" }

-- Item id per tier per slot (items defined in shared/data/Items.luau).
Clothing.Pieces = {
	{ Head = "HideHood", Body = "HideCoat", Feet = "HideBoots" },
	{ Head = "FurHood", Body = "FurCoat", Feet = "FurBoots" },
	{ Head = "ArcticHood", Body = "ArcticCoat", Feet = "ArcticBoots" },
} :: { { [string]: string } }

return Clothing
