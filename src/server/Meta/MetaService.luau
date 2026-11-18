--!strict
-- Meta core: per-player meta state (coins, stats, achievements, titles, equipped cosmetic/perk/title,
-- settings, hints). The client only sends ids and booleans; every value is validated and recomputed here.
-- All profile writes go through DataService.get(player) and mutate in place.
-- Handler order: type-check -> range (id length / known id) -> Guard.rateLimit -> permission/state -> act.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Achievements = require(Shared.data.Achievements)
local Shop = require(Shared.data.Shop)
local Types = require(Shared.data.Types)
local AchievementLogic = require(Shared.logic.AchievementLogic)
local MetaSnapshot = require(Shared.logic.MetaSnapshot)
local PerkLogic = require(Shared.logic.PerkLogic)
local ProfileSchema = require(Shared.logic.ProfileSchema)
local Guard = require(script.Parent.Parent.Net.Guard)
local DataService = require(script.Parent.Parent.Data.DataService)
local CosmeticService = require(script.Parent.CosmeticService)

local MetaService = {}

local mode = ""
local started = false
local connections: { RBXScriptConnection } = {}
local unsubscribe: (() -> ())? = nil
local achievementCallbacks: { (Player, Types.AchievementDef) -> () } = {}

local RATE_EQUIP_COSMETIC = "EquipCosmetic"
local RATE_EQUIP_PERK = "EquipPerk"
local RATE_EQUIP_TITLE = "EquipTitle"
local RATE_SETTINGS = "SettingsSet"
local RATE_HINT = "HintSeen"
local RATE_STATE = "MetaState"

function MetaService.setMode(newMode: string)
	mode = newMode
end

function MetaService.isLobby(): boolean
	return mode == Config.Teleport.ModeLobby
end

local function profileOf(player: Player): ProfileSchema.Profile?
	if player.Parent ~= Players then
		return nil
	end
	return DataService.get(player)
end

local function perkItem(id: string): Types.ShopItemDef?
	local item = Shop.ById[id]
	if item and item.category == "perk" then
		return item
	end
	return nil
end

-- Visible state only: Title (display name), Cosmetic (id), BestDays (saved max), ReduceScares.
local function applyAttributes(player: Player, profile: ProfileSchema.Profile)
	local meta = Config.Meta
	local title = Achievements.TitleById[profile.equippedTitle]
	player:SetAttribute(meta.TitleAttribute, if title then title.name else "")
	player:SetAttribute(meta.CosmeticAttribute, profile.equippedCosmetic)
	player:SetAttribute(meta.BestDaysAttribute, profile.maxDays)
	player:SetAttribute(Config.Settings.ReduceScaresAttribute, profile.settings.reduceScares)
	CosmeticService.refresh(player, profile.equippedCosmetic)
end

function MetaService.pushState(player: Player)
	local profile = profileOf(player)
	if not profile then
		return
	end
	applyAttributes(player, profile)
	local payload: Remotes.MetaStatePayload = MetaSnapshot.build(profile)
	local ok = pcall(function()
		Remotes.event(Remotes.MetaState):FireClient(player, payload)
	end)
	if not ok then
		warn("MetaService: MetaState send failed")
	end
end

function MetaService.onAchievement(callback: (Player, Types.AchievementDef) -> ()): () -> ()
	table.insert(achievementCallbacks, callback)
	return function()
		local index = table.find(achievementCallbacks, callback)
		if index then
			table.remove(achievementCallbacks, index)
		end
	end
end

-- Evaluates every achievement against the profile stat counters and grants new ones idempotently.
-- Returns the newly unlocked ids. Pushes state when anything changed.
function MetaService.evaluate(player: Player): { string }
	local profile = profileOf(player)
	local unlocked: { string } = {}
	if not profile then
		return unlocked
	end
	for _, def in AchievementLogic.evaluate(profile, Achievements.List) do
		if AchievementLogic.grant(profile, def) then
			table.insert(unlocked, def.id)
			local payload: Remotes.AchievementUnlockedPayload =
				{ id = def.id, coins = def.coins, title = def.title }
			pcall(function()
				Remotes.event(Remotes.AchievementUnlocked):FireClient(player, payload)
			end)
			for _, callback in table.clone(achievementCallbacks) do
				local ok = pcall(callback, player, def)
				if not ok then
					warn("MetaService: achievement callback failed")
				end
			end
		end
	end
	return unlocked
