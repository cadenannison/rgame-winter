--!strict
-- Wiring for massive structures + loot chests (integration round). One Heartbeat loop for all structures
-- and players (Config.Massive.DressingCheckInterval):
--   1. validate live structures: a covering chunk that unloaded or was rebuilt overwrote the carved voids,
--      so the structure is destroyed (neighbouring chunks get their terrain refreshed) and rebuilt later;
--   2. build at most one eligible site per tick (every covering chunk loaded with its terrain finished,
--      nearest to a player first, never more than Config.Massive.MaxLiveStructures live);
--   3. Handle.Update(playerPositions) for every live structure.
-- Chest slots become LootService chests (Ring from the site, Index per slot). Opened chests are remembered
-- for the run so a rebuilt structure does not refill them. Temple crypt dread feeds DreadService.
-- Run start/end: LootService.ResetRun and every structure destroyed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Logic = Shared:WaitForChild("logic")
local MassivePlacement = require(Logic:WaitForChild("MassivePlacement"))
local LootChests = require(Logic:WaitForChild("LootChests"))
local Server = ServerScriptService:WaitForChild("Server")
local ChunkService = require(script.Parent:WaitForChild("ChunkService"))
local LootService = require(Server:WaitForChild("Loot"):WaitForChild("LootService"))
local ChestArt = require(Server:WaitForChild("Art"):WaitForChild("ChestArt"))
local MobService = require(Server:WaitForChild("Mobs"):WaitForChild("MobService"))
local DebugService = require(Server:WaitForChild("Debug"):WaitForChild("DebugService"))
local DreadService = require(Server:WaitForChild("Horror"):WaitForChild("DreadService"))
local RunLifecycleService = require(Server:WaitForChild("Run"):WaitForChild("RunLifecycleService"))
local Structures = script.Parent:WaitForChild("Structures")

local M = Config.Massive
local L = Config.Loot
local DREAD_PICK_RANGE = M.DressingSpawnRadius -- nearest player within this of a dread zone gets the dread

-- Minimal handle surface common to both structure kits.
type Handle = {
	Model: Model,
	ChestSlots: { { Position: Vector3, Depth: number, StructureType: string, Room: string? } },
	Update: (playerPositions: { Vector3 }) -> (),
	Destroy: () -> (),
	DreadListener: ((position: Vector3, kind: string) -> ())?,
}
type Builder = (origin: Vector3, seed: number, parent: Instance) -> Handle

local BUILDERS: { [string]: Builder } = {
	ResearchStation = require(Structures:WaitForChild("ResearchStation")).build :: any,
	MineComplex = require(Structures:WaitForChild("MineComplex")).build :: any,
	FrozenShipwreck = require(Structures:WaitForChild("FrozenShipwreck")).build :: any,
	RuinedTemple = require(Structures:WaitForChild("RuinedTemple")).build :: any,
	RangerLodge = require(Structures:WaitForChild("RangerLodge")).build :: any,
	ExpandedRuins = require(Structures:WaitForChild("RuinsComplex")).build :: any,
}

type Live = {
	site: MassivePlacement.Site,
	handle: Handle,
	stamps: { [number]: number },
	chests: { Instance },
	chestCount: number, -- real chests this structure holds (selected slots)
	conns: { RBXScriptConnection },
}

local MassiveService = {}

local live: { [string]: Live } = {}
local liveCount = 0
local failed: { [string]: boolean } = {}
local lootSeed: number? = nil -- run seed used for chest picks (Studio /debug seed can change it)
local openedRarity: { [string]: string } = {} -- chest key -> rarity of chests already opened this run
local started = false
local ended = false
local accumulator = 0
local heartbeat: RBXScriptConnection? = nil
local unregisterEnd: (() -> ())? = nil

local function playerPositions(): { Vector3 }
	local out: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			table.insert(out, hrp.Position)
		end
	end
	return out
end

