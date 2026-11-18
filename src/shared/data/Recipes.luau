--!strict
-- Phase 3 recipes (pure data). Owner: brief 17 (structures/progression). Consumers: 18.
-- Merged into ItemCatalog.Recipes at load. Key = output item id (repair cost reads the recipe of the
-- item: Config.Repair.CostFraction of its inputs). Stations: Config.Craft.Stations keys.

local Config = require("../Config")
local Types = require("./Types")

local Recipes = {}

local function r(
	id: string,
	tier: number,
	station: string?,
	inputs: { Types.Stack },
	count: number?
): Types.Recipe
	return {
		id = id,
		tier = tier,
		station = station,
		inputs = inputs,
		output = { id = id, count = count or 1 },
	}
end

local list: { Types.Recipe } = {
	-- Tier 1: workbench
	r("StonePickaxe", 1, "workbench", { { id = "Wood", count = 3 }, { id = "Stone", count = 4 } }),
	r("Bow", 1, "workbench", { { id = "Wood", count = 5 }, { id = "Hide", count = 1 } }),
	r("Arrow", 1, "workbench", { { id = "Wood", count = 1 }, { id = "Stone", count = 1 } }, 4),
	r("Torch", 0, nil, { { id = "Wood", count = 2 }, { id = "Hide", count = 1 } }),
	r("Forge", 1, "workbench", { { id = "Stone", count = 20 }, { id = "Wood", count = 10 } }),
	r(
		"CookingStation",
		1,
		"workbench",
		{ { id = "Stone", count = 8 }, { id = "Wood", count = 8 } }
	),
	r("StorageChest", Config.Storage.CraftStationTier, Config.Storage.CraftStation, {
		{ id = "Wood", count = Config.Storage.CraftWood },
	}),
	r("Wall", 1, "workbench", { { id = "Wood", count = 6 } }),
	r("Door", 1, "workbench", { { id = "Wood", count = 8 }, { id = "Stone", count = 1 } }),
	r("SpikeTrap", 1, "workbench", { { id = "Wood", count = 6 }, { id = "Stone", count = 3 } }),
	r("Watchtower", 1, "workbench", { { id = "Wood", count = 30 }, { id = "Stone", count = 6 } }),
	r("SleepingBag", 1, "workbench", { { id = "Hide", count = 3 }, { id = "Wood", count = 2 } }),
	r("MapTable", 1, "workbench", { { id = "Wood", count = 12 }, { id = "Hide", count = 2 } }),
	r("HideHood", 1, "workbench", { { id = "Hide", count = 2 } }),
	r("HideCoat", 1, "workbench", { { id = "Hide", count = 4 } }),
	r("HideBoots", 1, "workbench", { { id = "Hide", count = 2 } }),
	-- Map table
	r("Map", 1, "mapTable", { { id = "Hide", count = 1 }, { id = "Wood", count = 1 } }),
	-- Cooking station recipes (multi-input food; single raw items cook via CookRequest)
	r(
		"Stew",
		1,
		"cookingStation",
		{ { id = "RawMeat", count = 2 }, { id = "RawFish", count = 1 } }
	),
	-- Tier 2: forge
	r("IronIngot", 2, "forge", { { id = "IronOre", count = 2 }, { id = "Wood", count = 1 } }),
	r("IronAxe", 2, "forge", { { id = "IronIngot", count = 3 }, { id = "Wood", count = 2 } }),
	r("IronPickaxe", 2, "forge", { { id = "IronIngot", count = 3 }, { id = "Wood", count = 2 } }),
	r("IronSpear", 2, "forge", { { id = "IronIngot", count = 2 }, { id = "Wood", count = 3 } }),
	r("Lantern", 2, "forge", { { id = "IronIngot", count = 2 }, { id = "FrostShard", count = 1 } }),
	r(
		"Flare",
		2,
		"forge",
		{ { id = "IronIngot", count = 1 }, { id = "FrostShard", count = 1 } },
		2
	),
	r("FurHood", 2, "forge", { { id = "Hide", count = 4 }, { id = "IronIngot", count = 1 } }),
	r("FurCoat", 2, "forge", { { id = "Hide", count = 8 }, { id = "IronIngot", count = 2 } }),
	r("FurBoots", 2, "forge", { { id = "Hide", count = 4 }, { id = "IronIngot", count = 1 } }),
	r("ArcticHood", 2, "forge", {
		{ id = "WardenCore", count = 1 },
		{ id = "Hide", count = 6 },
		{ id = "FrostShard", count = 4 },
	}),
	r("ArcticCoat", 2, "forge", {
		{ id = "MatriarchFang", count = 1 },
		{ id = "Hide", count = 10 },
		{ id = "FrostShard", count = 6 },
	}),
	r("ArcticBoots", 2, "forge", {
		{ id = "WardenCore", count = 1 },
		{ id = "Hide", count = 6 },
		{ id = "FrostShard", count = 4 },
	}),
}

Recipes.List = list

return Recipes
