--!strict
-- World queries for the mob modules: day / danger clocks, biome ring, player and fire snapshots, ground rays.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local FireRepel = require(Shared.logic.FireRepel)
local MobRules = require(Shared.logic.MobRules)
local Types = require(script.Parent.MobTypes)

type PlayerInfo = Types.PlayerInfo

local NIGHT = Config.Night
local MOBS = Config.Mobs

local MobWorld = {}

local folder: Folder? = nil
local ringProvider: ((Vector3) -> number)? = nil
local partyCount = 1

function MobWorld.setFolder(value: Folder?)
	folder = value
end

function MobWorld.getFolder(): Folder?
	return folder
end

function MobWorld.setRingProvider(fn: ((Vector3) -> number)?)
	ringProvider = fn
end

function MobWorld.setPartyCount(n: number)
	partyCount = math.max(1, n)
end

function MobWorld.getPartyCount(): number
	return partyCount
end

function MobWorld.getDay(): number
	local day = Workspace:GetAttribute(Config.Time.DayAttribute)
	return if type(day) == "number" then day else 1
end

function MobWorld.getIsNight(): boolean
	return Workspace:GetAttribute(Config.Time.IsNightAttribute) == true
end

-- Night or an active blizzard: hostiles hunt.
function MobWorld.getDanger(): boolean
	return MobWorld.getIsNight() or Workspace:GetAttribute(Config.Blizzard.ActiveAttribute) == true
end

-- Biome ring at a position (0 when no provider is wired: brief 18 wires BiomeService.getRing).
function MobWorld.ringAt(position: Vector3): number
	local provider = ringProvider
	if not provider then
		return 0
	end
	local ok, ring = pcall(provider, position)
	return if ok and type(ring) == "number" and ring == ring then math.max(0, ring) else 0
end

function MobWorld.collectPlayers(): { PlayerInfo }
	local list: { PlayerInfo } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			humanoid
			and root
			and root:IsA("BasePart")
			and humanoid.Health > 0
			and player:GetAttribute(Config.Downed.StateAttribute) ~= true
		then
			table.insert(list, { player = player, root = root, humanoid = humanoid })
		end
	end
	return list
end

function MobWorld.toPoint(position: Vector3): MobRules.Point
	return { x = position.X, z = position.Z }
end

function MobWorld.horizontalDir(from: Vector3, to: Vector3): Vector3
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return if d.Magnitude > 0.001 then d.Unit else Vector3.new(1, 0, 0)
end

-- Nearest player by flat distance (nil, nil with no players).
function MobWorld.nearestPlayer(position: Vector3, infos: { PlayerInfo }): (PlayerInfo?, number?)
	local best: PlayerInfo? = nil
	local bestDist: number? = nil
	local here = MobWorld.toPoint(position)
	for _, info in infos do
		local d = MobRules.distance(here, MobWorld.toPoint(info.root.Position))
		if bestDist == nil or d < bestDist then
			bestDist = d
			best = info
		end
	end
	return best, bestDist
end

function MobWorld.groundAt(x: number, z: number, originY: number): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if folder then
		table.insert(exclude, folder)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(
		Vector3.new(x, originY + MOBS.SpawnRayHeight, z),
		Vector3.new(0, -MOBS.SpawnRayLength, 0),
		params
	)
	return if hit then hit.Position else nil
end

-- Clear line from a mob to a player (terrain, trees and walls block; other mobs and characters do not).
function MobWorld.hasSight(from: Vector3, targetRoot: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if folder then
		table.insert(exclude, folder)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local eye = from + Vector3.new(0, Config.Aggro.SightEyeHeight, 0)
	return Workspace:Raycast(eye, targetRoot.Position - eye, params) == nil
end

-- Lit campfires from the Fire tag (position + per-fire WarmRadius attribute, Config fallback).
function MobWorld.collectFires(): { FireRepel.Fire }
	local out: { FireRepel.Fire } = {}
	for _, fire in CollectionService:GetTagged(Config.Fire.Tag) do
		local fuel = fire:GetAttribute(Config.Fire.FuelAttribute)
		if type(fuel) == "number" and fuel > 0 then
			local p: Vector3? = nil
			if fire:IsA("Model") then
				p = fire:GetPivot().Position
			elseif fire:IsA("BasePart") then
				p = fire.Position
			end
			if p then
				local r = fire:GetAttribute(NIGHT.WarmRadiusAttribute)
				table.insert(out, {
					x = p.X,
					z = p.Z,
					radius = if type(r) == "number" then r else Config.Fire.WarmRadius,
				})
			end
		end
	end
	return out
end

function MobWorld.repelOf(f: FireRepel.Fire): number
	return FireRepel.repelRadius(f.radius, Config.Fire.RepelRadius, NIGHT.RepelMargin)
end

return MobWorld
