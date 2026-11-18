--!strict
-- Target pick for the HUD: on PC the candidate nearest the mouse ray (within AimSlack) wins, else the
-- nearest within ActionRange. Tagged instances only; never scans Workspace. Returns a fresh result each
-- call; HudController mirrors it into its own state.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local HudConfig = require(script.Parent:WaitForChild("HudConfig"))
local HudKit = require(script.Parent:WaitForChild("HudKit"))

local positionOf = HudKit.positionOf

export type Result = {
	targetKind: string,
	targetInstance: Instance?,
	targetDistance: number?, -- studs to targetInstance (nil = none)
	targetAimed: boolean, -- true when the cursor/aim picked it (not just the closest)
	fireInstance: Instance?,
	fireDist: number,
	benchInstance: Instance?, -- nearest crafting station in range
	benchDist: number,
}

local HudTargeting = {}

function HudTargeting.pick(player: Player, touchOnly: boolean): Result
	local targetKind: string, targetInstance: Instance?, fireInstance: Instance? = "none", nil, nil
	local targetDistance: number?, targetAimed = nil, false
	local fireDist, benchInstance, benchDist = math.huge, nil :: Instance?, math.huge
	local function result(): Result
		return {
			targetKind = targetKind,
			targetInstance = targetInstance,
			targetDistance = targetDistance,
			targetAimed = targetAimed,
			fireInstance = fireInstance,
			fireDist = fireDist,
			benchInstance = benchInstance,
			benchDist = benchDist,
		}
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return result()
	end
	local camera = Workspace.CurrentCamera
	local ray: Ray? = nil
	if camera and not touchOnly then
		local m = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(m.X, m.Y)
	end
	local bestNear, bestAim = HudConfig.ActionRange, Config.Feedback.AimSlack
	local nearKind, nearInst, aimKind, aimInst = "none", nil :: Instance?, "none", nil :: Instance?
	local function scan(tag: string, kind: string)
		for _, inst in CollectionService:GetTagged(tag) do
			if
				inst ~= character
				and inst:GetAttribute(ItemCatalog.NodeDepletedAttribute) ~= true
			then
				local pos = positionOf(inst)
				if pos then
					local d = (pos - root.Position).Magnitude
					if d <= HudConfig.ActionRange then
						if d <= bestNear then
							bestNear, nearKind, nearInst = d, kind, inst
						end
						if ray then
							local off = pos - ray.Origin
							local along = off:Dot(ray.Direction.Unit)
							local perp = (off - ray.Direction.Unit * along).Magnitude
							if along > 0 and perp <= bestAim then
								bestAim, aimKind, aimInst = perp, kind, inst
							end
						end
					end
				end
			end
		end
	end
	scan(Config.Gather.NodeTag, "gather")
	scan(Config.Mobs.Tag, "attack")
	if aimInst then
		targetKind, targetInstance = aimKind, aimInst
		targetAimed = true
		local aimPos = positionOf(aimInst)
		targetDistance = if aimPos then (aimPos - root.Position).Magnitude else nil
	else
		targetKind, targetInstance = nearKind, nearInst
		targetDistance = if nearInst then bestNear else nil
	end
	local fireBest = Config.Fire.AddFuelRange
	for _, inst in CollectionService:GetTagged(Config.Fire.Tag) do
		local pos = positionOf(inst)
		if pos and (pos - root.Position).Magnitude <= fireBest then
			fireBest, fireInstance = (pos - root.Position).Magnitude, inst
			fireDist = fireBest
		end
	end
	for _, station in Config.Craft.Stations do
		for _, inst in CollectionService:GetTagged(station.Tag) do
			local pos = positionOf(inst)
			if pos then
				local d = (pos - root.Position).Magnitude
				if d <= station.Range and d < benchDist then
					benchDist, benchInstance = d, inst
				end
			end
		end
	end
	return result()
end

return HudTargeting
