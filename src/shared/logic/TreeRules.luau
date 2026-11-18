--!strict
-- Pure tree height/canopy rules (no Roblox APIs). Config.Trees holds the numbers; Forest.Classes holds the
-- per-class height ranges. The tree builder must place the lowest foliage at or above canopyBottom().

local Config = require("../Config")

local TreeRules = {}

-- Bare trunk fraction wanted (of height); clamped by foliageBottom and MAX_BARE_TRUNK.
TreeRules.BOTTOM_FRACTION = 0.4
-- The trunk part is the gather node (GatherService measures to its centre, Gather.Range 12), so the bare
-- trunk is capped: centre <= 10 above ground keeps every trunk choppable from the ground.
TreeRules.MAX_BARE_TRUNK = 18
TreeRules.TRUNK_OVERLAP = 2 -- trunk reaches this far into the lower foliage tier (hides the join)
TreeRules.LOWER_TIER_SHARE = 0.6 -- of foliage thickness, the wide lower tier
TreeRules.UPPER_TIER_START = 0.4 -- of foliage thickness, where the narrow upper tier begins

-- Lowest allowed Y (above ground) for the bottom of any foliage: head height + clearance.
function TreeRules.minCanopyBottom(): number
	return Config.Trees.HeadHeight + Config.Trees.CanopyClearance
end

-- Foliage bottom for a tree of `height`, given the wanted bottom as a fraction of height (0..1).
-- Clamped so the bottom is at least minCanopyBottom() and leaves MinFoliageThickness of foliage below the top.
function TreeRules.foliageBottom(height: number, wantedFraction: number): number
	local lo = TreeRules.minCanopyBottom()
	local hi = math.max(lo, height - Config.Trees.MinFoliageThickness)
	return math.clamp(height * wantedFraction, lo, hi)
end

-- Collision flags the builder applies (data so tests can assert them): the trunk blocks, foliage never does.
TreeRules.TRUNK_FLAGS = { CanCollide = true, CanTouch = false }
TreeRules.FOLIAGE_FLAGS = { CanCollide = false, CanQuery = false, CanTouch = false }

export type Shape = {
	trunkHeight: number, -- solid trunk part (the gather node), ground to just inside the foliage
	foliageBottom: number, -- lowest foliage Y above ground
	lowerBottom: number,
	lowerHeight: number,
	upperBottom: number,
	upperHeight: number,
}

-- Vertical layout of one tree: tall bare trunk, wide lower foliage tier, narrow upper tier to the top.
function TreeRules.shape(height: number): Shape
	local bottom = math.min(
		TreeRules.foliageBottom(height, TreeRules.BOTTOM_FRACTION),
		math.max(TreeRules.minCanopyBottom(), TreeRules.MAX_BARE_TRUNK)
	)
	local thick = height - bottom
	local lowerH = thick * TreeRules.LOWER_TIER_SHARE
	local upperBottom = bottom + thick * TreeRules.UPPER_TIER_START
	return {
		trunkHeight = math.min(bottom + TreeRules.TRUNK_OVERLAP, height),
		foliageBottom = bottom,
		lowerBottom = bottom,
		lowerHeight = lowerH,
		upperBottom = upperBottom,
		upperHeight = height - upperBottom,
	}
end

function TreeRules.canopyOk(height: number, foliageBottom: number): boolean
	return height >= Config.Trees.MinTotalHeight
		and foliageBottom >= TreeRules.minCanopyBottom() - 1e-6
		and foliageBottom <= height - Config.Trees.MinFoliageThickness + 1e-6
end

return TreeRules
