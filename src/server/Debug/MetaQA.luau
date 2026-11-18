--!strict
-- Studio-only QA helpers for tools/qa/meta-shop.luau, reached through DebugService's Studio-only bridge.
-- The bridge copies tables, so QA cannot mutate a profile directly: backup() stores a deep copy of the meta
-- fields server-side and restore() writes them back, so the real test profile is left as it was.
-- Every function refuses outside Studio.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileSchema = require(ReplicatedStorage.Shared.logic.ProfileSchema)
local DataService = require(script.Parent.Parent.Data.DataService)
local MetaService = require(script.Parent.Parent.Meta.MetaService)

local MetaQA = {}

-- Fields the meta scenario may touch; restored exactly.
local FIELDS = {
	"coins",
	"maxDays",
	"runs",
	"kills",
	"bossKills",
	"crafted",
	"achievements",
	"achievementProgress",
	"ownedCosmetics",
	"unlockedGear",
	"titles",
	"hintsSeen",
	"equippedCosmetic",
	"equippedPerk",
	"equippedTitle",
	"settings",
	"processedReceipts",
}

local backups: { [Player]: { [string]: any } } = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function profileOf(player: Player): ProfileSchema.Profile?
	if not RunService:IsStudio() then
		return nil
	end
	return DataService.get(player)
end

function MetaQA.backup(player: Player): boolean
	local profile = profileOf(player)
	if not profile then
		return false
	end
	local saved: { [string]: any } = {}
	for _, field in FIELDS do
		saved[field] = deepCopy((profile :: any)[field])
	end
	backups[player] = saved
	return true
end

function MetaQA.restore(player: Player): boolean
	local profile = profileOf(player)
	local saved = backups[player]
	if not profile or not saved then
		return false
	end
	for _, field in FIELDS do
		(profile :: any)[field] = deepCopy(saved[field])
	end
	backups[player] = nil
	return true
end

-- Read-only copy of the meta fields (the bridge copies it anyway).
function MetaQA.read(player: Player): { [string]: any }?
	local profile = profileOf(player)
	if not profile then
		return nil
	end
	local out: { [string]: any } = {}
	for _, field in FIELDS do
		out[field] = deepCopy((profile :: any)[field])
	end
	return out
end

-- Test setup only (between backup and restore).
function MetaQA.setCoins(player: Player, coins: number): boolean
	local profile = profileOf(player)
	if not profile or type(coins) ~= "number" then
		return false
	end
	profile.coins = math.max(0, math.floor(coins))
	return true
end

function MetaQA.clearOwned(player: Player, id: string): boolean
	local profile = profileOf(player)
	if not profile then
		return false
	end
	profile.ownedCosmetics[id] = nil
	profile.unlockedGear[id] = nil
	if profile.equippedPerk == id then
		profile.equippedPerk = ""
	end
	return true
end

function MetaQA.clearAchievement(player: Player, id: string): boolean
	local profile = profileOf(player)
	if not profile then
		return false
	end
	profile.achievements[id] = nil
	return true
end

function MetaQA.clearHint(player: Player, id: string): boolean
	local profile = profileOf(player)
	if not profile then
		return false
	end
	profile.hintsSeen[id] = nil
	MetaService.pushState(player)
	return true
end

function MetaQA.setStat(player: Player, field: string, value: number): boolean
	local profile = profileOf(player)
	if not profile or type(value) ~= "number" then
		return false
	end
	if table.find(ProfileSchema.STAT_FIELDS, field) then
		(profile :: any)[field] = value
		return true
	elseif table.find(ProfileSchema.PROGRESS_FIELDS, field) then
		profile.achievementProgress[field] = value
		return true
	end
	return false
end

return MetaQA
