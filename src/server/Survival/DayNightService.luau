--!strict
-- Server day/night clock. One Heartbeat connection; publishes Workspace attributes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DayClock = require(Shared.logic.DayClock)
local DebugService = require(script.Parent.Parent.Debug.DebugService)

local T = Config.Time
local HOUR_PRECISION = 10 -- hour attribute rounded to 1/10 hour to avoid per-frame writes

local DayNightService = {}

local elapsed = 0
local speed = 1
local started = false
local info: DayClock.Info = DayClock.at(0, T)
local connection: RBXScriptConnection? = nil
local unregisters: { () -> () } = {}

local function publish()
	info = DayClock.at(elapsed, T)
	Workspace:SetAttribute(T.DayAttribute, info.day)
	Workspace:SetAttribute(T.IsNightAttribute, info.isNight)
	Workspace:SetAttribute(
		T.ClockAttribute,
		math.floor(info.hour * HOUR_PRECISION + 0.5) / HOUR_PRECISION
	)
end

function DayNightService.getDay(): number
	return info.day
end

function DayNightService.isNight(): boolean
	return info.isNight
end

function DayNightService.getElapsed(): number
	return elapsed
end

function DayNightService.setDay(day: number)
	elapsed = DayClock.elapsedForDay(math.floor(day), T)
	publish()
end

function DayNightService.setClockSpeed(multiplier: number)
	speed = math.max(multiplier, 0)
end

function DayNightService.start()
	if started then
		return
	end
	started = true
	elapsed = 0
	speed = 1
	publish()
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt * speed
		publish()
	end)
	table.insert(
		unregisters,
		DebugService.register("setDay", function(_player, arg)
			if type(arg) == "number" then
				DayNightService.setDay(arg)
			end
		end)
	)
	table.insert(
		unregisters,
		DebugService.register("clockSpeed", function(_player, arg)
			if type(arg) == "number" then
				DayNightService.setClockSpeed(arg)
			end
		end)
	)
end

function DayNightService.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for _, unregister in unregisters do
		unregister()
	end
	table.clear(unregisters)
	started = false
end

return DayNightService
