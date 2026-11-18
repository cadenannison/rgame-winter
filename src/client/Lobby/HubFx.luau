--!strict
-- Hub visuals (art pass 1), lobby servers only: dusk lighting/atmosphere (client-side, restored on
-- stop), the soft pad pulse tinted by pad state, and warm light flicker on tagged lanterns/fires.
-- One Heartbeat loop for every object; no remotes. Reads LobbyState pads only.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ArtKit = require(Shared:WaitForChild("ArtKit"))
local LobbyState = require(script.Parent.LobbyState)

local HubFx = {}

local H = Config.Art.Hub
local P = ArtKit.palette(H.Palette)

type Flicker = { light: Light, base: number, phase: number }
type Pulse = { part: BasePart, light: PointLight?, color: Color3 }

local function applyLighting(): () -> ()
	local A = H.Ambient
	local saved = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		FogEnd = Lighting.FogEnd,
		FogColor = Lighting.FogColor,
	}
	Lighting.ClockTime = A.ClockTime
	Lighting.Brightness = A.Brightness
	Lighting.Ambient = ArtKit.color(A.Ambient)
	Lighting.OutdoorAmbient = ArtKit.color(A.OutdoorAmbient)
	Lighting.FogEnd = A.FogEnd
	Lighting.FogColor = ArtKit.color(A.FogColor)
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "HubAtmosphere"
	atmosphere.Density = A.AtmosphereDensity
	atmosphere.Haze = A.AtmosphereHaze
	atmosphere.Color = ArtKit.color(A.AtmosphereColor)
	atmosphere.Decay = ArtKit.color(A.AtmosphereDecay)
	atmosphere.Parent = Lighting
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "HubTint"
	tint.TintColor = Color3.fromRGB(226, 236, 255)
	tint.Saturation = -0.05
	tint.Contrast = 0.08
	tint.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "HubBloom"
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.7
	bloom.Parent = Lighting
	return function()
		atmosphere:Destroy()
		tint:Destroy()
		bloom:Destroy()
		for key, value in saved do
			(Lighting :: any)[key] = value
		end
	end
end

function HubFx.start(state: LobbyState.State): () -> ()
	local destroyed = false
	local restore: (() -> ())? = nil
	local flickers: { [Instance]: Flicker } = {}
	local pulses: { [BasePart]: Pulse } = {}
	local connections: { RBXScriptConnection } = {}
	local player = game:GetService("Players").LocalPlayer

	local function addLamp(instance: Instance)
		local light = instance:FindFirstChildWhichIsA("PointLight")
		if light and not flickers[instance] then
			flickers[instance] =
				{ light = light, base = light.Brightness, phase = math.random() * 6.28 }
		end
	end
	local function addPad(instance: Instance)
		if instance:IsA("BasePart") and not pulses[instance] then
			local glow = instance:FindFirstChildWhichIsA("PointLight")
			pulses[instance] = { part = instance, light = glow, color = instance.Color }
		end
	end
	local function watch(tag: string, add: (Instance) -> ())
		for _, instance in CollectionService:GetTagged(tag) do
			add(instance)
		end
		table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(add))
	end
	watch(H.Tags.Lamp, addLamp)
	watch(H.Tags.Pulse, addPad)
	table.insert(
		connections,
		CollectionService:GetInstanceRemovedSignal(H.Tags.Lamp):Connect(function(instance: Instance)
			flickers[instance] = nil
		end)
	)
	table.insert(
		connections,
		CollectionService:GetInstanceRemovedSignal(H.Tags.Pulse)
			:Connect(function(instance: Instance)
				pulses[instance :: BasePart] = nil
			end)
	)

	local function targetColor(index: number): (Color3, number)
		for _, pad in state.pads do
			if pad.index == index then
				if pad.launching then
					return P.PadLaunch, 1.4
				elseif #pad.memberIds > 0 then
					return P.PadActive, 1
				end
			end
		end
		return P.PadEmpty, 0.7
	end

	local beat = RunService.Heartbeat:Connect(function()
		if destroyed then
			return
		end
		local lobby = state.isLobby()
		if lobby and not restore then
			restore = applyLighting()
		end
		if not lobby then
			return
		end
		local t = os.clock()
		local mine = player:GetAttribute(Config.Lobby.PlayerPadAttribute)
		for part, pulse in pulses do
			local index = part:GetAttribute(Config.Lobby.PadIndexAttribute)
			local target, energy = P.PadEmpty, 0.7
			if type(index) == "number" then
				target, energy = targetColor(index)
			end
			pulse.color = pulse.color:Lerp(target, 0.08)
			local wave = 0.5
				+ 0.5
					* math.sin(t * H.PulseSpeed + (if type(index) == "number" then index else 0))
			part.Color = pulse.color
			part.Transparency = 0.5 - 0.3 * wave * energy - (if mine == index then 0.1 else 0)
			if pulse.light then
				pulse.light.Color = pulse.color
				pulse.light.Brightness = (0.8 + 0.9 * wave) * energy
			end
		end
		for _, f in flickers do
			f.light.Brightness = f.base
				* (
					1
					+ 0.07 * math.sin(t * H.FlickerSpeed + f.phase)
					+ 0.04 * math.sin(t * H.FlickerSpeed * 2.7 + f.phase * 2)
				)
		end
	end)

	return function()
		destroyed = true
		beat:Disconnect()
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
		if restore then
			restore()
			restore = nil
		end
	end
end

return HubFx