end

-- Progress sources call these (server only). Unknown fields are ignored.
function MetaService.addProgress(player: Player, field: string, amount: number)
	local profile = profileOf(player)
	if not profile then
		return
	end
	AchievementLogic.addProgress(profile, field, amount)
	MetaService.evaluate(player)
	MetaService.pushState(player)
end

function MetaService.raiseProgress(player: Player, field: string, value: number)
	local profile = profileOf(player)
	if not profile then
		return
	end
	local before = profile.achievementProgress[field] or 0
	if AchievementLogic.raiseProgress(profile, field, value) == before then
		return
	end
	MetaService.evaluate(player)
	MetaService.pushState(player)
end

-- Live saved stat counters that are not settled at run end (only "crafted"; kills/bossKills/maxDays/runs
-- are written once by RunPayout.apply). Clamped to Meta.MaxStatValue.
function MetaService.addStat(player: Player, field: string, amount: number)
	local profile = profileOf(player)
	if not profile or field ~= "crafted" or amount ~= amount or amount <= 0 then
		return
	end
	profile.crafted = math.min(profile.crafted + math.floor(amount), Config.Meta.MaxStatValue)
	MetaService.evaluate(player)
	MetaService.pushState(player)
end

-- Equipped perk item (run server applies it once at run start; amounts are capped by Meta.MaxPerkMagnitude).
function MetaService.getEquippedPerk(player: Player): Types.ShopItemDef?
	local profile = profileOf(player)
	if not profile or profile.equippedPerk == "" then
		return nil
	end
	local item = perkItem(profile.equippedPerk)
	if item and profile.ownedCosmetics[item.id] and PerkLogic.effectValid(item.perk) then
		return item
	end
	return nil
end

-- Run end: bump run-scoped counters, re-evaluate and return new achievement ids (for the summary).
function MetaService.onRunEnd(player: Player, partyRun: boolean, friendRun: boolean): { string }
	local profile = profileOf(player)
	if not profile then
		return {}
	end
	if partyRun then
		AchievementLogic.addProgress(profile, "partyRuns", 1)
	end
	if friendRun then
		AchievementLogic.addProgress(profile, "friendRuns", 1)
	end
	local ids = MetaService.evaluate(player)
	MetaService.pushState(player)
	return ids
end

-- ===== Remote handlers =====

-- Type-check and range-check an EquipPayload. Returns the id or nil.
local function parseId(payload: unknown): string?
	if type(payload) ~= "table" then
		return nil
	end
	local id = (payload :: { id: unknown }).id
	if type(id) ~= "string" or #id > Config.Meta.MaxItemIdLength then
		return nil
	end
	return id
end

local function refuse(player: Player, text: string)
	pcall(function()
		Remotes.event(Remotes.Notify):FireClient(player, "warn", text)
	end)
end

local function onEquipCosmetic(player: Player, payload: unknown)
	local id = parseId(payload)
	if id == nil then
		return
	end
	if not Guard.rateLimit(player, RATE_EQUIP_COSMETIC, Config.Net.EquipRateInterval) then
		return
	end
	local profile = profileOf(player)
	if not profile then
		return
	end
	local ok, reason = PerkLogic.equipCosmetic(profile, id, Shop.ById[id])
	if not ok then
		refuse(player, if reason == "locked" then "You do not own that." else "Not available.")
		return
	end
	MetaService.pushState(player)
end

