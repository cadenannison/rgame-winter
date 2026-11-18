--!strict
-- Points of interest inside streamed chunks: loot crates, cabin hearths, hot springs, thin ice.
-- ChunkService calls build() for each POI of a loaded chunk; state that must survive an unload
-- (looted, hearth fuel, broken ice) lives in `memory`, outside the chunk model. Owner: brief 13.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local BiomeLogic = require(Shared:WaitForChild("logic"):WaitForChild("BiomeLogic"))
local WorldLayout = require(Shared:WaitForChild("logic"):WaitForChild("WorldLayout"))
local World = require(Shared:WaitForChild("logic"):WaitForChild("World"))
local PoiPlan = require(Shared:WaitForChild("logic"):WaitForChild("PoiPlan"))
local Server = ServerScriptService:WaitForChild("Server")
local Guard = require(Server:WaitForChild("Net"):WaitForChild("Guard"))
local InventoryService = require(Server:WaitForChild("Items"):WaitForChild("InventoryService"))
local WorldArt = require(Server:WaitForChild("Art"):WaitForChild("WorldArt"))
local PoiStructures = require(Server:WaitForChild("World"):WaitForChild("PoiStructures"))

local TUNING = BiomeLogic.Tuning
local WARM = Config.WarmSpot
local POLL_INTERVAL = 0.25
local PROMPT_SLACK = 6 -- studs of server-side slack over the prompt's activation distance
local ICE_TAG = "ThinIce"
local ICE_HEIGHT = 0.15
local HEARTH_WOOD_ITEM = "Wood"
local CRATE_SIZE = Vector3.new(3, 2, 2)
local LCG_MOD = 4294967296
local LCG_MUL = 1664525
local LCG_ADD = 1013904223
local COLORS = {
	Wood = Color3.fromRGB(110, 78, 52),
	Dark = Color3.fromRGB(58, 54, 52),
	Stone = Color3.fromRGB(128, 132, 140),
	Metal = Color3.fromRGB(150, 156, 164),
	Tent = Color3.fromRGB(176, 102, 54),
	Crate = Color3.fromRGB(150, 118, 70),
	Spring = Color3.fromRGB(110, 190, 220),
	Ice = Color3.fromRGB(200, 232, 248),
	Water = Color3.fromRGB(28, 58, 88),
	HearthLit = Color3.fromRGB(230, 120, 40),
	HearthCold = Color3.fromRGB(70, 66, 64),
}

type Memory = { looted: boolean?, litUntil: number?, broken: { [number]: boolean }? }
type Hearth = { id: string, part: BasePart }
type Patch = {
	id: string,
	index: number,
	part: BasePart,
	radius: number,
	standing: { [Player]: number },
}

local PoiService = {}

local memory: { [string]: Memory } = {}
local hearths: { [BasePart]: Hearth } = {}
local patches: { [BasePart]: Patch } = {}
local breakCallbacks: { (Player) -> () } = {}
local heartbeatConn: RBXScriptConnection? = nil
local removingConn: RBXScriptConnection? = nil
local accumulator = 0
local worldSeed = 0
local woodItem = HEARTH_WOOD_ITEM

local function memoryFor(id: string): Memory
	local m = memory[id]
	if m == nil then
		m = {}
		memory[id] = m
	end
	return m
end

local function notify(player: Player, text: string)
	Remotes.event(Remotes.Notify):FireClient(player, "gather", text)
end

local function newRng(seed: number, a: number, b: number): () -> number
	local state = (seed * LCG_MUL + a * 7919 + b * 104729 + LCG_ADD) % LCG_MOD
	local function nextFloat(): number
		state = (state * LCG_MUL + LCG_ADD) % LCG_MOD
		return state / LCG_MOD
	end
	nextFloat()
	nextFloat()
	return nextFloat
end

local function slotOf(poi: WorldLayout.Poi): number
	return tonumber(string.match(poi.id, ":(%d+)$")) or 0
