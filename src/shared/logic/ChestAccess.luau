--!strict
-- Pure chest open decision (no Roblox APIs): distance + wall-blocked flag + opened flag -> ok / reason.
-- The server raycast that produces `blocked` is a thin wrapper in server/Loot/LootService.

local ChestAccess = {}

export type Result = { ok: boolean, reason: string? } -- reason: "opened" | "far" | "blocked" | "bad"

function ChestAccess.decide(
	distance: number,
	blocked: boolean,
	opened: boolean,
	maxDistance: number
): Result
	if distance ~= distance or distance < 0 or maxDistance ~= maxDistance then
		return { ok = false, reason = "bad" }
	end
	if opened then
		return { ok = false, reason = "opened" }
	end
	if distance > maxDistance then
		return { ok = false, reason = "far" }
	end
	if blocked then
		return { ok = false, reason = "blocked" }
	end
	return { ok = true, reason = nil }
end

return ChestAccess
