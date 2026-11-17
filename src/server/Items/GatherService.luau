--!strict
-- Resource nodes: tagged instances gated by tool tier, depleting after N hits, slow respawn.
-- Started by CraftingService.start() (init.server is not editable by this slice).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local ItemsGather = require(Shared.logic.ItemsGather)
local Guard = require(script.Parent.Parent.Net.Guard)
local InventoryService = require(script.Parent.InventoryService)

local GatherService = {}

type Saved = { part: BasePart, transparency: number, canCollide: boolean }
type NodeState = { saved: { Saved }, conn: RBXScriptConnection }

local nodes: { [Instance]: NodeState } = {}
local respawnAt: { [Instance]: number } = {}
local started = false

local function parts(node: Instance): { BasePart }
	local list: { BasePart } = {}
	if node:IsA("BasePart") then
		table.insert(list, node)
	end
	for _, d in node:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function nodePosition(node: Instance): Vector3?
	if node:IsA("BasePart") then
		return node.Position
	elseif node:IsA("Model") then
		return node:GetPivot().Position
	end
	return nil
end

local function unregister(node: Instance)
	local state = nodes[node]
	if state then
		state.conn:Disconnect()
		nodes[node] = nil
	end
	respawnAt[node] = nil
end

-- API for ChunkService: kind is "Tree" or "Rock". Safe to call once per node; re-registering is a no-op.
function GatherService.registerNode(node: Instance, kind: string): boolean
	if nodes[node] or ItemCatalog.Nodes[kind] == nil or nodePosition(node) == nil then
		return false
	end
	local saved: { Saved } = {}
	for _, p in parts(node) do
		table.insert(saved, { part = p, transparency = p.Transparency, canCollide = p.CanCollide })
	end
	node:SetAttribute(ItemCatalog.NodeKindAttribute, kind)
	node:SetAttribute(ItemCatalog.NodeHitsAttribute, Config.Gather.HitsToDeplete)
	node:SetAttribute(ItemCatalog.NodeDepletedAttribute, false)
	nodes[node] = {
		saved = saved,
		conn = node.Destroying:Connect(function()
			unregister(node)
		end),
	}
	CollectionService:AddTag(node, Config.Gather.NodeTag)
	return true
end

function GatherService.unregisterNode(node: Instance)
	unregister(node)
	CollectionService:RemoveTag(node, Config.Gather.NodeTag)
end

local function setDepleted(node: Instance, depleted: boolean)
	local state = nodes[node]
	if state == nil then
		return
	end
	for _, s in state.saved do
		s.part.Transparency = if depleted then 1 else s.transparency
		s.part.CanCollide = if depleted then false else s.canCollide
	end
	node:SetAttribute(ItemCatalog.NodeDepletedAttribute, depleted)
	if depleted then
		respawnAt[node] = os.clock() + Config.Gather.RespawnSeconds
	else
		respawnAt[node] = nil
		node:SetAttribute(ItemCatalog.NodeHitsAttribute, Config.Gather.HitsToDeplete)
	end
end

local function notify(player: Player, text: string)
	Remotes.event(Remotes.Notify):FireClient(player, "gather", text)
end

local function onGather(player: Player, node: unknown)
	-- 1. type-check
	if typeof(node) ~= "Instance" then
		return
	end
	local target = node :: Instance
	-- 2. sanity / range
	if
		nodes[target] == nil
		or target.Parent == nil
		or not CollectionService:HasTag(target, Config.Gather.NodeTag)
	then
		return
	end
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	local pos = nodePosition(target)
	if root == nil or not root:IsA("BasePart") or pos == nil then
		return
	end
	if (root.Position - pos).Magnitude > Config.Gather.Range then
		return
	end
	-- 3. rate limit
	if
		not Guard.rateLimit(
			player,
			"Gather",
			math.max(Config.Net.GatherRateInterval, Config.Gather.Cooldown)
		)
	then
		return
	end
	-- 4. state
	if target:GetAttribute(ItemCatalog.NodeDepletedAttribute) == true then
		return
	end
	local kind = target:GetAttribute(ItemCatalog.NodeKindAttribute)
	if type(kind) ~= "string" then
		return
	end
	local ok, reason = ItemsGather.canHarvest(kind, InventoryService.getSelected(player))
	if not ok then
		notify(
			player,
			if reason == "NoTool" then "You need a tool." else "That tool cannot harvest this."
		)
		return
	end
	-- 5. act
	local hits = (target:GetAttribute(ItemCatalog.NodeHitsAttribute) :: number?)
		or Config.Gather.HitsToDeplete
	hits -= 1
	InventoryService.wearSelected(player, Config.Gather.ToolDurabilityPerUse)
	if hits > 0 then
		target:SetAttribute(ItemCatalog.NodeHitsAttribute, hits)
		return
	end
	local def = ItemCatalog.Nodes[kind]
	local left = InventoryService.add(player, def.yieldId, def.yieldCount)
	if left > 0 then
		notify(player, "Inventory full.")
	end
	setDepleted(target, true)
end

function GatherService.start()
	if started then
		return
	end
	started = true
	Remotes.event(Remotes.GatherRequest).OnServerEvent:Connect(onGather)
	-- One loop for every node's respawn.
	RunService.Heartbeat:Connect(function()
		if next(respawnAt) == nil then
			return
		end
		local now = os.clock()
		for node, at in respawnAt do
			if now >= at then
				setDepleted(node, false)
			end
		end
	end)
end

return GatherService
