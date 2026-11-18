--!strict
-- Small shared helpers for the structure/progression services (state checks and instance positions).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ServerUtil = {}

function ServerUtil.pivot(i: Instance): Vector3?
	if i:IsA("BasePart") then
		return i.Position
	elseif i:IsA("Model") then
		return i:GetPivot().Position
	end
	return nil
end

-- The player's root part if they are alive and not downed (the state gate every action needs).
function ServerUtil.actingRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if humanoid == nil or root == nil or humanoid.Health <= 0 then
		return nil
	end
	if player:GetAttribute(Config.Downed.StateAttribute) == true then
		return nil
	end
	return root
end

-- Instance argument from a client: a live Instance inside Workspace within `range` of the root.
function ServerUtil.reachable(root: BasePart, target: unknown, range: number): Instance?
	if typeof(target) ~= "Instance" then
		return nil
	end
	local inst = target :: Instance
	if not inst:IsDescendantOf(Workspace) then
		return nil
	end
	local p = ServerUtil.pivot(inst)
	if p == nil or (p - root.Position).Magnitude > range then
		return nil
	end
	return inst
end

return ServerUtil
