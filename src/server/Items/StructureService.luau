--!strict
-- Behaviour of the Phase 3 placeables, applied by PlacementService after it builds the part:
-- chest (StorageService), wall/door/trap/watchtower (health, blocker tags), door toggling
-- (DoorToggleRequest), spike traps (mobs only, never players), watchtower map reveal, sleeping bag warm spot.
-- One loop (Structures.Tuning.StructureTickSeconds) serves traps, towers and chest range checks.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local Structures = require(Shared.data.Structures)
local Guard = require(script.Parent.Parent.Net.Guard)
local PartyLink = require(script.Parent.PartyLink)
local ServerUtil = require(script.Parent.ServerUtil)
local StorageService = require(script.Parent.StorageService)

local T = Structures.Tuning
local B = Config.Build

local StructureService = {}

type MobDamager = (mob: Model, amount: number, source: Player?) -> ()
type ExploreProvider = (position: Vector3, radius: number) -> ()

local doors: { [Instance]: boolean } = {}
local trapLastHit: { [Instance]: number } = {}
local towerLastReveal: { [Player]: number } = {}
local mobDamager: MobDamager? = nil
local exploreProvider: ExploreProvider? = nil
local connections: { RBXScriptConnection } = {}
local started = false
local accumulator = 0.0

-- Wiring (nil-safe): MobService.damage(mob, amount, sourcePlayer?) from brief 16, MapService.markExplored
-- from brief 13. ProgressionBoot also binds them lazily when those modules exist.
function StructureService.setMobDamager(fn: MobDamager?)
	mobDamager = fn
end

function StructureService.setExploreProvider(fn: ExploreProvider?)
	exploreProvider = fn
end

local function def(part: Instance): ItemCatalog.StructureDef?
	local id = part:GetAttribute(B.StructureAttribute)
	return if type(id) == "string" then ItemCatalog.Structures[id] else nil
end

-- Damages a breakable structure (heavy mobs/bosses call this); destroys it at 0. Returns remaining health.
function StructureService.damage(structure: Instance, amount: number): number?
	local health = structure:GetAttribute(B.HealthAttribute)
	if type(health) ~= "number" or not Guard.isNumber(amount) or amount <= 0 then
		return nil
	end
	local left = health - amount
	if left <= 0 then
		structure:Destroy()
		return 0
	end
	structure:SetAttribute(B.HealthAttribute, left)
	return left
end

local function buildTruss(tower: BasePart)
	local truss = Instance.new("TrussPart")
	truss.Name = "Ladder"
	truss.Size = Vector3.new(T.WatchtowerTrussWidth, tower.Size.Y, T.WatchtowerTrussWidth)
	truss.Anchored = true
	truss.CFrame = tower.CFrame * CFrame.new(0, 0, tower.Size.Z / 2 + T.WatchtowerTrussWidth / 2)
	truss.Parent = tower
end

-- Applies role behaviour to a freshly built structure part (before it is parented).
function StructureService.onBuilt(
	part: BasePart,
	structure: ItemCatalog.StructureDef,
	owner: Player
)
	if structure.maxHealth then
		part:SetAttribute(B.HealthAttribute, structure.maxHealth)
	end
	if structure.blocksPath then
		CollectionService:AddTag(part, B.BlockerTag)
	end
	local role = structure.role
	if role == "storage" then
		StorageService.register(part)
	elseif role == "door" then
		CollectionService:AddTag(part, T.DoorTag)
		part:SetAttribute(B.DoorOpenAttribute, false)
		doors[part] = true
		part.Destroying:Once(function()
			doors[part] = nil
		end)
	elseif role == "trap" then
		CollectionService:AddTag(part, B.TrapTag)
		part.Destroying:Once(function()
			trapLastHit[part] = nil
		end)
	elseif role == "watchtower" then
		CollectionService:AddTag(part, T.WatchtowerTag)
		buildTruss(part)
	elseif role == "bed" and structure.restRadius then
		CollectionService:AddTag(part, Config.WarmSpot.Tag)
		part:SetAttribute(Config.WarmSpot.RadiusAttribute, structure.restRadius)
	end
	-- Crafting stations (forge, cooking station, map table) are registered by PlacementService.
	local _ = owner
end

local function setDoor(door: BasePart, open: boolean)
	door:SetAttribute(B.DoorOpenAttribute, open)
	door.CanCollide = not open
	door.Transparency = if open then T.DoorOpenTransparency else 0
end

