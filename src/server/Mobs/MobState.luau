--!strict
-- Replicated creature attributes (State / Target / TelegraphLeft / Heading), SERVER side. Writes happen on
-- change only; the client animates from them (docs/CREATURES_CONTRACT.md). Pure mapping: MobStateMap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MobPoise = require(Shared.logic.MobPoise)
local MobStateMap = require(Shared.logic.MobStateMap)
local Types = require(script.Parent.MobTypes)

type MobRow = Types.MobRow

local C = Config.Creatures
local HEADING_EPSILON = 0.05

local MobState = {}

-- Writes State / Target / TelegraphLeft from the row's current action; change-only.
function MobState.sync(row: MobRow, now: number)
	local model = row.model
	local action = row.lastAction
	-- Heavy mobs (Frost Brute) never flinch out of a telegraph or slam: Hurt is ignored while they wind up.
	local state = MobPoise.resolveState(
		action,
		row.hurtUntil - now,
		row.attackUntil - now,
		MobPoise.isHeavy(row.kind.name)
	)
	local previous = row.stateWritten
	if state ~= previous then
		row.stateWritten = state
		if state == "Telegraph" then
			model:SetAttribute(C.TelegraphAttribute, row.telegraphSeconds)
		elseif previous == "Telegraph" then
			model:SetAttribute(C.TelegraphAttribute, nil)
		end
		model:SetAttribute(C.StateAttribute, state)
	end
	local userId: number? = nil
	if MobStateMap.hasTarget(action) and state ~= "Death" then
		local info = row.sp.targetInfo :: Player?
		userId = if info then info.UserId else nil
	end
	if userId ~= row.targetWritten then
		row.targetWritten = userId
		model:SetAttribute(C.TargetAttribute, userId)
	end
end

-- The player this mob is acting on (nil clears the Target attribute on the next sync).
function MobState.setTarget(row: MobRow, player: Player?)
	row.sp.targetInfo = player
end

-- Optional world heading (crow scatter, wisp drift); flat Vector3 or nil.
function MobState.setHeading(row: MobRow, heading: Vector3?)
	local previous = row.headingWritten
	if heading == nil then
		if previous ~= nil then
			row.headingWritten = nil
			row.model:SetAttribute(C.HeadingAttribute, nil)
		end
		return
	end
	if previous == nil or (previous - heading).Magnitude > HEADING_EPSILON then
		row.headingWritten = heading
		row.model:SetAttribute(C.HeadingAttribute, heading)
	end
end

function MobState.hurt(row: MobRow, now: number)
	row.hurtUntil = now + C.HurtSeconds
	MobState.sync(row, now)
end

-- A bite / slam / charge hit landed: State holds Attack briefly so the client plays the swing.
function MobState.attacked(row: MobRow, now: number)
	row.attackUntil = now + Config.Mobs.AttackHoldSeconds
	MobState.sync(row, now)
end

-- Final state: Death (the existing flow also sets MobHealth 0).
function MobState.death(row: MobRow)
	row.stateWritten = "Death"
	row.model:SetAttribute(C.StateAttribute, "Death")
	row.model:SetAttribute(C.TelegraphAttribute, nil)
	if row.targetWritten ~= nil then
		row.targetWritten = nil
		row.model:SetAttribute(C.TargetAttribute, nil)
	end
end

return MobState
