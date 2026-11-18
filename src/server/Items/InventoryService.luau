--!strict
-- Server-authoritative inventory (hotbar + backpack + worn equipment). The inventory is not persisted;
-- worn equipment persists in profile.equipment (DataService) and loads validated against ItemCatalog.
-- ONE validated move path (InventoryMove remote -> shared/logic/InventoryMove) covers hotbar, grid,
-- equipment and chests; the open chest comes from StorageService through setChestProvider.
-- Disconnect hold: when the hold predicate (wired to RunLifecycleService.ShouldHold) says so, a leaving
-- player's inventory is kept by UserId for Config.Run.RejoinWindowSeconds and restored on rejoin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local Equipment = require(Shared.logic.Equipment)
local Inventory = require(Shared.logic.Inventory)
local InventoryMove = require(Shared.logic.InventoryMove)
local DataService = require(script.Parent.Parent.Data.DataService)
local Guard = require(script.Parent.Parent.Net.Guard)
local HeldItem = require(script.Parent.HeldItem)
local ItemDrop = require(script.Parent.ItemDrop)
local ServerUtil = require(script.Parent.ServerUtil)

export type ChestCtx = {
	inv: Inventory.Inv,
	id: string,
	revision: number,
	changed: () -> (), -- chest contents changed: bump the revision, send snapshots to viewers
	resync: () -> (), -- re-send the snapshot to this player only (stale request)
}

local InventoryService = {}

local inventories: { [Player]: Inventory.Inv } = {}
local selected: { [Player]: number } = {}
local characterConns: { [Player]: RBXScriptConnection } = {}
local useHandler: ((Player, ItemCatalog.ItemDef, number) -> boolean)? = nil
local started = false
local holdPredicate: ((Player) -> boolean)? = nil
local held: {
	[number]: { inv: Inventory.Inv, equip: Inventory.Inv, selected: number, expires: number },
} =
	{}
local equipment: { [Player]: Inventory.Inv } = {}
local equipReady: { [Player]: boolean } = {}
local equipListeners: { (Player) -> () } = {}
local chestProvider: ((Player) -> ChestCtx?)? = nil

local REFUSAL: { [string]: string } = {
	Full = InventoryMove.FullText,
	WrongSlot = "That does not fit there",
	SlotBusy = "Slot is taken",
	BadCount = "Not that many",
	EmptySlot = "Nothing there",
	NoChest = "Chest is not open",
	Stale = "The chest changed",
	UnknownItem = "Cannot move that",
	Loading = "Still loading",
}

local TOTAL_SLOTS = Config.Inventory.HotbarSize + Config.Inventory.BackpackSize

local function sync(player: Player)
	local inv = inventories[player]
	if inv == nil or player.Parent ~= Players then
		return
	end
	local slots: { [number]: Remotes.ItemStack? } = {}
	for i, s in inv.slots do
		if s then
			slots[i] = { id = s.id, count = s.count, durability = s.durability }
		end
	end
	local index = selected[player] or 1
	local worn: { [string]: Remotes.ItemStack } = {}
	local equip = equipment[player]
	if equip then
		for slotIndex, slotId in Config.Equipment.Slots do
			local s = equip.slots[slotIndex]
			if s then
				worn[slotId] = { id = s.id, count = s.count, durability = s.durability }
			end
		end
	end
	local payload: Remotes.InventoryPayload = { slots = slots, selected = index, equipment = worn }
	Remotes.event(Remotes.InventoryUpdate):FireClient(player, payload)
	local stack = inv.slots[index]
	HeldItem.show(player, if stack then stack.id else nil)
end

-- Writes the worn set into profile.equipment (when the profile is loaded) and tells listeners.
local function persistEquipment(player: Player)
	local equip = equipment[player]
	local profile = DataService.get(player)
	if equip and profile then
		profile.equipment = Equipment.toMap(equip)
	end
	for _, fn in equipListeners do
		fn(player)
	end
end

local function loadEquipment(player: Player, profile: DataService.Profile)
	if player.Parent ~= Players or inventories[player] == nil or equipReady[player] then
		return
	end
	equipment[player] = Equipment.fromMap(profile.equipment)
	equipReady[player] = true
	-- Rewrite the validated map so dropped/unknown items leave the save.
	persistEquipment(player)
	sync(player)
end

local function setup(player: Player)
	if inventories[player] then
		return
	end
	local hold = held[player.UserId]
	held[player.UserId] = nil
	local inv: Inventory.Inv
	local slot = 1
	if hold and os.clock() < hold.expires then
		inv = hold.inv
		slot = hold.selected
		equipment[player] = hold.equip
		equipReady[player] = true
	else
		equipment[player] = Equipment.new()
		inv = Inventory.new(TOTAL_SLOTS)
		for _, starter in Config.Inventory.StarterItems do
			local def = ItemCatalog.Items[starter.id]
			if def then
				Inventory.add(inv, def.id, starter.count, def.maxStack, def.durability)
			end
		end
	end
	inventories[player] = inv
	selected[player] = slot
	player:SetAttribute(Config.Inventory.SlotAttribute, slot)
	-- Re-show the held item on every (re)spawn; deferred so the Humanoid exists.
	characterConns[player] = player.CharacterAdded:Connect(function()
		task.defer(function()
			if inventories[player] then
				local stack = inventories[player].slots[selected[player] or 1]
				HeldItem.show(player, if stack then stack.id else nil)
			end
		end)
	end)
	sync(player)
	local profile = DataService.get(player)
	if profile then
		loadEquipment(player, profile)
	end
