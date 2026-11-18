--!strict
-- Achievements and titles (pure data). Owner: brief 19 (meta). Contract shape: data/Types.luau (brief 21).
-- Conditions are data: unlocked when ProfileSchema.getStat(profile, condition.stat) >= condition.atLeast.
-- Coin rewards are placeholders pending balance (<= Config.Meta.MaxAchievementCoinReward; tested).

local Types = require("./Types")

local Achievements = {}

local function def(
	id: string,
	name: string,
	description: string,
	stat: string,
	atLeast: number,
	coins: number,
	title: string?
): Types.AchievementDef
	return {
		id = id,
		name = name,
		description = description,
		condition = { stat = stat, atLeast = atLeast },
		coins = coins,
		title = title,
	}
end

Achievements.List = {
	-- Days survived (best single run)
	def("FirstDawn", "First Dawn", "Survive your first day.", "maxDays", 1, 10),
	def("ThreeDays", "Holding On", "Survive 3 days in one run.", "maxDays", 3, 25),
	def(
		"WeekSurvivor",
		"Week Survivor",
		"Survive 7 days in one run.",
		"maxDays",
		7,
		75,
		"Survivor"
	),
	def("Fortnight", "Fortnight", "Survive 14 days in one run.", "maxDays", 14, 150),
	def("Unbroken", "Unbroken", "Survive 30 days in one run.", "maxDays", 30, 400, "Unbroken"),
	-- Runs
	def("FirstRun", "Into the White", "Finish your first run.", "runs", 1, 10),
	def("Regular", "Regular", "Finish 10 runs.", "runs", 10, 50),
	def("Veteran", "Veteran", "Finish 50 runs.", "runs", 50, 200, "Veteran"),
	-- Kills
	def("FirstHunt", "First Hunt", "Defeat a creature.", "kills", 1, 10),
	def("Hunter", "Hunter", "Defeat 50 creatures.", "kills", 50, 60),
	def("ApexHunter", "Apex Hunter", "Defeat 250 creatures.", "kills", 250, 250, "ApexHunter"),
	-- Bosses
	def("GiantSlayer", "Giant Slayer", "Defeat a boss.", "bossKills", 1, 100),
	def("Beastbane", "Beastbane", "Defeat 5 bosses.", "bossKills", 5, 300, "Beastbane"),
	-- Crafting and building
	def("Tinkerer", "Tinkerer", "Craft 10 items.", "crafted", 10, 20),
	def("Artisan", "Artisan", "Craft 100 items.", "crafted", 100, 100, "Artisan"),
	def("CampBuilder", "Camp Builder", "Place 25 structures.", "structuresPlaced", 25, 60),
	def("CampCook", "Camp Cook", "Cook 20 meals.", "mealsCooked", 20, 40, "Cook"),
	-- Events
	def("Weathered", "Weathered", "Survive a blizzard.", "blizzardsSurvived", 1, 40),
	def(
		"StormWalker",
		"Storm Walker",
		"Survive 10 blizzards.",
		"blizzardsSurvived",
		10,
		200,
		"StormWalker"
	),
	def("IntoTheDark", "Into the Dark", "Survive a dark event.", "darkEventsSurvived", 1, 40),
	def(
		"Unafraid",
		"Unafraid",
		"Survive 10 dark events.",
		"darkEventsSurvived",
		10,
		200,
		"Unafraid"
	),
	-- Exploration
	def("Pathfinder", "Pathfinder", "Reach the Deep Tundra.", "deepestRing", 3, 150, "Pathfinder"),
	-- Co-op
	def("Lifeline", "Lifeline", "Revive a teammate.", "revivesGiven", 1, 25),
	def("FieldMedic", "Field Medic", "Revive 10 teammates.", "revivesGiven", 10, 120, "Medic"),
	def("Together", "Together", "Finish a run with a party.", "partyRuns", 1, 25),
	def("Packmates", "Packmates", "Finish 5 runs with a friend.", "friendRuns", 5, 75),
	-- Daily
	def("Devoted", "Devoted", "Claim the daily reward 7 times.", "dailyClaims", 7, 50),
} :: { Types.AchievementDef }

Achievements.Titles = {
	{ id = "Survivor", name = "Survivor" },
	{ id = "Unbroken", name = "the Unbroken" },
	{ id = "Veteran", name = "Veteran" },
	{ id = "ApexHunter", name = "Apex Hunter" },
	{ id = "Beastbane", name = "Beastbane" },
	{ id = "Artisan", name = "Artisan" },
	{ id = "Cook", name = "Camp Cook" },
	{ id = "StormWalker", name = "Storm Walker" },
	{ id = "Unafraid", name = "the Unafraid" },
	{ id = "Pathfinder", name = "Pathfinder" },
	{ id = "Medic", name = "Field Medic" },
} :: { Types.TitleDef }

Achievements.ById = {} :: { [string]: Types.AchievementDef }
for _, a in Achievements.List do
	Achievements.ById[a.id] = a
end

Achievements.TitleById = {} :: { [string]: Types.TitleDef }
for _, t in Achievements.Titles do
	Achievements.TitleById[t.id] = t
end

return Achievements