end

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function within(player: Player, part: BasePart): boolean
	local hrp = playerRoot(player)
	return hrp ~= nil
		and (hrp.Position - part.Position).Magnitude <= TUNING.LootPromptRange + PROMPT_SLACK
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.Color = color
	part.Material = material
	part.CanCollide = collide
	part.Parent = parent
	return part
end

local function addPrompt(
	parent: BasePart,
	action: string,
	object: string,
	hold: number
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = TUNING.LootPromptRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function lootText(items: { { id: string, count: number } }): string
	local parts: { string } = {}
	for _, item in items do
		table.insert(parts, `{item.count} {item.id}`)
	end
	return "Found " .. table.concat(parts, ", ")
end

local function buildCrate(
	parent: Instance,
	base: CFrame,
	offset: Vector3,
	poi: WorldLayout.Poi,
	chunkIndex: number
)
	local crate = block(
		parent,
		"LootCrate",
		CRATE_SIZE,
		base * CFrame.new(offset),
		COLORS.Crate,
		Enum.Material.Wood,
		true
	)
	crate:SetAttribute("PoiKind", poi.kind)
	local mem = memoryFor(poi.id)
	if mem.looted then
		crate:SetAttribute("Looted", true)
		crate.Color = COLORS.Dark
		return
	end
	local prompt = addPrompt(crate, "Search", "Supplies", 0.4)
	prompt.Triggered:Connect(function(player: Player)
		-- type/state/range/rate order: the engine hands us a real Player; the rest is checked here.
		if not Guard.rateLimit(player, "PoiLoot", Config.Net.UseRateInterval) then
			return
		end
		local m = memoryFor(poi.id)
		if m.looted or crate.Parent == nil or not within(player, crate) then
			return
		end
		local items = BiomeLogic.rollLoot(poi.lootTier, newRng(worldSeed, chunkIndex, slotOf(poi)))
		local added: { { id: string, count: number } } = {}
		m.looted = true
		for _, item in items do
			local left = InventoryService.add(player, item.id, item.count)
			if left < item.count then
				table.insert(added, { id = item.id, count = item.count - left })
			end
		end
		if #added == 0 then
			m.looted = false
			notify(player, "Inventory full")
			return
		end
		crate:SetAttribute("Looted", true)
		crate.Color = COLORS.Dark
		prompt.Enabled = false
		notify(player, lootText(added))
	end)
end

local function applyHearth(hearth: Hearth)
	local part = hearth.part
	local lit = (memoryFor(hearth.id).litUntil or 0) > os.clock()
	if part:GetAttribute("Lit") == lit then
		return
	end
	part:SetAttribute("Lit", lit)
	part.Color = if lit then COLORS.HearthLit else COLORS.HearthCold
	part.Material = if lit then Enum.Material.Neon else Enum.Material.Slate
	local fire = part:FindFirstChild("HearthFire")
	if fire and fire:IsA("Fire") then
		fire.Enabled = lit
	end
	local glow = part:FindFirstChild("HearthLight")
	if glow and glow:IsA("PointLight") then
		glow.Enabled = lit
	end
	if lit then
		CollectionService:AddTag(part, WARM.Tag)
	else
		CollectionService:RemoveTag(part, WARM.Tag)
	end
end

local function buildHearth(parent: Instance, base: CFrame, offset: Vector3, poi: WorldLayout.Poi)
	local part = block(
		parent,
		"Hearth",
		Vector3.new(3, 1.5, 3),
		base * CFrame.new(offset),
		COLORS.HearthCold,
		Enum.Material.Slate,
		true
	)
	part:SetAttribute(WARM.RadiusAttribute, WARM.CabinRadius)
	part:SetAttribute("WarmSpotKind", "Hearth")
	WorldArt.dressHearth(parent, base, offset, part)
	local hearth: Hearth = { id = poi.id, part = part }
	hearths[part] = hearth
	part.Destroying:Connect(function()
		hearths[part] = nil
	end)
	local prompt = addPrompt(part, "Add wood", "Hearth", 0)
	prompt.Triggered:Connect(function(player: Player)
		if not Guard.rateLimit(player, "PoiHearth", Config.Net.UseRateInterval) then
			return
		end
		if part.Parent == nil or not within(player, part) then
			return
		end
		if not InventoryService.remove(player, woodItem, 1) then
			notify(player, "You need wood for the hearth")
			return
		end
		local m = memoryFor(poi.id)
		m.litUntil = BiomeLogic.hearthAfterWood(m.litUntil or 0, os.clock())
		applyHearth(hearth)
	end)
	applyHearth(hearth)
end

local function buildSpring(parent: Instance, base: CFrame)
	local spring = block(
		parent,
		"HotSpring",
		Vector3.new(0.5, 16, 16),
		base * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2),
		COLORS.Spring,
		Enum.Material.Glass,
		false
	)
	spring.Shape = Enum.PartType.Cylinder
	spring.Transparency = 0.3
	spring:SetAttribute(WARM.RadiusAttribute, WARM.HotSpringRadius)
	spring:SetAttribute("WarmSpotKind", "HotSpring")
	CollectionService:AddTag(spring, WARM.Tag)
	WorldArt.dressSpring(spring)
	WorldArt.poi(parent, "hotspring", base)
