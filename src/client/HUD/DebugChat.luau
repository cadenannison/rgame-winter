--!strict
-- Studio-only chat bridge: "/debug <command> [arg]" -> Remotes.DebugCommand. Inert (nothing connected) outside Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DebugCommands = require(Shared:WaitForChild("logic"):WaitForChild("DebugCommands"))
local HudMath = require(Shared:WaitForChild("logic"):WaitForChild("HudMath"))

local ALIAS = "/debug"
local COMMAND_NAME = "ArcticDebugCommand"
local CHANNEL_NAME = "RBXGeneral"

local DebugChat = {}

local function say(text: string)
	print(`[Debug] {text}`)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local channel = channels and channels:FindFirstChild(CHANNEL_NAME)
		if channel and channel:IsA("TextChannel") then
			channel:DisplaySystemMessage(`[Debug] {text}`)
		end
	end)
end

local function send(name: string, arg: unknown)
	local folder = ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
	local remote = folder and folder:FindFirstChild(Remotes.DebugCommand)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(name, arg)
		say(`sent {name} {tostring(arg)}`)
	else
		say("server has no debug remote (not a Studio server?)")
	end
end

local function handle(fullText: string)
	local rest = string.match(fullText, "^%s*%S+%s*(.-)%s*$") or ""
	local ok, nameOrErr, arg = HudMath.parseDebug(rest, DebugCommands.NAMES)
	if not ok then
		say(nameOrErr)
		return
	end
	send(nameOrErr, arg)
end

-- Returns a cleanup function; a no-op (and nothing connected) when not in Studio.
function DebugChat.start(): () -> ()
	if not RunService:IsStudio() then
		return function() end
	end
	local command: Instance? = nil
	local connection: RBXScriptConnection? = nil
	local ok, err = pcall(function()
		local cmd = Instance.new("TextChatCommand")
		cmd.Name = COMMAND_NAME
		cmd.PrimaryAlias = ALIAS
		connection = cmd.Triggered:Connect(function(_source: TextSource, text: string)
			local handled, handleErr = pcall(function()
				handle(text)
			end)
			if not handled then
				warn(`[Debug] {handleErr}`)
			end
		end)
		cmd.Parent = TextChatService
		command = cmd
	end)
	if not ok then
		warn(`[Debug] chat bridge unavailable: {err}`)
	end
	return function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if command then
			command:Destroy()
			command = nil
		end
	end
end

return DebugChat
