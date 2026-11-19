--!strict
-- Client chest effects. One RenderStepped loop for every LootChest: only chests near the camera (and under
-- ChestStyle.Budget.MaxEffectChests) get a PointLight + ParticleEmitter and a glow pulse, all driven by the
-- ChestRarity / LootOpened Attributes. Opened chests lose their effects and play one burst + sound hook.
-- The server builds the parts (server/Art/ChestArt); nothing here is trusted or sent to the server.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Assets = require(Shared:WaitForChild("Assets"))
local ChestStyle = require(Shared:WaitForChild("logic"):WaitForChild("ChestStyle"))

local L = Config.Loot
local A = Config.ArtStructures
local B = ChestStyle.Budget

local PARTICLE_TEXTURE_KEY = "ChestParticle" -- Assets hook; engine sparkles when absent
local ENGINE_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local PARTICLE_SIZE = 0.5
local SOUND_VOLUME = 0.7
local SOUND_LIFETIME = 4
local BURST_LIFETIME_PAD = 0.5
local BURST_SPEED = 8
local BEAM_REFRESH_SECONDS = 0.1 -- beam distance fade update interval
local GLOW_REACH_FRACTION = 0.5 -- speed * lifetime as a fraction of ChestGlowMaxStuds
local GLOW_RING_RADIUS = 0.8 -- studs: emitter points spread on a small ring over the chest
local GLOW_LIFT = 0.2
local BEAM_FOLDER_NAME = "ChestBeams"
local BEAM_BASE_LIFT = 1 -- beam starts at the chest top (half body height)

type Rec = {
	model: Model,
	rarity: string,
	style: ChestStyle.Style,
	opened: boolean,
	active: boolean,
	light: PointLight?,
	emitters: { ParticleEmitter },
	beam: BasePart?,
	conn: RBXScriptConnection?,
}

local ChestVisuals = {}

local dropBeam: (rec: Rec) -> () -- defined with the beam code below

local recs: { [Model]: Rec } = {}
local connections: { RBXScriptConnection } = {}
local started = false

local function baseOf(rec: Rec): BasePart?
	local base = rec.model.PrimaryPart or rec.model:FindFirstChild("Base")
	if base and base:IsA("BasePart") then
		return base
	end
	return nil
end

local function toColor(c: { number }?): Color3
	local v = c or { 255, 255, 255 }
	return Color3.fromRGB(v[1], v[2], v[3])
end

local function textureId(): string
	local id = (Assets :: { [string]: string })[PARTICLE_TEXTURE_KEY]
	if id and id ~= "" then
		return id
	end
	return ENGINE_SPARKLE
end

-- Small glow emitter: a tiny attachment on top of the chest; particles never travel further than
-- ArtStructures.ChestGlowMaxStuds from the chest (speed * lifetime is capped to half of that).
local function makeEmitter(rec: Rec, base: BasePart, rate: number, offset: Vector3): ParticleEmitter
	local lifetime = math.max(rec.style.particleLifetime, 0.5)
	local attachment = Instance.new("Attachment")
	attachment.Name = "ChestGlowPoint"
	attachment.Position = offset
	attachment.Parent = base
	local e = Instance.new("ParticleEmitter")
	e.Texture = textureId()
	e.Color = ColorSequence.new(toColor(rec.style.glowColor))
	e.LightEmission = 1
	e.Size = NumberSequence.new(PARTICLE_SIZE)
	e.Lifetime = NumberRange.new(lifetime)
	local speed = A.ChestGlowMaxStuds * GLOW_REACH_FRACTION / lifetime
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = math.min(rate, B.MaxParticleRate)
	e.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = attachment
	return e
end

local function deactivate(rec: Rec)
	rec.active = false
	if rec.light then
		rec.light:Destroy()
		rec.light = nil
	end
	for _, e in rec.emitters do
		local holder = e.Parent
		e:Destroy()
		if holder and holder:IsA("Attachment") then
			holder:Destroy()
		end
	end
	table.clear(rec.emitters)
end

