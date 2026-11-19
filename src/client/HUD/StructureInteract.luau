--!strict
-- Context interactions with the Phase 3 structures, hooked into the HUD's click / E / Act action:
-- open a chest, toggle a door, cook raw food at a lit fire or cooking station, repair a damaged tool at a
-- workbench. peek() gives the HUD the prompt ("Cook Raw Meat [E]", greyed with the reason when something is
-- missing); run() performs the intent. The server re-validates everything; this only picks and sends.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local Structures = require(Shared:WaitForChild("data"):WaitForChild("Structures"))
local Logic = Shared:WaitForChild("logic")
local Cooking = require(Logic:WaitForChild("Cooking"))
local Repair = require(Logic:WaitForChild("Repair"))
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))
local Feedback = require(script.Parent:WaitForChild("Feedback"))
local InventoryMirror =
	require(script.Parent.Parent:WaitForChild("Storage"):WaitForChild("InventoryMirror"))

local CueResolve = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("logic"):WaitForChild("CueResolve")
)
local P = HudConfig.Progression
local T = Structures.Tuning

-- gatherDistance/gatherAimed: the HUD's current gather target (nil = none), so a closer structure wins.
export type Ctx = { action: string, slot: number, gatherDistance: number?, gatherAimed: boolean? }
export type Prompt = { target: Instance, text: string, warn: boolean, label: string }
export type Api = {
	peek: (ctx: Ctx) -> Prompt?,
	run: (ctx: Ctx) -> boolean,
	destroy: () -> (),
}

type Interaction = {
	prompt: Prompt,
	distance: number,
	send: (() -> ())?, -- nil = informational / refused: run() only toasts `refusal`
	refusal: string?,
	feedbackAt: Vector3,
}

local StructureInteract = {}

local function pivot(i: Instance): Vector3?
	if i:IsA("BasePart") then
		return i.Position
	elseif i:IsA("Model") then
		return i:GetPivot().Position
	end
	return nil
end

