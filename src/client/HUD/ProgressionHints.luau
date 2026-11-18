--!strict
-- First-run hints for the Phase 3 mechanics (chest, cooking, repair, door, trap, ping and every new
-- placeable). One hint at a time, shown when the player has something to use it on, and finished by the
-- real action: report("chestOpened" | "cooked" | "repaired" | "doorToggled" | "pinged" | "placed:<id>").
-- An action done before its hint showed counts as done. Per session (see docs/KNOWN_ISSUES.md).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local Repair = require(Shared:WaitForChild("logic"):WaitForChild("Repair"))
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))
local InventoryMirror =
	require(script.Parent.Parent:WaitForChild("Storage"):WaitForChild("InventoryMirror"))

local P = HudConfig.Progression
local CHECK_SECONDS = 1

export type Hints = { report: (event: string) -> (), current: () -> string?, destroy: () -> () }

type Hint = {
	id: string,
	have: string?,
	damaged: boolean?,
	party: boolean?,
	done: string,
	text: string,
}

local ProgressionHints = {}

function ProgressionHints.start(gui: ScreenGui, mirror: InventoryMirror.Mirror): Hints
	local list: { Hint } = {}
	for _, h in P.Hints do
		table.insert(list, h :: any)
	end
	for _, id in P.PlaceHintIds do
		local def = ItemCatalog.Items[id]
		table.insert(
			list,
			{
				id = `place{id}`,
				have = id,
				done = `placed:{id}`,
				text = string.gsub(P.PlaceHint, "{name}", if def then def.name else id),
			} :: Hint
		)
	end

	local events: { [string]: boolean } = {}
	local finished: { [string]: boolean } = {}
	local shownId: string? = nil
	local destroyed = false
	local flashUntil = 0.0

	local label = Instance.new("TextLabel")
	label.Name = "ProgressionHint"
	label.Position = P.HintPosition
	label.Size = UDim2.fromOffset(P.HintWidth, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundColor3 = HudConfig.PanelColor
	label.BackgroundTransparency = HudConfig.PanelTransparency
	label.BorderSizePixel = 0
	label.TextColor3 = HudConfig.TextColor
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	label.Parent = gui

	local function relevant(h: Hint): boolean
		if h.have then
			return (mirror.counts()[h.have] or 0) > 0
		elseif h.damaged then
			for _, stack in mirror.slots() do
				local def = ItemCatalog.Items[stack.id]
				if
					def
					and Repair.isRepairable(def)
					and stack.durability ~= nil
					and Repair.percent(def, stack.durability) <= P.HintDamagedPercent
				then
					return true
				end
			end
			return false
		elseif h.party then
			return #Players:GetPlayers() > 1
		end
		return false
	end

	local function evaluate()
		if destroyed or os.clock() < flashUntil then
			return
		end
		for _, h in list do
			if not finished[h.id] and events[h.done] then
				finished[h.id] = true
			end
		end
		local pick: Hint? = nil
		for _, h in list do
			if not finished[h.id] and relevant(h) then
				pick = h
				break
			end
		end
		if pick then
			shownId = pick.id
			label.Text = pick.text
			label.Visible = true
		else
			shownId = nil
			label.Visible = false
		end
	end

	mirror.onChange(evaluate)
	task.spawn(function()
		while not destroyed do
			evaluate()
			task.wait(CHECK_SECONDS)
		end
	end)

	return {
		report = function(event: string)
			if events[event] then
				return
			end
			events[event] = true
			local doneHint = shownId
			evaluate()
			if doneHint and finished[doneHint] and not destroyed then
				label.Text = "Done!"
				label.Visible = true
				flashUntil = os.clock() + P.HintDoneFlashSeconds
				task.delay(P.HintDoneFlashSeconds + 0.05, evaluate)
			end
		end,
		current = function(): string?
			return shownId
		end,
		destroy = function()
			destroyed = true
			label:Destroy()
		end,
	}
end

return ProgressionHints
