--!strict
-- Shared mob actions used by the drivers and species modules: hit a player (server-recomputed, invincibility
-- and hit handler honoured), chew structures, move helpers, the legacy windup flag.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local FireRepel = require(Shared.logic.FireRepel)
local MobState = require(script.Parent.MobState)
local Types = require(script.Parent.MobTypes)

type MobRow = Types.MobRow
type PlayerInfo = Types.PlayerInfo

local NIGHT = Config.Night
local MOBS = Config.Mobs

local MobActions = {}

local hitHandler: ((Player, string) -> ())? = nil

-- Wiring (init.server): called with (player, kindName) just before a mob hit damages a player.
function MobActions.setHitHandler(fn: ((Player, string) -> ())?)
	hitHandler = fn
end

function MobActions.setWindup(row: MobRow, on: boolean)
	if (row.model:GetAttribute(NIGHT.WindupAttribute) == true) ~= on then
		row.model:SetAttribute(NIGHT.WindupAttribute, on)
	end
end

local function biteSeq(player: Player)
	local n = player:GetAttribute(NIGHT.BiteAttribute)
	player:SetAttribute(NIGHT.BiteAttribute, (if type(n) == "number" then n else 0) + 1)
end

-- Damages a player (bite / slam / charge): never into invincible players; the caller has already verified
-- reach and fire rules at this moment. Returns true when damage was dealt.
function MobActions.dealDamage(row: MobRow, info: PlayerInfo): boolean
	if info.player:GetAttribute(Config.Debug.PlayerInvincibleAttribute) == true then
		return false
	end
	local onHit = hitHandler
	if onHit then
		pcall(onHit, info.player, row.kind.name)
	end
	info.humanoid:TakeDamage(row.damage)
	biteSeq(info.player)
	return true
end

-- A landed strike: State holds Attack for the client swing, then damage via dealDamage.
function MobActions.strike(row: MobRow, info: PlayerInfo, now: number): boolean
	MobState.attacked(row, now)
	return MobActions.dealDamage(row, info)
end

-- Damages the nearest wall/door within reach (server-side; StructureHealth is owned by structures).
function MobActions.breakStructure(row: MobRow, pos: Vector3): boolean
	local reach = row.kind.stats.AttackRange + row.kind.stats.HitRadius
	local best: Instance? = nil
	local bestDist = reach
	for _, structure in CollectionService:GetTagged(Config.Build.BlockerTag) do
		local p: Vector3? = nil
		if structure:IsA("Model") then
			p = structure:GetPivot().Position
		elseif structure:IsA("BasePart") then
			p = structure.Position
		end
		if p then
			local d = (p - pos).Magnitude
			if d <= bestDist then
				bestDist = d
				best = structure
			end
		end
	end
	if not best then
		return false
	end
	local health = best:GetAttribute(Config.Build.HealthAttribute)
	if type(health) == "number" then
		local left = health - row.damage
		if left <= 0 then
			best:Destroy()
		else
			best:SetAttribute(Config.Build.HealthAttribute, left)
		end
	end
	return true
end

-- Walks toward a flat point at a speed.
function MobActions.moveToward(row: MobRow, x: number, z: number, speed: number)
	row.humanoid.WalkSpeed = speed
	row.humanoid:MoveTo(Vector3.new(x, row.root.Position.Y, z))
end

function MobActions.stop(row: MobRow)
	row.humanoid:MoveTo(row.root.Position)
end

-- Random wander step (same rhythm as the legacy mobs).
function MobActions.wander(row: MobRow, now: number, rng: Random)
	row.humanoid.WalkSpeed = row.kind.stats.WalkSpeed
	if now >= row.wanderUntil then
		row.wanderUntil = now + MOBS.WanderInterval * (0.5 + rng:NextNumber())
		local angle = rng:NextNumber(0, math.pi * 2)
		row.humanoid:MoveTo(
			row.root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * MOBS.WanderRadius
		)
	end
end

-- The fire whose repel edge the mob stands in (hostile species back off from lit fires), else nil.
function MobActions.insideFire(row: MobRow, fires: { FireRepel.Fire }): FireRepel.Fire?
	local pos = row.root.Position
	local index =
		FireRepel.insideAny(pos.X, pos.Z, fires, NIGHT.RepelMargin, Config.Fire.RepelRadius)
	return if index then fires[index] else nil
end

return MobActions
