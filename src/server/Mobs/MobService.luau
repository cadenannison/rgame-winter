--!strict
-- Server-authoritative mobs: capped spawn budget near players, AI only near players,
-- one Heartbeat loop for all mobs, melee via AttackRequest. Spec: docs/systems/mobs.md

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local MobAI = require(Shared.logic.MobAI)
local MobRules = require(Shared.logic.MobRules)
local Server = script.Parent.Parent
local Guard = require(Server.Net.Guard)
local FireService = require(Server.Survival.FireService)
local InventoryService = require(Server.Items.InventoryService)

type MobKind = {
	name: string,
	stats: Config.MobStats,
	behavior: MobAI.Behavior,
	size: Vector3,
	color: Color3,
}

type MobRow = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	kind: MobKind,
	health: number,
	damage: number,
	nextAttackAt: number,
	wanderUntil: number,
	lastAction: string?,
}

type PlayerInfo = { player: Player, root: BasePart, humanoid: Humanoid }

-- Visual/behavior data rows. Stats come from Config.Mobs.
local KINDS: { MobKind } = {
	{
		name = "ArcticHare",
		stats = Config.Mobs.Hare,
		behavior = "Flee",
		size = Vector3.new(1.5, 1.5, 2),
		color = Color3.fromRGB(240, 240, 245),
	},
	{
		name = "Caribou",
		stats = Config.Mobs.Caribou,
		behavior = "Flee",
		size = Vector3.new(2.5, 4, 5),
		color = Color3.fromRGB(150, 120, 90),
	},
	{
		name = "Wolf",
		stats = Config.Mobs.Wolf,
		behavior = "Hunt",
		size = Vector3.new(2, 3, 4),
		color = Color3.fromRGB(90, 90, 100),
	},
}

local MOBS = Config.Mobs
local HEALTH_ATTRIBUTE = MOBS.HealthAttribute

local MobService = {}

local started = false
local folder: Folder? = nil
local rows: { [Model]: MobRow } = {}
local rowCount = 0
local spawnAccum = 0
local aiAccum = 0
local lastMeleeAt: { [Player]: number } = {}
local rng = Random.new()

-- Count of AI steps executed (tests/QA: stays flat with no player nearby).
MobService.AIStepCount = 0

local function getDay(): number
	local day = Workspace:GetAttribute(Config.Time.DayAttribute)
	return if type(day) == "number" then day else 1
end

local function getIsNight(): boolean
	return Workspace:GetAttribute(Config.Time.IsNightAttribute) == true
end

local function collectPlayers(): { PlayerInfo }
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

local function toPoint(position: Vector3): MobRules.Point
	return { x = position.X, z = position.Z }
end

local function removeMob(model: Model)
	local row = rows[model]
	if row then
		rows[model] = nil
		rowCount -= 1
	end
	if model.Parent then
		model:Destroy()
	end
end

local function createMob(kind: MobKind, position: Vector3): Model?
	local parent = folder
	if not parent then
		return nil
	end
	local day = getDay()
	local health = MobRules.scaledStat(
		kind.stats.Health,
		Config.Scaling.MobHealthPerDay,
		day,
		Config.Scaling.MaxMobHealthMultiplier
	)
	local damage = MobRules.scaledStat(
		kind.stats.Damage,
		Config.Scaling.MobDamagePerDay,
		day,
		Config.Scaling.MaxMobDamageMultiplier
	)

	local model = Instance.new("Model")
	model.Name = kind.name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = kind.size
	root.Color = kind.color
	root.Material = Enum.Material.SmoothPlastic
	root.CanCollide = true
	root.Anchored = false
	root.CFrame = CFrame.new(position + Vector3.new(0, kind.size.Y / 2 + MOBS.SpawnLift, 0))
	root.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = kind.stats.WalkSpeed
	humanoid.HipHeight = 0
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = root
	model:SetAttribute(MOBS.KindAttribute, kind.name)
	model:SetAttribute(HEALTH_ATTRIBUTE, health)

	local row: MobRow = {
		model = model,
		root = root,
		humanoid = humanoid,
		kind = kind,
		health = health,
		damage = damage,
		nextAttackAt = 0,
		wanderUntil = 0,
		lastAction = nil,
	}
	rows[model] = row
	rowCount += 1
	CollectionService:AddTag(model, Config.Mobs.Tag)
	model.Destroying:Once(function()
		if rows[model] then
			rows[model] = nil
			rowCount -= 1
		end
	end)
	model.Parent = parent
	root:SetNetworkOwner(nil)
	return model
end

local function groundAt(x: number, z: number, originY: number): Vector3?
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