end

function InventoryService.get(player: Player): Inventory.Inv?
	return inventories[player]
end

-- Worn gear (Equipment.new() shape); nil before the player is set up.
function InventoryService.getEquipment(player: Player): Inventory.Inv?
	return equipment[player]
end

-- Called after worn gear changes (ClothingService recomputes resistance, HUD attribute).
function InventoryService.onEquipmentChanged(fn: (Player) -> ())
	table.insert(equipListeners, fn)
end

-- StorageService installs how a player's open chest is found (range, open state, revision).
function InventoryService.setChestProvider(fn: ((Player) -> ChestCtx?)?)
	chestProvider = fn
end

-- Run end / death hook: removes worn gear (and the profile copy), like the inventory is lost.
function InventoryService.clearEquipment(player: Player)
	if equipment[player] then
		equipment[player] = Equipment.new()
		persistEquipment(player)
		sync(player)
	end
end

function InventoryService.canAdd(player: Player, id: string, count: number): boolean
	local inv = inventories[player]
	local def = ItemCatalog.Items[id]
	if inv == nil or def == nil or not Guard.isNumber(count) or count <= 0 then
		return false
	end
	return Inventory.canAdd(inv, id, count, def.maxStack, def.durability)
end

function InventoryService.count(player: Player, id: string): number
	local inv = inventories[player]
	return if inv then Inventory.count(inv, id) else 0
end

-- Returns the leftover that did not fit (0 = all added).
function InventoryService.add(player: Player, id: string, count: number): number
	local inv = inventories[player]
	local def = ItemCatalog.Items[id]
	if inv == nil or def == nil or not Guard.isNumber(count) or count <= 0 then
		return count
	end
	local left = Inventory.add(inv, id, count, def.maxStack, def.durability)
	sync(player)
	return left
end

-- Loot/reward grant with the normal stack rules: whatever does not fit is dropped at the player's feet
-- (pickup prompt) and the player is told. Returns (added, dropped).
function InventoryService.grant(player: Player, id: string, count: number): (number, number)
	local def = ItemCatalog.Items[id]
	if def == nil or not Guard.isNumber(count) or count <= 0 or inventories[player] == nil then
		return 0, 0
	end
	local left = InventoryService.add(player, id, count)
	if left > 0 then
		local at = ItemDrop.feetPosition(player, 0)
		if at then
			ItemDrop.spawn(id, left, at, InventoryService.add)
		end
		Remotes.event(Remotes.Notify):FireClient(player, "craft", REFUSAL.Full)
	end
	return count - left, left
end

-- Removes exactly count (false and unchanged if short). Used by e.g. AddFuel.
function InventoryService.remove(player: Player, id: string, count: number): boolean
	local inv = inventories[player]
	if inv == nil or not Guard.isNumber(count) then
		return false
	end
	local ok = Inventory.remove(inv, id, count)
	if ok then
		sync(player)
	end
	return ok
end

function InventoryService.getSelectedSlot(player: Player): number
	return selected[player] or 1
end

function InventoryService.getSelected(player: Player): Inventory.Stack?
	local inv = inventories[player]
	return if inv then inv.slots[selected[player] or 1] else nil
end

-- Wears the selected item; returns true if it broke.
function InventoryService.wearSelected(player: Player, amount: number): boolean
	local inv = inventories[player]
	if inv == nil then
		return false
	end
	local slot = selected[player] or 1
	local stack = inv.slots[slot]
	if stack ~= nil and ItemCatalog.isUnbreakable(stack.id) then
		return false -- the starting Axe never wears (Config.Durability.UnbreakableItems)
	end
	local broke = Inventory.wear(inv, slot, amount)
	sync(player)
	return broke
end

-- Survival (or another system) registers how consumables apply; return true to consume one item.
function InventoryService.setUseHandler(handler: (Player, ItemCatalog.ItemDef, number) -> boolean)
	useHandler = handler
end

function InventoryService.sync(player: Player)
	sync(player)
end

local function onSelect(player: Player, slot: unknown)
	if not Guard.isNumber(slot) or not Guard.inRange(slot, 1, Config.Inventory.HotbarSize) then
		return
	end
	local index = math.floor(slot :: number)
	if not Guard.rateLimit(player, "Select", Config.Net.SelectRateInterval) then
		return
	end
	if inventories[player] == nil then
		return
	end
	selected[player] = index
	player:SetAttribute(Config.Inventory.SlotAttribute, index)
	sync(player)
end

