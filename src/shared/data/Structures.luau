--!strict
-- Phase 3 structures (pure data). Owner: brief 17 (structures/progression). Consumers: 15 (warm spots,
-- Stalker never enters a SleepingBag restRadius), 16 (breakable walls, traps), 18.
-- Merged into ItemCatalog.Structures at load. Placement rules stay in shared/logic/Placement.
-- Build-radius exemptions: Config.Build.RangeExempt (SleepingBag already exempt).

local Config = require("../Config")
local Types = require("./Types")

local Structures = {}

Structures.List = {
	{
		id = "Forge",
		itemId = "Forge",
		role = "forge",
		sizeX = 6,
		sizeY = 4,
		sizeZ = 5,
		tier = 2,
		station = "forge",
	},
	{
		id = "CookingStation",
		itemId = "CookingStation",
		role = "cooking",
		sizeX = 4,
		sizeY = 3,
		sizeZ = 4,
		station = Config.Cooking.Station,
	},
	{
		id = "StorageChest",
		itemId = "StorageChest",
		role = "storage",
		sizeX = 4,
		sizeY = 3,
		sizeZ = 3,
		storageSlots = Config.Storage.ChestSlots,
	},
	{
		id = "Wall",
		itemId = "Wall",
		role = "wall",
		sizeX = 8,
		sizeY = 8,
		sizeZ = 1,
		maxHealth = 200,
		blocksPath = true,
	},
	{
		id = "Door",
		itemId = "Door",
		role = "door",
		sizeX = 4,
		sizeY = 8,
		sizeZ = 1,
		maxHealth = 150,
		blocksPath = true,
		opensForParty = true,
	},
	{
		id = "SpikeTrap",
		itemId = "SpikeTrap",
		role = "trap",
		sizeX = 4,
		sizeY = 1,
		sizeZ = 4,
		maxHealth = 80,
		trapDamage = 15, -- mobs only: players never take trap damage
		trapCooldown = 2,
	},
	{
		id = "Watchtower",
		itemId = "Watchtower",
		role = "watchtower",
		sizeX = 6,
		sizeY = 16,
		sizeZ = 6,
		maxHealth = 300,
		viewBonus = 160,
	},
	{
		id = "SleepingBag",
		itemId = "SleepingBag",
		role = "bed",
		sizeX = 3,
		sizeY = 1,
		sizeZ = 6,
		restRadius = 8,
		respawnPoint = true,
	},
	{
		id = "MapTable",
		itemId = "MapTable",
		role = "maptable",
		sizeX = 5,
		sizeY = 3,
		sizeZ = 4,
		station = "mapTable",
	},
} :: { Types.StructureDef }

-- Tuning for the server and client structure code (values live in Config.Structures).
Structures.Tuning = Config.Structures

return Structures
