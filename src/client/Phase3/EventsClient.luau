--!strict
-- Phase 3 client boot hook for brief 14 (Events). Owned exclusively by brief 14: start your client
-- controllers here. init.client.luau calls start() once in run mode after HudController.start().
-- Must not yield.

local EventsClient = {}

function EventsClient.start()
	require(script.Parent.Parent.Events.EventCues).start()
end

return EventsClient
