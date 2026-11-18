--!strict
-- Live mob registry: rows by model, budget slots, part count, per-kind counts. One place owns the counters
-- so unregister keeps them in step however a mob leaves (kill, despawn, Destroying).

local Types = require(script.Parent.MobTypes)

type MobRow = Types.MobRow

local MobRegistry = {}

local rows: { [Model]: MobRow } = {}
local rowCount = 0
local costUsed = 0 -- budget slots held by live non-boss mobs
local partsUsed = 0 -- BaseParts held by live mobs
local liveByKind: { [string]: number } = {}
local groups: { [number]: { [MobRow]: boolean } } = {}

function MobRegistry.rows(): { [Model]: MobRow }
	return rows
end

function MobRegistry.get(model: Model): MobRow?
	return rows[model]
end

function MobRegistry.count(): number
	return rowCount
end

function MobRegistry.costUsed(): number
	return costUsed
end

function MobRegistry.partsUsed(): number
	return partsUsed
end

function MobRegistry.liveOf(kindName: string): number
	return liveByKind[kindName] or 0
end

function MobRegistry.add(row: MobRow)
	rows[row.model] = row
	rowCount += 1
	partsUsed += row.parts
	liveByKind[row.kind.name] = (liveByKind[row.kind.name] or 0) + 1
	if not row.isBoss then
		costUsed += row.kind.cost
	end
	local id = row.groupId
	if id then
		local members = groups[id]
		if not members then
			members = {}
			groups[id] = members
		end
		members[row] = true
	end
end

-- Live members of a herd / pack (includes the caller's own row).
function MobRegistry.group(id: number?): { MobRow }
	local out: { MobRow } = {}
	local members = if id then groups[id] else nil
	if members then
		for member in members do
			table.insert(out, member)
		end
	end
	return out
end

-- Drops a mob from the registry (once); keeps the counters in step.
function MobRegistry.unregister(model: Model)
	local row = rows[model]
	if row then
		rows[model] = nil
		rowCount -= 1
		partsUsed -= row.parts
		liveByKind[row.kind.name] = math.max(0, (liveByKind[row.kind.name] or 1) - 1)
		if not row.isBoss then
			costUsed -= row.kind.cost
		end
		local id = row.groupId
		local members = if id then groups[id] else nil
		if id and members then
			members[row] = nil
			if next(members) == nil then
				groups[id] = nil
			end
		end
	end
end

function MobRegistry.remove(model: Model)
	MobRegistry.unregister(model)
	if model.Parent then
		model:Destroy()
	end
end

return MobRegistry