local function onDoorToggle(player: Player, payload: unknown)
	if type(payload) ~= "table" or typeof((payload :: any).door) ~= "Instance" then
		return
	end
	local arg: Instance = (payload :: any).door
	if not Guard.rateLimit(player, "Door", Config.Net.UseRateInterval) then
		return
	end
	local root = ServerUtil.actingRoot(player)
	if root == nil then
		return
	end
	local door = ServerUtil.reachable(root, arg, T.ServerInteractRange)
	if door == nil or not door:IsA("BasePart") or not doors[door] then
		return
	end
	-- Party members may use the door (opensForParty); a stranger who is not in the owner's party may not.
	local ownerId = door:GetAttribute(B.OwnerAttribute)
	local owner = if type(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
	if owner and not PartyLink.same(player, owner) then
		Remotes.event(Remotes.Notify)
			:FireClient(player, "build", "Only the owner's party can use this door")
		return
	end
	setDoor(door, door:GetAttribute(B.DoorOpenAttribute) ~= true)
end

StructureService.handleDoorToggle = onDoorToggle

local function liveMobs(): { Model }
	local out: { Model } = {}
	for _, inst in CollectionService:GetTagged(Config.Mobs.Tag) do
		if inst:IsA("Model") and inst:IsDescendantOf(Workspace) then
			local humanoid = inst:FindFirstChildOfClass("Humanoid")
			if humanoid == nil or humanoid.Health > 0 then
				table.insert(out, inst)
			end
		end
	end
	return out
end

-- Spike traps: mobs standing on one take trapDamage every trapCooldown seconds. Targets come only from the
-- Mob tag, so a player is never a candidate.
local function tickTraps(now: number)
	local damage = mobDamager
	if damage == nil then
		return
	end
	local mobs: { Model }? = nil
	for _, inst in CollectionService:GetTagged(B.TrapTag) do
		local structure = def(inst)
		if inst:IsA("BasePart") and structure and structure.trapDamage then
			if now - (trapLastHit[inst] or -math.huge) >= (structure.trapCooldown or 0) then
				mobs = mobs or liveMobs()
				local owner = if type(inst:GetAttribute(B.OwnerAttribute)) == "number"
					then Players:GetPlayerByUserId(inst:GetAttribute(B.OwnerAttribute) :: number)
					else nil
				for _, mob in mobs :: { Model } do
					local o = inst.CFrame:PointToObjectSpace(mob:GetPivot().Position)
					if
						math.abs(o.X) <= inst.Size.X / 2
						and math.abs(o.Z) <= inst.Size.Z / 2
						and o.Y >= -inst.Size.Y / 2
						and o.Y <= inst.Size.Y / 2 + T.TrapHeight
					then
						trapLastHit[inst] = now
						damage(mob, structure.trapDamage, owner)
					end
				end
			end
		end
	end
end

-- Watchtowers: a player standing on top reveals map cells in a wider radius.
local function tickTowers(now: number)
	local reveal = exploreProvider
	if reveal == nil then
		return
	end
	for _, tower in CollectionService:GetTagged(T.WatchtowerTag) do
		local structure = def(tower)
		if tower:IsA("BasePart") and structure and structure.viewBonus then
			for _, player in Players:GetPlayers() do
				local root = ServerUtil.actingRoot(player)
				if
					root
					and now - (towerLastReveal[player] or -math.huge)
						>= T.WatchtowerRevealSeconds
				then
					local o = tower.CFrame:PointToObjectSpace(root.Position)
					local above = o.Y - tower.Size.Y / 2
					if
						math.abs(o.X) <= tower.Size.X / 2
						and math.abs(o.Z) <= tower.Size.Z / 2
						and above >= 0
						and above <= T.WatchtowerStandHeight
					then
						towerLastReveal[player] = now
						reveal(root.Position, Config.Map.ExploreRadius + structure.viewBonus)
					end
				end
			end
		end
	end
end

function StructureService.start()
	if started then
		return
	end
	started = true
	table.insert(
		connections,
		Remotes.event(Remotes.DoorToggleRequest).OnServerEvent:Connect(onDoorToggle)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			towerLastReveal[player] = nil
		end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator < T.StructureTickSeconds then
				return
			end
			accumulator = 0
			local now = os.clock()
			StorageService.tick()
			tickTraps(now)
			tickTowers(now)
		end)
	)
end

function StructureService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(doors)
	table.clear(trapLastHit)
	table.clear(towerLastReveal)
	started = false
end

return StructureService
