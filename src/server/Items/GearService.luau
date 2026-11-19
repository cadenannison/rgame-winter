--!strict
-- Worn gear visuals: shows every equipped item (InventoryService equipment) on the player's R15 character via
-- GearModels. Rebuilds only the changed slots on equip/unequip (InventoryService.onEquipmentChanged, which also
-- fires from clearEquipment), re-applies on CharacterAdded, clears on death, character removal and PlayerRemoving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Equipment = require(Shared.logic.Equipment)
local GearModels = require(Server.Art.GearModels)
local InventoryService = require(script.Parent.InventoryService)

local GearService = {}

type State = {
	applied: { [string]: string }, -- slot -> item id currently built
	conns: { RBXScriptConnection },
	token: number, -- bumps to cancel pending retries
}

local states: { [Player]: State } = {}
local started = false

local function worn(player: Player): { [string]: string }
	local equip = InventoryService.getEquipment(player)
	return if equip then Equipment.toMap(equip) else {}
end

local function liveCharacter(player: Player): Model?
	local character = player.Character
	if character == nil or character.Parent == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return character
end

-- Brings the character in line with the equipment; returns true when every worn slot is fully built.
local function apply(player: Player): boolean
	local state = states[player]
	local character = liveCharacter(player)
	if state == nil or character == nil then
		return true
	end
	local folder = character:FindFirstChild(Config.ArtGear.FolderName)
	if folder == nil then
		state.applied = {} -- fresh character (or folder lost): rebuild everything
	end
	local map = worn(player)
	local complete = true
	for _, slot in Config.Equipment.Slots do
		local id = map[slot]
		if state.applied[slot] ~= id then
			if id == nil then
				GearModels.clearSlot(character, slot)
				state.applied[slot] = nil
			else
				local parts = GearModels.build(id, slot, character)
				if #parts > 0 then
					state.applied[slot] = id
				else
					complete = false -- rig not ready (or over budget); retry
				end
			end
		end
	end
	return complete
end

local function applyWithRetry(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	state.token += 1
	local token = state.token
	local function attempt(left: number)
		local current = states[player]
		if current == nil or current.token ~= token then
			return
		end
		if not apply(player) and left > 0 then
			task.delay(Config.ArtGear.RetrySeconds, attempt, left - 1)
		end
	end
	attempt(Config.ArtGear.RetryCount)
end

local function disconnectAll(state: State)
	for _, conn in state.conns do
		conn:Disconnect()
	end
	table.clear(state.conns)
end

local function onCharacter(player: Player, character: Model)
	local state = states[player]
	if state == nil then
		return
	end
	state.applied = {}
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(
			state.conns,
			humanoid.Died:Connect(function()
				local current = states[player]
				if current then
					current.token += 1
					current.applied = {}
				end
				GearModels.clearAll(character)
			end)
		)
	end
	table.insert(
		state.conns,
		character.Destroying:Connect(function()
			local current = states[player]
			if current and player.Character == character then
				current.applied = {}
			end
		end)
	)
	task.defer(applyWithRetry, player)
end

local function setup(player: Player)
	if states[player] then
		return
	end
	local state: State = { applied = {}, conns = {}, token = 0 }
	states[player] = state
	-- Character connections are per character; the CharacterAdded link lives for the player.
	table.insert(
		state.conns,
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	)
	local character = player.Character
	if character then
		onCharacter(player, character)
	end
end

local function cleanup(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	state.token += 1
	disconnectAll(state)
	states[player] = nil
	local character = player.Character
	if character then
		GearModels.clearAll(character)
	end
end

-- Rebuilds changed slots from InventoryService's equipment.
function GearService.refresh(player: Player)
	if states[player] then
		applyWithRetry(player)
	end
end

-- Removes every worn-gear part and forgets what was applied.
function GearService.clear(player: Player)
	local state = states[player]
	if state then
		state.token += 1
		state.applied = {}
	end
	local character = player.Character
	if character then
		GearModels.clearAll(character)
	end
end

function GearService.start()
	if started then
		return
	end
	started = true
	InventoryService.onEquipmentChanged(GearService.refresh)
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(cleanup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

return GearService
