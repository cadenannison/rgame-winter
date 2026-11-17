--!strict
-- Pure profile schema: defaults, validation and migrations keyed on schemaVersion. No Roblox APIs.
-- Saved tables use string keys only (DataStores reject sparse numeric tables): use tostring(id).

local Config = require("../Config")

export type Profile = {
	schemaVersion: number,
	coins: number,
}

local ProfileSchema = {}

function ProfileSchema.default(): Profile
	return {
		schemaVersion = Config.SchemaVersion,
		coins = Config.StartingCoins,
	}
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function sanitizeCount(value: any, default: number, max: number): number
	if not isFiniteNumber(value) then
		return default
	end
	return math.clamp(math.floor(value), 0, max)
end

-- Migrates data in place to the current schema. Returns false (and leaves data alone)
-- when the data is unusable or from a newer schema, so callers refuse to overwrite it.
-- Add one `if version < N then ... end` block per schema change and bump Config.SchemaVersion.
function ProfileSchema.migrate(data: any): boolean
	if type(data) ~= "table" then
		return false
	end
	local version = data.schemaVersion
	if version == nil then
		version = 0
	end
	if type(version) ~= "number" or version > Config.SchemaVersion then
		return false
	end
	-- v0 (fresh/unversioned) -> v1: fill every field with validated values.
	if version < 1 then
		local fresh = ProfileSchema.default()
		data.coins = sanitizeCount(data.coins, fresh.coins, Config.MaxCoins)
		data.schemaVersion = 1
	end
	return true
end

function ProfileSchema.validate(data: any): boolean
	if type(data) ~= "table" then
		return false
	end
	if data.schemaVersion ~= Config.SchemaVersion then
		return false
	end
	local coins = data.coins
	return isFiniteNumber(coins) and coins >= 0 and coins <= Config.MaxCoins
end

return ProfileSchema