local function onUse(player: Player, slot: unknown)
	if not Guard.isNumber(slot) or not Guard.inRange(slot, 1, TOTAL_SLOTS) then
		return
	end
	local index = math.floor(slot :: number)
	if not Guard.rateLimit(player, "Use", Config.Net.UseRateInterval) then
		return
	end
	local inv = inventories[player]
	local stack = if inv then inv.slots[index] else nil
	if inv == nil or stack == nil or useHandler == nil then
		return
	end
	local def = ItemCatalog.Items[stack.id]
	if def == nil then
		return
	end
	if useHandler(player, def, index) then
		stack.count -= 1
		if stack.count <= 0 then
			inv.slots[index] = nil
		end
		sync(player)
	end
end

-- Same path as UseItemRequest (QA and server callers); runs the full validation.
InventoryService.handleUse = onUse

local function failMove(player: Player, reason: string, from: Remotes.InventoryAddr?)
	if reason ~= "Same" then
		local text = REFUSAL[reason]
		if text then
			Remotes.event(Remotes.Notify):FireClient(player, "craft", text)
		end
	end
	local payload: Remotes.InventoryMoveResultPayload = { ok = false, reason = reason, from = from }
	Remotes.event(Remotes.InventoryMoveResult):FireClient(player, payload)
	-- A refused move leaves state unchanged; resend it so the client reconciles to the server's truth.
	sync(player)
end

-- type-check -> range/sanity -> rate limit (Guard) -> permission/state/zone -> act
local function onMove(player: Player, payload: unknown)
	local req = InventoryMove.parseRequest(payload)
	if req == nil then
		return
	end
	if not Guard.rateLimit(player, "InvMove", Config.Storage.MoveRateInterval) then
		return
	end
	local inv, equip = inventories[player], equipment[player]
	if inv == nil or equip == nil or ServerUtil.actingRoot(player) == nil then
		return
	end
	local touchesEquip = req.from.kind == "equip" or (req.to ~= nil and req.to.kind == "equip")
	if touchesEquip and not equipReady[player] then
		failMove(player, "Loading", req.from)
		return
	end
	local provider = chestProvider
	local chest: ChestCtx? = if provider then provider(player) else nil
	local ctx: InventoryMove.Ctx = {
		inv = inv,
		equip = equip,
		chest = if chest then chest.inv else nil,
		chestId = if chest then chest.id else nil,
	}
	local ok, reason, touched, stale =
		InventoryMove.perform(ctx, req, if chest then chest.revision else 0)
	if chest then
		if touched.chest then
			chest.changed()
		elseif stale then
			chest.resync()
		end
	end
	if not ok then
		failMove(player, reason, req.from)
		return
	end
	if touched.equip then
		persistEquipment(player)
	end
	sync(player)
end

-- Same path as the InventoryMove remote (QA and server callers); runs the full validation.
InventoryService.handleMove = onMove

-- Explicit Drop (Q / Drop button): type-check -> range -> rate limit -> state (alive, has the stack) -> act.
local function onDrop(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local p = payload :: { [string]: unknown }
	if not Guard.isNumber(p.slot) or not Guard.isNumber(p.count) then
		return
	end
	if not Guard.rateLimit(player, "InvDrop", Config.Storage.MoveRateInterval) then
		return
	end
	local inv = inventories[player]
	if inv == nil or ServerUtil.actingRoot(player) == nil then
		return
	end
	local at = ItemDrop.feetPosition(player, 0)
	if at == nil then
		return
	end
	local ok, reason, id, n = InventoryMove.drop(inv, p.slot, p.count)
	if not ok or id == nil then
		failMove(player, reason, nil)
		return
	end
	ItemDrop.spawn(id, n, at, InventoryService.add)
	sync(player)
end

-- Same path as the DropItemRequest remote (QA and server callers); runs the full validation.
InventoryService.handleDrop = onDrop

local function cleanup(player: Player)
	local t = os.clock()
	for userId, entry in held do
		if t >= entry.expires then
			held[userId] = nil
		end
	end
	local inv = inventories[player]
	local predicate = holdPredicate
	if inv and predicate then
		local ok, keep = pcall(predicate, player)
		if ok and keep == true then
			held[player.UserId] = {
				inv = inv,
				equip = equipment[player] or Equipment.new(),
				selected = selected[player] or 1,
				expires = t + Config.Run.RejoinWindowSeconds,
			}
		end
	end
	inventories[player] = nil
	selected[player] = nil
	equipment[player] = nil
	equipReady[player] = nil
	local conn = characterConns[player]
	if conn then
		conn:Disconnect()
		characterConns[player] = nil
	end
	HeldItem.cleanup(player)
end

-- Wiring (init.server): whether a leaving player's inventory is held for a rejoin.
function InventoryService.setHoldPredicate(fn: ((Player) -> boolean)?)
	holdPredicate = fn
end

function InventoryService.start()
	if started then
		return
	end
	started = true
	Remotes.event(Remotes.SelectSlotRequest).OnServerEvent:Connect(onSelect)
	Remotes.event(Remotes.UseItemRequest).OnServerEvent:Connect(onUse)
	Remotes.event(Remotes.InventoryMove).OnServerEvent:Connect(onMove)
	Remotes.event(Remotes.DropItemRequest).OnServerEvent:Connect(onDrop)
	DataService.onLoaded(loadEquipment)
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(cleanup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

return InventoryService