end

local function breakPatch(patch: Patch)
	local mem = memoryFor(patch.id)
	local broken = mem.broken or {}
	mem.broken = broken
	broken[patch.index] = true
	for player in patch.standing do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:TakeDamage(TUNING.ThinIceDamage)
		end
		for _, cb in breakCallbacks do
			if not pcall(cb, player) then
				warn("[PoiService] thin ice callback failed")
			end
		end
	end
	table.clear(patch.standing)
	patches[patch.part] = nil
	patch.part:SetAttribute("Cracking", false)
	patch.part:SetAttribute("Broken", true)
	patch.part.Color = COLORS.Water
	patch.part.Transparency = 0.2
	CollectionService:RemoveTag(patch.part, ICE_TAG)
end

local function buildIce(
	parent: Instance,
	poi: WorldLayout.Poi,
	heightFn: (number, number) -> number
)
	local mem = memoryFor(poi.id)
	for index, pos in poi.patches do
		local r = TUNING.ThinIcePatchRadius
		local part = block(
			parent,
			"ThinIcePatch",
			Vector3.new(ICE_HEIGHT * 2, r * 2, r * 2),
			CFrame.new(pos.x, heightFn(pos.x, pos.z) + ICE_HEIGHT, pos.z)
				* CFrame.Angles(0, 0, math.pi / 2),
			COLORS.Ice,
			Enum.Material.Ice,
			false
		)
		part.Shape = Enum.PartType.Cylinder
		part.Transparency = 0.15
		part.CanQuery = false
		part:SetAttribute("Cracking", false)
		if mem.broken and mem.broken[index] then
			part:SetAttribute("Broken", true)
			part.Color = COLORS.Water
			part.Transparency = 0.2
		else
			CollectionService:AddTag(part, ICE_TAG)
			local patch: Patch =
				{ id = poi.id, index = index, part = part, radius = r, standing = {} }
			patches[part] = patch
			part.Destroying:Connect(function()
				patches[part] = nil
			end)
		end
	end
end

-- Terrain height closure for this world (camp is the flat centre).
local function heightFn(): (number, number) -> number
	local camp = Workspace:GetAttribute(Config.World.CampAttribute)
	local fx, fz = 0, 0
	if typeof(camp) == "Vector3" then
		fx, fz = camp.X, camp.Z
	end
	local seed = worldSeed
	return function(x: number, z: number): number
		return World.heightAt(seed, x, z, fx, fz)
	end
end

