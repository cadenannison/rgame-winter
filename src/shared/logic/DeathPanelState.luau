--!strict
-- Pure mapping from authoritative player/run state to which death-UI pieces show. No Roblox APIs.
-- The client re-evaluates this on every state change (attributes, CharacterAdded, respawn), never from
-- a remembered "was shown" flag, so a respawned (alive) player can never keep a stale panel.

export type Input = {
	downed: boolean,
	dead: boolean,
	runEnded: boolean, -- a RunSummary was received for this run
	hasSummary: boolean, -- real summary data exists (an empty payload never shows the opaque panel)
	inLobby: boolean, -- the lobby shows the summary to living players too
	dismissed: boolean, -- the player closed the summary
}

export type Mode = "hidden" | "downed" | "dead" | "summary"

export type Result = {
	mode: Mode,
	visible: boolean,
	opaque: boolean, -- only the summary is an opaque full panel
	showRevive: boolean, -- downed banner / revive-me UI
	showSpectate: boolean, -- spectate controls (dead)
	showReturn: boolean, -- "Return to lobby" button
	showPlayAgain: boolean, -- "Play again" (summary in a run server, or queue in the lobby)
	blocksInput: boolean, -- panel may take input (Active); false whenever hidden
}

local DeathPanelState = {}

local function result(mode: Mode): Result
	return {
		mode = mode,
		visible = mode ~= "hidden",
		opaque = mode == "summary",
		showRevive = mode == "downed",
		showSpectate = mode == "dead",
		showReturn = mode == "dead" or mode == "summary",
		showPlayAgain = mode == "summary",
		blocksInput = mode ~= "hidden",
	}
end

function DeathPanelState.resolve(input: Input): Result
	local alive = not input.downed and not input.dead
	if input.runEnded and input.hasSummary and not input.dismissed then
		if input.inLobby or not alive then
			return result("summary")
		end
		return result("hidden") -- respawned (alive) in a run server: never covered by a stale summary
	end
	if input.dead then
		return result("dead")
	end
	if input.downed then
		return result("downed")
	end
	return result("hidden")
end

return DeathPanelState
