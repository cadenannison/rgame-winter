--!strict
-- Pure helpers over Config.Massive (no Roblox APIs): footprint radius, ring permission, plan validation.
-- Plans (agents J/K) are checked with validatePlan in tests; keep it the single rulebook.

local Config = require("../Config")

local MassiveRules = {}

export type PlanSummary = {
	id: string,
	footprintX: number,
	footprintZ: number,
	rooms: number,
	levels: number,
	undergroundDepth: number,
	minCorridorWidth: number,
	minCeilingHeight: number,
	parts: number,
	dressingParts: number,
	lights: number,
	particles: number,
}

-- Exclusion radius (studs) around the structure centre for trees, POIs, camp and mob spawns.
function MassiveRules.footprintRadius(id: string): number
	local def = Config.Massive.Structures[id]
	return math.ceil(math.sqrt(def.MinFootprintX ^ 2 + def.MinFootprintZ ^ 2) / 2)
		+ Config.Massive.FootprintMargin
end

function MassiveRules.ringAllowed(id: string, ring: number): boolean
	local def = Config.Massive.Structures[id]
	return def ~= nil and table.find(def.Rings, ring) ~= nil
end

-- Returns a list of rule violations (empty = the plan meets Config.Massive).
function MassiveRules.validatePlan(plan: PlanSummary): { string }
	local M = Config.Massive
	local def = M.Structures[plan.id]
	local errs: { string } = {}
	if def == nil then
		return { `unknown structure {plan.id}` }
	end
	local B = def.Budget
	local function need(ok: boolean, msg: string)
		if not ok then
			table.insert(errs, msg)
		end
	end
	need(
		plan.footprintX >= def.MinFootprintX and plan.footprintZ >= def.MinFootprintZ,
		"footprint below minimum"
	)
	need(plan.rooms >= def.MinRooms, "too few rooms")
	need(plan.levels >= def.MinLevels, "too few levels")
	need(plan.undergroundDepth >= def.UndergroundDepth, "underground too shallow")
	need(plan.minCorridorWidth >= M.CorridorWidthMin, "corridor too narrow")
	need(plan.minCeilingHeight >= M.CeilingHeightMin, "ceiling too low")
	need(plan.parts <= B.Parts, "over part budget")
	need(plan.dressingParts <= B.DressingParts, "over dressing budget")
	need(plan.lights <= B.Lights, "over light budget")
	need(plan.particles <= B.Particles, "over particle budget")
	return errs
end

return MassiveRules
