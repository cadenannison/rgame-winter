--!strict
-- Horror adapter: nil-safe providers (party, fires, warm spots, events, lights, camp) and a per-tick party
-- snapshot shared by DreadService, StalkerService and LurkerService. Brief 18 wires the providers; until
-- then tag-based defaults read Campfire/WarmSpot tags and visible Workspace attributes.
-- Everything here is server-only. Nothing is written to Attributes or printed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DreadLogic = require(Shared.logic.DreadLogic)
local Isolation = require(Shared.logic.Isolation)
local CreatureRegistry = require(Shared.Creatures.Registry)
local SurvivalService = require(script.Parent.Parent.Survival.SurvivalService)

export type Repeller = DreadLogic.Repeller
export type Light = DreadLogic.Light
export type EventModifiers = {
	dreadGain: number, -- 1 = none (capped by Events.MaxDreadGainMultiplier in DreadLogic)
	huntBonus: number, -- 0 = none (capped by Events.MaxHuntChanceBonus in DreadLogic)
	nightRules: boolean, -- false night: counts as dark
}

export type Member = {
	player: Player,
	root: BasePart,
	x: number,
	z: number,
	warm: boolean, -- inside a lit fire radius or warm spot
	downed: boolean,
	ring: number,
	light: Light,
}

export type Snapshot = {
	members: { Member }, -- living members with a character
	weights: { number }, -- Isolation weight per member (server-only)
	fullGroup: boolean,
	partySize: number,
	warmZones: { Repeller }, -- lit fires + warm spots (raw radii)
	day: number,
	dark: boolean,
	blizzard: boolean,
	modifiers: EventModifiers,
	farFromCamp: boolean,
}

local HorrorWorld = {}

local partyProvider: (() -> { Player })? = nil
local fireProvider: (() -> { Repeller })? = nil
local warmSpotProvider: (() -> { Repeller })? = nil
local eventProvider: (() -> EventModifiers?)? = nil
local lightProvider: ((Player) -> Light)? = nil
local campProvider: (() -> Vector3?)? = nil

local NO_MODIFIERS: EventModifiers = { dreadGain = 1, huntBonus = 0, nightRules = false }

-- Providers (nil restores the default). All are pcall'd: a failing provider falls back to the default.
function HorrorWorld.setPartyProvider(fn: (() -> { Player })?)
	partyProvider = fn
end
function HorrorWorld.setFireProvider(fn: (() -> { Repeller })?)
	fireProvider = fn
end
function HorrorWorld.setWarmSpotProvider(fn: (() -> { Repeller })?)
	warmSpotProvider = fn
end
function HorrorWorld.setEventProvider(fn: (() -> EventModifiers?)?)
	eventProvider = fn
end
function HorrorWorld.setLightProvider(fn: ((Player) -> Light)?)
	lightProvider = fn
end
function HorrorWorld.setCampProvider(fn: (() -> Vector3?)?)
	campProvider = fn
end

local function call<T>(fn: (() -> T)?, fallback: () -> T): T
	if fn then
		local ok, result = pcall(fn)
		if ok and result ~= nil then
			return result
		end
	end
	return fallback()
end

local function pivotOf(inst: Instance): Vector3?
	if inst:IsA("Model") then
		return inst:GetPivot().Position
	elseif inst:IsA("BasePart") then
		return inst.Position
	end
	return nil
end

local function defaultFires(): { Repeller }
	local out: { Repeller } = {}
	for _, fire in CollectionService:GetTagged(Config.Fire.Tag) do
		if
			fire:GetAttribute(Config.Fire.LitAttribute) == true and fire:IsDescendantOf(Workspace)
		then
			local p = pivotOf(fire)
			local radius = fire:GetAttribute(Config.Fire.WarmRadiusAttribute)
			if p then
				table.insert(out, {
					x = p.X,
					z = p.Z,
					radius = if type(radius) == "number" then radius else Config.Fire.WarmRadius,
				})
			end
		end
	end
	return out
end

local function defaultWarmSpots(): { Repeller }
	local out: { Repeller } = {}
	for _, spot in CollectionService:GetTagged(Config.WarmSpot.Tag) do
		if spot:IsDescendantOf(Workspace) then
			local p = pivotOf(spot)
			local radius = spot:GetAttribute(Config.WarmSpot.RadiusAttribute)
			if p and type(radius) == "number" and radius > 0 then
				table.insert(out, { x = p.X, z = p.Z, radius = radius })
			end
		end
	end
	return out
end

function HorrorWorld.party(): { Player }
	return call(partyProvider, function()
		return Players:GetPlayers()
	end)
end

function HorrorWorld.fires(): { Repeller }
	return call(fireProvider, defaultFires)
end

-- Lit fires and warm spots together (raw radii).
function HorrorWorld.warmZones(): { Repeller }
	local out = table.clone(HorrorWorld.fires())
	for _, spot in call(warmSpotProvider, defaultWarmSpots) do
		table.insert(out, spot)
	end
	return out