local function activate(rec: Rec, base: BasePart)
	rec.active = true
	if rec.style.lightRange > 0 and rec.light == nil then
		local light = Instance.new("PointLight")
		light.Color = toColor(rec.style.glowColor)
		light.Range = math.min(rec.style.lightRange, B.MaxLightRange)
		light.Brightness = math.min(rec.style.lightBrightness, B.MaxLightBrightness)
		light.Shadows = false
		light.Parent = base
		rec.light = light
	end
	local count = math.min(rec.style.glowEmitters, A.ChestGlowEmitters)
	if count > 0 and rec.style.particleRate > 0 and #rec.emitters == 0 then
		local rate = rec.style.particleRate / count
		for i = 1, count do
			local angle = (i - 1) / count * math.pi * 2
			local offset = Vector3.new(
				math.cos(angle) * GLOW_RING_RADIUS,
				base.Size.Y / 2 + GLOW_LIFT,
				math.sin(angle) * GLOW_RING_RADIUS
			)
			table.insert(rec.emitters, makeEmitter(rec, base, rate, offset))
		end
	end
end

local function playOpenSound(rec: Rec, base: BasePart)
	local id = (Assets :: { [string]: string })[rec.style.soundKey]
	if not id or id == "" then
		return -- hook only: silent until the id is supplied in shared/Assets
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = SOUND_VOLUME
	sound.RollOffMaxDistance = B.EffectRadius
	sound.Parent = base
	sound:Play()
	Debris:AddItem(sound, SOUND_LIFETIME)
end

local function onOpened(rec: Rec)
	if rec.opened then
		return
	end
	rec.opened = true
	local base = baseOf(rec)
	deactivate(rec)
	if not base then
		return
	end
	local cam = Workspace.CurrentCamera
	if cam and (cam.CFrame.Position - base.Position).Magnitude > B.EffectRadius then
		return
	end
	playOpenSound(rec, base)
	if rec.style.burstCount > 0 then
		local e = makeEmitter(rec, base, 0, Vector3.new(0, base.Size.Y / 2 + GLOW_LIFT, 0))
		e.Speed = NumberRange.new(BURST_SPEED)
		e:Emit(rec.style.burstCount)
		Debris:AddItem(e, rec.style.particleLifetime + BURST_LIFETIME_PAD)
		if e.Parent then
			Debris:AddItem(e.Parent, rec.style.particleLifetime + BURST_LIFETIME_PAD)
		end
	end
end

local function untrack(model: Instance)
	local rec = recs[model :: Model]
	if rec then
		deactivate(rec)
		dropBeam(rec)
		if rec.conn then
			rec.conn:Disconnect()
		end
		recs[model :: Model] = nil
	end
end

local function track(inst: Instance)
	if not inst:IsA("Model") or recs[inst] then
		return
	end
	local rarityAttr = inst:GetAttribute(L.ChestRarityAttribute)
	local rarity = if type(rarityAttr) == "string" then rarityAttr else "common"
	local rec: Rec = {
		model = inst,
		rarity = rarity,
		style = ChestStyle.get(rarity),
		opened = inst:GetAttribute(L.ChestOpenedAttribute) == true,
		active = false,
		light = nil,
		emitters = {},
		beam = nil,
		conn = nil,
	}
	rec.conn = inst:GetAttributeChangedSignal(L.ChestOpenedAttribute):Connect(function()
		if inst:GetAttribute(L.ChestOpenedAttribute) == true then
			onOpened(rec)
		end
	end)
	recs[inst] = rec
end

local function pulseActive(t: number)
	for _, rec in recs do
		if rec.active and not rec.opened then
			local gem = rec.model:FindFirstChild("Gem")
			if gem and gem:IsA("BasePart") then
				gem.Transparency = ChestStyle.pulse(rec.style, t)
			end
		end
	end
end

-- Beams (rare+, short, client side only): the part is created locally for the nearest chests within
-- ArtStructures.BeamNearStuds of the local player, at most Beam.MaxActive, and destroyed when out of range or
-- opened. It never exists on the server and never rotates (fixed upright column). One pass for every chest.
local beamFolder: Folder? = nil

