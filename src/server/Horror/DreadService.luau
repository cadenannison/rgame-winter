--!strict
-- Hidden per-party Dread (one party per run server). One Heartbeat accumulator steps it every
-- Dread.TickInterval. The only client view is the coarse DreadLevel cue, sent on change.
-- Dread is never written to an Attribute, a remote payload or the output.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DreadLogic = require(Shared.logic.DreadLogic)
local Isolation = require(Shared.logic.Isolation)
local HorrorWorld = require(script.Parent.HorrorWorld)
local CueSender = require(script.Parent.CueSender)

local D = Config.Dread

local DreadService = {}

local dread = 0
local snapshot: HorrorWorld.Snapshot? = nil
local sentLevel: { [Player]: number } = {}
local connections: { RBXScriptConnection } = {}
local accumulator = 0
local started = false

local function pushLevels()
	local level = DreadLogic.cueLevel(dread)
	for _, player in HorrorWorld.party() do
		if sentLevel[player] ~= level then
			if CueSender.send(player, { kind = "DreadLevel", level = level }) then
				sentLevel[player] = level
			end
		end
	end
end

local function tick(dt: number)
	local snap = HorrorWorld.snapshot()
	snapshot = snap
	if #snap.members == 0 then
		return
	end
	local allWarm = true
	local ring = 0
	for _, m in snap.members do
		allWarm = allWarm and m.warm
		ring = math.max(ring, m.ring)
	end
	dread = DreadLogic.step(dread, {
		isolation = Isolation.maxWeight(snap.weights),
		farFromCamp = snap.farFromCamp,
		dark = snap.dark,
		blizzard = snap.blizzard,
		nearFire = allWarm,
		day = snap.day,
		ring = ring,
		eventMultiplier = snap.modifiers.dreadGain,
	}, dt)
	pushLevels()
end

-- Server-only reads for StalkerService/LurkerService. Never forward these to a client.
function DreadService.value(): number
	return dread
end

-- Latest party snapshot (refreshed every Dread tick); builds one if none yet.
function DreadService.snapshot(): HorrorWorld.Snapshot
	local snap = snapshot
	if snap then
		return snap
	end
	local fresh = HorrorWorld.snapshot()
	snapshot = fresh
	return fresh
end

-- Whole party traveling together (EventService.setFullGroupPredicate; brief 18 wires).
function DreadService.isFullGroup(): boolean
	return DreadService.snapshot().fullGroup
end

-- Lurker sighting (or any one-off scare). Amount defaults to Dread.GainLurkerSighting.
function DreadService.addSighting(_player: Player, amount: number?)
	dread = DreadLogic.add(dread, amount or D.GainLurkerSighting)
	pushLevels()
end

function DreadService.start()
	if started then
		return
	end
	started = true
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			sentLevel[player] = nil
		end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator >= D.TickInterval then
				local step = accumulator
				accumulator = 0
				tick(step)
			end
		end)
	)
end

function DreadService.stop()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(sentLevel)
	started = false
	snapshot = nil
	dread = 0
	accumulator = 0
end

return DreadService
