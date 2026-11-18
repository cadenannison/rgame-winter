--!strict
-- Repair at a workbench (RepairRequest { slot }). Order: type -> slot range -> rate limit -> state (alive,
-- workbench in range, repairable and damaged, materials held) -> act (spend the cost, restore durability).
-- The cost is recomputed here from the recipe; the client sends only the slot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local Repair = require(Shared.logic.Repair)
local Guard = require(script.Parent.Parent.Net.Guard)
local InventoryService = require(script.Parent.InventoryService)
local CraftingService = require(script.Parent.CraftingService)
local ServerUtil = require(script.Parent.ServerUtil)

local RepairService = {}

local connection: RBXScriptConnection? = nil

local function refuse(player: Player, text: string)
	Remotes.event(Remotes.Notify):FireClient(player, "craft", text)
end

local function onRepair(player: Player, payload: unknown)
	-- 1. type-check, 2. range
	if type(payload) ~= "table" then
		return
	end
	local slot = (payload :: any).slot
	local inv = InventoryService.get(player)
	if inv == nil or not Guard.inRange(slot, 1, inv.size) or slot ~= math.floor(slot) then
		return
	end
	-- 3. rate limit
	if not Guard.rateLimit(player, "Repair", Config.Net.RepairRateInterval) then
		return
	end
	-- 4. state
	if ServerUtil.actingRoot(player) == nil then
		return
	end
	local stack = inv.slots[slot :: number]
	local def = if stack then ItemCatalog.Items[stack.id] else nil
	if stack == nil or def == nil then
		return
	end
	local ok, reason = Repair.check(def, stack.durability)
	if not ok then
		refuse(
			player,
			if reason == "FullDurability"
				then `{def.name} is already in good shape`
				elseif reason == "Unbreakable" then `{def.name} never wears out`
				else `Cannot repair {def.name}`
		)
		return
	end
	local station = Config.Craft.Stations[Config.Repair.Station]
	if not CraftingService.nearStations(player)[Config.Repair.Station] then
		refuse(
			player,
			`Repair needs a {if station then station.Label else Config.Repair.Station} nearby`
		)
		return
	end
	local cost = Repair.cost(def.id)
	if cost == nil then
		return
	end
	local counts: { [string]: number } = {}
	for _, row in cost do
		counts[row.id] = InventoryService.count(player, row.id)
	end
	if not Repair.canAfford(cost, counts) then
		refuse(player, `Repair needs {Repair.costText(cost)}`)
		return
	end
	-- 5. act: the costs were verified above, so every remove succeeds
	for _, row in cost do
		InventoryService.remove(player, row.id, row.count)
	end
	-- Spending cost items can shift stacks; find the damaged stack again by identity.
	if inv.slots[slot :: number] == stack then
		stack.durability = def.durability
	end
	InventoryService.sync(player)
	Remotes.event(Remotes.Notify):FireClient(player, "repair", `Repaired {def.name}`)
end

RepairService.handleRepair = onRepair

function RepairService.start()
	if connection then
		return
	end
	connection = Remotes.event(Remotes.RepairRequest).OnServerEvent:Connect(onRepair)
end

function RepairService.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return RepairService