local function onEquipPerk(player: Player, payload: unknown)
	local id = parseId(payload)
	if id == nil then
		return
	end
	if not Guard.rateLimit(player, RATE_EQUIP_PERK, Config.Net.EquipRateInterval) then
		return
	end
	if not MetaService.isLobby() then
		refuse(player, "Perks can only be changed in the lobby.")
		return
	end
	local profile = profileOf(player)
	if not profile then
		return
	end
	local ok, reason = PerkLogic.equipPerk(profile, id, Shop.ById[id])
	if not ok then
		refuse(player, if reason == "locked" then "You do not own that perk." else "Not available.")
		return
	end
	MetaService.pushState(player)
end

local function onEquipTitle(player: Player, payload: unknown)
	local id = parseId(payload)
	if id == nil then
		return
	end
	if not Guard.rateLimit(player, RATE_EQUIP_TITLE, Config.Net.EquipRateInterval) then
		return
	end
	local profile = profileOf(player)
	if not profile then
		return
	end
	local ok, reason =
		PerkLogic.equipTitle(profile, id, id == "" or Achievements.TitleById[id] ~= nil)
	if not ok then
		refuse(
			player,
			if reason == "locked" then "You have not earned that title." else "Not available."
		)
		return
	end
	MetaService.pushState(player)
end

local function onSettingsSet(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local data = payload :: { key: unknown, value: unknown }
	if type(data.key) ~= "string" or type(data.value) ~= "boolean" then
		return
	end
	if not table.find(Config.Settings.Keys, data.key) then
		return
	end
	if not Guard.rateLimit(player, RATE_SETTINGS, Config.Net.SettingsRateInterval) then
		return
	end
	local profile = profileOf(player)
	if not profile then
		return
	end
	if data.key == Config.Settings.ReduceScares then
		profile.settings.reduceScares = data.value
	end
	MetaService.pushState(player)
end

local function onHintSeen(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local hintId = (payload :: { hintId: unknown }).hintId
	if type(hintId) ~= "string" or not table.find(Config.Hints.Ids, hintId) then
		return
	end
	if not Guard.rateLimit(player, RATE_HINT, Config.Net.HintRateInterval) then
		return
	end
	local profile = profileOf(player)
	if not profile or profile.hintsSeen[hintId] then
		return
	end
	local count = 0
	for _ in profile.hintsSeen do
		count += 1
	end
	if count >= Config.Meta.MaxHintsSeen then
		return
	end
	profile.hintsSeen[hintId] = true
	MetaService.pushState(player)
end

local function onStateRequest(player: Player)
	if not Guard.rateLimit(player, RATE_STATE, Config.Net.MetaStateRateInterval) then
		return
	end
	MetaService.pushState(player)
end

local function onLoaded(player: Player, profile: ProfileSchema.Profile)
	-- Unequip anything not owned (tampered or refunded data).
	PerkLogic.sanitizeEquipped(profile, function(id: string): boolean
		return perkItem(id) ~= nil
	end)
	MetaService.evaluate(player)
	MetaService.pushState(player)
end

-- Same paths as the remotes (QA callers); run the full validation.
MetaService.handleEquipPerk = onEquipPerk
MetaService.handleSettingsSet = onSettingsSet

function MetaService.Start()
	if started then
		return
	end
	started = true
	local function connect(name: string, handler: (Player, unknown) -> ())
		table.insert(connections, Remotes.event(name).OnServerEvent:Connect(handler))
	end
	connect(Remotes.EquipCosmeticRequest, onEquipCosmetic)
	connect(Remotes.EquipPerkRequest, onEquipPerk)
	connect(Remotes.EquipTitleRequest, onEquipTitle)
	connect(Remotes.SettingsSetRequest, onSettingsSet)
	connect(Remotes.HintSeenRequest, onHintSeen)
	table.insert(
		connections,
		Remotes.event(Remotes.MetaStateRequest).OnServerEvent:Connect(onStateRequest)
	)
	unsubscribe = DataService.onLoaded(onLoaded)
	CosmeticService.Start()
end

function MetaService.Stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(achievementCallbacks)
	if unsubscribe then
		unsubscribe()
		unsubscribe = nil
	end
	CosmeticService.Stop()
	started = false
end

return MetaService
