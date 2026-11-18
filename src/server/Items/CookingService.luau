--!strict
-- Cooking (CookRequest { slot, station }) at a lit campfire (Config.Fire.CookRadius) or a cooking station
-- (Config.Cooking.StationRange). Order: type -> slot range -> rate limit -> state (alive, heat source is a
-- real structure in reach, raw food, cookable there) -> act (1 raw becomes 1 cooked). Food cooked at the
-- station remembers it (a per-player counter) so eating it grants the longer buff.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local Cooking = require(Shared.logic.Cooking)
local Guard = require(script.Parent.Parent.Net.Guard)
local InventoryService = require(script.Parent.InventoryService)
local FireService = require(script.Parent.Parent.Survival.FireService)
local ServerUtil = require(script.Parent.ServerUtil)

local CookingService = {}

local stationCooked: { [Player]: { [string]: number } } = {}
local connections: { RBXScriptConnection } = {}
local started = false
local cookedHandler: ((Player, string) -> ())? = nil

-- Wiring (Phase 4): told after every successful cook (cooked item id). Nil-safe.
function CookingService.setCookedHandler(fn: ((Player, string) -> ())?)
	cookedHandler = fn
end

local function refuse(player: Player, text: string)
	Remotes.event(Remotes.Notify):FireClient(player, "craft", text)
end

local REFUSAL: { [string]: string } = {
	NotCookable = "That cannot be cooked",
	NeedStation = "Needs a cooking station",
	NoHeat = "Needs a lit fire or cooking station",
}

local function onCook(player: Player, payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local slot = (payload :: any).slot
	local stationArg = (payload :: any).station
	local inv = InventoryService.get(player)
	if
		inv == nil
		or typeof(stationArg) ~= "Instance"
		or not Guard.inRange(slot, 1, inv.size)
		or slot ~= math.floor(slot)
	then
		return
	end
	if not Guard.rateLimit(player, "Cook", Config.Net.CookRateInterval) then
		return
	end
	local root = ServerUtil.actingRoot(player)
	if root == nil then
		return
	end
	local stack = inv.slots[slot :: number]
	if stack == nil then
		return
	end
	-- The heat source is judged from the instance the client names, re-checked here (tag, lit, distance).
	local pos = ServerUtil.pivot(stationArg)
	local dist = if pos then (pos - root.Position).Magnitude else math.huge
	local atFire = CollectionService:HasTag(stationArg, Config.Fire.Tag)
		and FireService.isLit(stationArg)
		and dist <= Config.Fire.CookRadius
	local atStation = CollectionService:HasTag(
		stationArg,
		Config.Craft.Stations[Config.Cooking.Station].Tag
	) and dist <= Config.Cooking.StationRange
	local ok, reason = Cooking.check(stack.id, atFire, atStation)
	if not ok then
		refuse(player, REFUSAL[reason] or "Cannot cook that")
		return
	end
	local def = Cooking.defFor(stack.id)
	local cooked = if def then ItemCatalog.Items[def.cookedId] else nil
	if def == nil or cooked == nil then
		return
	end
	-- Act: raw out first (frees room), cooked in; refund the raw if the cooked item cannot fit.
	if not InventoryService.remove(player, def.rawId, 1) then
		return
	end
	if InventoryService.add(player, cooked.id, 1) > 0 then
		InventoryService.add(player, def.rawId, 1)
		refuse(player, "Inventory full")
		return
	end
	if atStation then
		local counts = stationCooked[player]
		if counts == nil then
			counts = {}
			stationCooked[player] = counts
		end
		counts[cooked.id] = (counts[cooked.id] or 0) + 1
	end
	Remotes.event(Remotes.Notify):FireClient(player, "cook", `Cooked {cooked.name}`)
	local handler = cookedHandler
	if handler then
		task.spawn(handler, player, cooked.id)
	end
end

-- Eating hook (FoodService): true if this item was cooked at a station (consumes one credit).
function CookingService.consumeStationBonus(player: Player, itemId: string): boolean
	local counts = stationCooked[player]
	local n = if counts then counts[itemId] or 0 else 0
	if counts == nil or n <= 0 then
		return false
	end
	-- Credits cannot exceed what is still carried (items may have been stored or lost).
	counts[itemId] = math.min(n, InventoryService.count(player, itemId)) - 1
	return true
end

CookingService.handleCook = onCook

function CookingService.start()
	if started then
		return
	end
	started = true
	table.insert(connections, Remotes.event(Remotes.CookRequest).OnServerEvent:Connect(onCook))
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			stationCooked[player] = nil
		end)
	)
end

function CookingService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(stationCooked)
	started = false
end

return CookingService
