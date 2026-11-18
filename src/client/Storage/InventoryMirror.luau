--!strict
-- Read-only client copy of the player's inventory (InventoryUpdate) with durability, for the Phase 3
-- structure UI (interact prompts, chest panel, hints). The HUD keeps its own copy for the hotbar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

export type Stack = { id: string, count: number, durability: number? }
export type Mirror = {
	slots: () -> { [number]: Stack },
	counts: () -> { [string]: number },
	selected: () -> Stack?,
	selectedSlot: () -> number,
	onChange: (fn: (before: { [string]: number }) -> ()) -> (),
	destroy: () -> (),
}

local InventoryMirror = {}

function InventoryMirror.start(): Mirror
	local slots: { [number]: Stack } = {}
	local counts: { [string]: number } = {}
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
			for i, s in p.slots do
				if type(i) == "number" and type(s) == "table" and type(s.id) == "string" then
					local n = if type(s.count) == "number" then s.count else 1
					slots[i] = {
						id = s.id,
						count = n,
						durability = if type(s.durability) == "number" then s.durability else nil,
					}
					counts[s.id] = (counts[s.id] or 0) + n
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
