--!strict
-- Single-loop client driver for procedural creature animation (Art Pass 3). Every model tagged
-- Config.Creatures.Tag gets an AnimKit binding the first time it is inside AnimRadius of the camera.
-- Selection (nearest MaxAnimated within AnimRadius) runs a few times a second; the per-frame loop only steps
-- the selected set: near tier every frame, far tier at AnimHz. Creatures outside keep their last pose (no cost).
-- Client-side Hurt: a MobHealth drop flinches immediately. start() is idempotent and never yields.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Registry = require(Shared:WaitForChild("Creatures"):WaitForChild("Registry"))
local AnimKit = require(Shared:WaitForChild("Creatures"):WaitForChild("AnimKit"))
local Types = require(Shared:WaitForChild("Creatures"):WaitForChild("Types"))

local CFG = Config.Creatures
local HEALTH_ATTRIBUTE = Config.Mobs.HealthAttribute
local SELECT_INTERVAL = 0.25 -- seconds between nearest-N selections

type Entry = {
	model: Model,
	root: BasePart?,
	binding: Types.Binding?,
	rig: Types.RigSpec?,
	conns: { RBXScriptConnection },
	dist: number,
	active: boolean,
	acc: number,
	health: number,
}

local CreatureAnim = {}

local started = false
local entries: { [Model]: Entry } = {}
local ordered: { Entry } = {}
local active: { Entry } = {}
local selectClock = 0

local function rootOf(model: Model): BasePart?
	local r = model.PrimaryPart
	if r then
		return r
	end
	local c = model:FindFirstChild("HumanoidRootPart")
	if c and c:IsA("BasePart") then
		return c
	end
	return nil
end

local function removeEntry(model: Model)
	local e = entries[model]
	if not e then
		return
	end
	entries[model] = nil
	for _, c in e.conns do
		c:Disconnect()
	end
	if e.binding then
		e.binding.unbind()
		e.binding = nil
	end
	local i = table.find(ordered, e)
	if i then
		table.remove(ordered, i)
	end
	local j = table.find(active, e)
	if j then
		table.remove(active, j)
	end
end

local function addEntry(inst: Instance)
	if not inst:IsA("Model") or entries[inst] then
		return
	end
	local model = inst
	local h = model:GetAttribute(HEALTH_ATTRIBUTE)
	local e: Entry = {
		model = model,
		root = rootOf(model),
		binding = nil,
		rig = nil,
		conns = {},
		dist = math.huge,
		active = false,
		acc = 0,
		health = if type(h) == "number" then h else 0,
	}
	entries[model] = e
	table.insert(ordered, e)
	table.insert(
		e.conns,
		model:GetAttributeChangedSignal(HEALTH_ATTRIBUTE):Connect(function()
			local v = model:GetAttribute(HEALTH_ATTRIBUTE)
			if type(v) ~= "number" then
				return
			end
			if v < e.health and v > 0 and e.binding then
				e.binding.hurt()
			end
			e.health = v
		end)
	)
	table.insert(
		e.conns,
		model.Destroying:Connect(function()
			removeEntry(model)
		end)
	)
end

local function ensureBinding(e: Entry)
	if e.binding then
		return
	end
	local kind = e.model:GetAttribute(CFG.KindAttribute)
	if type(kind) ~= "string" then
		return
	end
	local def = Registry.get(kind)
	if not def then
		return
	end
	e.rig = def.rig
	e.binding = AnimKit.bind(e.model, def.rig)
end

local function sortNearest(a: Entry, b: Entry): boolean
	return a.dist < b.dist
end

local function selectActive(camPos: Vector3)
	for _, e in ordered do
		if not e.root or not e.root.Parent then
			e.root = rootOf(e.model)
		end
		local r = e.root
		e.dist = if r then (r.Position - camPos).Magnitude else math.huge
	end
	table.sort(ordered, sortNearest)
	table.clear(active)
	for _, e in ordered do
		if e.dist <= CFG.AnimRadius and #active < CFG.MaxAnimated then
			ensureBinding(e)
			if e.binding then
				e.active = true
				table.insert(active, e)
			else
				e.active = false
			end
		else
			e.active = false
		end
	end
end

local function onFrame(dt: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	selectClock += dt
	if selectClock >= SELECT_INTERVAL then
		selectClock = 0
		selectActive(cam.CFrame.Position)
	end
	local farStep = 1 / CFG.AnimHz
	for _, e in active do
		local b = e.binding
		if b then
			if e.dist <= CFG.NearRadius then
				b.step(dt + e.acc)
				e.acc = 0
			else
				e.acc += dt
				if e.acc >= farStep then
					b.step(e.acc)
					e.acc = 0
				end
			end
		end
	end
end

function CreatureAnim.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(CFG.Tag):Connect(addEntry)
	CollectionService:GetInstanceRemovedSignal(CFG.Tag):Connect(function(inst: Instance)
		if inst:IsA("Model") then
			removeEntry(inst)
		end
	end)
	for _, inst in CollectionService:GetTagged(CFG.Tag) do
		addEntry(inst)
	end
	RunService.RenderStepped:Connect(onFrame)
end

return CreatureAnim
