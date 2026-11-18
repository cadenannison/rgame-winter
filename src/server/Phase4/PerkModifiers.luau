--!strict
-- Run-server perk state (brief 21 wiring). The equipped perk is read ONCE per player per run (first
-- profile load on this server) and frozen; a rejoin keeps the captured perk. Every multiplier comes from
-- PerkLogic, so it stays within 1 +/- Config.Meta.MaxPerkMagnitude. Server only; nothing replicates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.data.Types)
local PerkLogic = require(Shared.logic.PerkLogic)

local PerkModifiers = {}

local captured: { [number]: Types.PerkEffect | false } = {} -- userId -> effect (false = no perk)
local present: { [number]: boolean } = {} -- userIds currently on the server
local gatherCarry: { [number]: number } = {}

-- Records the run perk the first time a player loads on this server (later calls are ignored).
function PerkModifiers.capture(userId: number, item: Types.ShopItemDef?)
	present[userId] = true
	if captured[userId] ~= nil then
		return
	end
	local effect = item and item.perk
	captured[userId] = if effect and PerkLogic.effectValid(effect) then effect else false
end

function PerkModifiers.leave(userId: number)
	present[userId] = nil
	gatherCarry[userId] = nil
end

local function effectOf(userId: number): Types.PerkEffect?
	local effect = captured[userId]
	if effect == nil or effect == false then
		return nil
	end
	return effect :: Types.PerkEffect
end

-- Per-player multiplier (warmthDrain, hungerDrain, moveSpeed, gatherSpeed); 1 = none.
function PerkModifiers.multiplier(player: Player, stat: string): number
	return PerkLogic.multiplier(effectOf(player.UserId), stat)
end

-- Camp-wide multiplier (fuelBurn): the best perk among players on the server.
function PerkModifiers.teamMultiplier(stat: string): number
	local effects: { Types.PerkEffect } = {}
	for userId in present do
		local effect = effectOf(userId)
		if effect then
			table.insert(effects, effect)
		end
	end
	return PerkLogic.lowestMultiplier(effects, stat)
end

-- gatherSpeed perk: extra whole items for this harvest (fractional carry kept per player).
function PerkModifiers.gatherBonus(player: Player, base: number): number
	local userId = player.UserId
	local extra, carry = PerkLogic.bonusYield(
		gatherCarry[userId] or 0,
		base,
		PerkModifiers.multiplier(player, "gatherSpeed")
	)
	gatherCarry[userId] = carry
	return extra
end

return PerkModifiers
