--!strict
-- Pure teleport data contract between lobby and run servers. No Roblox APIs.
-- The lobby builds it with TeleportData.build; the receiving server must accept only what
-- TeleportData.parse returns (via Guard.teleportData). Anything else is refused.

local Config = require("../Config")

export type TeleportData = {
	mode: string, -- Config.Teleport.ModeRun or ModeLobby
	seed: number, -- world seed, integer in [0, Config.Teleport.MaxSeed]
	partyIds: { number }, -- UserIds of the party, 1..MaxPartySize, unique positive integers
	version: number, -- Config.Teleport.DataVersion
}

local TeleportData = {}

local EXPECTED_KEYS = { mode = true, seed = true, partyIds = true, version = true }

local function isInteger(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value % 1 == 0
end

local function isMode(value: any): boolean
	return value == Config.Teleport.ModeRun or value == Config.Teleport.ModeLobby
end

-- Copies and checks a party id list. Returns nil if it is not a dense array of unique positive integers.
local function parsePartyIds(value: any): { number }?
	if type(value) ~= "table" then
		return nil
	end
	local ids: { number } = {}
	local seen: { [number]: boolean } = {}
	local count = 0
	for key, id in value do
		count += 1
		if not isInteger(key) or key < 1 or count > Config.Teleport.MaxPartySize then
			return nil
		end
		if not isInteger(id) or id <= 0 or seen[id] then
			return nil
		end
		seen[id] = true
		ids[key] = id
	end
	if count < 1 or #ids ~= count then
		return nil
	end
	return ids
end

-- Returns a clean copy of `data` if it matches the schema exactly, else nil and a reason.
function TeleportData.parse(data: unknown): (TeleportData?, string?)
	if type(data) ~= "table" then
		return nil, "not a table"
	end
	local raw = data :: any
	for key in raw do
		if not EXPECTED_KEYS[key] then
			return nil, "unexpected key"
		end
	end
	if raw.version ~= Config.Teleport.DataVersion then
		return nil, "bad version"
	end
	if not isMode(raw.mode) then
		return nil, "bad mode"
	end
	if not isInteger(raw.seed) or raw.seed < 0 or raw.seed > Config.Teleport.MaxSeed then
		return nil, "bad seed"
	end
	local partyIds = parsePartyIds(raw.partyIds)
	if not partyIds then
		return nil, "bad partyIds"
	end
	return {
		mode = raw.mode,
		seed = raw.seed,
		partyIds = partyIds,
		version = raw.version,
	},
		nil
end

-- Builds teleport data for the lobby side. Returns nil if the result would not parse.
function TeleportData.build(mode: string, seed: number, partyIds: { number }): TeleportData?
	local data = {
		mode = mode,
		seed = seed,
		partyIds = table.clone(partyIds),
		version = Config.Teleport.DataVersion,
	}
	local parsed = TeleportData.parse(data)
	return parsed
end

-- True if `userId` is in the party list.
function TeleportData.hasMember(data: TeleportData, userId: number): boolean
	return table.find(data.partyIds, userId) ~= nil
end

return TeleportData
