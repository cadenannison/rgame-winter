--!strict
-- Campfires: tagged instances with fuel (burn seconds) stored in attributes. One Heartbeat loop burns all fires.
-- World/build code tags a Model or BasePart with Config.Fire.Tag; fuel defaults to Config.Fire.BurnSeconds.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local FireLogic = require(Shared.logic.FireLogic)
local FireTiers = require(Shared.logic.FireTiers)
local Guard = require(script.Parent.Parent.Net.Guard)
local InventoryService = require(script.Parent.Parent.Items.InventoryService)

local F = Config.Fire
local FUEL_ATTRIBUTE = F.FuelAttribute
local LIT_ATTRIBUTE = F.LitAttribute
local RATE_KEY = "AddFuel"
local UPGRADE_RATE_KEY = "UpgradeFire"

export type WoodSpender = (player: Player, amount: number) -> boolean

-- A lit campfire for range checks: position plus the radii of its current tier.
export type LitFire = { x: number, z: number, warmRadius: number, buildRadius: number }

local FireService = {}

local fires: { [Instance]: boolean } = {}
local woodSpender: WoodSpender? = nil
local fuelBurnProvider: (() -> number)? = nil
local connections: { RBXScriptConnection } = {}
local accumulator = 0
local meterAccumulator = 0
local started = false

local function pivotPosition(fire: Instance): Vector3?
	if fire:IsA("Model") then
		return fire:GetPivot().Position
	elseif fire:IsA("BasePart") then
		return fire.Position
	end
	return nil
end

local function readFuel(fire: Instance): number
	local v = fire:GetAttribute(FUEL_ATTRIBUTE)
	return if type(v) == "number" then v else 0
end

local function tierOf(fire: Instance): number
	return FireTiers.clamp(fire:GetAttribute(F.TierAttribute))
end

-- Publishes fuel / tier max as FuelFraction (clients draw the world-space meter from it). Called on
-- events (register, add fuel, upgrade) and, while burning, at most every F.Meter.UpdateInterval.
local function publishFraction(fire: Instance)
	local row = FireTiers.get(tierOf(fire))
	fire:SetAttribute(
		F.FuelFractionAttribute,
		FireLogic.fraction(readFuel(fire), row.MaxFuelSeconds)
	)
end

local function writeFire(fire: Instance, fuel: number)
	fire:SetAttribute(FUEL_ATTRIBUTE, fuel)
	fire:SetAttribute(LIT_ATTRIBUTE, fuel > 0)
end

-- Server recomputes every tier-derived attribute from the tier row (replicates to clients and mobs).
local function applyTier(fire: Instance, tier: number)
	local row = FireTiers.get(tier)
	fire:SetAttribute(F.TierAttribute, FireTiers.clamp(tier))
	fire:SetAttribute(F.WarmRadiusAttribute, row.WarmRadius)
	fire:SetAttribute(F.BuildRadiusAttribute, row.BuildRadius)
	fire:SetAttribute(F.LightRangeAttribute, row.LightRange)
	publishFraction(fire) -- the cap changed with the tier
end

local function register(fire: Instance)
	if fires[fire] then
		return
	end
	fires[fire] = true
	applyTier(fire, tierOf(fire))
	if type(fire:GetAttribute(FUEL_ATTRIBUTE)) ~= "number" then
		writeFire(fire, F.BurnSeconds)
	else
		fire:SetAttribute(LIT_ATTRIBUTE, readFuel(fire) > 0)
	end
	publishFraction(fire)
end

local function unregister(fire: Instance)
	fires[fire] = nil
end

-- Registers a campfire now (placement code calls this after tagging and parenting). Idempotent;
-- the tag signal also registers it, so either path alone is enough.
function FireService.register(fire: Instance)
	if fire:IsDescendantOf(Workspace) and CollectionService:HasTag(fire, F.Tag) then
		register(fire)
	end
end

-- Number of registered campfires (lit or not), for the per-run cap.
function FireService.count(): number
	local n = 0
	for _ in fires do
		n += 1
	end
	return n
end

-- Positions of every lit campfire (mobs use these for the repel edge).
function FireService.getLitPositions(): { Vector3 }
	local out: { Vector3 } = {}
	for fire in fires do
		if readFuel(fire) > 0 then
			local p = pivotPosition(fire)
			if p then
				table.insert(out, p)
			end
		end
	end
	return out
end

-- Every lit campfire with its tier radii (placement build range, mob repel).
function FireService.getLitFires(): { LitFire }
	local out: { LitFire } = {}
	for fire in fires do
		if readFuel(fire) > 0 then
			local p = pivotPosition(fire)
			if p then
				local row = FireTiers.get(tierOf(fire))
				table.insert(out, {
					x = p.X,
					z = p.Z,
					warmRadius = row.WarmRadius,
					buildRadius = row.BuildRadius,
				})
			end
		end
	end
	return out
end

function FireService.getTier(fire: Instance): number
	return tierOf(fire)
end

-- Server hook: Inventory code installs the function that removes wood from a player; returns true if spent.
function FireService.setWoodSpender(fn: WoodSpender?)
	woodSpender = fn
end

-- Wiring (init.server): event fuel burn multiplier provider (EventService.getModifiers().fuelBurn).
function FireService.setFuelBurnProvider(fn: (() -> number)?)
	fuelBurnProvider = fn
end

function FireService.isLit(fire: Instance): boolean
	return fires[fire] == true and readFuel(fire) > 0
end

-- Adds burn seconds (clamped to the cap). Returns seconds actually added.
function FireService.addFuel(fire: Instance, seconds: number): number
	if not fires[fire] then
		return 0
	end
	local state = FireLogic.new(readFuel(fire))
	local added = FireLogic.addFuel(state, seconds, FireTiers.get(tierOf(fire)).MaxFuelSeconds)
	writeFire(fire, state.fuel)
	publishFraction(fire)
	return added