local function beamParent(): Instance?
	local existing = beamFolder
	if existing and existing.Parent then
		return existing
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = BEAM_FOLDER_NAME
	folder.Parent = cam
	beamFolder = folder
	return folder
end

function dropBeam(rec: Rec)
	if rec.beam then
		rec.beam:Destroy()
		rec.beam = nil
	end
end

local function localOrigin(): Vector3?
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else nil
end

local function makeBeam(rec: Rec, base: BasePart, parent: Instance): BasePart
	local height = math.min(rec.style.beamHeight, A.BeamMaxStuds, L.Beam.MaxHeight)
	local part = Instance.new("Part")
	part.Name = "LocalBeam"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = toColor(rec.style.glowColor)
	part.Size = Vector3.new(rec.style.beamWidth, height, rec.style.beamWidth)
	part.Position = base.Position + Vector3.new(0, BEAM_BASE_LIFT + height / 2, 0)
	part.Transparency = rec.style.beamTransparency
	part.Parent = parent
	return part
end

local function updateBeams()
	local origin = localOrigin()
	local parent = beamParent()
	if not origin or not parent then
		return
	end
	local near: { { rec: Rec, base: BasePart, dist: number } } = {}
	for _, rec in recs do
		local base = baseOf(rec)
		if rec.style.beamHeight > 0 and not rec.opened and base then
			local d = (base.Position - origin).Magnitude
			if d <= A.BeamNearStuds then
				table.insert(near, { rec = rec, base = base, dist = d })
			end
		end
	end
	table.sort(near, function(a, b)
		return a.dist < b.dist
	end)
	local keep: { [Rec]: boolean } = {}
	for i, e in near do
		if i <= L.Beam.MaxActive then
			keep[e.rec] = true
			local existing = e.rec.beam
			local beam: BasePart
			if existing ~= nil and existing.Parent ~= nil then
				beam = existing
			else
				beam = makeBeam(e.rec, e.base, parent)
				e.rec.beam = beam
			end
			local fade = ChestStyle.beamFade(e.dist, A.BeamNearStuds, L.Beam.FadeBand)
			beam.Transparency = e.rec.style.beamTransparency
				+ (1 - e.rec.style.beamTransparency) * fade
		end
	end
	for _, rec in recs do
		if not keep[rec] then
			dropBeam(rec)
		end
	end
end

local function sweep()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local origin = cam.CFrame.Position
	local near: { { rec: Rec, base: BasePart, dist: number } } = {}
	for _, rec in recs do
		local base = baseOf(rec)
		if base and not rec.opened and ChestStyle.hasEffects(rec.style) then
			local d = (base.Position - origin).Magnitude
			if d <= B.EffectRadius then
				table.insert(near, { rec = rec, base = base, dist = d })
			elseif rec.active then
				deactivate(rec)
			end
		elseif rec.active then
			deactivate(rec)
		end
	end
	table.sort(near, function(a, b)
		return a.dist < b.dist
	end)
	for i, entry in near do
		if i <= B.MaxEffectChests then
			if not entry.rec.active then
				activate(entry.rec, entry.base)
			end
		elseif entry.rec.active then
			deactivate(entry.rec)
		end
	end
end

function ChestVisuals.start()
	if started then
		return
	end
	started = true
	table.insert(connections, CollectionService:GetInstanceAddedSignal(L.ChestTag):Connect(track))
	table.insert(
		connections,
		CollectionService:GetInstanceRemovedSignal(L.ChestTag):Connect(untrack)
	)
	for _, inst in CollectionService:GetTagged(L.ChestTag) do
		track(inst)
	end
	local acc = B.RefreshSeconds
	local beamAcc = BEAM_REFRESH_SECONDS
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt: number)
			acc += dt
			if acc >= B.RefreshSeconds then
				acc = 0
				sweep()
			end
			beamAcc += dt
			if beamAcc >= BEAM_REFRESH_SECONDS then
				beamAcc = 0
				updateBeams()
			end
			pulseActive(os.clock())
		end)
	)
end

function ChestVisuals.destroy()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for model in recs do
		untrack(model)
	end
	if beamFolder then
		beamFolder:Destroy()
		beamFolder = nil
	end
	started = false
end

return ChestVisuals