-- Parts the live structures may hold (budget + chest art), for the chunk streaming cap.
function MassiveService.livePartsEstimate(): number
	local total = 0
	for _, entry in live do
		local def = M.Structures[entry.site.id]
		total += def.Budget.Parts + entry.chestCount * M.ChestsPerPartAllowance
	end
	return total
end

local function chestKey(site: MassivePlacement.Site, index: number): string
	return `{site.key}:{index}`
end

local function registerChests(entry: Live)
	local site, handle = entry.site, entry.handle
	-- Only a deterministic, spread-out subset of the plan's slots become chests (Config.Loot.Chests).
	local candidates: { LootChests.Candidate } = {}
	for i, slot in handle.ChestSlots do
		table.insert(candidates, { index = i, room = slot.Room, depth = slot.Depth })
	end
	local picks = LootChests.selectSlots(
		site.id,
		lootSeed or ChunkService.getSeed() or 0,
		site.key,
		candidates,
		site.ring
	)
	entry.chestCount = #picks
	for _, pick in picks do
		local i = pick.index
		local slot = handle.ChestSlots[i]
		local key = chestKey(site, i)
		local opened = openedRarity[key]
		if opened ~= nil then
			-- Already looted this run: show it open and empty, never registered with LootService.
			local model = ChestArt.build(opened, CFrame.new(slot.Position), handle.Model)
			ChestArt.setOpened(model, true)
			continue
		end
		local chest = LootService.RegisterChest({
			Position = slot.Position,
			Depth = slot.Depth,
			StructureType = slot.StructureType,
			Ring = site.ring,
			Index = i,
			ChunkKey = tostring(site.chunks[1]),
			TopMode = pick.topMode,
		}, handle.Model)
		table.insert(entry.chests, chest)
		table.insert(
			entry.conns,
			chest:GetAttributeChangedSignal(L.ChestOpenedAttribute):Connect(function()
				if chest:GetAttribute(L.ChestOpenedAttribute) == true then
					local rarity = chest:GetAttribute(L.ChestRarityAttribute)
					openedRarity[key] = if type(rarity) == "string" then rarity else "common"
				end
			end)
		)
	end
end

local function nearestPlayer(position: Vector3): Player?
	local best: Player? = nil
	local bestD = DREAD_PICK_RANGE
	for _, player in Players:GetPlayers() do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			local d = (hrp.Position - position).Magnitude
			if d <= bestD then
				best, bestD = player, d
			end
		end
	end
	return best
end

local function destroyLive(key: string, refreshNeighbours: boolean)
	local entry = live[key]
	if not entry then
		return
	end
	live[key] = nil
	liveCount -= 1
	for _, c in entry.conns do
		c:Disconnect()
	end
	for _, chest in entry.chests do
		LootService.UnregisterChest(chest)
	end
	local ok = pcall(entry.handle.Destroy)
	if not ok then
		warn(`[Massive] destroy {key} failed`)
	end
	if refreshNeighbours then
		-- Terrain voids/pad stay in chunks that did not rebuild: regenerate them.
		for _, index in entry.site.chunks do
			if
				ChunkService.isLoaded(index)
				and ChunkService.generation(index) == entry.stamps[index]
			then
				ChunkService.refreshTerrain(index)
			end
		end
	end
end

local function build(site: MassivePlacement.Site, seed: number)
	local builder = BUILDERS[site.id]
	local stamps: { [number]: number } = {}
	for _, index in site.chunks do
		stamps[index] = ChunkService.generation(index)
	end
	local ok, handleOrErr = pcall(function(): Handle
		return builder(Vector3.new(site.x, site.y, site.z), seed, Workspace)
	end)
	if not ok then
		failed[site.key] = true
		warn(`[Massive] build {site.key} failed: {handleOrErr}`)
		return
	end
	local handle = handleOrErr :: Handle
	local entry: Live =
		{ site = site, handle = handle, stamps = stamps, chests = {}, chestCount = 0, conns = {} }
	live[site.key] = entry
	liveCount += 1
	handle.DreadListener = function(position: Vector3, _kind: string)
		local player = nearestPlayer(position)
		if player then
			DreadService.addSighting(player, Config.Dread.GainLurkerSighting * M.TempleDreadScale)
		end
	end
	registerChests(entry)
