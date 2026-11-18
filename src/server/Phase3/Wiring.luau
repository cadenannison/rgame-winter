--!strict
-- Phase 3 cross-system wiring (brief 18). init.server.luau calls Wiring.apply() once in run mode, after
-- ChunkService.start() and before the Phase 3 boot hooks, so every nil-safe setter is set before any
-- system starts ticking. Only server-side values cross here: nothing hidden reaches a client.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemCatalog = require(Shared.ItemCatalog)
local Events = require(Shared.data.Events)
local BiomeLogic = require(Shared.logic.BiomeLogic)

local Server = script.Parent.Parent
local ChunkService = require(Server.World.ChunkService)
local BiomeService = require(Server.World.BiomeService)
local PoiService = require(Server.World.PoiService)
local DayNightService = require(Server.Survival.DayNightService)
local SurvivalService = require(Server.Survival.SurvivalService)
local FireService = require(Server.Survival.FireService)
local InventoryService = require(Server.Items.InventoryService)
local BuffService = require(Server.Items.BuffService)
local ClothingService = require(Server.Items.ClothingService)
local MobService = require(Server.Mobs.MobService)
local BossService = require(Server.Mobs.BossService)
local EventService = require(Server.Events.EventService)
local HorrorWorld = require(Server.Horror.HorrorWorld)
local DreadService = require(Server.Horror.DreadService)
local StalkerService = require(Server.Horror.StalkerService)
local CueSender = require(Server.Horror.CueSender)
local RunLifecycleService = require(Server.Run.RunLifecycleService)
local PerkModifiers = require(Server.Phase4.PerkModifiers)

local W = Config.WarmSpot
local HOT_SPRING_KIND = "HotSpring" -- PoiService WarmSpotKind attribute value
local THIN_ICE_CAUSE = "Cold"

local Wiring = {}

local function pivotOf(inst: Instance): Vector3?
	if inst:IsA("Model") then
		return inst:GetPivot().Position
	elseif inst:IsA("BasePart") then
		return inst.Position
	end
	return nil
end

-- Warm spots (cabin hearth while lit, hot springs, sleeping bags) stop warmth drain like a fire.
local function inWarmSpot(position: Vector3): boolean
	for _, spot in CollectionService:GetTagged(W.Tag) do
		local radius = spot:GetAttribute(W.RadiusAttribute)
		local p = pivotOf(spot)
		if type(radius) == "number" and p and spot:IsDescendantOf(Workspace) then
			local dx, dz = position.X - p.X, position.Z - p.Z
			if dx * dx + dz * dz <= radius * radius then
				return true
			end
		end
	end
	return false
end

-- Hot springs attract mobs: a capped budget bias while a player is near one.
local function hotSpringBias(position: Vector3): number
	local range = Config.Scaling.HotSpringBiasRange
	for _, spot in CollectionService:GetTagged(W.Tag) do
		local p = pivotOf(spot)
		if p and spot:GetAttribute("WarmSpotKind") == HOT_SPRING_KIND then
			local dx, dz = position.X - p.X, position.Z - p.Z
			if dx * dx + dz * dz <= range * range then
				return Config.Scaling.HotSpringSpawnBias
			end
		end
	end
	return 1
end

-- Survival environment: warm spots, biome cold x clothing, event warmth drain, food buffs, run perk
-- (perk multipliers are capped by Meta.MaxPerkMagnitude; speed is clamped again by Buffs.MaxSpeedBonus).
local function survivalEnv(player: Player, position: Vector3): SurvivalService.EnvExtra
	local ring = BiomeService.getRing(player) or BiomeLogic.ringAt(position.X, position.Z)
	local biome = BiomeLogic.drainMultiplier(ring, ClothingService.get(player))
	local event = math.clamp(
		EventService.getModifiers().warmthDrain,
		0,
		Config.Events.MaxWarmthDrainMultiplier
	)
	local buffs = BuffService.getModifiers(player)
	return {
		warm = inWarmSpot(position),
		warmthDrain = biome * event * buffs.warmthDrain * PerkModifiers.multiplier(
			player,
			"warmthDrain"
		),
		hungerDrain = buffs.hungerDrain * PerkModifiers.multiplier(player, "hungerDrain"),
		regenBonus = buffs.regenBonus,
		speed = buffs.speed * PerkModifiers.multiplier(player, "moveSpeed"),
	}
