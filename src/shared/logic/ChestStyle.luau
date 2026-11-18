--!strict
-- Pure chest look table: rarity -> colours, materials, glow, light, particles, beam, open animation.
-- Shared by the server builder (server/Art/ChestArt) and the client effects (client/Loot). No Roblox APIs.
-- Colours are {r, g, b} 0-255. Light/particle numbers must stay inside ChestStyle.Budget (tests check).

local Config = require("../Config")
local Rarity = require("../data/Rarity")

export type Style = {
	bodyColor: { number },
	bodyMaterial: string, -- Enum.Material name
	trimColor: { number },
	trimMaterial: string,
	glowColor: { number }?, -- nil = no glow strip / beam
	glowTransparency: number, -- glow strip base transparency (client pulses around it)
	lightRange: number, -- 0 = no light (client creates it only for nearby chests)
	lightBrightness: number,
	particleRate: number, -- per second per emitter; 0 = none
	particleLifetime: number,
	beamHeight: number, -- studs; 0 = no beam
	beamWidth: number,
	beamTransparency: number,
	openSeconds: number, -- lid tween time
	lidAngle: number, -- degrees the lid opens
	holdSeconds: number, -- prompt hold duration
	burstCount: number, -- particles emitted once on open
	pulseSpeed: number, -- radians per second of the glow pulse
	pulseAmount: number, -- 0..1 transparency swing
	soundKey: string, -- shared/Assets key (nil id = silent hook)
	label: string, -- prompt label
}

local ChestStyle = {}

-- Local budgets (Config has no chest section; listed as an open issue). Particle rate and emitter count
-- derive from Config.Perf. A chest's own server parts are capped; effects exist only on nearby chests.
ChestStyle.Budget = {
	MaxParts = 8, -- server parts per chest model
	MaxLightRange = 24,
	MaxLightBrightness = 3,
	MaxParticleRate = Config.Perf.MaxParticleRate,
	MaxBeamHeight = 160,
	MaxBeamWidth = 4,
	MaxEffectChests = math.floor(Config.Perf.MaxParticleEmitters / 3), -- nearby chests with live light + emitter
	EffectRadius = 90, -- studs: light/particles/pulse only inside this
	RefreshSeconds = 0.5, -- nearby-set sweep interval
	OpenedDim = 0.5, -- colour multiplier when opened
	PromptDistance = Config.Loot.OpenRange,
	HingeInset = 0.1,
} :: { [string]: number }

local STYLES: { [string]: Style } = {
	common = {
		bodyColor = { 112, 82, 52 },
		bodyMaterial = "Wood",
		trimColor = { 78, 66, 56 },
		trimMaterial = "WoodPlanks",
		glowColor = nil,
		glowTransparency = 1,
		lightRange = 0,
		lightBrightness = 0,
		particleRate = 0,
		particleLifetime = 0,
		beamHeight = 0,
		beamWidth = 0,
		beamTransparency = 1,
		openSeconds = 0.35,
		lidAngle = 95,
		holdSeconds = 0,
		burstCount = 0,
		pulseSpeed = 0,
		pulseAmount = 0,
		soundKey = "ChestOpenCommonSound",
		label = "Weathered Chest",
	},
	uncommon = {
		bodyColor = { 92, 70, 48 },
		bodyMaterial = "Wood",
		trimColor = { 120, 124, 132 },
		trimMaterial = "CorrodedMetal",
		glowColor = nil,
		glowTransparency = 1,
		lightRange = 0,
		lightBrightness = 0,
		particleRate = 0,
		particleLifetime = 0,
		beamHeight = 0,
		beamWidth = 0,
		beamTransparency = 1,
		openSeconds = 0.4,
		lidAngle = 100,
		holdSeconds = 0,
		burstCount = 4,
		pulseSpeed = 0,
		pulseAmount = 0,
		soundKey = "ChestOpenUncommonSound",
		label = "Iron-Bound Chest",
	},
	rare = {
		bodyColor = { 150, 190, 220 },
		bodyMaterial = "Metal",
		trimColor = { 70, 100, 140 },
		trimMaterial = "Metal",
		glowColor = { 80, 170, 255 },
		glowTransparency = 0.25,
		lightRange = 14,
		lightBrightness = 1.2,
		particleRate = 6,
		particleLifetime = 1.6,
		beamHeight = 34,
		beamWidth = 0.7,
		beamTransparency = 0.72,
		openSeconds = 0.5,
		lidAngle = 105,
		holdSeconds = 0,
		burstCount = 14,
		pulseSpeed = 2.2,
		pulseAmount = 0.2,
		soundKey = "ChestOpenRareSound",
		label = "Frost-Steel Chest",
	},
	epic = {
		bodyColor = { 70, 40, 110 },
		bodyMaterial = "Glass",
		trimColor = { 160, 100, 235 },
		trimMaterial = "Neon",
		glowColor = { 180, 110, 255 },
		glowTransparency = 0.15,
		lightRange = 18,
		lightBrightness = 1.8,
		particleRate = 12,
		particleLifetime = 2,
		beamHeight = 70,
		beamWidth = 1.4,
		beamTransparency = 0.62,
		openSeconds = 0.65,
		lidAngle = 110,
		holdSeconds = 0.25,
		burstCount = 24,
		pulseSpeed = 3,
		pulseAmount = 0.28,
		soundKey = "ChestOpenEpicSound",
		label = "Spectral Chest",
	},
	legendary = {
		bodyColor = { 235, 190, 70 },
		bodyMaterial = "Metal",
		trimColor = { 255, 225, 120 },
		trimMaterial = "Neon",
		glowColor = { 255, 210, 90 },
		glowTransparency = 0.08,
		lightRange = 22,
		lightBrightness = 2.6,
		particleRate = 20,
		particleLifetime = 2.4,
		beamHeight = 130,
		beamWidth = 3,
		beamTransparency = 0.5,
		openSeconds = 0.9,
		lidAngle = 115,
		holdSeconds = 0.5,
		burstCount = 40,
		pulseSpeed = 4,
		pulseAmount = 0.35,
		soundKey = "ChestOpenLegendarySound",
		label = "Golden Chest",
	},
}

