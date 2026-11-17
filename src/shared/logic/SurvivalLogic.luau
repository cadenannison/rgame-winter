--!strict
-- Pure survival meters, downed and revive rules. No Roblox APIs.

export type MeterCfg = {
	MaxHealth: number,
	MaxWarmth: number,
	MaxHunger: number,
	HungerDrainPerSecond: number,
	WarmthDrainPerSecond: number,
	WarmthDrainNightMultiplier: number,
	WarmthRegenPerSecond: number,
	StarveDamagePerSecond: number,
	FreezeDamagePerSecond: number,
	HealthRegenPerSecond: number,
	RegenMinHunger: number,
	RegenMinWarmth: number,
}

export type DownedCfg = {
	BleedoutSeconds: number,
	ReviveHealthFraction: number,
}

export type State = {
	health: number,
	warmth: number,
	hunger: number,
	downed: boolean,
	dead: boolean,
	bleed: number, -- seconds left before a downed player dies
}

export type Env = {
	inFire: boolean,
	isNight: boolean,
	invincible: boolean,
}

local SurvivalLogic = {}

function SurvivalLogic.new(m: MeterCfg): State
	return {
		health = m.MaxHealth,
		warmth = m.MaxWarmth,
		hunger = m.MaxHunger,
		downed = false,
		dead = false,
		bleed = 0,
	}
end

-- Advances meters by dt. Downed or dead states do not change. Returns true when health reaches 0.
function SurvivalLogic.step(s: State, env: Env, m: MeterCfg, dt: number): boolean
	if s.downed or s.dead then
		return false
	end
	if env.inFire then
		s.warmth += m.WarmthRegenPerSecond * dt
	else
		local mult = if env.isNight then m.WarmthDrainNightMultiplier else 1
		s.warmth -= m.WarmthDrainPerSecond * mult * dt
	end
	s.warmth = math.clamp(s.warmth, 0, m.MaxWarmth)
	s.hunger = math.clamp(s.hunger - m.HungerDrainPerSecond * dt, 0, m.MaxHunger)

	local damage = 0
	if s.hunger <= 0 then
		damage += m.StarveDamagePerSecond
	end
	if s.warmth <= 0 then
		damage += m.FreezeDamagePerSecond
	end
	if damage > 0 then
		if not env.invincible then
			s.health -= damage * dt
		end
	elseif s.hunger >= m.RegenMinHunger and s.warmth >= m.RegenMinWarmth then
		s.health += m.HealthRegenPerSecond * dt
	end
	s.health = math.clamp(s.health, 0, m.MaxHealth)
	return s.health <= 0
end

-- Applies outside damage (mobs, etc). Returns true when health reaches 0.
function SurvivalLogic.damage(s: State, amount: number, m: MeterCfg, invincible: boolean): boolean
	if s.downed or s.dead or invincible or amount <= 0 then
		return false
	end
	s.health = math.clamp(s.health - amount, 0, m.MaxHealth)
	return s.health <= 0
end

function SurvivalLogic.heal(s: State, amount: number, m: MeterCfg)
	if s.downed or s.dead or amount <= 0 then
		return
	end
	s.health = math.clamp(s.health + amount, 0, m.MaxHealth)
end

function SurvivalLogic.feed(s: State, amount: number, m: MeterCfg)
	if s.dead then
		return
	end
	s.hunger = math.clamp(s.hunger + amount, 0, m.MaxHunger)
end

function SurvivalLogic.warm(s: State, amount: number, m: MeterCfg)
	if s.dead then
		return
	end
	s.warmth = math.clamp(s.warmth + amount, 0, m.MaxWarmth)
end

function SurvivalLogic.down(s: State, d: DownedCfg)
	s.downed = true
	s.health = 0
	s.bleed = d.BleedoutSeconds
end

-- Returns true when the downed player bled out.
function SurvivalLogic.tickDowned(s: State, dt: number): boolean
	if not s.downed or s.dead then
		return false
	end
	s.bleed = math.max(s.bleed - dt, 0)
	return s.bleed <= 0
end

function SurvivalLogic.revive(s: State, m: MeterCfg, d: DownedCfg): boolean
	if not s.downed or s.dead then
		return false
	end
	s.downed = false
	s.bleed = 0
	s.health = math.max(m.MaxHealth * d.ReviveHealthFraction, 1)
	return true
end

function SurvivalLogic.kill(s: State)
	s.dead = true
	s.downed = false
	s.health = 0
	s.bleed = 0
end

return SurvivalLogic
