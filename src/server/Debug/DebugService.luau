--!strict
-- Studio-only debug commands. Inert (start() is a no-op, run() rejects) on published servers.
-- Each command writes state to attributes (Config.Debug.*) and notifies plug-in handlers from the registry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local DebugCommands = require(Shared.logic.DebugCommands)
local TpResolve = require(Shared.logic.TpResolve)
local ItemCatalog = require(Shared.ItemCatalog)
local Guard = require(script.Parent.Parent.Net.Guard)
local Rarity = require(Shared.data.Rarity)

export type Handler = (player: Player, arg: unknown) -> ()

local DebugService = {}

local D = Config.Debug
local registry: { [string]: { Handler } } = {}
local connections: { RBXScriptConnection } = {}
local ownedForceFields: { [Player]: ForceField } = {}
local playerConnections: { [Player]: RBXScriptConnection } = {}
local exposed: { [string]: { [string]: any } } = {}
local bridge: BindableFunction? = nil
local started = false

local limits: DebugCommands.Limits = {
	maxDay = D.MaxDay,
	maxClockSpeed = D.MaxClockSpeed,
	maxSeed = D.MaxSeed,
	ringCount = D.RingCount,
	darkEvents = D.DarkEvents,
	itemIds = (function(): { string }
		local ids: { string } = {}
		for id in ItemCatalog.Items do
			table.insert(ids, id)
		end
		return ids
	end)(),
	mobKinds = D.MobKinds,
	gallerySets = Config.Art.GallerySets,
}

function DebugService.isActive(): boolean
	return RunService:IsStudio()
end

-- Other systems plug in here. Returns an unregister function.
function DebugService.register(command: string, handler: Handler): () -> ()
	local list = registry[command]
	if not list then
		list = {}
		registry[command] = list
	end
	table.insert(list, handler)
	return function()
		local l = registry[command]
		local i = l and table.find(l, handler)
		if l and i then
			table.remove(l, i)
		end
	end
end

-- Registers a service API for the Studio-only QA bridge (MCP/command-bar code runs in another VM
-- and gets fresh module copies, so it must call the live services through this bridge).
function DebugService.expose(name: string, api: { [string]: any })
	exposed[name] = api
end

local function onBridgeInvoke(service: unknown, fn: unknown, ...: any): ...any
	if type(service) ~= "string" or type(fn) ~= "string" then
		error("bridge: service and fn must be strings")
	end
	local api = exposed[service]
	local f = api and api[fn]
	if type(f) ~= "function" then
		error(`bridge: unknown {service}.{fn}`)
	end
	return f(...)
end

local function setInvincible(player: Player, on: boolean)
	local existing = ownedForceFields[player]
	if existing then
		existing:Destroy()
		ownedForceFields[player] = nil
	end
	if on and player.Character then
		local ff = Instance.new("ForceField")
		ff.Visible = false
		ff.Parent = player.Character
		ownedForceFields[player] = ff
	end
end

local function worldAttribute(name: string): string
	local map: { [string]: string } = {
		setDay = D.WorldDayAttribute,
		clockSpeed = D.WorldClockSpeedAttribute,
		blizzard = D.WorldBlizzardAttribute,
		darkEvent = D.WorldDarkEventAttribute,
		stalker = D.WorldStalkerAttribute,
	}
	return map[name] or ""
end

-- Validates and applies one command. Returns ok, message. Safe to call from server code too.
function DebugService.run(player: Player, name: unknown, arg: unknown): (boolean, string)
	if not DebugService.isActive() then
		return false, "inactive"
	end
	local ok, value = DebugCommands.validate(name, arg, limits)
	if not ok then
		return false, tostring(value)
	end
	local command = name :: string
	if command == "invincible" then
		player:SetAttribute(D.PlayerInvincibleAttribute, value :: boolean)
		setInvincible(player, value :: boolean)
	elseif command == "teleportRing" then
		player:SetAttribute(D.PlayerRingAttribute, value :: number)
	elseif DebugCommands.ACTION_ONLY[command] then
		if #(registry[command] or {}) == 0 then
			return false, "no handler registered"
		end
	else
		Workspace:SetAttribute(worldAttribute(command), value :: any)
	end
	local handlers: { Handler } = table.clone(registry[command] or {})
	for _, handler in handlers do
		local success, err = pcall(handler :: any, player, value)
		if not success then
			warn(`[Debug] handler for {command} failed: {err}`)
		end
	end
	return true, "ok"
