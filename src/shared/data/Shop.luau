--!strict
-- Shop catalog (pure data). Owner: brief 19 (meta). Contract shape: data/Types.luau (brief 21).
-- Guardrails (tested in tests/MetaTests.luau): no random or loot-box entries, every purchase grants
-- exactly what is listed; coin prices inside Meta.MinCoinPrice..MaxCoinPrice; perks capped by
-- Meta.MaxPerkMagnitude (one equipped per run); Robux entries name a Config.Meta.ProductIds key.
-- Prices are placeholders pending balance. Robux prices are display only (the product sets the charge).

local Types = require("./Types")

local Shop = {}

Shop.List = {
	-- Cosmetics (coins)
	{
		id = "FurTrimHood",
		name = "Fur-Trim Hood",
		category = "cosmetic",
		currency = "coins",
		price = 300,
		cosmeticSlot = "outfit",
	},
	{
		id = "RangerJacket",
		name = "Ranger Jacket",
		category = "cosmetic",
		currency = "coins",
		price = 900,
		cosmeticSlot = "outfit",
	},
	{
		id = "FrostTrail",
		name = "Frost Trail",
		category = "cosmetic",
		currency = "coins",
		price = 600,
		cosmeticSlot = "trail",
	},
	{
		id = "EmberTrail",
		name = "Ember Trail",
		category = "cosmetic",
		currency = "coins",
		price = 1200,
		cosmeticSlot = "trail",
	},
	{
		id = "CampBanner",
		name = "Camp Banner",
		category = "cosmetic",
		currency = "coins",
		price = 400,
		cosmeticSlot = "camp",
	},
	{
		id = "LanternString",
		name = "Lantern String",
		category = "cosmetic",
		currency = "coins",
		price = 800,
		cosmeticSlot = "camp",
	},
	{
		id = "ArcticFox",
		name = "Arctic Fox",
		category = "cosmetic",
		currency = "coins",
		price = 2500,
		cosmeticSlot = "pet",
	},
	{
		id = "SnowOwl",
		name = "Snow Owl",
		category = "cosmetic",
		currency = "coins",
		price = 4000,
		cosmeticSlot = "pet",
	},
	-- Cosmetics (Robux only; developer products, granted once and idempotently via ProcessReceipt)
	{
		id = "AuroraParka",
		name = "Aurora Parka",
		category = "cosmetic",
		currency = "robux",
		price = 149,
		productKey = "AuroraParka",
		cosmeticSlot = "outfit",
	},
	{
		id = "NorthernLightsTrail",
		name = "Northern Lights Trail",
		category = "cosmetic",
		currency = "robux",
		price = 99,
		productKey = "NorthernLightsTrail",
		cosmeticSlot = "trail",
	},
	{
		id = "HuskyPup",
		name = "Husky Pup",
		category = "cosmetic",
		currency = "robux",
		price = 199,
		productKey = "HuskyPup",
		cosmeticSlot = "pet",
	},
	-- Run-start perks (coins; one equipped; small capped effects)
	{
		id = "WarmBlood",
		name = "Warm Blood",
		category = "perk",
		currency = "coins",
		price = 1500,
		perk = { stat = "warmthDrain", amount = -0.1 },
	},
	{
		id = "IronStomach",
		name = "Iron Stomach",
		category = "perk",
		currency = "coins",
		price = 1500,
		perk = { stat = "hungerDrain", amount = -0.1 },
	},
	{
		id = "Kindler",
		name = "Kindler",
		category = "perk",
		currency = "coins",
		price = 1200,
		perk = { stat = "fuelBurn", amount = -0.1 },
	},
	{
		id = "QuickHands",
		name = "Quick Hands",
		category = "perk",
		currency = "coins",
		price = 1200,
		perk = { stat = "gatherSpeed", amount = 0.1 },
	},
	{
		id = "LightStep",
		name = "Light Step",
		category = "perk",
		currency = "coins",
		price = 2000,
		perk = { stat = "moveSpeed", amount = 0.05 },
	},
	-- Starter gear (coins, milestone-gated; granted at every run start once unlocked)
	{
		id = "StarterAxe",
		name = "Starter Axe",
		category = "gear",
		currency = "coins",
		price = 200,
		gear = { itemId = "Axe", count = 1 },
		requires = { stat = "runs", atLeast = 1 },
	},
	{
		id = "StarterTorch",
		name = "Starter Torch",
		category = "gear",
		currency = "coins",
		price = 400,
		gear = { itemId = "Torch", count = 1 },
		requires = { stat = "maxDays", atLeast = 2 },
	},
	{
		id = "StarterHideCoat",
		name = "Hide Coat",
		category = "gear",
		currency = "coins",
		price = 600,
		gear = { itemId = "HideCoat", count = 1 },
		requires = { stat = "maxDays", atLeast = 3 },
	},
	{
		id = "StarterFurHood",
		name = "Fur Hood",
		category = "gear",
		currency = "coins",
		price = 1500,
		gear = { itemId = "FurHood", count = 1 },
		requires = { stat = "maxDays", atLeast = 7 },
	},
	{
		id = "StarterIronAxe",
		name = "Iron Axe",
		category = "gear",
		currency = "coins",
		price = 2500,
		gear = { itemId = "IronAxe", count = 1 },
		requires = { stat = "bossKills", atLeast = 1 },
	},
	-- Coin packs (Robux)
	{
		id = "CoinPackSmall",
		name = "Pouch of Coins",
		category = "coinPack",
		currency = "robux",
		price = 49,
		productKey = "CoinPackSmall",
		coins = 500,
	},
	{
		id = "CoinPackMedium",
		name = "Sack of Coins",
		category = "coinPack",
		currency = "robux",
		price = 129,
		productKey = "CoinPackMedium",
		coins = 1500,
	},
	{
		id = "CoinPackLarge",
		name = "Chest of Coins",
		category = "coinPack",
		currency = "robux",
		price = 299,
		productKey = "CoinPackLarge",
		coins = 4000,
	},
} :: { Types.ShopItemDef }

Shop.ById = {} :: { [string]: Types.ShopItemDef }
Shop.ByProductKey = {} :: { [string]: Types.ShopItemDef }
for _, item in Shop.List do
	Shop.ById[item.id] = item
	if item.productKey then
		Shop.ByProductKey[item.productKey] = item
	end
end

return Shop
