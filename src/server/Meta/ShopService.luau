--!strict
-- Shop handlers. Coin purchases (lobby only) and Robux prompts. The client sends an item id only; price,
-- ownership, milestone and caps are recomputed from data/Shop and the profile here.
-- Handler order: type-check -> range (id length, known id) -> Guard.rateLimit -> permission/state -> act.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Shop = require(Shared.data.Shop)
local ShopLogic = require(Shared.logic.ShopLogic)
local Guard = require(script.Parent.Parent.Net.Guard)
local DataService = require(script.Parent.Parent.Data.DataService)
local MetaService = require(script.Parent.MetaService)

local ShopService = {}

local RATE_BUY = "ShopBuy"
local RATE_ROBUX = "RobuxPrompt"

local started = false
local connections: { RBXScriptConnection } = {}

function ShopService.sendResult(player: Player, ok: boolean, itemId: string, reason: string?)
	local profile = DataService.get(player)
	local payload: Remotes.PurchaseResultPayload =
		{ ok = ok, itemId = itemId, coins = if profile then profile.coins else 0, reason = reason }
	pcall(function()
		Remotes.event(Remotes.PurchaseResult):FireClient(player, payload)
	end)
end

local function parseItemId(payload: unknown): string?
	if type(payload) ~= "table" then
		return nil
	end
	local id = (payload :: { itemId: unknown }).itemId
	if type(id) ~= "string" or #id == 0 or #id > Config.Meta.MaxItemIdLength then
		return nil
	end
	return id
end

-- Returns the outcome ("ok" or a refusal reason; "ignored" = dropped before a result) for QA callers.
local function onBuy(player: Player, payload: unknown): string
	local id = parseItemId(payload)
	if id == nil then
		return "ignored"
	end
	if not Guard.rateLimit(player, RATE_BUY, Config.Net.ShopRateInterval) then
		return "ignored"
	end
	if player.Parent ~= Players then
		return "ignored"
	end
	if not MetaService.isLobby() then
		ShopService.sendResult(player, false, id, "unavailable")
		return "unavailable"
	end
	local profile = DataService.get(player)
	if not profile then
		ShopService.sendResult(player, false, id, "failed")
		return "failed"
	end
	local ok, reason = ShopLogic.buyWithCoins(profile, Shop.ById[id])
	if ok then
		MetaService.pushState(player)
	end
	ShopService.sendResult(player, ok, id, reason)
	return if ok then "ok" else reason or "failed"
end

-- Returns "prompted" or the refusal reason ("ignored" = dropped before a result) for QA callers.
local function onRobuxRequest(player: Player, payload: unknown): string
	local id = parseItemId(payload)
	if id == nil then
		return "ignored"
	end
	if not Guard.rateLimit(player, RATE_ROBUX, Config.Net.RobuxPromptRateInterval) then
		return "ignored"
	end
	if player.Parent ~= Players then
		return "ignored"
	end
	local item = Shop.ById[id]
	if item == nil or item.currency ~= "robux" or item.productKey == nil then
		ShopService.sendResult(player, false, id, "unavailable")
		return "unavailable"
	end
	local productId = (Config.Meta.ProductIds :: { [string]: number })[item.productKey] or 0
	if productId <= 0 then
		ShopService.sendResult(player, false, id, "unavailable") -- placeholder id: never prompt
		return "unavailable"
	end
	local profile = DataService.get(player)
	if not profile then
		ShopService.sendResult(player, false, id, "failed")
		return "failed"
	end
	if item.category == "cosmetic" and ShopLogic.owned(profile, item) then
		ShopService.sendResult(player, false, id, "owned")
		return "owned"
	end
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
	if not ok then
		ShopService.sendResult(player, false, id, "failed")
		return "failed"
	end
	return "prompted"
end

-- Same paths as the remotes (QA and server callers); run the full validation.
ShopService.handleBuy = onBuy
ShopService.handleRobux = onRobuxRequest

function ShopService.Start()
	if started then
		return
	end
	started = true
	table.insert(connections, Remotes.event(Remotes.ShopBuyRequest).OnServerEvent:Connect(onBuy))
	table.insert(
		connections,
		Remotes.event(Remotes.RobuxPurchaseRequest).OnServerEvent:Connect(onRobuxRequest)
	)
end

function ShopService.Stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	started = false
end

return ShopService