end

-- Held light for the Stalker: Flare ends hunts, any other lit light (Torch, Lantern) repels like a torch.
local function heldLight(player: Player): HorrorWorld.Light
	local stack = InventoryService.getSelected(player)
	local def = stack and ItemCatalog.Items[stack.id]
	if not stack or not def or def.kind ~= "light" or def.repelsStalker ~= true then
		return "none"
	end
	if stack.durability ~= nil and stack.durability <= 0 then
		return "none"
	end
	return if def.endsHunt == true then "flare" else "torch"
end

local function isDarkEvent(id: string): boolean
	return Events.ById[id] ~= nil
end

function Wiring.apply()
	-- Events: run seed, full-group test, mob budget, night rules, coins, blizzard boss.
	local seed = ChunkService.getSeed()
	if seed then
		EventService.setSeed(seed)
	end
	EventService.setFullGroupPredicate(DreadService.isFullGroup)
	EventService.setSpawnMultiplierSink(MobService.setBudgetMultiplier)
	EventService.onEventStart(function(id: string)
		local def = Events.ById[id]
		if def and def.nightRules then
			DayNightService.setForcedNight(true)
		end
	end)
	EventService.onEventEnd(function(id: string, survivors: { Player })
		local def = Events.ById[id]
		if def and def.nightRules then
			DayNightService.setForcedNight(false)
		end
		if isDarkEvent(id) then
			for _, player in survivors do
				RunLifecycleService.RecordDarkEventSurvived(player)
			end
		end
	end)
	BossService.wireEvents(EventService.onBlizzardStart)
	BossService.setCampProvider(ChunkService.getCampPosition)
	FireService.setFuelBurnProvider(function(): number
		return EventService.getModifiers().fuelBurn * PerkModifiers.teamMultiplier("fuelBurn")
	end)

	-- Survival: biome cold x clothing, warm spots, event drain, food buffs.
	SurvivalService.setEnvProvider(survivalEnv)

	-- Mobs: biome ring by position, hot-spring bias.
	MobService.setRingProvider(function(position: Vector3): number
		return BiomeLogic.ringAt(position.X, position.Z)
	end)
	MobService.setSpawnBiasProvider(hotSpringBias)

	-- World: thin ice costs warmth and plays the crack cue; hearths burn Wood.
	PoiService.setHearthWoodItem("Wood")
	PoiService.onThinIceBreak(function(player: Player)
		SurvivalService.markHit(player, THIN_ICE_CAUSE)
		SurvivalService.warm(player, -Config.Biome.ThinIceWarmthPenalty)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		CueSender.send(player, {
			kind = "IceCrack",
			position = if root and root:IsA("BasePart") then root.Position else nil,
		})
	end)

	-- Horror: camp, event modifiers, held lights. Fires and warm spots use the tag defaults
	-- (Campfire + WarmSpot tags: camp/extra fires, lit hearths, hot springs, sleeping bags).
	HorrorWorld.setCampProvider(ChunkService.getCampPosition)
	HorrorWorld.setEventProvider(function(): HorrorWorld.EventModifiers?
		local m = EventService.getModifiers()
		return { dreadGain = m.dreadGain, huntBonus = m.huntBonus, nightRules = m.nightRules }
	end)
	HorrorWorld.setLightProvider(heldLight)
	-- A Stalker strike reuses the bite feedback (client flash + sound from the visible BiteSeq counter).
	StalkerService.onStrike(function(player: Player)
		local n = player:GetAttribute(Config.Night.BiteAttribute)
		player:SetAttribute(Config.Night.BiteAttribute, (if type(n) == "number" then n else 0) + 1)
	end)
end

return Wiring