function StructureInteract.new(
	mirror: InventoryMirror.Mirror,
	toast: (string) -> (),
	report: (string) -> ()
): Api
	local player = Players.LocalPlayer
	local inputHint = if game:GetService("UserInputService").TouchEnabled
			and not game:GetService("UserInputService").KeyboardEnabled
		then "[Act]"
		else "[E]"
	local destroyed = false

	local function rootPosition(): Vector3?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root.Position else nil
	end

	local function nearest(tag: string, from: Vector3, range: number): (Instance?, number)
		local best: Instance? = nil
		local bestDist = range
		for _, inst in CollectionService:GetTagged(tag) do
			local p = pivot(inst)
			if p then
				local d = (p - from).Magnitude
				if d <= bestDist then
					best, bestDist = inst, d
				end
			end
		end
		return best, bestDist
	end

	-- Cook: nearest working heat source for the selected raw food, else why not.
	local function cookInteraction(
		stack: InventoryMirror.Stack,
		slot: number,
		from: Vector3
	): Interaction?
		local def = ItemCatalog.Items[stack.id]
		if def == nil or Cooking.defFor(stack.id) == nil then
			return nil
		end
		local stationTag = Config.Craft.Stations[Config.Cooking.Station].Tag
		local station, stationDist = nearest(stationTag, from, Config.Cooking.StationRange)
		local fire: Instance? = nil
		local fireDist = Config.Fire.CookRadius
		local unlit: Instance? = nil
		for _, inst in CollectionService:GetTagged(Config.Fire.Tag) do
			local p = pivot(inst)
			if p and (p - from).Magnitude <= Config.Fire.CookRadius then
				if inst:GetAttribute(Config.Fire.LitAttribute) == true then
					if (p - from).Magnitude <= fireDist then
						fire, fireDist = inst, (p - from).Magnitude
					end
				else
					unlit = inst
				end
			end
		end
		local source = station
		local dist = stationDist
		if fire and (source == nil or fireDist < dist) then
			source, dist = fire, fireDist
		end
		if source == nil then
			if unlit then
				local p = pivot(unlit) or from
				return {
					prompt = {
						target = unlit,
						text = `Cook {def.name}: light the fire first`,
						warn = true,
						label = P.Labels.Cook,
					},
					distance = (p - from).Magnitude,
					refusal = "The fire is out. Add fuel first",
					feedbackAt = p,
				}
			end
			return nil -- no heat in reach: E eats it as before
		end
		local at = pivot(source) or from
		local ok, reason = Cooking.check(stack.id, source == fire, source == station)
		if not ok then
			return {
				prompt = {
					target = source,
					text = `Cook {def.name}: {if reason == "NeedStation"
						then "needs a cooking station"
						else "needs heat"}`,
					warn = true,
					label = P.Labels.Cook,
				},
				distance = dist,
				refusal = "That needs a cooking station",
				feedbackAt = at,
			}
		end
		local heat = source
		return {
			prompt = {
				target = source,
				text = `Cook {def.name} {inputHint}`,
				warn = false,
				label = P.Labels.Cook,
			},
			distance = dist,
			send = function()
				report("cookSent")
				Remotes.event(Remotes.CookRequest):FireServer({ slot = slot, station = heat })
			end,
			feedbackAt = at,
		}
	end

	local function repairInteraction(
		stack: InventoryMirror.Stack,
		slot: number,
		from: Vector3
	): Interaction?
		local def = ItemCatalog.Items[stack.id]
		if
			def == nil
			or not Repair.isRepairable(def)
			or Repair.check(def, stack.durability) ~= true
		then
			return nil
		end
		local station = Config.Craft.Stations[Config.Repair.Station]
		local bench, dist = nearest(station.Tag, from, station.Range)
		local cost = Repair.cost(def.id)
		if bench == nil or cost == nil then
			return nil
		end
		local at = pivot(bench) or from
		local pct = Repair.percent(def, stack.durability)
		if not Repair.canAfford(cost, mirror.counts()) then
			local need = Repair.costText(cost)
			return {
				prompt = {
					target = bench,
					text = `Repair {def.name}: needs {need}`,
					warn = true,
					label = P.Labels.Repair,
				},
				distance = dist,
				refusal = `Repair needs {need}`,
				feedbackAt = at,
			}
		end
		return {
			prompt = {
				target = bench,
				text = `Repair {def.name} ({pct}%): {Repair.costText(cost)} {inputHint}`,
				warn = false,
				label = P.Labels.Repair,
			},
			distance = dist,
			send = function()
				Remotes.event(Remotes.RepairRequest):FireServer({ slot = slot })
			end,
			feedbackAt = at,
		}
	end

	local function toggleDoor(door: Instance)
		Remotes.event(Remotes.DoorToggleRequest):FireServer({ door = door })
		-- Confirm from server state: the door's DoorOpen attribute flips.
		door:GetAttributeChangedSignal(Config.Build.DoorOpenAttribute):Once(function()
			report("doorToggled")
			-- sound hook: door toggled (docs/ART.md); silent until the audio pass
		end)
	end

	local function pick(ctx: Ctx): Interaction?
		-- Gather keeps priority only when its node is aimed at or closer than the structure; every other
		-- HUD-first action (attack, place, fuel) still wins.
		local gatherContest = ctx.action == "gather"
		if P.HudFirstActions[ctx.action] and not gatherContest then
			return nil
		end
		local from = rootPosition()
		if from == nil then
			return nil
		end
		local stack = mirror.slots()[ctx.slot]
		local def = if stack then ItemCatalog.Items[stack.id] else nil
		-- A selected food is eaten by E; only raw food next to heat turns into a cook.
		if def and def.kind == "food" then
			return cookInteraction(stack :: InventoryMirror.Stack, ctx.slot, from)
		end
		local best: Interaction? = nil
		local function consider(candidate: Interaction?)
			if candidate and (best == nil or candidate.distance < best.distance) then
				best = candidate
			end
		end
		local chest, chestDist = nearest(Config.Build.StorageTag, from, P.InteractRange)
		if chest then
			consider({
				prompt = {
					target = chest,
					text = `{P.Labels.OpenChest} {inputHint}`,
					warn = false,
					label = P.Labels.OpenChest,
				},
				distance = chestDist,
				send = function()
					Remotes.event(Remotes.StorageOpenRequest):FireServer({ chest = chest })
				end,
				feedbackAt = pivot(chest) or from,
			})
		end
		local door, doorDist = nearest(T.DoorTag, from, P.InteractRange)
		if door then
			local open = door:GetAttribute(Config.Build.DoorOpenAttribute) == true
			local label = if open then P.Labels.CloseDoor else P.Labels.OpenDoor
			consider({
				prompt = {
					target = door,
					text = `{label} {inputHint}`,
					warn = false,
					label = label,
				},
				distance = doorDist,
				send = function()
					toggleDoor(door)
				end,
				feedbackAt = pivot(door) or from,
			})
		end
		if stack then
			consider(repairInteraction(stack, ctx.slot, from))
		end
		local found = best :: Interaction?
		if
			gatherContest
			and found
			and not CueResolve.structureBeatsGather(
				ctx.gatherDistance,
				ctx.gatherAimed == true,
				found.distance
			)
		then
			return nil
		end
		return found
	end

	return {
		peek = function(ctx: Ctx): Prompt?
			local found = pick(ctx)
			return if found then found.prompt else nil
		end,
		run = function(ctx: Ctx): boolean
			if destroyed then
				return false
			end
			local found = pick(ctx)
			if found == nil then
				return false
			end
			if found.send then
				-- sound hook: structure interact sent (docs/ART.md); silent until the audio pass
				found.send()
			else
				Feedback.sound("DenySound", nil)
				toast(found.refusal or found.prompt.text)
			end
			return true
		end,
		destroy = function()
			destroyed = true
		end,
	}
end

return StructureInteract