end

-- True if the position is inside the warm radius of any lit campfire.
function FireService.isWarm(position: Vector3): boolean
	for fire in fires do
		if readFuel(fire) > 0 then
			local p = pivotPosition(fire)
			if
				p
				and FireLogic.inRadius(
					p.X,
					p.Z,
					position.X,
					position.Z,
					FireTiers.get(tierOf(fire)).WarmRadius
				)
			then
				return true
			end
		end
	end
	return false
end

-- Event fuel burn multiplier (Deep Freeze), clamped to Events.MaxFuelBurnMultiplier.
local function fuelBurnMultiplier(): number
	local provider = fuelBurnProvider
	if not provider then
		return 1
	end
	local ok, value = pcall(provider)
	if not ok or type(value) ~= "number" or value ~= value then
		return 1
	end
	return math.clamp(value, 0, Config.Events.MaxFuelBurnMultiplier)
end

local function burnAll(dt: number)
	local burnDt = dt * fuelBurnMultiplier()
	meterAccumulator += dt
	local publish = meterAccumulator >= F.Meter.UpdateInterval
	if publish then
		meterAccumulator = 0
	end
	for fire in fires do
		local fuel = readFuel(fire)
		if fuel > 0 then
			local state = FireLogic.new(fuel)
			local wentOut = FireLogic.burn(state, burnDt)
			writeFire(fire, state.fuel)
			if publish or wentOut then
				publishFraction(fire)
			end
		end
	end
end

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return humanoid.RootPart
end

-- Handler order: type -> sanity -> rate limit -> state -> range -> act.
local function onAddFuel(player: Player, fire: unknown)
	if typeof(fire) ~= "Instance" then
		return
	end
	local target = fire :: Instance
	if not fires[target] or not target:IsDescendantOf(Workspace) then
		return
	end
	if not Guard.rateLimit(player, RATE_KEY, Config.Net.UseRateInterval) then
		return
	end
	if player:GetAttribute(Config.Downed.StateAttribute) == true then
		return
	end
	local root = playerRoot(player)
	local position = pivotPosition(target)
	if not root or not position then
		return
	end
	if (root.Position - position).Magnitude > F.AddFuelRange then
		return
	end
	local row = FireTiers.get(tierOf(target))
	if readFuel(target) >= row.MaxFuelSeconds then
		return
	end
	local spend = woodSpender
	if not spend then
		return
	end
	local okSpend, spent = pcall(spend, player, 1)
	if not okSpend or spent ~= true then
		return
	end
	FireService.addFuel(target, row.WoodFuelSeconds)
end

local function notify(player: Player, text: string)
	Remotes.event(Remotes.Notify):FireClient(player, "fire", text)
end

local function itemName(id: string): string
	local def = ItemCatalog.Items[id]
	return if def then def.name else id
end

-- Handler order: type -> sanity -> rate limit -> state (downed, range, tier cap, cost) -> act.
-- The server recomputes tier rows and cost; the client sends only the fire.
local function onUpgrade(player: Player, fire: unknown)
	if typeof(fire) ~= "Instance" then
		return
	end
	local target = fire :: Instance
	if not fires[target] or not target:IsDescendantOf(Workspace) then
		return
	end
	if not Guard.rateLimit(player, UPGRADE_RATE_KEY, F.UpgradeRateInterval) then
		return
	end
	if player:GetAttribute(Config.Downed.StateAttribute) == true then
		return
	end
	local root = playerRoot(player)
	local position = pivotPosition(target)
	if not root or not position then
		return
	end
	if (root.Position - position).Magnitude > F.UpgradeRange then
		notify(player, "Too far to upgrade the fire")
		return
	end
	local tier = tierOf(target)
	local cost = FireTiers.nextCost(tier)
	if cost == nil then
		notify(player, "Fire is fully upgraded")
		return
	end
	for _, input in cost do
		if InventoryService.count(player, input.id) < input.count then
			notify(player, `Upgrade needs {FireTiers.costText(cost, itemName)}`)
			return
		end
	end
	for _, input in cost do
		if not InventoryService.remove(player, input.id, input.count) then
			return
		end
	end
	applyTier(target, tier + 1)
	notify(player, `Fire upgraded to tier {tier + 1}`)
end

-- Same path as UpgradeFireRequest (QA and server callers); runs the full validation.
FireService.handleUpgrade = onUpgrade

-- Same path as AddFuelRequest (QA and server callers); runs the full validation.
FireService.handleAddFuel = onAddFuel

function FireService.start()
	if started then
		return
	end
	started = true
	table.insert(
		connections,
		CollectionService:GetInstanceAddedSignal(F.Tag):Connect(function(instance)
			register(instance)
		end)
	)
	table.insert(
		connections,
		CollectionService:GetInstanceRemovedSignal(F.Tag):Connect(function(instance)
			unregister(instance)
		end)
	)
	for _, instance in CollectionService:GetTagged(F.Tag) do
		register(instance)
	end
	table.insert(
		connections,
		Remotes.event(Remotes.AddFuelRequest).OnServerEvent
			:Connect(function(player: Player, fire: unknown)
				if player.Parent ~= Players then
					return
				end
				onAddFuel(player, fire)
			end)
	)
	table.insert(
		connections,
		Remotes.event(Remotes.UpgradeFireRequest).OnServerEvent
			:Connect(function(player: Player, fire: unknown)
				if player.Parent ~= Players then
					return
				end
				onUpgrade(player, fire)
			end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator >= Config.Meters.TickInterval then
				local step = accumulator
				accumulator = 0
				burnAll(step)
			end
		end)
	)
end

function FireService.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(fires)
	started = false
end

return FireService
