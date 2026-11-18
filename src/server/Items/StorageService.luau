--!strict
-- Player-placed storage chests (9 slots, shared by the whole party; distinct from loot chests). Open/close:
-- type -> range -> rate limit -> state (alive, registered, in reach) -> act. Contents move only through
-- InventoryService's single InventoryMove path: this module supplies the open chest (range checked at the
-- action) and owns the revision counter (Config.Storage.RevisionAttribute, bumped on every change). Two
-- players on one chest: a stale revision is re-synced and applied only if the source item is unchanged
-- (shared/logic/InventoryMove). Snapshots go only to players who have the chest open. Cleanup on
-- PlayerRemoving and chest Destroying. Non-empty chests refuse pick-up (canPickUp).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Inventory = require(Shared.logic.Inventory)
local Structures = require(Shared.data.Structures)
local Guard = require(script.Parent.Parent.Net.Guard)
local InventoryService = require(script.Parent.InventoryService)
local ServerUtil = require(script.Parent.ServerUtil)

local T = Structures.Tuning
local RATE_KEY = "Storage"
local TOO_FAR_TEXT = "Too far from the chest"

local StorageService = {}

type Record = { inv: Inventory.Inv, revision: number, id: string }

local chests: { [Instance]: Record } = {}
local viewers: { [Instance]: { [Player]: true } } = {}
local opened: { [Player]: Instance } = {}
local connections: { RBXScriptConnection } = {}
local nextId = 0
local started = false

local function notify(player: Player, text: string)
	Remotes.event(Remotes.Notify):FireClient(player, "craft", text)
end

local function snapshot(chest: Instance?): Remotes.StorageStatePayload
	local slots: { [number]: Remotes.ItemStack? } = {}
	local rec = if chest then chests[chest] else nil
	if rec then
		for i, s in rec.inv.slots do
			if s then
				slots[i] = { id = s.id, count = s.count, durability = s.durability }
			end
		end
	end
	return {
		chest = chest,
		slots = slots,
		id = if rec then rec.id else nil,
		rev = if rec then rec.revision else nil,
	}
end

local function send(player: Player, chest: Instance?)
	if player.Parent == Players then
		Remotes.event(Remotes.StorageState):FireClient(player, snapshot(chest))
	end
end

local function sendToViewers(chest: Instance)
	local set = viewers[chest]
	if set then
		for player in set do
			send(player, chest)
		end
	end
end

-- Contents changed: bump the revision (attribute + record) and refresh every viewer.
local function changed(chest: Instance)
	local rec = chests[chest]
	if rec == nil then
		return
	end
	rec.revision += 1
	chest:SetAttribute(Config.Storage.RevisionAttribute, rec.revision)
	sendToViewers(chest)
end

-- Closes whatever chest the player has open (and tells their client when notifyClient).
local function close(player: Player, notifyClient: boolean)
	local chest: Instance? = opened[player]
	if chest == nil then
		return
	end
	opened[player] = nil
	local set = viewers[chest]
	if set then
		set[player] = nil
	end
	if player.Parent == Players then
		player:SetAttribute(Config.Storage.OpenAttribute, "")
		if notifyClient then
			send(player, nil)
		end
	end
end

-- Registers a freshly placed chest (PlacementService via StructureService). Idempotent.
function StorageService.register(chest: Instance)
	if chests[chest] then
		return
	end
	nextId += 1
	local id = `chest{nextId}`
	chests[chest] = { inv = Inventory.new(Config.Storage.ChestSlots), revision = 0, id = id }
	chest:SetAttribute(T.ChestIdAttribute, id)
	chest:SetAttribute(Config.Storage.RevisionAttribute, 0)
	CollectionService:AddTag(chest, Config.Build.StorageTag)
	chest.Destroying:Once(function()
		local set = viewers[chest]
		if set then
			for player in set do
				close(player, true)
			end
		end
		viewers[chest] = nil
		chests[chest] = nil
	end)
end

-- Contents of a chest (QA and tests).
function StorageService.getInventory(chest: Instance): Inventory.Inv?
	local rec = chests[chest]
	return if rec then rec.inv else nil