end

local function eligible(site: MassivePlacement.Site): boolean
	if live[site.key] or failed[site.key] then
		return false
	end
	for _, index in site.chunks do
		if not ChunkService.isTerrainReady(index) then
			return false
		end
	end
	return true
end

local function distanceToNearest(site: MassivePlacement.Site, positions: { Vector3 }): number
	local best = math.huge
	for _, p in positions do
		best = math.min(best, math.sqrt((p.X - site.x) ^ 2 + (p.Z - site.z) ^ 2))
	end
	return best
end

local function tick()
	local seed = ChunkService.getSeed()
	if ended or seed == nil then
		return
	end
	-- 1. validate
	for key, entry in table.clone(live) do
		local stale = false
		for _, index in entry.site.chunks do
			if
				not ChunkService.isLoaded(index)
				or ChunkService.generation(index) ~= entry.stamps[index]
			then
				stale = true
				break
			end
		end
		if stale then
			destroyLive(key, true)
		end
	end
	-- 2. build one (stream out a live structure no player is near when a nearer site is waiting)
	local positions = playerPositions()
	if liveCount >= M.MaxLiveStructures and #positions > 0 then
		for key, entry in table.clone(live) do
			if
				distanceToNearest(entry.site, positions)
				> entry.site.radius + M.DressingDespawnRadius
			then
				for _, site in ChunkService.getSites() do
					if
						eligible(site)
						and distanceToNearest(site, positions)
							< distanceToNearest(entry.site, positions)
					then
						destroyLive(key, true)
						break
					end
				end
			end
		end
	end
	if liveCount < M.MaxLiveStructures and #positions > 0 then
		local best: MassivePlacement.Site? = nil
		local bestD = math.huge
		for _, site in ChunkService.getSites() do
			if eligible(site) then
				local d = distanceToNearest(site, positions)
				if d < bestD then
					best, bestD = site, d
				end
			end
		end
		if best then
			build(best, seed)
		end
	end
	-- 3. update
	for key, entry in live do
		local ok = pcall(entry.handle.Update, positions)
		if not ok then
			warn(`[Massive] update {key} failed`)
		end
	end
end

-- Run start/end: every structure gone, chests cleared, opened memory forgotten.
function MassiveService.reset(seed: number?)
	for key in table.clone(live) do
		destroyLive(key, false)
	end
	table.clear(failed)
	table.clear(openedRarity)
	lootSeed = seed
	LootService.ResetRun(seed)
end

function MassiveService.liveCount(): number
	return liveCount
end

function MassiveService.start()
	if started then
		return
	end
	started = true
	ended = false
	LootService.SetArtBuilder(function(slot, rarity, parent)
		return ChestArt.build(rarity, CFrame.new(slot.Position), parent)
	end)
	LootService.start()
	DebugService.expose("Massive", MassiveService) -- Studio /debug seed
	DebugService.expose("Loot", LootService) -- Studio /debug chest
	MassiveService.reset(ChunkService.getSeed())
	ChunkService.setExtraPartsProvider("massive", MassiveService.livePartsEstimate)
	-- Mob spawns are excluded from every massive structure footprint (live or not).
	MobService.setSpawnBlocker(function(x: number, z: number): boolean
		return MassivePlacement.blocks(ChunkService.getSites(), x, z)
	end)
	unregisterEnd = RunLifecycleService.onRunEnded(function()
		ended = true
		MassiveService.reset(nil)
	end)
	heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < M.DressingCheckInterval then
			return
		end
		accumulator = 0
		tick()
	end)
end

function MassiveService.stop()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if unregisterEnd then
		unregisterEnd()
		unregisterEnd = nil
	end
	ChunkService.setExtraPartsProvider("massive", nil)
	MobService.setSpawnBlocker(nil)
	MassiveService.reset(nil)
	started = false
end

return MassiveService
