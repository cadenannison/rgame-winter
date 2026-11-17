--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

export type MetersPayload = {
	health: number,
	warmth: number,
	hunger: number,
	day: number,
	isNight: boolean,
}
export type ItemStack = { id: string, count: number, durability: number? }
export type InventoryPayload = { slots: { [number]: ItemStack? }, selected: number } -- full snapshot, index = slot
export type CraftPayload = { recipeId: string }
export type PlacePayload = { structureId: string, position: Vector3, rotationY: number }
export type GatherPayload = { node: Instance }
export type AttackPayload = { target: Instance? } -- server validates range, cooldown, weapon

local Remotes = {}

-- Remote names (one RemoteEvent per intent). Document payload types and direction here.
Remotes.Notify = "Notify" -- server -> client (kind: string, text: string)
-- Phase 1 (payload types above; client -> server unless noted; server re-validates everything)
Remotes.MetersUpdate = "MetersUpdate" -- server -> client (MetersPayload)
Remotes.InventoryUpdate = "InventoryUpdate" -- server -> client (InventoryPayload)
Remotes.CraftRequest = "CraftRequest" -- client -> server (recipeId: string)
Remotes.PlaceRequest = "PlaceRequest" -- client -> server (structureId: string, position: Vector3, rotationY: number)
Remotes.GatherRequest = "GatherRequest" -- client -> server (node: Instance)
Remotes.AttackRequest = "AttackRequest" -- client -> server (target: Instance?)
Remotes.SelectSlotRequest = "SelectSlotRequest" -- client -> server (slot: number)
Remotes.UseItemRequest = "UseItemRequest" -- client -> server (slot: number), eat/consume
Remotes.AddFuelRequest = "AddFuelRequest" -- client -> server (fire: Instance), spends wood from inventory
Remotes.UpgradeFireRequest = "UpgradeFireRequest" -- client -> server (fire: Instance), spends the tier upgrade cost
Remotes.ReviveRequest = "ReviveRequest" -- client -> server (target: Player)
Remotes.DebugCommand = "DebugCommand" -- client -> server, Studio only (command: string, arg: any); not in Remotes.all

-- Every remote the server creates eagerly at startup (so clients never wait on a missing folder).
Remotes.all = {
	Remotes.Notify,
	Remotes.MetersUpdate,
	Remotes.InventoryUpdate,
	Remotes.CraftRequest,
	Remotes.PlaceRequest,
	Remotes.GatherRequest,
	Remotes.AttackRequest,
	Remotes.SelectSlotRequest,
	Remotes.UseItemRequest,
	Remotes.AddFuelRequest,
	Remotes.UpgradeFireRequest,
	Remotes.ReviveRequest,
}

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
	if existing then
		return existing :: Folder
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = Config.RemoteFolderName
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(Config.RemoteFolderName) :: Folder
end

-- Server creates the event lazily; the client waits for it.
function Remotes.event(name: string): RemoteEvent
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end
	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

-- Server only: create the folder and every remote.
function Remotes.createAll()
	for _, name in Remotes.all do
		Remotes.event(name)
	end
end

return Remotes
