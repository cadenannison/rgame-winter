--!strict
-- MarketplaceService.ProcessReceipt for developer products (coin packs, Robux-only cosmetics).
-- Idempotent: a PurchaseId already in profile.processedReceipts is acknowledged without a second grant.
-- Grant and receipt record happen in one synchronous profile mutation (ShopLogic.grantReceipt), then
-- PurchaseGranted is returned. Profile not loaded / unknown product / any error -> NotProcessedYet
-- (Roblox retries). No random or paid-random item exists.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Shop = require(Shared.data.Shop)
local Types = require(Shared.data.Types)
local ShopLogic = require(Shared.logic.ShopLogic)
local DataService = require(script.Parent.Parent.Data.DataService)
local MetaService = require(script.Parent.MetaService)
local ShopService = require(script.Parent.ShopService)

local ReceiptService = {}

type ReceiptInfo = {
	PurchaseId: string | number,
	PlayerId: number,
	ProductId: number,
}

local started = false

-- Shop item for a developer product id (placeholder 0 ids never match).
function ReceiptService.itemForProduct(productId: number): Types.ShopItemDef?
	for key, id in Config.Meta.ProductIds :: { [string]: number } do
		if id > 0 and id == productId then
			return Shop.ByProductKey[key]
		end
	end
	return nil
end

-- Pure-ish core (injectable for tests/QA): returns true when PurchaseGranted may be returned.
function ReceiptService.process(
	player: Player?,
	purchaseId: string,
	productId: number,
	now: number
): boolean
	if player == nil or player.Parent ~= Players then
		return false
	end
	local profile = DataService.get(player)
	if profile == nil then
		return false
	end
	return ReceiptService.processItem(
		player,
		purchaseId,
		ReceiptService.itemForProduct(productId),
		now
	)
end

-- Grant core shared by ProcessReceipt and Studio QA (which names a shop item because ProductIds are 0).
function ReceiptService.processItem(
	player: Player?,
	purchaseId: string,
	item: Types.ShopItemDef?,
	now: number
): boolean
	if player == nil or player.Parent ~= Players then
		return false
	end
	local profile = DataService.get(player)
	if profile == nil then
		return false
	end
	local result = ShopLogic.grantReceipt(profile, purchaseId, item, now)
	if result == "invalid" then
		return false
	end
	if result == "granted" then
		-- Persist the grant and its receipt record now rather than at the next autosave.
		DataService.save(player)
		MetaService.pushState(player)
		ShopService.sendResult(player, true, if item then item.id else "", nil)
	end
	return true
end

local function handle(info: ReceiptInfo): Enum.ProductPurchaseDecision
	local ok, granted = pcall(function()
		local player = Players:GetPlayerByUserId(info.PlayerId)
		return ReceiptService.process(player, tostring(info.PurchaseId), info.ProductId, os.time())
	end)
	if ok and granted == true then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not ok then
		warn("ReceiptService: receipt processing failed")
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ReceiptService.Start()
	if started then
		return
	end
	started = true
	MarketplaceService.ProcessReceipt = handle
end

function ReceiptService.Stop()
	started = false
end

return ReceiptService
