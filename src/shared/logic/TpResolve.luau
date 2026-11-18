--!strict
-- Pure target resolution for "/debug tp <query>" (no Roblox APIs). Query forms, all case-insensitive and fuzzy:
-- "ring N" | a structure name or alias ("research", "beacon", "mine", "ship"...; optional trailing index "research 2")
-- | "structure [n|Id]" | a player name (exact, prefix, then substring). Returns where to stand and what it resolved
-- to, or a clear error. Grounding and chunk streaming are the server adapter's job.

export type Vec2 = { x: number, z: number }
export type Site = { key: string, id: string, x: number, z: number, ring: number, radius: number }
export type PlayerPos = { name: string, x: number, z: number }
export type Ctx = {
	ringCount: number,
	from: Vec2, -- the teleporting player's position (nearest-first ordering, approach side)
	selfName: string,
	sites: { Site },
	players: { PlayerPos },
	aliases: { [string]: string }, -- squashed alias -> structure id
	ringPoint: (ring: number) -> Vec2?,
	gap: number, -- studs outside a structure footprint
	playerOffset: number, -- studs beside a target player
}
export type Result = { ok: boolean, name: string, x: number, z: number, error: string }

local MIN_FUZZY = 3 -- shortest query that may match by prefix/substring

local TpResolve = {}

local function squash(text: string): string
	return (string.gsub(string.lower(text), "[^%w]", ""))
end

local function distance(a: Vec2, x: number, z: number): number
	return math.sqrt((a.x - x) ^ 2 + (a.z - z) ^ 2)
end

local function fail(message: string): Result
	return { ok = false, name = "", x = 0, z = 0, error = message }
end

local function success(name: string, x: number, z: number): Result
	return { ok = true, name = name, x = x, z = z, error = "" }
end

local function idsPresent(sites: { Site }): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	for _, s in sites do
		if not seen[s.id] then
			seen[s.id] = true
			table.insert(out, s.id)
		end
	end
	table.sort(out)
	return out
end

-- Structure ids a squashed word refers to: alias, exact id, id prefix, then id substring.
local function matchingIds(word: string, ctx: Ctx): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local aliased = ctx.aliases[word]
	if aliased ~= nil then
		out[aliased] = true
		return out
	end
	for _, id in idsPresent(ctx.sites) do
		if squash(id) == word then
			out[id] = true
		end
	end
	if next(out) ~= nil or #word < MIN_FUZZY then
		return out
	end
	for _, id in idsPresent(ctx.sites) do
		if string.sub(squash(id), 1, #word) == word then
			out[id] = true
		end
	end
	if next(out) ~= nil then
		return out
	end
	for _, id in idsPresent(ctx.sites) do
		if string.find(squash(id), word, 1, true) ~= nil then
			out[id] = true
		end
	end
	return out
end

local function sitesByDistance(ctx: Ctx, ids: { [string]: boolean }?): { Site }
	local list: { Site } = {}
	for _, s in ctx.sites do
		if ids == nil or ids[s.id] then
			table.insert(list, s)
		end
	end
	table.sort(list, function(a, b)
		local da, db = distance(ctx.from, a.x, a.z), distance(ctx.from, b.x, b.z)
		if da == db then
			return a.key < b.key
		end
		return da < db
	end)
	return list
end

-- Stand outside the footprint, on the side facing the player.
local function approach(ctx: Ctx, s: Site): Result
	local dx, dz = ctx.from.x - s.x, ctx.from.z - s.z
	local len = math.sqrt(dx * dx + dz * dz)
	local ux, uz = 1, 0
	if len > 0.001 then
		ux, uz = dx / len, dz / len
	end
	local reach = s.radius + ctx.gap
	return success(`{s.key} (ring {s.ring})`, s.x + ux * reach, s.z + uz * reach)
end

local function resolveRing(n: number, ctx: Ctx): Result
	if n % 1 ~= 0 or n < 1 or n > ctx.ringCount then
		return fail(`ring {n} out of range (1 to {ctx.ringCount})`)
	end
	local p = ctx.ringPoint(n)
	if p == nil then
		return fail(`ring {n} has no position (world not ready)`)
	end
	return success(`ring {n}`, p.x, p.z)
end

local function resolvePlayer(query: string, ctx: Ctx): Result?
	local want = string.lower(query)
	local exact: { PlayerPos } = {}
	local prefix: { PlayerPos } = {}
	local partial: { PlayerPos } = {}
	for _, p in ctx.players do
		local lower = string.lower(p.name)
		if lower == want then
			table.insert(exact, p)
		elseif #want >= 1 and string.sub(lower, 1, #want) == want then
			table.insert(prefix, p)
		elseif #want >= MIN_FUZZY and string.find(lower, want, 1, true) ~= nil then
			table.insert(partial, p)
		end
	end
	for _, group in { exact, prefix, partial } do
		if #group == 1 then
			local p = group[1]
			return success(p.name, p.x + ctx.playerOffset, p.z)
		elseif #group > 1 then
			local names: { string } = {}
			for _, p in group do
				table.insert(names, p.name)
			end
			table.sort(names)
			return fail(`"{query}" matches several players: {table.concat(names, ", ")}`)
		end
	end
	return nil
end

function TpResolve.resolve(rawQuery: string, ctx: Ctx): Result
	local text = string.match(rawQuery, "^%s*(.-)%s*$") or ""
	if text == "" then
		return fail(
			"tp needs a target: research, mine, shipwreck, temple, lodge, ruins, ring <n> or a player"
		)
	end
	local lower = string.lower(text)

	local ringText = string.match(lower, "^ring%s*(%S+)$") or string.match(lower, "^r(%d+)$")
	if ringText ~= nil then
		local n = tonumber(ringText)
		if n == nil then
			return fail(`ring needs a number 1 to {ctx.ringCount}, got "{ringText}"`)
		end
		return resolveRing(n, ctx)
	end

	-- "structure", "structure 2" (nth nearest of any kind), "structure ResearchStation"
	local rest = string.match(lower, "^structures?%s*(.*)$")
	if rest ~= nil and (rest == "" or tonumber(rest) ~= nil) then
		local list = sitesByDistance(ctx, nil)
		local n = if rest == "" then 1 else math.floor(tonumber(rest) :: number)
		local s = list[n]
		if s == nil then
			return fail(
				if #list == 0
					then "no massive structures in this world"
					else `only {#list} structures in this world`
			)
		end
		return approach(ctx, s)
	end
	local query = if rest ~= nil then rest else lower
	local index = 1
	local base, nth = string.match(query, "^(.-)%s+(%d+)$")
	if base ~= nil and nth ~= nil then
		query = base
		index = math.max(1, math.floor(tonumber(nth) :: number))
	end

	local squashed = squash(query)
	local ids = if squashed ~= "" then matchingIds(squashed, ctx) else {}
	if next(ids) ~= nil then
		local list = sitesByDistance(ctx, ids)
		local s = list[index]
		if s == nil then
			return fail(`only {#list} matching "{query}" in this world`)
		end
		return approach(ctx, s)
	end

	local player = resolvePlayer(text, ctx)
	if player ~= nil then
		return player
	end

	local names: { string } = {}
	for _, p in ctx.players do
		if p.name ~= ctx.selfName then
			table.insert(names, p.name)
		end
	end
	local known = idsPresent(ctx.sites)
	return fail(
		`unknown tp target "{text}". Structures here: {if #known > 0
			then table.concat(known, ", ")
			else "none"}; `
			.. `ring 1 to {ctx.ringCount}; players: {if #names > 0
				then table.concat(names, ", ")
				else "none else"}`
	)
end

return TpResolve
