--!strict
-- Return-to-lobby decision (ReturnPlan). Needs registering in tests/run.luau.

local Config = require("../src/shared/Config")
local ReturnPlan = require("../src/shared/logic/ReturnPlan")

return function(check: (string, boolean) -> ())
	local texts: ReturnPlan.Texts = {
		StudioFallback = Config.Run.ReturnStudioText,
		TeleportFailed = Config.Run.ReturnFailedToast,
	}
	local studio = ReturnPlan.decide(true, true, texts)
	check(
		"returnPlan: Studio falls back to lobby mode with a toast",
		studio.kind == "studioFallback" and studio.setStudioLobbyMode and studio.toast ~= nil
	)
	local noTeleport = ReturnPlan.decide(false, false, texts)
	check("returnPlan: no teleport available falls back", noTeleport.kind == "studioFallback")
	local live = ReturnPlan.decide(false, true, texts)
	check(
		"returnPlan: published server teleports, no studio write",
		live.kind == "teleport" and not live.setStudioLobbyMode and live.toast == nil
	)
	local failure = ReturnPlan.failureToast("HttpError 773", texts)
	check(
		"returnPlan: failure toast is readable, never the raw reason",
		failure == Config.Run.ReturnFailedToast and string.find(failure, "773", 1, true) == nil
	)
	check(
		"returnPlan: texts are not empty",
		#texts.StudioFallback > 0 and #texts.TeleportFailed > 0
	)
end
