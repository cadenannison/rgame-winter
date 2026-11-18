--!strict
-- Config module: Constants. Values shared by several Config domain modules (single source each).

return {
	-- Single source for the live mob cap (Scaling.MaxLiveMobs and Perf.MaxLiveMobs).
	MAX_LIVE_MOBS = 40,
	-- Fire radius unit R0 (the pre-scale warm radius). Tiers: warm = (2 + tier) * R0, i.e. 3R0, 4R0, 5R0.
	FIRE_R0 = 18,
	-- Massive structures: at most this many live at once, each within its Budget.Parts (largest 1000).
	MASSIVE_MAX_LIVE_STRUCTURES = 1, -- one massive structure live at a time; others stream out
	MASSIVE_LARGEST_PARTS = 1000,
	MASSIVE_MAX_LIVE_PARTS = 1 * 1000, -- MASSIVE_MAX_LIVE_STRUCTURES * MASSIVE_LARGEST_PARTS
	BASE_LIVE_PARTS = 6000, -- chunks + trees + POIs + mobs (the pre-massive budget)
	GIANT_TREE_HEIGHT = { 70, 100 }, -- Forest.Classes Giant height and Trees.GiantHeightMin/Max
}
