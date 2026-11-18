--!strict
-- Mini-bosses (one per far biome, killable, later in the run) and the blizzard boss (spawn requested by
-- EventService, nil-safe). Bosses are spawned through MobService (one AI loop); this module only decides
-- when and where. A boss kill reaches RunLifecycleService.RecordKill(player, true) through
-- MobService.setKillHandler (isBoss = true), wired in init.server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Biomes = require(Shared.data.Biomes)
local MobData = require(Shared.data.Mobs)
local MobScaling = require(Shared.logic.MobScaling)
local MobService = require(script.Parent.MobService)

local BOSS_KIND = "WhiteoutBeast"
local APPROACH_FRACTION = 0.8 -- blizzard boss starts this fraction of its aggro range from camp

local BossService = {}

local started = false
local eventsWired = false
local lastKilledDay: { [string]: number } = {}
local campProvider: (() -> Vector3?)? = nil
local rng = Random.new()

-- Brief 18 wires ChunkService.getCampPosition (nil-safe: no camp, no blizzard boss).
function BossService.setCampProvider(fn: (() -> Vector3?)?)
	campProvider = fn
end

local function aliveOfCategory(category: string): number
	local n = 0
	for _, live in MobService.getLive() do
		local def = MobData.ByKind[live.kind]
		if def and def.category == category then
			n += 1
		end
	end
	return n
end

local function isAlive(kind: string): boolean
	for _, live in MobService.getLive() do
		if live.kind == kind then
			return true
		end
	end
	return false
end

local function spawnBoss(kind: string, position: Vector3): Model?
	local def = MobData.ByKind[kind]
	if not def then
		return nil
	end
	local health = MobScaling.bossHealth(def.health, MobService.getPartyCount())
	local damage = MobScaling.bossDamage(def.damage, MobService.getDay())
	return MobService.spawnScaled(kind, position, health, damage)
end

-- Mini-bosses: every spawn tick, a far-biome player with no live guardian of that kind and a cooled-down
-- respawn timer gets one placed at spawn distance (so it is inside the streamed area).
local function onSpawnTick(
	infos: { { player: Player, root: BasePart, humanoid: Humanoid } },
	day: number
)
	local alive = aliveOfCategory("miniboss")
	for _, def in MobData.List do
		if def.category == "miniboss" and not isAlive(def.kind) then
			if MobScaling.miniBossDue(def.minDay, day, alive, lastKilledDay[def.kind]) then
				for _, info in infos do
					local biome = Biomes.forRing(MobService.ringAt(info.root.Position)).id
					if table.find(def.biomes, biome) then
						local at = MobService.groundNear(
							info.root.Position,
							Config.Mobs.SpawnMinDistance,
							Config.Mobs.SpawnMaxDistance
						)
						if at and spawnBoss(def.kind, at) then
							alive += 1
						end
						break
					end
				end
			end
		end
	end
end

-- Blizzard boss: spawned near camp, approaching from a random side. Returns nil when too early or one
-- already lives (never two blizzard bosses).
function BossService.spawnBlizzardBoss(campPos: Vector3): Model?
	if typeof(campPos) ~= "Vector3" then
		return nil
	end
	local def = MobData.ByKind[BOSS_KIND]
	if
		not def
		or MobService.getDay() < Config.Bosses.BlizzardBossFirstDay
		or isAlive(BOSS_KIND)
	then
		return nil
	end
	local at = MobService.groundNear(campPos, def.aggroRange * APPROACH_FRACTION, def.aggroRange)
	if not at then
		return nil
	end
	local model = spawnBoss(BOSS_KIND, at)
	if model then
		local cue = Remotes.event(Remotes.Cue)
		for _, player in Players:GetPlayers() do
			cue:FireClient(player, { kind = "BossWarning", position = at })
		end
	end
	return model
end

-- Selected blizzards: roll the capped chance, then spawn at camp.
function BossService.onBlizzardStart()
	if rng:NextNumber() >= MobScaling.blizzardBossChance(MobService.getDay()) then
		return
	end
	local provider = campProvider
	local camp = if provider then provider() else nil
	if camp then
		BossService.spawnBlizzardBoss(camp)
	end
end

-- Brief 18 wiring: pass EventService.onBlizzardStart (nil-safe when the events API is absent).
function BossService.wireEvents(onBlizzardStart: ((() -> ()) -> ())?)
	if onBlizzardStart then
		eventsWired = true
		onBlizzardStart(BossService.onBlizzardStart)
	end
end

function BossService.start()
	if started then
		return
	end
	started = true
	MobService.addSpawnHook(function(infos, day)
		onSpawnTick(infos, day)
	end)
	MobService.onKilled(function(_model, kind, _killer)
		local def = MobData.ByKind[kind]
		if def and def.category == "miniboss" then
			lastKilledDay[kind] = MobService.getDay()
		end
	end)
	-- Fallback trigger when no events API was wired: the visible Blizzard attribute turning on.
	Workspace:GetAttributeChangedSignal(Config.Blizzard.ActiveAttribute):Connect(function()
		if not eventsWired and Workspace:GetAttribute(Config.Blizzard.ActiveAttribute) == true then
			BossService.onBlizzardStart()
		end
	end)
end

return BossService