local function trySpawn(infos: { PlayerInfo })
	if #infos == 0 then
		return
	end
	local isNight = getIsNight()
	local budget = MobRules.budget(
		Config.Mobs.Budget,
		getDay(),
		#infos,
		isNight,
		Config.Scaling.MobBudgetPerDay,
		Config.Scaling.MobBudgetPerExtraPlayer,
		Config.Mobs.NightBudgetMultiplier,
		Config.Scaling.MaxMobBudgetMultiplier
	)
	if rowCount >= budget then
		return
	end

	local eligible: { MobKind } = {}
	local weights: { number } = {}
	for _, kind in KINDS do
		if isNight or not kind.stats.NightOnly then
			table.insert(eligible, kind)
			table.insert(weights, kind.stats.Weight)
		end
	end
	local pick = MobRules.pickWeighted(weights, rng:NextNumber())
	if not pick then
		return
	end

	local anchor = infos[rng:NextInteger(1, #infos)].root.Position
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(Config.Mobs.SpawnMinDistance, Config.Mobs.SpawnMaxDistance)
	local x = anchor.X + math.cos(angle) * dist
	local z = anchor.Z + math.sin(angle) * dist
	local candidate = { x = x, z = z }
	local dists: { number } = {}
	for _, info in infos do
		table.insert(dists, MobRules.distance(candidate, toPoint(info.root.Position)))
	end
	if
		not MobRules.spawnDistanceOk(
			dists,
			Config.Mobs.SpawnMinDistance,
			Config.Mobs.SpawnMaxDistance
		)
	then
		return
	end
	local ground = groundAt(x, z, anchor.Y)
	if ground then
		createMob(eligible[pick], ground)
	end
end

local function horizontalDir(from: Vector3, to: Vector3): Vector3
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return if d.Magnitude > 0.001 then d.Unit else Vector3.new(1, 0, 0)
end

-- Lit campfire (FireService state) whose repel radius contains pos.
local function repellingFire(pos: Vector3, fires: { Vector3 }): Vector3?
	for _, f in fires do
		if MobRules.distance(toPoint(pos), toPoint(f)) <= Config.Fire.RepelRadius then
			return f
		end
	end
	return nil
end

local function stepMob(
	row: MobRow,
	infos: { PlayerInfo },
	fires: { Vector3 },
	isNight: boolean,
	now: number
)
	local pos = row.root.Position
	local stats = row.kind.stats
	local nearestInfo: PlayerInfo? = nil
	local nearest: number? = nil
	for _, info in infos do
		local d = MobRules.distance(toPoint(pos), toPoint(info.root.Position))
		if nearest == nil or d < nearest then
			nearest = d
			nearestInfo = info
		end
	end
	local fire = if row.kind.behavior == "Hunt" then repellingFire(pos, fires) else nil
	local action = MobAI.decide({
		behavior = row.kind.behavior,
		nearestPlayerDist = nearest,
		isNight = isNight,
		nightOnly = stats.NightOnly,
		fleeRange = stats.FleeRange,
		aggroRange = stats.AggroRange,
		attackRange = stats.AttackRange,
		inFireRepel = fire ~= nil,
		canAttack = now >= row.nextAttackAt,
	})
	row.lastAction = action

	local humanoid = row.humanoid
	if action == "Flee" and nearestInfo then
		humanoid.WalkSpeed = stats.FleeSpeed
		humanoid:MoveTo(pos + horizontalDir(nearestInfo.root.Position, pos) * MOBS.FleeStep)
	elseif action == "Retreat" and fire then
		humanoid.WalkSpeed = stats.FleeSpeed
		humanoid:MoveTo(pos + horizontalDir(fire, pos) * MOBS.RetreatStep)
	elseif action == "Chase" and nearestInfo then
		humanoid.WalkSpeed = stats.FleeSpeed
		humanoid:MoveTo(nearestInfo.root.Position)
	elseif action == "Attack" and nearestInfo then
		-- Server recomputes distance at the action.
		local d = MobRules.distance(toPoint(pos), toPoint(nearestInfo.root.Position))
		if d <= stats.AttackRange then
			row.nextAttackAt = now + stats.AttackCooldown
			if nearestInfo.player:GetAttribute(Config.Debug.PlayerInvincibleAttribute) ~= true then
				nearestInfo.humanoid:TakeDamage(row.damage)
			end
		end
	else
		humanoid.WalkSpeed = stats.WalkSpeed
		if now >= row.wanderUntil then
			row.wanderUntil = now + MOBS.WanderInterval * (0.5 + rng:NextNumber())
			local angle = rng:NextNumber(0, math.pi * 2)
			humanoid:MoveTo(
				pos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * MOBS.WanderRadius
			)
		end
	end
end

local function aiPass(infos: { PlayerInfo })
	local models: { Model } = {}
	local points: { MobRules.Point } = {}
	for model, row in rows do
		table.insert(models, model)
		table.insert(points, toPoint(row.root.Position))
	end
	local playerPoints: { MobRules.Point } = {}
	for _, info in infos do
		table.insert(playerPoints, toPoint(info.root.Position))
	end

	-- Despawn mobs with no player within range.
	for i, model in models do
		if
			MobRules.shouldDespawn(
				MobRules.nearestDistance(points[i], playerPoints),
				Config.Mobs.DespawnDistance
			)
		then
			removeMob(model)
		end
	end

	local active = MobRules.selectActive(points, playerPoints, Config.Mobs.AIActiveRadius)
	if #active == 0 then
		return
	end
	local fires = FireService.getLitPositions()
	local isNight = getIsNight()
	local now = os.clock()
	for _, index in active do
		local row = rows[models[index]]
		if row and row.model.Parent then
			MobService.AIStepCount += 1
			stepMob(row, infos, fires, isNight, now)
		end
	end
end

local function onHeartbeat(dt: number)
	aiAccum += dt
	spawnAccum += dt
	local doAI = aiAccum >= Config.Mobs.AITickInterval
	local doSpawn = spawnAccum >= Config.Mobs.SpawnInterval
	if not (doAI or doSpawn) then
		return
	end
	local infos = collectPlayers()
	if doAI then
		aiAccum = 0
		aiPass(infos)
	end
	if doSpawn then
		spawnAccum = 0
		trySpawn(infos)
	end
end

local function resolveMob(target: Instance): MobRow?
	local model: Instance? = target
	if target:IsA("BasePart") then
		model = target.Parent
	end
	if model and model:IsA("Model") then
		return rows[model]
	end
	return nil
end

local function onAttack(player: Player, target: unknown)
	-- 1. type check
	if typeof(target) ~= "Instance" then
		return
	end
	local instance = target :: Instance
	-- 2. sanity: must be a live registered mob
	local row = resolveMob(instance)
	if not row or not row.model.Parent then
		return
	end
	-- 3. rate limit
	if not Guard.rateLimit(player, "Attack", Config.Net.AttackRateInterval) then
		return
	end
	-- 4. state: alive, not downed, melee cooldown
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return
	end
	if player:GetAttribute(Config.Downed.StateAttribute) == true then
		return
	end
	local now = os.clock()
	if now - (lastMeleeAt[player] or -math.huge) < Config.Combat.MeleeCooldown then
		return
	end
	-- 5. act: server-recomputed distance and damage
	local dist = MobRules.distance(toPoint(root.Position), toPoint(row.root.Position))
	if not MobRules.canMelee(dist, Config.Combat.MeleeRange, Config.Combat.LagCompensation) then
		return
	end
	lastMeleeAt[player] = now
	-- Damage from the equipped weapon's item data (fist / non-weapon = MeleeBaseDamage).
	local held = InventoryService.getSelected(player)
	local def = if held then ItemCatalog.Items[held.id] else nil
	local isWeapon = def ~= nil and def.kind == "weapon" and def.damage ~= nil
	local damage = if isWeapon
			and def
			and def.damage
		then def.damage
		else Config.Combat.MeleeBaseDamage
	if isWeapon then
		InventoryService.wearSelected(player, Config.Combat.WeaponDurabilityPerHit)
	end
	row.health -= damage
	row.model:SetAttribute(HEALTH_ATTRIBUTE, math.max(0, row.health))
	if row.health <= 0 then
		local stats = row.kind.stats
		removeMob(row.model)
		-- Drop goes straight to the killer's inventory (no world pickups yet).
		if stats.DropId and stats.DropCount > 0 then
			InventoryService.add(player, stats.DropId, stats.DropCount)
		end
	end
end

-- Same path as AttackRequest (QA and server callers); runs the full validation.
MobService.handleAttack = onAttack

-- Server/QA: spawn one mob of a kind ("ArcticHare" | "Caribou" | "Wolf") at a ground position.
function MobService.spawn(kindName: string, position: Vector3): Model?
	for _, kind in KINDS do
		if kind.name == kindName then
			return createMob(kind, position)
		end
	end
	return nil
end

-- Last AI action of a mob ("Wander" | "Flee" | "Chase" | "Attack" | "Retreat"), nil before its first step.
function MobService.getLastAction(model: Model): string?
	local row = rows[model]
	return if row then row.lastAction else nil
end

function MobService.start()
	if started then
		return
	end
	started = true
	local mobsFolder = Instance.new("Folder")
	mobsFolder.Name = MOBS.FolderName
	mobsFolder.Parent = Workspace
	folder = mobsFolder

	Players.PlayerRemoving:Connect(function(player)
		lastMeleeAt[player] = nil
	end)
	Remotes.event(Remotes.AttackRequest).OnServerEvent:Connect(onAttack)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return MobService