-- Builds one POI under `parent` (a chunk model). Everything is parented to the model, so unloading
-- the chunk destroys it; persistent state is in `memory`. Structures come from PoiPlan: the variant is a
-- deterministic pick from (seed, poi id, biome); the floor sits at the highest terrain under the footprint
-- over a foundation, entry steps bridge any drop, and the door faces the lowest ground.
function PoiService.build(parent: Instance, poi: WorldLayout.Poi, chunkIndex: number)
	local height = heightFn()
	if poi.kind == "thinice" then
		buildIce(parent, poi, height)
		return
	end
	local px, pz = poi.position.x, poi.position.z
	if poi.kind == "hotspring" then
		local y = height(px, pz)
		buildSpring(parent, CFrame.new(px, y, pz))
		return
	end
	local biome = World.biomeAt(px, pz)
	local variant = PoiPlan.pickVariant(worldSeed, poi.id, poi.kind, biome)
	local probe = PoiPlan.build(poi.kind, variant, 0, 0)
	if probe == nil then
		return
	end
	local floorY, minY =
		PoiPlan.siteFloor(height, px, pz, probe.radius - Config.Shelter.FootprintMargin)
	local pref = (chunkIndex * 37 + slotOf(poi) * 53) % 4
	local yawIndex = PoiPlan.chooseYaw(height, px, pz, probe.doorDistance, pref)
	local dx, dz = PoiPlan.doorDirection(yawIndex)
	local doorGround = height(px + dx * probe.doorDistance, pz + dz * probe.doorDistance)
	local plan =
		PoiPlan.build(poi.kind, variant, math.max(0, floorY - doorGround), floorY - minY + 1)
	if plan == nil then
		return
	end
	local base = CFrame.new(px, floorY, pz) * CFrame.Angles(0, yawIndex * math.pi / 2, 0)
	local model = PoiStructures.build(parent, plan, base)
	model:SetAttribute("Radius", plan.radius)
	if plan.legacy == "campsite" then
		WorldArt.poi(model, "campsite", base)
	end
	if plan.hearth then
		buildHearth(model, base, Vector3.new(plan.hearth.x, 0.75, plan.hearth.z), poi)
	end
	local c = plan.crate
	buildCrate(model, base, Vector3.new(c.x, c.y + 1, c.z), poi, chunkIndex)
end

local function step()
	for _, hearth in hearths do
		applyHearth(hearth)
	end
	if next(patches) == nil then
		return
	end
	local roots: { [Player]: BasePart } = {}
	for _, player in Players:GetPlayers() do
		local hrp = playerRoot(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hrp and humanoid and humanoid.Health > 0 then
			roots[player] = hrp
		end
	end
	for _, patch in table.clone(patches) do
		local center = patch.part.Position
		local any = false
		for player, hrp in roots do
			local dx, dz = hrp.Position.X - center.X, hrp.Position.Z - center.Z
			local onPatch = dx * dx + dz * dz <= patch.radius * patch.radius
				and hrp.Position.Y < center.Y + 6
			local seconds, broke =
				BiomeLogic.iceStep(patch.standing[player] or 0, onPatch, POLL_INTERVAL)
			if onPatch then
				patch.standing[player] = seconds
				any = true
			else
				patch.standing[player] = nil
			end
			if broke then
				patch.standing[player] = 1 -- keep the breaker in the damage list
				breakPatch(patch)
				break
			end
		end
		patch.part:SetAttribute("Cracking", any and patches[patch.part] ~= nil)
	end
end

function PoiService.onThinIceBreak(cb: (Player) -> ())
	table.insert(breakCallbacks, cb)
end

-- Brief 17 may rename the fuel item; nil-safe.
function PoiService.setHearthWoodItem(id: string?)
	woodItem = if id and id ~= "" then id else HEARTH_WOOD_ITEM
end

function PoiService.start(seed: number)
	worldSeed = seed
	if heartbeatConn then
		return
	end
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < POLL_INTERVAL then
			return
		end
		accumulator = 0
		step()
	end)
	removingConn = Players.PlayerRemoving:Connect(function(player)
		for _, patch in patches do
			patch.standing[player] = nil
		end
	end)
end

function PoiService.stop()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	if removingConn then
		removingConn:Disconnect()
		removingConn = nil
	end
	table.clear(memory)
	table.clear(hearths)
	table.clear(patches)
end

return PoiService
