--!strict
-- Species registry: kind name -> AI module. The Art Pass 3 species have their own module; every legacy kind
-- (ArcticHare, Caribou, Fish, Wolf, PolarBear, IceWraith, SnowLurker, CaveCrawler, mini bosses, the blizzard
-- boss) shares the unchanged Legacy driver.

local Types = require(script.Parent.MobTypes)
local LegacyDriver = require(script.Parent.Drivers.Legacy)

local Legacy: Types.Species = { step = LegacyDriver.step }

local modules: { [string]: Types.Species } = {
	SnowGrouse = require(script.SnowGrouse),
	RidgeStag = require(script.RidgeStag),
	LakeSeal = require(script.LakeSeal),
	RimeWolverine = require(script.RimeWolverine),
	ScrapHound = require(script.ScrapHound),
	CarrionCrow = require(script.CarrionCrow),
	FrostboundBrute = require(script.FrostboundBrute),
	AuroraWisp = require(script.AuroraWisp),
}

local Species = {}

function Species.get(kindName: string): Types.Species
	return modules[kindName] or Legacy
end

return Species
