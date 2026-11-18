--!strict
-- Pure ground correction (no Roblox APIs). A placed part (fire, spawn pad) is compared with the real terrain
-- surface found by raycast; if its bottom is buried (or floating) by more than the tolerance, the Y shift that
-- puts the bottom exactly on the surface is returned.

local GroundFix = {}

-- Returns the Y delta to add to the part, or nil when it already sits within `tolerance` of the surface.
function GroundFix.correction(bottomY: number, surfaceY: number, tolerance: number): number?
	local delta = surfaceY - bottomY
	if math.abs(delta) <= tolerance then
		return nil
	end
	return delta
end

-- Never lowers by more than `maxDrop` (a raycast that hit a roof or tree must not sink the part).
function GroundFix.clampedCorrection(
	bottomY: number,
	surfaceY: number,
	tolerance: number,
	maxDrop: number
): number?
	local delta = GroundFix.correction(bottomY, surfaceY, tolerance)
	if delta == nil then
		return nil
	end
	return math.max(delta, -maxDrop)
end

return GroundFix
