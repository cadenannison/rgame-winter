--!strict
-- Storage chests on the client: an "Open" ProximityPrompt on every placed chest (CollectionService tag
-- Config.Build.StorageTag), the server's StorageState snapshots feeding the chest grid of the backpack panel,
-- and the panel itself (BackpackPanel: hotbar, 27-slot grid, equipment, chest). Display and intent only: the
-- server validates range, revision and every move (Remotes.InventoryMove).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SlotViewModel = require(Shared:WaitForChild("logic"):WaitForChild("SlotViewModel"))
local BackpackPanel = require(script.Parent:WaitForChild("BackpackPanel"))
local DebugChat = require(script.Parent.Parent:WaitForChild("HUD"):WaitForChild("DebugChat"))
local InventoryMirror = require(script.Parent:WaitForChild("InventoryMirror"))
local UiConfig = require(script.Parent:WaitForChild("InventoryUiConfig"))

export type Controller = {
	isOpen: () -> boolean,
	close: () -> (),
	panel: BackpackPanel.Panel,
	destroy: () -> (),
}

local StorageController = {}

local function promptParent(chest: Instance): Instance?
	if chest:IsA("BasePart") then
		return chest
	elseif chest:IsA("Model") then
		return chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

function StorageController.start(mirror: InventoryMirror.Mirror, report: (string) -> ()): Controller
	local destroyed = false
	local openChest: Instance? = nil
	local connections: { RBXScriptConnection } = {}
	local prompts: { [Instance]: ProximityPrompt } = {}
	local panel = BackpackPanel.new(mirror)
	DebugChat.onLocal("inv", function()
		for _, line in panel.debugLines() do
			print(`[Debug] {line}`)
		end
	end)

	local function addPrompt(chest: Instance)
		if prompts[chest] or destroyed then
			return
		end
		local parent = promptParent(chest)
		if parent == nil then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StorageOpenPrompt"
		prompt.ActionText = UiConfig.PromptActionText
		prompt.ObjectText = UiConfig.PromptObjectText
		prompt.KeyboardKeyCode = UiConfig.ChestKeyCode
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = Config.Storage.OpenRange
		prompts[chest] = prompt
		table.insert(
			connections,
			prompt.Triggered:Connect(function()
				Remotes.event(Remotes.StorageOpenRequest):FireServer({ chest = chest })
			end)
		)
		chest.Destroying:Once(function()
			prompts[chest] = nil
		end)
		prompt.Parent = parent
	end

	for _, chest in CollectionService:GetTagged(Config.Build.StorageTag) do
		addPrompt(chest)
	end
	table.insert(
		connections,
		CollectionService:GetInstanceAddedSignal(Config.Build.StorageTag):Connect(addPrompt)
	)

	local function close()
		panel.close()
		openChest = nil
	end

	task.spawn(function()
		local ev = Remotes.event(Remotes.StorageState)
		if destroyed then
			return
		end
		table.insert(
			connections,
			ev.OnClientEvent:Connect(function(p: any)
				if type(p) ~= "table" then
					return
				end
				if typeof(p.chest) ~= "Instance" or type(p.id) ~= "string" then
					-- closed by the server (walked away, destroyed) or by us: hide the chest grid only
					openChest = nil
					panel.setChest(nil)
					return
				end
				local slots = SlotViewModel.decodeSlots(p.slots)
				if openChest == nil then
					report("chestOpened")
				end
				openChest = p.chest
				panel.setChest({
					chest = p.chest,
					id = p.id,
					rev = if type(p.rev) == "number" then p.rev else 0,
					slots = slots,
				})
			end)
		)
	end)

	return {
		isOpen = function(): boolean
			return panel.isOpen()
		end,
		close = close,
		panel = panel,
		destroy = function()
			destroyed = true
			DebugChat.onLocal("inv", nil)
			for _, c in connections do
				c:Disconnect()
			end
			table.clear(connections)
			for _, prompt in prompts do
				prompt:Destroy()
			end
			table.clear(prompts)
			panel.destroy()
		end,
	}
end

return StorageController
