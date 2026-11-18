--!strict
-- Ragdoll-free downed pose: tilts and lowers the character's root Motor6D so the body lies prone while
-- the player crawls (Humanoid keeps working, no joints are broken, no limbs scatter). The original C0 is
-- remembered per joint so a revive restores the standing pose exactly. Server only (replicates).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local D = Config.Downed

local DownedPose = {}

-- Weak keys: a destroyed joint drops its entry.
local originals: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function findJoint(character: Model): Motor6D?
	local found = character:FindFirstChild(D.PoseJointName, true)
	if found and found:IsA("Motor6D") then
		return found
	end
	return nil
end

-- Lie down. Safe to call twice (the original is kept from the first call).
function DownedPose.apply(character: Model)
	local joint = findJoint(character)
	if not joint then
		return
	end
	local original = originals[joint]
	if not original then
		original = joint.C0
		originals[joint] = original
	end
	joint.C0 = CFrame.new(0, -D.PoseDropY, 0)
		* (original :: CFrame)
		* CFrame.Angles(-math.rad(D.PoseTiltDegrees), 0, 0)
end

-- Stand back up (no-op if the pose was never applied).
function DownedPose.clear(character: Model)
	local joint = findJoint(character)
	if not joint then
		return
	end
	local original = originals[joint]
	if original then
		joint.C0 = original
		originals[joint] = nil
	end
end

return DownedPose
