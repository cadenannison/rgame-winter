--!strict
-- Applies the equipped cosmetic to characters as data only: a "Cosmetic" attribute (id) on the character
-- and a CollectionService tag per slot (art/visual scripts react to the tag). Cleaned up on leave/respawn.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Shop = require(Shared.data.Shop)

local CosmeticService = {}

local TAG_PREFIX = Config.Meta.CosmeticTagPrefix -- + slot: outfit | trail | camp | pet
local SLOTS = Config.Meta.CosmeticSlots

local started = false
local connections: { RBXScriptConnection } = {}
local characterConns: { [Player]: { RBXScriptConnection } } = {}
local equipped: { [Player]: string } = {}

local function clear(character: Model)
	for _, slot in SLOTS do
		CollectionService:RemoveTag(character, TAG_PREFIX .. slot)
	end
	character:SetAttribute(Config.Meta.CosmeticAttribute, nil)
end

local function applyTo(character: Model, id: string)
	clear(character)
	local item = Shop.ById[id]
	if id == "" or item == nil or item.cosmeticSlot == nil then
		return
	end
	character:SetAttribute(Config.Meta.CosmeticAttribute, id)
	CollectionService:AddTag(character, TAG_PREFIX .. item.cosmeticSlot)
end

local function release(player: Player)
	local list = characterConns[player]
	if list then
		for _, connection in list do
			connection:Disconnect()
		end
	end
	characterConns[player] = nil
	equipped[player] = nil
	if player.Character then
		clear(player.Character)
	end
end

-- Records the equipped id and applies it to the current and every future character of this player.
function CosmeticService.refresh(player: Player, id: string)
	if player.Parent ~= Players then
		return
	end
	equipped[player] = id
	if not characterConns[player] then
		characterConns[player] = {
			player.CharacterAdded:Connect(function(character: Model)
				applyTo(character, equipped[player] or "")
			end),
		}
	end
	if player.Character then
		applyTo(player.Character, id)
	end
end

function CosmeticService.Start()
	if started then
		return
	end
	started = true
	table.insert(connections, Players.PlayerRemoving:Connect(release))
end

function CosmeticService.Stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for player in table.clone(characterConns) do
		release(player)
	end
	started = false
end

return CosmeticService
