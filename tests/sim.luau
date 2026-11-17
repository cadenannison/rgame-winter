--!strict
-- Headless fixed-seed simulation harness (pure Luau, runs under lune). No Roblox APIs.
-- Each system plugs in via Sim.addSystem({ name, init, step }) and may record() events into the checksum.
-- Usage: local sim = Sim.new({ seed = 1 }); sim:addSystem(mySystem); local r = sim:runDays(100).

local MODULUS = 4294967296 -- 2^32

export type Rng = {
	state: number,
	next: (Rng) -> number, -- float in [0, 1)
	int: (Rng, number, number) -> number, -- inclusive
	chance: (Rng, number) -> boolean,
}

export type Clock = { time: number, day: number, dayLength: number, dt: number }

export type Sim = {
	seed: number,
	rng: Rng,
	clock: Clock,
	systems: { System },
	hash: number,
	events: number,
	addSystem: (Sim, System) -> (),
	record: (Sim, string, number) -> (),
	step: (Sim) -> (),
	runDays: (Sim, number) -> Result,
}

export type System = {
	name: string,
	init: ((Sim) -> ())?,
	step: (Sim, Clock) -> (),
	onDay: ((Sim, number) -> ())?,
}

export type Result = { hash: number, days: number, events: number, time: number }

local Sim = {}

-- Deterministic LCG; products stay below 2^53 so doubles are exact.
local function newRng(seed: number): Rng
	local rng = { state = seed % MODULUS } :: any
	function rng.next(self: Rng): number
		self.state = (self.state * 1664525 + 1013904223) % MODULUS
		return self.state / MODULUS
	end
	function rng.int(self: Rng, lo: number, hi: number): number
		return lo + math.floor(self:next() * (hi - lo + 1))
	end
	function rng.chance(self: Rng, p: number): boolean
		return self:next() < p
	end
	return rng :: Rng
end

Sim.newRng = newRng

export type Options = { seed: number?, dayLength: number?, dt: number? }

function Sim.new(opts: Options?): Sim
	local o: Options = opts or {}
	local seed = o.seed or 1
	local sim = {
		seed = seed,
		rng = newRng(seed),
		clock = { time = 0, day = 1, dayLength = o.dayLength or 360, dt = o.dt or 1 },
		systems = {},
		hash = 2166136261, -- FNV offset basis
		events = 0,
	} :: any

	function sim.addSystem(self: Sim, system: System)
		table.insert(self.systems, system)
		if system.init then
			system.init(self)
		end
	end

	-- Fold a named event into the determinism checksum (FNV-1a style, 32-bit).
	function sim.record(self: Sim, name: string, value: number)
		local h = self.hash
		for i = 1, #name do
			h = (bit32.bxor(h, string.byte(name, i)) * 16777619) % MODULUS
		end
		h = (bit32.bxor(h, math.floor(value * 1000) % MODULUS) * 16777619) % MODULUS
		self.hash = h
		self.events += 1
	end

	function sim.step(self: Sim)
		local c = self.clock
		c.time += c.dt
		local newDay = math.floor(c.time / c.dayLength) + 1
		for _, system in self.systems do
			system.step(self, c)
		end
		if newDay ~= c.day then
			c.day = newDay
			for _, system in self.systems do
				if system.onDay then
					system.onDay(self, newDay)
				end
			end
		end
	end

	function sim.runDays(self: Sim, days: number): Result
		local target = days * self.clock.dayLength
		while self.clock.time < target do
			self:step()
		end
		return {
			hash = self.hash,
			days = self.clock.day,
			events = self.events,
			time = self.clock.time,
		}
	end

	return sim :: Sim
end

-- Skeleton for the 100-day determinism check: build the sim twice with the same seed and compare hashes.
-- `plug` adds every system under test; real systems extend it as they land.
function Sim.determinism(seed: number, days: number, plug: (Sim) -> ()): (boolean, Result, Result)
	local a = Sim.new({ seed = seed })
	plug(a)
	local ra = a:runDays(days)
	local b = Sim.new({ seed = seed })
	plug(b)
	local rb = b:runDays(days)
	return ra.hash == rb.hash and ra.events == rb.events and ra.time == rb.time, ra, rb
end

return Sim