end

-- A chest may be picked up only while empty.
function StorageService.canPickUp(chest: Instance): (boolean, string?)
	local rec = chests[chest]
	if rec == nil then
		return false, "Not a storage chest"
	end
	for i = 1, rec.inv.size do
		if rec.inv.slots[i] ~= nil then
			return false, "Empty the chest first"
		end
	end
	return true, nil
end

-- Chests this player has placed and that still exist.
function StorageService.ownedCount(player: Player): number
	local n = 0
	for chest in chests do
		if chest:GetAttribute(Config.Build.OwnerAttribute) == player.UserId then
			n += 1
		end
	end
	return n
end

-- Refusal text when the player may not place another chest (Config.Storage.MaxPerPlayer), else nil.
-- PlacementService calls this before spending the item.
function StorageService.placeRefusal(player: Player): string?
	if StorageService.ownedCount(player) >= Config.Storage.MaxPerPlayer then
		return `You can place at most {Config.Storage.MaxPerPlayer} storage chests`
	end
	return nil
end

-- Validates the chest argument at the action: registered, tagged, alive in Workspace, within reach.
local function reachableChest(player: Player, arg: unknown): Instance?
	local root = ServerUtil.actingRoot(player)
	if root == nil then
		return nil
	end
	local inst = ServerUtil.reachable(root, arg, T.ServerInteractRange)
	if
		inst == nil
		or chests[inst] == nil
		or not CollectionService:HasTag(inst, Config.Build.StorageTag)
	then
		return nil
	end
	return inst
end

-- The player's open chest for InventoryService's move path; range/alive re-checked at every move.
local function provide(player: Player): InventoryService.ChestCtx?
	local chest: Instance? = opened[player]
	if chest == nil then
		return nil
	end
	local rec = chests[chest]
	if rec == nil or reachableChest(player, chest) == nil then
		return nil
	end
	return {
		inv = rec.inv,
		id = rec.id,
		revision = rec.revision,
		changed = function()
			changed(chest)
		end,
		resync = function()
			send(player, chest)
		end,
	}
end

local function onOpen(player: Player, payload: unknown)
	if type(payload) ~= "table" or typeof((payload :: any).chest) ~= "Instance" then
		return
	end
	local chestArg = (payload :: any).chest
	if not Guard.rateLimit(player, RATE_KEY, Config.Net.StorageRateInterval) then
		return
	end
	local chest = reachableChest(player, chestArg)
	if chest == nil then
		notify(player, TOO_FAR_TEXT)
		return
	end
	close(player, false)
	opened[player] = chest
	local set = viewers[chest]
	if set == nil then
		set = {}
		viewers[chest] = set
	end
	set[player] = true
	player:SetAttribute(Config.Storage.OpenAttribute, chests[chest].id)
	send(player, chest)
end

local function onClose(player: Player)
	if not Guard.rateLimit(player, RATE_KEY, Config.Net.StorageRateInterval) then
		return
	end
	close(player, true)
end

-- Same paths as the remotes (QA and server callers).
StorageService.handleOpen = onOpen
StorageService.handleClose = onClose

-- Called by StructureService's loop: closes chests the player walked away from or died beside.
function StorageService.tick()
	for player in opened do
		local root = ServerUtil.actingRoot(player)
		local chest = opened[player]
		local pos = if chest then ServerUtil.pivot(chest) else nil
		if root == nil or pos == nil or (pos - root.Position).Magnitude > T.ServerInteractRange then
			close(player, true)
		end
	end
end

function StorageService.start()
	if started then
		return
	end
	started = true
	InventoryService.setChestProvider(provide)
	table.insert(
		connections,
		Remotes.event(Remotes.StorageOpenRequest).OnServerEvent:Connect(onOpen)
	)
	table.insert(
		connections,
		Remotes.event(Remotes.StorageCloseRequest).OnServerEvent:Connect(onClose)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			close(player, false)
		end)
	)
end

function StorageService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(chests)
	table.clear(viewers)
	table.clear(opened)
	InventoryService.setChestProvider(nil)
	started = false
end

return StorageService
