--!strict
-- Shared party chests. Each placed chest owns an Inventory (Config.Storage.ChestSlots). Open/close/deposit/
-- withdraw: type -> range -> rate limit -> state (alive, chest registered, in reach, opened) -> act, with
-- the chest and the player's inventory validated at the action (shared/logic/Storage). Snapshots go only
-- to players who have that chest open. Cleanup on PlayerRemoving and chest Destroying.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Inventory = require(Shared.logic.Inventory)
local Storage = require(Shared.logic.Storage)
local Structures = require(Shared.data.Structures)
local Guard = require(script.Parent.Parent.Net.Guard)
local InventoryService = require(script.Parent.InventoryService)
local ServerUtil = require(script.Parent.ServerUtil)

local T = Structures.Tuning
local RATE_KEY = "Storage"
local REFUSAL: { [string]: string } = {
	ChestFull = "Chest is full",
	InventoryFull = "Inventory full",
	BadSlot = "Nothing there",
	EmptySlot = "Nothing there",
	BadCount = "Not that many",
	BadArgs = "Cannot do that",
	UnknownItem = "Cannot store that",
}

local StorageService = {}

local chests: { [Instance]: Inventory.Inv } = {}
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
	local inv = if chest then chests[chest] else nil
	if inv then
		for i, s in inv.slots do
			if s then
				slots[i] = { id = s.id, count = s.count, durability = s.durability }
			end
		end
	end
	return { chest = chest, slots = slots }
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
	chests[chest] = Inventory.new(Config.Storage.ChestSlots)
	chest:SetAttribute(T.ChestIdAttribute, `chest{nextId}`)
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
	return chests[chest]
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
	local id = chest:GetAttribute(T.ChestIdAttribute)
	player:SetAttribute(Config.Storage.OpenAttribute, if type(id) == "string" then id else "")
	send(player, chest)
end

local function onClose(player: Player)
	if not Guard.rateLimit(player, RATE_KEY, Config.Net.StorageRateInterval) then
		return
	end
	close(player, true)
end

-- shared body of deposit/withdraw after type and range checks
local function transfer(
	player: Player,
	chestArg: unknown,
	slot: number,
	count: number,
	deposit: boolean
)
	if not Guard.rateLimit(player, RATE_KEY, Config.Net.StorageRateInterval) then
		return
	end
	local chest = reachableChest(player, chestArg)
	if chest == nil or opened[player] ~= chest then
		return
	end
	local inv = InventoryService.get(player)
	local chestInv = chests[chest]
	if inv == nil or chestInv == nil then
		return
	end
	local ok, reason
	if deposit then
		ok, reason = Storage.deposit(chestInv, inv, slot, count)
	else
		ok, reason = Storage.withdraw(chestInv, inv, slot, count)
	end
	if not ok then
		notify(player, REFUSAL[reason] or "Cannot do that")
		return
	end
	InventoryService.sync(player)
	sendToViewers(chest)
end

local function onDeposit(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local p: any = payload
	if
		typeof(p.chest) ~= "Instance"
		or not Guard.inRange(p.slot, 1, Config.Inventory.HotbarSize + Config.Inventory.BackpackSize)
		or not Guard.inRange(p.count, 1, Config.Inventory.MaxStack)
	then
		return
	end
	transfer(player, p.chest, p.slot, p.count, true)
end

local function onWithdraw(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local p: any = payload
	if
		typeof(p.chest) ~= "Instance"
		or not Guard.inRange(p.chestSlot, 1, Config.Storage.ChestSlots)
		or not Guard.inRange(p.count, 1, Config.Inventory.MaxStack)
	then
		return
	end
	transfer(player, p.chest, p.chestSlot, p.count, false)
end

-- Same paths as the remotes (QA and server callers).
StorageService.handleOpen = onOpen
StorageService.handleClose = onClose
StorageService.handleDeposit = onDeposit
StorageService.handleWithdraw = onWithdraw

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
		Remotes.event(Remotes.StorageDepositRequest).OnServerEvent:Connect(onDeposit)
	)
	table.insert(
		connections,
		Remotes.event(Remotes.StorageWithdrawRequest).OnServerEvent:Connect(onWithdraw)
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
	started = false
end

return StorageService
