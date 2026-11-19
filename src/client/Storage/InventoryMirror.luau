--!strict
-- Read-only client copy of the player's inventory (InventoryUpdate) with durability, for the Phase 3
-- structure UI (interact prompts, chest panel, hints). The HUD keeps its own copy for the hotbar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local SlotViewModel = require(Shared:WaitForChild("logic"):WaitForChild("SlotViewModel"))

export type Stack = { id: string, count: number, durability: number? }
export type Mirror = {
	slots: () -> { [number]: Stack },
	counts: () -> { [string]: number },
	equipment: () -> { [string]: Stack }, -- worn gear, Config.Equipment.Slots id -> stack
	selected: () -> Stack?,
	selectedSlot: () -> number,
	onChange: (fn: (before: { [string]: number }) -> ()) -> (),
	destroy: () -> (),
}

local InventoryMirror = {}

function InventoryMirror.start(): Mirror
	local slots: { [number]: Stack } = {}
	local counts: { [string]: number } = {}
	local equipment: { [string]: Stack } = {}
	local selected = 1
	local listeners: { (before: { [string]: number }) -> () } = {}
	local connection: RBXScriptConnection? = nil
	local destroyed = false

	task.spawn(function()
		local ev = Remotes.event(Remotes.InventoryUpdate)
		if destroyed then
			return
		end
		connection = ev.OnClientEvent:Connect(function(p: any)
			if type(p) ~= "table" or type(p.slots) ~= "table" then
				return
			end
			local before = counts
			slots = {}
			counts = {}
			slots = SlotViewModel.decodeSlots(p.slots) -- tolerates string keys from sparse tables
			for _, s in slots do
				counts[s.id] = (counts[s.id] or 0) + s.count
			end
			equipment = {}
			if type(p.equipment) == "table" then
				for slotId, s in p.equipment do
					if
						type(slotId) == "string"
						and type(s) == "table"
						and type(s.id) == "string"
					then
						equipment[slotId] = { id = s.id, count = 1 }
					end
				end
			end
			if type(p.selected) == "number" then
				selected = p.selected
			end
			for _, fn in listeners do
				fn(before)
			end
		end)
	end)

	return {
		slots = function()
			return slots
		end,
		counts = function()
			return counts
		end,
		equipment = function()
			return equipment
		end,
		selected = function(): Stack?
			return slots[selected]
		end,
		selectedSlot = function(): number
			return selected
		end,
		onChange = function(fn)
			table.insert(listeners, fn)
		end,
		destroy = function()
			destroyed = true
			if connection then
				connection:Disconnect()
			end
			table.clear(listeners)
		end,
	}
end

return InventoryMirror
