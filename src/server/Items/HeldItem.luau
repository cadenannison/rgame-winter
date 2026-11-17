--!strict
-- Server-built visual of the selected hotbar item in the character's hand (a Tool parented to the
-- character, so it replicates and uses the default hold pose). Visual only: gameplay always reads
-- InventoryService's selected stack, never this Tool. Owned by InventoryService (show/clear/cleanup).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemCatalog = require(Shared.ItemCatalog)

local HeldItem = {}

type Held = { id: string, tool: Tool }

local held: { [Player]: Held } = {}

local function destroy(player: Player)
	local h = held[player]
	if h then
		held[player] = nil
		h.tool:Destroy()
	end
end

local function build(id: string): Tool?
	local def = ItemCatalog.Items[id]
	if def == nil then
		return nil
	end
	local visual = Config.Held.Visuals[id] or Config.Held.Default
	local tool = Instance.new("Tool")
	tool.Name = Config.Held.ToolName
	tool.ToolTip = def.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool.GripPos = Vector3.new(0, -visual.GripOffset, 0)
	tool:SetAttribute("ItemId", id)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(visual.Size[1], visual.Size[2], visual.Size[3])
	handle.Color = Color3.fromRGB(visual.Color[1], visual.Color[2], visual.Color[3])
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

-- Shows id (nil = empty hand) in the player's current character. Idempotent.
function HeldItem.show(player: Player, id: string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local h = held[player]
	if h and h.id == id and character and h.tool.Parent == character then
		return
	end
	destroy(player)
	if id == nil or character == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local tool = build(id)
	if tool == nil then
		return
	end
	held[player] = { id = id, tool = tool }
	tool.Parent = character -- parenting a Tool to the character equips it
end

function HeldItem.cleanup(player: Player)
	destroy(player)
end

return HeldItem