end

function HorrorWorld.modifiers(): EventModifiers
	local m = call(eventProvider, function()
		return NO_MODIFIERS
	end)
	return {
		dreadGain = if type(m.dreadGain) == "number" then m.dreadGain else 1,
		huntBonus = if type(m.huntBonus) == "number" then m.huntBonus else 0,
		nightRules = m.nightRules == true,
	}
end

function HorrorWorld.lightOf(player: Player): Light
	if lightProvider then
		local ok, light = pcall(lightProvider, player)
		if ok and (light == "torch" or light == "flare") then
			return light
		end
	end
	return "none"
end

function HorrorWorld.rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = (character :: Model):FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function HorrorWorld.day(): number
	local day = Workspace:GetAttribute(Config.Time.DayAttribute)
	return if type(day) == "number" then day else 1
end

-- Ground point under (x, z), ignoring characters and the given folder.
function HorrorWorld.groundAt(x: number, z: number, originY: number, ignore: Instance?): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if ignore then
		table.insert(exclude, ignore)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(
		Vector3.new(x, originY + Config.Mobs.SpawnRayHeight, z),
		Vector3.new(0, -Config.Mobs.SpawnRayLength, 0),
		params
	)
	return if hit then hit.Position else nil
end

local FOLDER_NAME = "Horror"
local folder: Folder? = nil

-- Workspace folder for Stalker/lurker placeholder models (created on demand, destroyed by clearFolder).
function HorrorWorld.folder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	folder = created
	return created
end

function HorrorWorld.clearFolder()
	if folder then
		folder:Destroy()
		folder = nil
	end
end

export type Visual = {
	size: { number },
	color: { number },
	transparency: number,
	glow: boolean?,
}

-- One-part placeholder model (anchored, no collision, no query: nothing can hit or damage it), tagged.
function HorrorWorld.makeModel(name: string, visual: Visual, tag: string, at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = name
	local part = Instance.new("Part")
	part.Name = "Body"
	part.Size = Vector3.new(visual.size[1], visual.size[2], visual.size[3])
	part.Color = Color3.fromRGB(visual.color[1], visual.color[2], visual.color[3])
	part.Transparency = visual.transparency
	part.Material = if visual.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.CFrame = CFrame.new(at + Vector3.new(0, visual.size[2] / 2, 0))
	part.Parent = model
	model.PrimaryPart = part
	CollectionService:AddTag(model, tag)
	CreatureRegistry.attach(name, part) -- art pass 3: Stalker / lurker rigs (0 parts for unknown names)
	model.Parent = HorrorWorld.folder()
	return model
end

-- Builds the party snapshot. Call at most once per Dread tick and share the result.
function HorrorWorld.snapshot(): Snapshot
	local party = HorrorWorld.party()
	local zones = HorrorWorld.warmZones()
	local camp = call(campProvider, function(): Vector3?
		return nil
	end)
	local fires = HorrorWorld.fires()
	local members: { Member } = {}
	local points: { Isolation.Point } = {}
	local farFromCamp = false
	local far2 = Config.Dread.FarFromCampDistance ^ 2
	for _, player in party do
		local root = HorrorWorld.rootOf(player)
		if root and player.Parent == Players then
			local pos = root.Position
			local ring = player:GetAttribute(Config.Biome.RingAttribute)
			local member: Member = {
				player = player,
				root = root,
				x = pos.X,
				z = pos.Z,
				warm = DreadLogic.isInside(pos.X, pos.Z, zones, 0),
				downed = SurvivalService.isDowned(player),
				ring = if type(ring) == "number" then ring else 0,
				light = HorrorWorld.lightOf(player),
			}
			table.insert(members, member)
			table.insert(points, { x = pos.X, z = pos.Z })
			-- Far from camp: beyond the distance from the camp point, or from every lit fire by default.
			if camp then
				if (pos.X - camp.X) ^ 2 + (pos.Z - camp.Z) ^ 2 > far2 then
					farFromCamp = true
				end
			else
				local near = false
				for _, f in fires do
					if (pos.X - f.x) ^ 2 + (pos.Z - f.z) ^ 2 <= far2 then
						near = true
						break
					end
				end
				farFromCamp = farFromCamp or not near
			end
		end
	end
	local modifiers = HorrorWorld.modifiers()
	return {
		members = members,
		weights = Isolation.weights(points, #party),
		fullGroup = Isolation.fullGroup(points) and #points == #party,
		partySize = #party,
		warmZones = zones,
		day = HorrorWorld.day(),
		dark = Workspace:GetAttribute(Config.Time.IsNightAttribute) == true or modifiers.nightRules,
		blizzard = Workspace:GetAttribute(Config.Blizzard.ActiveAttribute) == true,
		modifiers = modifiers,
		farFromCamp = farFromCamp,
	}
end

return HorrorWorld
