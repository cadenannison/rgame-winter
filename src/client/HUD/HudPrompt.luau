--!strict
-- HUD prompt text for the current context: what the hovered/nearest target offers (fuel, craft, upgrade,
-- gather, hunt) as (target, text, progress, warn). Pure function of the state HudController passes in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local Logic = Shared:WaitForChild("logic")
local FireTiers = require(Logic:WaitForChild("FireTiers"))
local ItemsGather = require(Logic:WaitForChild("ItemsGather"))
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))

export type Args = {
	action: string,
	interact: { target: Instance, text: string, warn: boolean }?, -- structure hook prompt (wins when set)
	inputHint: string,
	counts: { [string]: number },
	shownStack: { id: string, count: number }?, -- stack in the shown hotbar slot
	targetKind: string,
	targetInstance: Instance?,
	fireInstance: Instance?,
	benchInstance: Instance?,
	upgradableFire: () -> Instance?,
	itemName: (id: string) -> string,
}

local HudPrompt = {}

function HudPrompt.compute(a: Args): (Instance?, string, number?, boolean)
	local action = a.action
	local interact = a.interact
	if interact then
		return interact.target, interact.text, nil, interact.warn
	end
	if action == "fuel" and a.fireInstance then
		return a.fireInstance, `Add wood {a.inputHint}`, nil, false
	end
	if action == "craft" and a.benchInstance then
		return a.benchInstance, `Craft {a.inputHint}`, nil, false
	elseif action == "upgrade" then
		local fire = a.upgradableFire()
		local cost = if fire
			then FireTiers.nextCost(FireTiers.clamp(fire:GetAttribute(Config.Fire.TierAttribute)))
			else nil
		if fire and cost then
			local affordable = FireTiers.canAfford(a.counts, cost)
			return fire,
				`Upgrade fire ({FireTiers.costText(cost, a.itemName)}) {a.inputHint}`,
				nil,
				not affordable
		end
	end
	local target = a.targetInstance
	if target == nil then
		return nil, "", nil, false
	end
	if a.targetKind == "gather" then
		local kind = target:GetAttribute(ItemCatalog.NodeKindAttribute)
		local node = if type(kind) == "string" then ItemCatalog.Nodes[kind] else nil
		if node == nil then
			return nil, "", nil, false
		end
		local hits = target:GetAttribute(ItemCatalog.NodeHitsAttribute)
		local progress = if type(hits) == "number" then hits / Config.Gather.HitsToDeplete else nil
		local stack = a.shownStack
		local ok = ItemsGather.canHarvest(
			node.kind,
			if stack then { id = stack.id, count = stack.count } else nil
		)
		local tool = ItemCatalog.Items[node.toolId]
		if ok then
			return target, `{node.verb} {a.inputHint}`, progress, false
		end
		return target,
			`{node.verb}: needs {if tool then tool.name else node.toolId}`,
			progress,
			true
	elseif a.targetKind == "attack" then
		local hp = target:GetAttribute(Config.Mobs.HealthAttribute)
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		local progress = if type(hp) == "number"
				and humanoid
				and humanoid.MaxHealth > 0
			then hp / humanoid.MaxHealth
			else nil
		local name = HudConfig.MobNames[target.Name] or target.Name
		return target, `Hunt {name} {a.inputHint}`, progress, false
	end
	return nil, "", nil, false
end

return HudPrompt
