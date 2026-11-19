--!strict
-- Server-built visual of the selected hotbar item in the character's hand (a Tool parented to the
-- character, so it replicates and uses the default hold pose). Visual only: gameplay always reads
-- InventoryService's selected stack, never this Tool. Owned by InventoryService (show/clear/cleanup).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemCatalog = require(Shared.ItemCatalog)
local ItemModels = require(Shared.ItemModels)

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
	local model = ItemModels.build(id, "held")
	local primary = model and model.PrimaryPart
	if model == nil or primary == nil then
		if model then
			model:Destroy()
		end
		return nil
	end
	local tool = Instance.new("Tool")
	tool.Name = Config.Held.ToolName
	tool.ToolTip = def.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool.GripPos = ItemModels.heldGrip(id)
	tool:SetAttribute("ItemId", id)
	primary.Name = "Handle" -- Tool contract; the other parts stay welded to it (WeldConstraints survive the move)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
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
