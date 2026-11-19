--!strict
-- Pure decision for "Return to lobby". No Roblox APIs. Studio cannot teleport (the adapter fake only
-- records the call), so it gets a fallback plan instead of silently doing nothing.

export type Plan = {
	kind: string, -- "teleport" | "studioFallback"
	setStudioLobbyMode: boolean, -- write the Studio mode override ("lobby") for the next Test
	toast: string?, -- shown to the player right away (nil = none)
}

export type Texts = {
	StudioFallback: string,
	TeleportFailed: string,
}

local ReturnPlan = {}

-- isStudio: RunService:IsStudio(). reservedServer: this server can take part in a real teleport
-- (published place); false in a Studio test even if somebody forces it.
function ReturnPlan.decide(isStudio: boolean, teleportAvailable: boolean, texts: Texts): Plan
	if isStudio or not teleportAvailable then
		return { kind = "studioFallback", setStudioLobbyMode = true, toast = texts.StudioFallback }
	end
	return { kind = "teleport", setStudioLobbyMode = false, toast = nil }
end

-- Toast for a real teleport that failed after its retries (reason is logged, never shown raw).
function ReturnPlan.failureToast(reason: string?, texts: Texts): string
	local _ = reason
	return texts.TeleportFailed
end

return ReturnPlan