end

local function onCharacterAdded(player: Player)
	if player:GetAttribute(D.PlayerInvincibleAttribute) == true then
		setInvincible(player, true)
	end
end

-- Built-in handlers (items round): structures, tp, chest, seed, respawn. Services are required lazily so this
-- module never creates a require cycle; everything runs server side after DebugService.run validated the arg.
local function say(player: Player, text: string)
	print(`[Debug] {text}`)
	Remotes.event(Remotes.Notify):FireClient(player, "build", text)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Live services come through the expose() registry (init.server / MassiveService), never a static require:
-- SurvivalService and others already depend on this module.
local function worldService(name: string): any
	local api = exposed[name]
	if api == nil then
		error(`service {name} not exposed (run server only)`)
	end
	return api
end

-- Sites sorted nearest first from a point: { site, distance }.
local function sitesByDistance(from: Vector3): { { site: any, distance: number } }
	local out: { { site: any, distance: number } } = {}
	for _, site in worldService("Chunk").getSites() do
		local dx, dz = site.x - from.X, site.z - from.Z
		table.insert(out, { site = site, distance = math.sqrt(dx * dx + dz * dz) })
	end
	table.sort(out, function(a, b)
		return a.distance < b.distance
	end)
	return out
end

local function onStructures(player: Player)
	local root = rootOf(player)
	if root == nil then
		return
	end
	local list = sitesByDistance(root.Position)
	if #list == 0 then
		say(player, "no massive structures in this world")
		return
	end
	for i = 1, math.min(#list, D.NearestListMax) do
		local e = list[i]
		say(
			player,
			`{i}. {e.site.key} ring {e.site.ring} {math.floor(e.distance)} studs at ({math.floor(
				e.site.x
			)}, {math.floor(e.site.z)})`
		)
	end
end

-- /debug tp <query>: the pure resolver (TpResolve) picks the target by fuzzy name, then the Chunk service waits
-- for that chunk's terrain, grounds with SiteGround and PivotTo. Prints the resolved name and coordinates, or why not.
local function onTeleport(player: Player, target: unknown)
	local t = target :: DebugCommands.TpTarget
	local root = rootOf(player)
	if root == nil then
		say(player, "tp: no character to move")
		return
	end
	local chunks = worldService("Chunk")
	local sites: { TpResolve.Site } = {}
	for _, site in chunks.getSites() do
		table.insert(sites, {
			key = site.key,
			id = site.id,
			x = site.x,
			z = site.z,
			ring = site.ring,
			radius = site.radius,
		})
	end
	local others: { TpResolve.PlayerPos } = {}
	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		if other ~= player and otherRoot then
			table.insert(
				others,
				{ name = other.Name, x = otherRoot.Position.X, z = otherRoot.Position.Z }
			)
		end
	end
	local result = TpResolve.resolve(t.text, {
		ringCount = D.RingCount,
		from = { x = root.Position.X, z = root.Position.Z },
		selfName = player.Name,
		sites = sites,
		players = others,
		aliases = D.TpAliases,
		ringPoint = function(n: number): TpResolve.Vec2?
			return chunks.ringPoint(n)
		end,
		gap = D.TeleportStructureGap,
		playerOffset = D.TeleportPlayerOffset,
	})
	if not result.ok then
		say(player, `tp: {result.error}`)
		return
	end
	-- Yields while the chunk streams in; run off the remote handler thread.
	task.spawn(function()
		local at: Vector3? = chunks.teleportGrounded(
			player,
			result.x,
			result.z,
			D.TeleportBodySize,
			D.TeleportLift,
			D.TeleportWaitSeconds
		)
		if at == nil then
			say(
				player,
				`tp {result.name}: terrain at ({math.floor(result.x)}, {math.floor(result.z)}) did not load; not moved`
			)
		else
			say(
				player,
				`tp -> {result.name} at ({math.floor(at.X)}, {math.floor(at.Y)}, {math.floor(at.Z)})`
			)
		end
	end)
end

local function onChest(player: Player, rarity: unknown)
	local root = rootOf(player)
	if root == nil or not Rarity.isRarity(rarity) then
		return
	end
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local dir = if flat.Magnitude > 0.001 then flat.Unit else Vector3.new(0, 0, -1)
	local pos = root.Position + dir * D.ChestSpawnDistance
	local ground = worldService("Chunk").heightAt(pos.X, pos.Z) or root.Position.Y
	local at = Vector3.new(pos.X, math.max(ground, root.Position.Y - D.TeleportLift), pos.Z)
	worldService("Loot").RegisterDebugChest({
		Position = at,
		Depth = 0,
		StructureType = "debug",
		Index = os.time() % 100000,
	}, rarity :: string, Workspace)
	say(player, `spawned a {rarity} chest`)
end

local function onSeed(player: Player, value: unknown)
	local chunks = worldService("Chunk")
	if type(value) ~= "number" then
		say(player, `world seed {chunks.getSeed()}`)
		return
	end
	-- Chest rolls and picks change; structures rebuild near players. The world layout is fixed per run.
	worldService("Massive").reset(value :: number)
	say(player, `run (loot) seed set to {value}; world layout stays {chunks.getSeed()}`)
end

local function onRespawn(player: Player)
	-- The one real revive/respawn path (docs/systems/hud.md: SurvivalService.respawn), never attributes by hand.
	if not worldService("Survival").respawn(player) then
		say(player, "respawn: already alive")
	end
end

local function registerBuiltins()
	DebugService.register("structures", onStructures)
	DebugService.register("tp", onTeleport)
	DebugService.register("chest", onChest)
	DebugService.register("seed", onSeed)
	DebugService.register("respawn", onRespawn)
end

local function onPlayerAdded(player: Player)
	if playerConnections[player] then
		return
	end
	playerConnections[player] = player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
end

local function clearPlayerState(player: Player)
	setInvincible(player, false)
	player:SetAttribute(D.PlayerInvincibleAttribute, nil)
	player:SetAttribute(D.PlayerRingAttribute, nil)
end

local function onPlayerRemoving(player: Player)
	local conn = playerConnections[player]
	if conn then
		conn:Disconnect()
		playerConnections[player] = nil
	end
	clearPlayerState(player)
end

local function clearWorldState()
	for _, attr in
		{
			D.WorldDayAttribute,
			D.WorldClockSpeedAttribute,
			D.WorldBlizzardAttribute,
			D.WorldDarkEventAttribute,
			D.WorldStalkerAttribute,
		}
	do
		Workspace:SetAttribute(attr, nil)
	end
end

function DebugService.start()
	if started or not DebugService.isActive() then
		return
	end
	started = true
	registerBuiltins()
	local remote = Remotes.event(Remotes.DebugCommand)
	table.insert(
		connections,
		remote.OnServerEvent:Connect(function(player: Player, name: unknown, arg: unknown)
			-- type-check and range-check happen in run (DebugCommands.validate) before any state change;
			-- rate limit comes first for cheap rejection of spam.
			if
				type(name) ~= "string"
				or not Guard.rateLimit(player, "DebugCommand", D.CommandRateInterval)
			then
				return
			end
			local ok, msg = DebugService.run(player, name, arg)
			if not ok then
				warn(`[Debug] {player.Name} {name}: {msg}`)
			end
		end)
	)
	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	-- Studio-only QA bridge: ServerStorage[D.BridgeName]:Invoke(service, fn, ...) -> results.
	local b = Instance.new("BindableFunction")
	b.Name = D.BridgeName
	b.OnInvoke = onBridgeInvoke
	b.Parent = ServerStorage
	bridge = b
end

function DebugService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for player, conn in playerConnections do
		conn:Disconnect()
		playerConnections[player] = nil
	end
	for _, player in Players:GetPlayers() do
		clearPlayerState(player)
	end
	for player in ownedForceFields do
		setInvincible(player, false)
	end
	clearWorldState()
	if bridge then
		bridge:Destroy()
		bridge = nil
	end
	started = false
end

return DebugService