ChestStyle.Styles = STYLES

-- Style for a rarity; unknown names fall back to common.
function ChestStyle.get(rarity: string): Style
	return STYLES[rarity] or STYLES.common
end

-- Server parts a style needs: Base, Lid, two straps, plus lock plate; glow strip and beam when glowing.
function ChestStyle.partCount(style: Style): number
	local n = 5
	if style.glowColor then
		n += 1
		if style.beamHeight > 0 then
			n += 1
		end
	end
	return n
end

-- True when this rarity gets a light and emitter on the client.
function ChestStyle.hasEffects(style: Style): boolean
	return style.lightRange > 0 or style.particleRate > 0
end

-- Colour multiplied by factor (opened chests dim). Clamped 0-255.
function ChestStyle.dim(color: { number }, factor: number): { number }
	return {
		math.clamp(math.floor(color[1] * factor + 0.5), 0, 255),
		math.clamp(math.floor(color[2] * factor + 0.5), 0, 255),
		math.clamp(math.floor(color[3] * factor + 0.5), 0, 255),
	}
end

-- Glow transparency at time t (seconds): base pulsing by pulseAmount, clamped 0..1.
function ChestStyle.pulse(style: Style, t: number): number
	if style.pulseSpeed <= 0 then
		return style.glowTransparency
	end
	local s = (math.sin(t * style.pulseSpeed) + 1) * 0.5
	return math.clamp(style.glowTransparency + s * style.pulseAmount, 0, 1)
end

-- Problems with one style against the budget (empty = OK).
function ChestStyle.validate(rarity: string, style: Style): { string }
	local B = ChestStyle.Budget
	local problems: { string } = {}
	if ChestStyle.partCount(style) > B.MaxParts then
		table.insert(problems, `{rarity}: too many parts`)
	end
	if style.lightRange > B.MaxLightRange or style.lightBrightness > B.MaxLightBrightness then
		table.insert(problems, `{rarity}: light over budget`)
	end
	if style.particleRate > B.MaxParticleRate then
		table.insert(problems, `{rarity}: particle rate over budget`)
	end
	if style.beamHeight > B.MaxBeamHeight or style.beamWidth > B.MaxBeamWidth then
		table.insert(problems, `{rarity}: beam over budget`)
	end
	if
		Rarity.rank(rarity) >= Rarity.rank("rare")
		and (style.glowColor == nil or style.beamHeight <= 0)
	then
		table.insert(problems, `{rarity}: rare+ chests need a glow and a beam to be seen from far`)
	end
	return problems
end

return ChestStyle
