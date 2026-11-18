--!strict
-- Hit confirm: watch a target we just hit for the server's attribute change (HitsLeft / Depleted /
-- MobHealth), then burst + sound (+ flash for mobs). Short-lived connections, swept by the HUD loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ItemCatalog = require(Shared:WaitForChild("ItemCatalog"))
local HudKit = require(script.Parent:WaitForChild("HudKit"))
local Feedback = require(script.Parent:WaitForChild("Feedback"))

local WATCH_SECONDS = 2 -- how long a hit target's attributes are watched for the confirm

type Watch = { conns: { RBXScriptConnection }, expires: number }

export type HitWatch = {
	watch: (inst: Instance, isMob: boolean) -> (),
	sweep: (force: boolean) -> (),
}

local positionOf = HudKit.positionOf

local HitWatchModule = {}

function HitWatchModule.new(): HitWatch
	local watches: { [Instance]: Watch } = {}

	local function watch(inst: Instance, isMob: boolean)
		local now = os.clock()
		local w = watches[inst]
		if w then
			w.expires = now + WATCH_SECONDS
			return
		end
		local conns: { RBXScriptConnection } = {}
		local function confirm()
			local pos = positionOf(inst)
			if pos then
				Feedback.burst(pos)
				Feedback.sound(if isMob then "MobHitSound" else "ChopSound", pos)
			end
			if isMob then
				Feedback.flash(inst)
			end
		end
		if isMob then
			table.insert(
				conns,
				inst:GetAttributeChangedSignal(Config.Mobs.HealthAttribute):Connect(confirm)
			)
		else
			table.insert(
				conns,
				inst:GetAttributeChangedSignal(ItemCatalog.NodeHitsAttribute):Connect(confirm)
			)
			table.insert(
				conns,
				inst:GetAttributeChangedSignal(ItemCatalog.NodeDepletedAttribute):Connect(function()
					if inst:GetAttribute(ItemCatalog.NodeDepletedAttribute) == true then
						confirm()
					end
				end)
			)
		end
		watches[inst] = { conns = conns, expires = now + WATCH_SECONDS }
	end
	local function sweepWatches(force: boolean)
		local now = os.clock()
		for inst, w in watches do
			if force or now > w.expires or inst.Parent == nil then
				for _, c in w.conns do
					c:Disconnect()
				end
				watches[inst] = nil
			end
		end
	end

	return { watch = watch, sweep = sweepWatches }
end

return HitWatchModule
