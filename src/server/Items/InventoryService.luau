--!strict
-- Server-authoritative inventory (hotbar + backpack). Not persisted (DataService integration is separate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local Inventory = require(Shared.logic.Inventory)
local Guard = require(script.Parent.Parent.Net.Guard)

local InventoryService = {}

local inventories: { [Player]: Inventory.Inv } = {}
local selected: { [Player]: number } = {}
local useHandler: ((Player, ItemCatalog.ItemDef, number) -> boolean)? = nil
local started = false

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
	local payload: Remotes.InventoryPayload = { slots = slots, selected = selected[player] or 1 }
	Remotes.event(Remotes.InventoryUpdate):FireClient(player, payload)
end

local function setup(player: Player)
	if inventories[player] then
		return
	end
	local inv = Inventory.new(TOTAL_SLOTS)
	for _, starter in Config.Inventory.StarterItems do
		local def = ItemCatalog.Items[starter.id]
		if def then
			Inventory.add(inv, def.id, starter.count, def.maxStack, def.durability)
		end
	end
	inventories[player] = inv
	selected[player] = 1
	player:SetAttribute(Config.Inventory.SlotAttribute, 1)
	sync(player)
end

function InventoryService.get(player: Player): Inventory.Inv?
	return inventories[player]
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
	local broke = Inventory.wear(inv, selected[player] or 1, amount)
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

local function cleanup(player: Player)
	inventories[player] = nil
	selected[player] = nil
end

function InventoryService.start()
	if started then
		return
	end
	started = true
	Remotes.event(Remotes.SelectSlotRequest).OnServerEvent:Connect(onSelect)
	Remotes.event(Remotes.UseItemRequest).OnServerEvent:Connect(onUse)
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(cleanup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

return InventoryService
