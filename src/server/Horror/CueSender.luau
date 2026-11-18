--!strict
-- Sends Remotes.Cue to one player, throttled to one per Config.Cue.MinIntervalSeconds per player per kind.
-- Payloads carry only a kind, a coarse level, a position or an event id: never a hidden metric.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CueSender = {}

local lastSent: { [Player]: { [string]: number } } = {}
local validKinds: { [string]: boolean } = {}
for _, kind in Config.Cue.Kinds do
	validKinds[kind] = true
end
local connection: RBXScriptConnection? = nil

-- Returns true when the cue was sent (false when throttled or invalid).
function CueSender.send(player: Player, payload: Remotes.CuePayload): boolean
	if not validKinds[payload.kind] or player.Parent ~= Players then
		return false
	end
	local now = os.clock()
	local byKind = lastSent[player]
	if not byKind then
		byKind = {}
		lastSent[player] = byKind
	end
	local last = byKind[payload.kind]
	if last and now - last < Config.Cue.MinIntervalSeconds then
		return false
	end
	byKind[payload.kind] = now
	local out: Remotes.CuePayload = { kind = payload.kind }
	if payload.level ~= nil then
		out.level = math.clamp(math.floor(payload.level), 0, Config.Cue.MaxLevel)
	end
	out.position = payload.position
	out.event = payload.event
	Remotes.event(Remotes.Cue):FireClient(player, out)
	return true
end

function CueSender.start()
	if connection then
		return
	end
	connection = Players.PlayerRemoving:Connect(function(player: Player)
		lastSent[player] = nil
	end)
end

function CueSender.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	table.clear(lastSent)
end

return CueSender
