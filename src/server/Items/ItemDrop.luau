--!strict
-- Overflow drops: items that did not fit in a full inventory land at the player's feet as a pickup part
-- with a ProximityPrompt. Server-owned, capped, expiring. Pickup runs through the supplied adder so the
-- same stack rules apply (no yield; the part and prompt are destroyed by Debris or on a full pickup).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemCatalog = require(Shared.ItemCatalog)

local LIFETIME_SECONDS = 120 -- how long an overflow drop lasts
local MAX_DROPS = 60 -- live drops in the world (oldest removed first)
local SIZE = Vector3.new(1.2, 1.2, 1.2)
local BELOW_ROOT = 2.5 -- studs under the root part: at the player's feet
local SPREAD = 2.5 -- studs between drops of one overflow
local FOLDER_NAME = "ItemDrops"
local DROP_COLOR = Color3.fromRGB(235, 200, 120)

export type Adder = (Player, string, number) -> number -- returns the leftover

local ItemDrop = {}

local drops: { BasePart } = {}

local function remove(part: BasePart)
	part:Destroy() -- the Destroying hook below drops it from the list
end

local function folder(): Instance
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = FOLDER_NAME
	f.Parent = Workspace
	return f
end

-- Drops `count` of `id` at `at` (feet position). `pickUp` adds to a taker's inventory and returns the leftover.
function ItemDrop.spawn(id: string, count: number, at: Vector3, pickUp: Adder)
	if count <= 0 or ItemCatalog.Items[id] == nil then
		return
	end
	while #drops >= MAX_DROPS do
		remove(drops[1])
	end
	local def = ItemCatalog.Items[id]
	local part = Instance.new("Part")
	part.Name = "ItemDrop"
	part.Size = SIZE
	part.Position = at
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = DROP_COLOR
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = `{def.name} x{count}`
	prompt.MaxActivationDistance = Config.Inventory.DropPickupRange
	prompt.Parent = part
	local remaining = count
	prompt.Triggered:Connect(function(taker: Player)
		local character = taker.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			taker.Parent ~= Players
			or part.Parent == nil
			or root == nil
			or not root:IsA("BasePart")
			or (root.Position - part.Position).Magnitude > Config.Inventory.DropPickupRange
		then
			return
		end
		local left = pickUp(taker, id, remaining)
		if left <= 0 then
			remove(part)
		elseif left < remaining then
			remaining = left
			prompt.ObjectText = `{def.name} x{left}`
		end
	end)
	table.insert(drops, part)
	part.Destroying:Once(function()
		local index = table.find(drops, part)
		if index then
			table.remove(drops, index)
		end
	end)
	part.Parent = folder()
	Debris:AddItem(part, LIFETIME_SECONDS)
end

-- Drop position at a player's feet, nudged by `index` so several drops do not overlap.
function ItemDrop.feetPosition(player: Player, index: number): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root.Position - Vector3.new(-index * SPREAD, BELOW_ROOT, 0)
end

return ItemDrop
