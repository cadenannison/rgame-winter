--!strict
-- Resource nodes: tagged instances gated by tool tier, depleting after N hits, slow respawn.
-- Started by CraftingService.start(). ChunkService registers tree/rock slots via registerNode.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local InventoryMove = require(Shared.logic.InventoryMove)
local ItemsGather = require(Shared.logic.ItemsGather)
local TreeRules = require(Shared.logic.TreeRules)
local Guard = require(script.Parent.Parent.Net.Guard)
local SwingRelay = require(script.Parent.Parent.Atmosphere.SwingRelay)
local InventoryService = require(script.Parent.InventoryService)

local GatherService = {}

local HIT_EPSILON = 1e-6 -- float slack when fractional hits (better tools) reach zero

type Saved = { part: BasePart, transparency: number, canCollide: boolean }
type NodeState = { saved: { Saved }, conn: RBXScriptConnection }

local nodes: { [Instance]: NodeState } = {}
local respawnAt: { [Instance]: number } = {}
-- Managed nodes (forage round): ForageService owns their lifecycle; the hook runs instead of the timed respawn
-- when the node is used up (player, node, item id, items granted).
local managed: { [Instance]: (Player, Instance, string, number) -> () } = {}
local started = false
-- Wiring (Phase 4 gatherSpeed perk): extra whole items for a harvest (player, base count) -> extra >= 0.
local yieldBonusProvider: ((Player, number) -> number)? = nil

function GatherService.setYieldBonusProvider(fn: ((Player, number) -> number)?)
	yieldBonusProvider = fn
end

local function bonusYield(player: Player, base: number): number
	local provider = yieldBonusProvider
	if not provider then
		return 0
	end
	local ok, extra = pcall(provider, player, base)
	if not ok or type(extra) ~= "number" or extra ~= extra then
		return 0
	end
	return math.clamp(math.floor(extra), 0, base)
end

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
	managed[node] = nil
end

-- Forage round: marks a registered node as managed (see `managed`). Cleared by unregisterNode.
function GatherService.setManaged(
	node: Instance,
	onDepleted: (Player, Instance, string, number) -> ()
)
	if nodes[node] then
		managed[node] = onDepleted
	end
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
	node:SetAttribute(ItemCatalog.NodeHitsAttribute, ItemsGather.baseHits(kind))
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
		local kind = node:GetAttribute(ItemCatalog.NodeKindAttribute)
		node:SetAttribute(
			ItemCatalog.NodeHitsAttribute,
			if type(kind) == "string"
				then ItemsGather.baseHits(kind)
				else Config.Gather.HitsToDeplete
		)
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
	-- Reach is measured to the node's surface (trunk radius), so giant trees can be chopped from the ground.
	local reach = (root.Position - pos).Magnitude
	if target:IsA("BasePart") then
		reach = TreeRules.reachDistance(
			root.Position.X - pos.X,
			root.Position.Z - pos.Z,
			root.Position.Y - pos.Y,
			math.max(target.Size.X, target.Size.Z) / 2,
			target.Size.Y / 2
		)
	end
	if reach > Config.Gather.Range then
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
	local ok = ItemsGather.canHarvest(kind, InventoryService.getSelected(player))
	if not ok then
		local nodeDef = ItemCatalog.Nodes[kind]
		local tool = nodeDef and ItemCatalog.Items[nodeDef.toolId]
		notify(
			player,
			if nodeDef and tool
				then `{nodeDef.verb}: needs {tool.name}`
				else "That tool cannot harvest this."
		)
		return
	end
	-- 5. act
	SwingRelay.notify(player) -- accepted swing: other clients animate it
	-- Effort comes from Config.Gather.Effort by node kind; a better tool removes more of the node per hit.
	local selected = InventoryService.getSelected(player)
	local selectedDef = if selected then ItemCatalog.Items[selected.id] else nil
	local toolTier = if selectedDef and selectedDef.toolTier then selectedDef.toolTier else 0
	local hits = (target:GetAttribute(ItemCatalog.NodeHitsAttribute) :: number?)
		or ItemsGather.baseHits(kind)
	hits -= ItemsGather.hitDamage(kind, toolTier)
	if hits < HIT_EPSILON then
		hits = 0
	end
	local nodeYield = ItemCatalog.Nodes[kind]
	local pickCount = target:GetAttribute(Config.Forage.CountAttribute)
	local yieldCount = if type(pickCount) == "number" and pickCount >= 1
		then math.floor(pickCount)
		else nodeYield.yieldCount
	if hits <= 0 and not InventoryService.canAdd(player, nodeYield.yieldId, yieldCount) then
		notify(player, InventoryMove.FullText) -- the last hit waits until there is room (nothing is lost)
		return
	end
	if nodeYield.toolType ~= "hand" then
		InventoryService.wearSelected(player, Config.Gather.ToolDurabilityPerUse)
	end
	if hits > 0 then
		target:SetAttribute(ItemCatalog.NodeHitsAttribute, hits)
		return
	end
	local def = ItemCatalog.Nodes[kind]
	local grant = yieldCount + bonusYield(player, yieldCount)
	local left = InventoryService.add(player, def.yieldId, grant)
	if left > 0 then
		notify(player, InventoryMove.FullText)
	end
	local hook = managed[target]
	if hook then
		hook(player, target, def.yieldId, grant - left)
	else
		setDepleted(target, true)
	end
end

-- Same path as GatherRequest (QA and server callers); runs the full validation.
GatherService.handleGather = onGather

function GatherService.start()
	if started then
		return
	end
	started = true
	Remotes.event(Remotes.GatherRequest).OnServerEvent:Connect(onGather)
	-- Lazy require: ForageService needs ChunkService, which itself requires this module at load.
	local ok, forage = pcall(require, script.Parent.Parent.Forage.ForageService)
	if ok then
		(forage :: any).start()
	else
		warn("GatherService: ForageService failed to load")
	end
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
