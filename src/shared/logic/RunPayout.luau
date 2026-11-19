--!strict
-- Pure run payout and stat application. No Roblox APIs. Coin values come from Config.Meta (placeholders).

local Config = require("../Config")

export type RunResult = {
	daysSurvived: number,
	kills: number,
	bossKills: number,
	partners: number, -- other party members (friend bonus proxy)
	darkEventsSurvived: number?, -- dark events this player was alive for at the end
	forageCoins: number?, -- coins from picked-up nodes/relics (Config.Forage.CoinValues, ForageService credit)
}

export type Summary = {
	daysSurvived: number,
	kills: number,
	bossKills: number,
	coinsEarned: number,
	personalBest: boolean,
	newAchievements: { string },
	previousBest: number?, -- saved maxDays before this run (nil when the profile is not loaded)
}

export type StatProfile = {
	coins: number,
	maxDays: number,
	runs: number,
	kills: number,
	bossKills: number,
	[string]: any,
}

local RunPayout = {}

-- "What got you" tips, keyed by cause (Config.Run.DefaultCause and mob/cold labels). Copy only.
local TIPS: { [string]: string } = {
	Cold = "Stay near a fire and wear warmer clothes before you head out.",
	Hunger = "Cook food at a fire; cooked meals restore far more.",
	Wolf = "Wolves fear fire. Fight near your camp and keep your spear ready.",
	Fall = "Stay inside the map and away from the edge.",
}
local DEFAULT_TIP = "Keep your fire fed and stay close to your party."

-- One short tip for the run summary.
function RunPayout.tip(cause: string?): string
	return TIPS[cause or ""] or DEFAULT_TIP
end

local function count(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(math.floor(value), 0, Config.Meta.MaxStatValue)
end

-- Coins for one player's run, capped at Meta.MaxCoinsPerRun. Always an integer in [0, cap].
function RunPayout.coins(result: RunResult): number
	local meta = Config.Meta
	local total = meta.CoinsPerRun
		+ count(result.daysSurvived) * meta.CoinsPerDaySurvived
		+ count(result.kills) * meta.CoinsPerKill
		+ count(result.bossKills) * meta.CoinsPerBossKill
		+ math.clamp(count(result.partners), 0, Config.Teleport.MaxPartySize - 1) * meta.CoinsPerFriendInParty
		+ count(result.darkEventsSurvived) * meta.CoinsPerDarkEventSurvived
		+ count(result.forageCoins)
	return math.clamp(math.floor(total), 0, meta.MaxCoinsPerRun)
end

-- Builds the summary against the saved maxDays (profile may be nil when it is not loaded).
function RunPayout.summarize(result: RunResult, savedMaxDays: number?): Summary
	local days = count(result.daysSurvived)
	return {
		daysSurvived = days,
		kills = count(result.kills),
		bossKills = count(result.bossKills),
		coinsEarned = RunPayout.coins(result),
		personalBest = days > (savedMaxDays or 0),
		newAchievements = {},
		previousBest = savedMaxDays,
	}
end

-- Mutates the profile in place with a summary (clamped). Call once per player per run.
function RunPayout.apply(profile: StatProfile, summary: Summary)
	local maxStat = Config.Meta.MaxStatValue
	profile.coins = math.clamp(profile.coins + summary.coinsEarned, 0, Config.MaxCoins)
	profile.maxDays = math.min(math.max(profile.maxDays, summary.daysSurvived), maxStat)
	profile.runs = math.min(profile.runs + 1, maxStat)
	profile.kills = math.min(profile.kills + summary.kills, maxStat)
	profile.bossKills = math.min(profile.bossKills + summary.bossKills, maxStat)
end

return RunPayout
