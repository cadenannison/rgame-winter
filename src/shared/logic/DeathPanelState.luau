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
	aliveTeammates: number, -- other players still alive (not dead, not downed-out); spectating needs >= 1
}

export type Mode = "hidden" | "downed" | "dead" | "summary"

export type Result = {
	mode: Mode,
	visible: boolean,
	opaque: boolean, -- only the summary is an opaque full panel
	showRevive: boolean, -- downed banner / revive-me UI
	showDeadBar: boolean, -- the bottom bar (title + Return); never together with the summary
	showSpectate: boolean, -- Prev/Next/Watching controls: dead AND at least one teammate alive
	showReturn: boolean, -- "Return to lobby" button
	showPlayAgain: boolean, -- "Play again" (summary in a run server, or queue in the lobby)
	blocksInput: boolean, -- panel may take input (Active); false whenever hidden
}

local DeathPanelState = {}

local function result(mode: Mode, aliveTeammates: number): Result
	return {
		mode = mode,
		visible = mode ~= "hidden",
		opaque = mode == "summary",
		showRevive = mode == "downed",
		showDeadBar = mode == "dead",
		showSpectate = mode == "dead" and aliveTeammates > 0,
		showReturn = mode == "dead" or mode == "summary",
		showPlayAgain = mode == "summary",
		blocksInput = mode ~= "hidden",
	}
end

function DeathPanelState.resolve(input: Input): Result
	local alive = not input.downed and not input.dead
	if input.runEnded and input.hasSummary and not input.dismissed then
		if input.inLobby or not alive then
			return result("summary", input.aliveTeammates)
		end
		return result("hidden", input.aliveTeammates) -- respawned (alive) in a run server: never covered by a stale summary
	end
	if input.dead then
		return result("dead", input.aliveTeammates)
	end
	if input.downed then
		return result("downed", input.aliveTeammates)
	end
	return result("hidden", input.aliveTeammates)
end

return DeathPanelState
