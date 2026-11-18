--!strict
-- Player -> mob combat: AttackRequest validation, server-computed melee damage, kill / drop flow.
-- Order for the remote: type-check -> sanity -> Guard rate limit -> state -> act (docs/systems/mobs.md).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemCatalog = require(Shared.ItemCatalog)
local MobRules = require(Shared.logic.MobRules)
local MobSpecies = require(Shared.logic.MobSpecies)
local Server = script.Parent.Parent
local Guard = require(Server.Net.Guard)
local SwingRelay = require(Server.Atmosphere.SwingRelay)
local InventoryService = require(Server.Items.InventoryService)
local MobRegistry = require(script.Parent.MobRegistry)
local MobState = require(script.Parent.MobState)
local MobWorld = require(script.Parent.MobWorld)
local Types = require(script.Parent.MobTypes)

type MobRow = Types.MobRow

local MOBS = Config.Mobs
local HEALTH_ATTRIBUTE = MOBS.HealthAttribute

local MobCombat = {}

local killHandler: ((Player, string, boolean) -> ())? = nil
local killedListeners: { (Model, string, Player?) -> () } = {}
local lastMeleeAt: { [Player]: number } = {}
local rng = Random.new()

-- Wiring (init.server): called with (player, kindName, isBoss) when a player kills a mob.
function MobCombat.setKillHandler(fn: ((Player, string, boolean) -> ())?)
	killHandler = fn
end

-- Called once per kill (any source) with (model, kindName, killer?). Used by BossService.
function MobCombat.onKilled(fn: (Model, string, Player?) -> ())
	table.insert(killedListeners, fn)
end

-- Killed: unregister at once (no second kill, no AI), publish health 0, remove after a short delay so
-- clients can play the hit confirm on the attribute change.
local function killMob(row: MobRow)
	local model = row.model
	MobRegistry.unregister(model)
	CollectionService:RemoveTag(model, MOBS.Tag)
	row.root.Anchored = true
	model:SetAttribute(HEALTH_ATTRIBUTE, 0)
	MobState.death(row)
	task.delay(MOBS.DeathRemoveDelay, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

function MobCombat.resolve(target: Instance): MobRow?
	local model: Instance? = target
	if target:IsA("BasePart") then
		model = target.Parent
	end
	if model and model:IsA("Model") then
		return MobRegistry.get(model)
	end
	return nil
end

-- Species drops straight to the killer's inventory (rolled server-side from Config.Mobs.Species).
local function giveDrops(row: MobRow, killer: Player)
	local def = row.kind.species
	if not def then
		return
	end
	local drops = MobSpecies.rollDrops(def.drops, function()
		return rng:NextNumber()
	end)
	for _, drop in drops do
		InventoryService.add(killer, drop.id, drop.count)
	end
end

-- Applies server-computed damage. killer = the player credited (kill record, drop); nil for traps.
function MobCombat.applyDamage(row: MobRow, damage: number, killer: Player?)
	if MobRegistry.get(row.model) ~= row then
		return -- already dead or removed
	end
	row.health -= damage
	row.model:SetAttribute(HEALTH_ATTRIBUTE, math.max(0, row.health))
	if row.health > 0 then
		row.provoked = true -- Retaliate / TerritorialWarn read this on the next AI step
		MobState.hurt(row, os.clock())
		return
	end
	local stats = row.kind.stats
	local name = row.kind.name
	killMob(row)
	if killer then
		local onKill = killHandler
		if onKill then
			pcall(onKill, killer, name, row.isBoss)
		end
		-- Drop goes straight to the killer's inventory (no world pickups yet).
		if stats.DropId and stats.DropCount > 0 then
			InventoryService.add(killer, stats.DropId, stats.DropCount)
		end
		giveDrops(row, killer)
	end
	for _, listener in killedListeners do
		pcall(listener, row.model, name, killer)
	end
end

local function onAttack(player: Player, target: unknown)
	-- 1. type check
	if typeof(target) ~= "Instance" then
		return
	end
	local instance = target :: Instance
	-- 2. sanity: must be a live registered mob
	local row = MobCombat.resolve(instance)
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
	local dist =
		MobRules.distance(MobWorld.toPoint(root.Position), MobWorld.toPoint(row.root.Position))
	local reach = Config.Combat.MeleeRange + row.kind.stats.HitRadius
	if not MobRules.canMelee(dist, reach, Config.Combat.LagCompensation) then
		return
	end
	lastMeleeAt[player] = now
	SwingRelay.notify(player) -- accepted swing: other clients animate it
	-- Damage from the equipped item: weapon data, gather tool = Combat.ToolDamage, else MeleeBaseDamage.
	local held = InventoryService.getSelected(player)
	local def = if held then ItemCatalog.Items[held.id] else nil
	-- A bow in melee is a fist: its damage is per arrow (ProjectileService).
	local isWeapon = def ~= nil
		and def.kind == "weapon"
		and def.damage ~= nil
		and def.ranged ~= true
	local isTool = def ~= nil and def.kind == "tool"
	local damage = if isWeapon
			and def
			and def.damage
		then def.damage
		elseif isTool then Config.Combat.ToolDamage
		else Config.Combat.MeleeBaseDamage
	if isWeapon or isTool then
		InventoryService.wearSelected(player, Config.Combat.WeaponDurabilityPerHit)
	end
	MobCombat.applyDamage(row, damage, player)
end

MobCombat.handleAttack = onAttack

-- Server-side damage for traps and projectiles (type + range checked). killer nil = no kill record or drop.
function MobCombat.damage(mob: Instance, amount: number, sourcePlayer: Player?)
	if typeof(mob) ~= "Instance" or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	local row = MobCombat.resolve(mob)
	if row and row.model.Parent then
		MobCombat.applyDamage(row, amount, sourcePlayer)
	end
end

function MobCombat.start()
	Players.PlayerRemoving:Connect(function(player)
		lastMeleeAt[player] = nil
	end)
	Remotes.event(Remotes.AttackRequest).OnServerEvent:Connect(onAttack)
end

return MobCombat
