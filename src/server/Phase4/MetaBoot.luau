--!strict
-- Phase 4 server boot hook for brief 19 (meta: achievements, shop, perks, receipts, cosmetics).
-- init.server.luau calls start(mode) once in BOTH modes (mode = Config.Teleport.ModeLobby or ModeRun),
-- after the mode's services start and before Spawn.start(). Must not yield.
-- MarketplaceService.ProcessReceipt is assigned in both modes (a receipt can arrive on any server).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MetaService = require(script.Parent.Parent.Meta.MetaService)
local PerkService = require(script.Parent.Parent.Meta.PerkService)
local ReceiptService = require(script.Parent.Parent.Meta.ReceiptService)
local ShopService = require(script.Parent.Parent.Meta.ShopService)

local MetaBoot = {}

function MetaBoot.start(mode: string)
	MetaService.setMode(mode)
	MetaService.Start()
	ShopService.Start()
	ReceiptService.Start()
	if mode == Config.Teleport.ModeRun then
		PerkService.Start()
	end
end

return MetaBoot
