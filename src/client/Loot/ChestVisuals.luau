--!strict
-- Client chest effects. One RenderStepped loop for every LootChest: only chests near the camera (and under
-- ChestStyle.Budget.MaxEffectChests) get a PointLight + ParticleEmitter and a glow pulse, all driven by the
-- ChestRarity / LootOpened Attributes. Opened chests lose their effects and play one burst + sound hook.
-- The server builds the parts (server/Art/ChestArt); nothing here is trusted or sent to the server.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Assets = require(Shared:WaitForChild("Assets"))
local ChestStyle = require(Shared:WaitForChild("logic"):WaitForChild("ChestStyle"))

local L = Config.Loot
local B = ChestStyle.Budget

local PARTICLE_TEXTURE_KEY = "ChestParticle" -- Assets hook; engine sparkles when absent
local ENGINE_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local PARTICLE_SIZE = 0.5
local PARTICLE_SPEED_MIN = 1
local PARTICLE_SPEED_MAX = 3
local SOUND_VOLUME = 0.7
local SOUND_LIFETIME = 4
local BURST_LIFETIME_PAD = 0.5
local BURST_SPEED = 8
local BEAM_REFRESH_SECONDS = 0.1 -- beam distance fade update interval

type Rec = {
	model: Model,
	rarity: string,
	style: ChestStyle.Style,
	opened: boolean,
	active: boolean,
	light: PointLight?,
	emitter: ParticleEmitter?,
	beam: BasePart?,
	conn: RBXScriptConnection?,
}

local ChestVisuals = {}

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

local function makeEmitter(rec: Rec, base: BasePart, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = textureId()
	e.Color = ColorSequence.new(toColor(rec.style.glowColor))
	e.LightEmission = 1
	e.Size = NumberSequence.new(PARTICLE_SIZE)
	e.Lifetime = NumberRange.new(rec.style.particleLifetime)
	e.Speed = NumberRange.new(PARTICLE_SPEED_MIN, PARTICLE_SPEED_MAX)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = math.min(rate, B.MaxParticleRate)
	e.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = base
	return e
end

local function deactivate(rec: Rec)
	rec.active = false
	if rec.light then
		rec.light:Destroy()
		rec.light = nil
	end
	if rec.emitter then
		rec.emitter:Destroy()
		rec.emitter = nil
	end
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
	if rec.style.particleRate > 0 and rec.emitter == nil then
		rec.emitter = makeEmitter(rec, base, rec.style.particleRate)
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
		local e = makeEmitter(rec, base, 0)
		e.Speed = NumberRange.new(BURST_SPEED)
		e:Emit(rec.style.burstCount)
		Debris:AddItem(e, rec.style.particleLifetime + BURST_LIFETIME_PAD)
	end
end

local function untrack(model: Instance)
	local rec = recs[model :: Model]
	if rec then
		deactivate(rec)
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
		emitter = nil,
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
			local glow = rec.model:FindFirstChild("Glow")
			if glow and glow:IsA("BasePart") then
				glow.Transparency = ChestStyle.pulse(rec.style, t)
			end
		end
	end
end

-- Beams (rare+, short): visible only within Beam.VisibleRadius of the camera (distance fade), and only the
-- nearest Beam.MaxActive. One pass for every chest; purely client side.
local function updateBeams()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local origin = cam.CFrame.Position
	local beam = L.Beam
	local seen: { { rec: Rec, part: BasePart, dist: number } } = {}
	for _, rec in recs do
		if rec.style.beamHeight > 0 then
			local part = rec.beam
			if part == nil or part.Parent == nil then
				local found = rec.model:FindFirstChild("Beam")
				part = if found and found:IsA("BasePart") then found else nil
				rec.beam = part
			end
			local base = baseOf(rec)
			if part and base then
				if rec.opened then
					part.LocalTransparencyModifier = 1
				else
					table.insert(
						seen,
						{ rec = rec, part = part, dist = (base.Position - origin).Magnitude }
					)
				end
			end
		end
	end
	table.sort(seen, function(a, b)
		return a.dist < b.dist
	end)
	for i, e in seen do
		e.part.LocalTransparencyModifier = if i > beam.MaxActive
			then 1
			else ChestStyle.beamFade(e.dist, beam.VisibleRadius, beam.FadeBand)
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
	started = false
end

return ChestVisuals
