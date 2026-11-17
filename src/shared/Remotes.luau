--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Remotes = {}

-- Remote names (one RemoteEvent per intent). Document payload types and direction here.
Remotes.Notify = "Notify" -- server -> client (kind: string, text: string)
Remotes.DebugCommand = "DebugCommand" -- client -> server, Studio only (command: string, arg: any); not in Remotes.all

-- Every remote the server creates eagerly at startup (so clients never wait on a missing folder).
Remotes.all = {
	Remotes.Notify,
}

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
	if existing then
		return existing :: Folder
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = Config.RemoteFolderName
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(Config.RemoteFolderName) :: Folder
end

-- Server creates the event lazily; the client waits for it.
function Remotes.event(name: string): RemoteEvent
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end
	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

-- Server only: create the folder and every remote.
function Remotes.createAll()
	for _, name in Remotes.all do
		Remotes.event(name)
	end
end

return Remotes
