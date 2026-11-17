--!strict
-- Pure first-run hint chain. Each step completes on its real action (the client reports events);
-- the shown step is the first one not done, so an action done early is not asked for again.

export type Done = { [string]: boolean }

local Onboarding = {}

Onboarding.STEPS = {
	"equipAxe",
	"chop",
	"openCraft",
	"craftCampfire",
	"placeCampfire",
	"addWood",
	"eat",
} :: { string }

-- The step to show, or nil once every step is done.
function Onboarding.current(done: Done): string?
	for _, id in Onboarding.STEPS do
		if not done[id] then
			return id
		end
	end
	return nil
end

-- Marks a step done. Returns true only when it was a known step not done before.
function Onboarding.complete(done: Done, id: string): boolean
	if done[id] or not table.find(Onboarding.STEPS, id) then
		return false
	end
	done[id] = true
	return true
end

function Onboarding.finished(done: Done): boolean
	return Onboarding.current(done) == nil
end

return Onboarding
