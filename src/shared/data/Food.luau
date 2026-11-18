--!strict
-- Cooking and food buffs (pure data). Owner: brief 17 (structures/progression). Consumers: 18.
-- Caps: Config.Buffs (durations, reductions, max active), Config.Cooking (station multiplier).
-- Cook = Remotes.CookRequest at a lit campfire (Config.Fire.CookRadius) or the cooking station.

local Types = require("./Types")

local Food = {}

Food.Cook = {
	{ rawId = "RawMeat", cookedId = "CookedMeat", stationOnly = false },
	{ rawId = "RawFish", cookedId = "CookedFish", stationOnly = false },
} :: { Types.CookDef }

Food.Buffs = {
	{
		id = "WellFed",
		name = "Well fed",
		durationSeconds = 120,
		warmthDrainMultiplier = 1,
		hungerDrainMultiplier = 0.7,
		healthRegenBonus = 0.3,
		speedMultiplier = 1,
		debuff = false,
	},
	{
		id = "Warmed",
		name = "Warmed",
		durationSeconds = 90,
		warmthDrainMultiplier = 0.7,
		hungerDrainMultiplier = 1,
		healthRegenBonus = 0,
		speedMultiplier = 1,
		debuff = false,
	},
	{
		id = "Hearty",
		name = "Hearty",
		durationSeconds = 180,
		warmthDrainMultiplier = 0.8,
		hungerDrainMultiplier = 0.7,
		healthRegenBonus = 0.5,
		speedMultiplier = 1.05,
		debuff = false,
	},
	{
		id = "Queasy",
		name = "Queasy",
		durationSeconds = 30,
		warmthDrainMultiplier = 1,
		hungerDrainMultiplier = 1.3,
		healthRegenBonus = 0,
		speedMultiplier = 0.95,
		debuff = true,
	},
} :: { Types.BuffDef }

-- Item id -> buff id granted on eat. Raw food carries the downside.
Food.EatBuffs = {
	CookedMeat = "WellFed",
	CookedFish = "Warmed",
	Stew = "Hearty",
	RawFish = "Queasy",
} :: { [string]: string }

-- Player attribute: "id:expiresAt,..." (workspace:GetServerTimeNow seconds) so the HUD can show timers.
Food.TimesAttribute = "BuffTimes"

Food.BuffById = {} :: { [string]: Types.BuffDef }
for _, def in Food.Buffs do
	Food.BuffById[def.id] = def
end

return Food
