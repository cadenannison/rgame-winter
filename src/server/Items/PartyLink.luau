--!strict
-- Who counts as "the party" for shared chests, doors and pings. A run server holds exactly one party, so
-- the default is every player on the server; brief 18 can narrow it with setProvider (nil-safe).

local Players = game:GetService("Players")

local PartyLink = {}

local provider: ((Player) -> { Player })? = nil

function PartyLink.setProvider(fn: ((Player) -> { Player })?)
	provider = fn
end

-- Party members of `player` (including the player), only those still in the game.
function PartyLink.members(player: Player): { Player }
	local list = Players:GetPlayers()
	if provider then
		local ok, result = pcall(provider, player)
		if ok and type(result) == "table" then
			list = result
		end
	end
	local out: { Player } = {}
	local hasSelf = false
	for _, p in list do
		if p.Parent == Players then
			table.insert(out, p)
			if p == player then
				hasSelf = true
			end
		end
	end
	if not hasSelf and player.Parent == Players then
		table.insert(out, player)
	end
	return out
end

function PartyLink.same(a: Player, b: Player): boolean
	if a == b then
		return true
	end
	return table.find(PartyLink.members(a), b) ~= nil
end

return PartyLink
