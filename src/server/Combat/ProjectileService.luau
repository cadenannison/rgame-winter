--!strict
-- Server-resolved projectiles (bow). ShootRequest -> validate -> spend ammo -> simulate in ONE Heartbeat loop
-- -> hit mobs (full damage) or a stray player (Projectile.FriendlyFireMultiplier x damage). Melee never hurts
-- players. The client only gets ProjectileFired (a tracer); it never supplies origin, damage or hits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local MobData = require(Shared.data.Mobs)
local Projectile = require(Shared.logic.Projectile)
local Server = script.Parent.Parent
local Guard = require(Server.Net.Guard)
local InventoryService = require(Server.Items.InventoryService)
local MobService = require(Server.Mobs.MobService)

local ORIGIN_HEIGHT = 1.5 -- studs above the root part the arrow leaves from
local HELD_POLL_SECONDS = 0.25

type Shot = {
	owner: Player,
	position: Vector3,
	direction: Vector3,
	traveled: number,
	age: number,
	damage: number,
}

local ProjectileService = {}

local started = false
local shots: { Shot } = {}
local active: { [Player]: number } = {}
local heldAccum = 0

local function aliveCharacter(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function toV3(v: Vector3): Projectile.V3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function onShoot(player: Player, payload: unknown)
	-- 1. type check
	if type(payload) ~= "table" then
		return
	end
	local rawDir = (payload :: { [string]: unknown }).direction
	if typeof(rawDir) ~= "Vector3" then
		return
	end
	-- 2. sanity: finite, roughly unit direction
	local clean = Projectile.cleanDirection(toV3(rawDir))
	if not clean then
		return
	end
	-- 3. rate limit
	if not Guard.rateLimit(player, "Shoot", Config.Net.ShootRateInterval) then
		return
	end
	-- 4. state: alive, not downed, ranged weapon selected, ammo, active cap
	local humanoid, root = aliveCharacter(player)
	if not humanoid or not root then
		return
	end
	if player:GetAttribute(Config.Downed.StateAttribute) == true then
		return
	end
	local held = InventoryService.getSelected(player)
	local def = if held then ItemCatalog.Items[held.id] else nil
	if
		not def
		or def.kind ~= "weapon"
		or def.ranged ~= true
		or not def.ammoId
		or not def.damage
	then
		return
	end
	if not Projectile.canFire(active[player] or 0, Config.Projectile.MaxActivePerPlayer) then
		return
	end
	-- 5. act
	if not InventoryService.remove(player, def.ammoId, 1) then
		return
	end
	InventoryService.wearSelected(player, Config.Combat.WeaponDurabilityPerHit)
	local origin = root.Position + Vector3.new(0, ORIGIN_HEIGHT, 0)
	local targets: { Projectile.V3 } = {}
	for _, live in MobService.getLive() do
		table.insert(targets, toV3(live.position))
	end
	local aimed =
		Projectile.aimAssist(toV3(origin), clean, targets, Config.Projectile.AimAssistDegrees)
	local direction = Vector3.new(aimed.x, aimed.y, aimed.z)
	active[player] = (active[player] or 0) + 1
	table.insert(shots, {
		owner = player,
		position = origin,
		direction = direction,
		traveled = 0,
		age = 0,
		damage = def.damage,
	})
	Remotes.event(Remotes.ProjectileFired):FireAllClients({
		shooterId = player.UserId,
		origin = origin,
		direction = direction,
		speed = Config.Projectile.Speed,
	})
end

local function finish(index: number)
	local shot = shots[index]
	active[shot.owner] = math.max(0, (active[shot.owner] or 1) - 1)
	table.remove(shots, index)
end

local function resolveHit(shot: Shot, hit: Instance)
	if MobService.isMob(hit) then
		MobService.damage(hit, shot.damage, shot.owner)
		return
	end
	local model = hit:FindFirstAncestorOfClass("Model")
	local victim = if model then Players:GetPlayerFromCharacter(model) else nil
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if victim and victim ~= shot.owner and humanoid and humanoid.Health > 0 then
		if victim:GetAttribute(Config.Debug.PlayerInvincibleAttribute) ~= true then
			humanoid:TakeDamage(
				Projectile.playerDamage(shot.damage, Config.Projectile.FriendlyFireMultiplier)
			)
		end
	end
end

local function step(dt: number)
	for i = #shots, 1, -1 do
		local shot = shots[i]
		local distance = Config.Projectile.Speed * dt
		shot.age += dt
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local filter: { Instance } = {}
		if shot.owner.Character then
			table.insert(filter, shot.owner.Character)
		end
		params.FilterDescendantsInstances = filter
		local result = Workspace:Raycast(shot.position, shot.direction * distance, params)
		if result then
			resolveHit(shot, result.Instance)
			finish(i)
		else
			shot.position += shot.direction * distance
			shot.traveled += distance
			if
				shot.traveled >= Config.Projectile.MaxRange
				or shot.age >= Config.Projectile.MaxLifetime
				or shot.owner.Parent == nil
			then
				finish(i)
			end
		end
	end
end

-- Visible hint for the client: is the selected item a ranged weapon?
local function updateHeld()
	for _, player in Players:GetPlayers() do
		local held = InventoryService.getSelected(player)
		local def = if held then ItemCatalog.Items[held.id] else nil
		local ranged = def ~= nil and def.ranged == true
		if player:GetAttribute(MobData.HeldRangedAttribute) ~= ranged then
			player:SetAttribute(MobData.HeldRangedAttribute, ranged)
		end
	end
end

function ProjectileService.start()
	if started then
		return
	end
	started = true
	Remotes.event(Remotes.ShootRequest).OnServerEvent:Connect(onShoot)
	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
		for i = #shots, 1, -1 do
			if shots[i].owner == player then
				table.remove(shots, i)
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		heldAccum += dt
		if heldAccum >= HELD_POLL_SECONDS then
			heldAccum = 0
			updateHeld()
		end
		if #shots > 0 then
			step(dt)
		end
	end)
end

return ProjectileService
