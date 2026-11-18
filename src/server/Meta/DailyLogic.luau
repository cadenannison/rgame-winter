--!strict
-- Pure daily reward check (no Roblox APIs). Times are os.time() seconds (UTC epoch).
-- Same rule as the client button (shared/logic/LobbyLogic.canClaimDaily): one claim per UTC calendar
-- day, resetting at UTC midnight. tests/RunTests cross-checks the two.

local SECONDS_PER_DAY = 86400

local DailyLogic = {}

local function utcDay(t: number): number
	return math.floor(t / SECONDS_PER_DAY)
end

-- Returns (canClaim, nextClaimAt). lastClaim 0 = never. A last claim on a later UTC day than `now`
-- (clock skew or tampering) blocks the claim until the midnight after that claim.
function DailyLogic.check(lastClaim: number, now: number): (boolean, number)
	if lastClaim <= 0 then
		return true, now
	end
	local nextAt = (utcDay(lastClaim) + 1) * SECONDS_PER_DAY
	return now >= nextAt, nextAt
end

return DailyLogic
