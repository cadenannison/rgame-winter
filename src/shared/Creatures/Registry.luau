--!strict
-- Creature registry (orchestrator-owned; one line per kind). Server: Registry.attach(kind, root) after the
-- root part exists. Client + server: Registry.get(kind).rig. Agents edit their Defs/<Kind>.luau only.
local CollectionService = game:GetService("CollectionService")
local Config = require("../Config")
local CreatureBuild = require("./CreatureBuild")
local Types = require("./Types")

local ArcticHare = require("./Defs/ArcticHare")
local Caribou = require("./Defs/Caribou")
local Fish = require("./Defs/Fish")
local Wolf = require("./Defs/Wolf")
local SnowGrouse = require("./Defs/SnowGrouse")
local RidgeStag = require("./Defs/RidgeStag")
local LakeSeal = require("./Defs/LakeSeal")
local RimeWolverine = require("./Defs/RimeWolverine")
local ScrapHound = require("./Defs/ScrapHound")
local CarrionCrow = require("./Defs/CarrionCrow")
local FrostboundBrute = require("./Defs/FrostboundBrute")
local AuroraWisp = require("./Defs/AuroraWisp")
local PolarBear = require("./Defs/PolarBear")
local IceWraith = require("./Defs/IceWraith")
local SnowLurker = require("./Defs/SnowLurker")
local CaveCrawler = require("./Defs/CaveCrawler")
local IceWarden = require("./Defs/IceWarden")
local CaveMatriarch = require("./Defs/CaveMatriarch")
local RuinColossus = require("./Defs/RuinColossus")
local WhiteoutBeast = require("./Defs/WhiteoutBeast")
local Stalker = require("./Defs/Stalker")
local TreeWatcher = require("./Defs/TreeWatcher")
local IceScratcher = require("./Defs/IceScratcher")
local EyesInDark = require("./Defs/EyesInDark")

local DEFS: { [string]: Types.CreatureDef } = {
	ArcticHare = ArcticHare,
	Caribou = Caribou,
	Fish = Fish,
	Wolf = Wolf,
	SnowGrouse = SnowGrouse,
	RidgeStag = RidgeStag,
	LakeSeal = LakeSeal,
	RimeWolverine = RimeWolverine,
	ScrapHound = ScrapHound,
	CarrionCrow = CarrionCrow,
	FrostboundBrute = FrostboundBrute,
	AuroraWisp = AuroraWisp,
	PolarBear = PolarBear,
	IceWraith = IceWraith,
	SnowLurker = SnowLurker,
	CaveCrawler = CaveCrawler,
	IceWarden = IceWarden,
	CaveMatriarch = CaveMatriarch,
	RuinColossus = RuinColossus,
	WhiteoutBeast = WhiteoutBeast,
	Stalker = Stalker,
	TreeWatcher = TreeWatcher,
	IceScratcher = IceScratcher,
	EyesInDark = EyesInDark,
}

local CFG = Config.Creatures
local Registry = {}

function Registry.get(kind: string): Types.CreatureDef?
	return DEFS[kind]
end

function Registry.kinds(): { string }
	local out = {}
	for kind in DEFS do
		table.insert(out, kind)
	end
	table.sort(out)
	return out
end

-- SERVER. Builds the visual rig under root (root becomes the invisible hitbox), tags + sets attrs on the
-- model, and enforces the part cap. Returns the part count (0 = unknown kind, nothing built).
function Registry.attach(kind: string, root: BasePart): number
	local def = DEFS[kind]
	local model = root.Parent
	if not def or not model then
		return 0
	end
	root.Transparency = 1
	def.build(root)
	local count = CreatureBuild.countParts(model)
	assert(count <= CFG.PartCap, `{kind} has {count} parts (cap {CFG.PartCap})`)
	model:SetAttribute(CFG.KindAttribute, kind)
	if model:GetAttribute(CFG.StateAttribute) == nil then
		model:SetAttribute(CFG.StateAttribute, "Idle")
	end
	CollectionService:AddTag(model, CFG.Tag)
	return count
end

return Registry
