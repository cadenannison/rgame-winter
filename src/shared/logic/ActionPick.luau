--!strict
-- Pure context-action choice for the HUD button (client display only; the server re-validates).

export type Context = {
	fireInRange: boolean,
	hasWood: boolean,
	targetKind: string, -- "gather" | "attack" | "none"
	selectedKind: string?, -- ItemCatalog kind of the selected hotbar item
}

local ActionPick = {}

-- Returns "fuel" | "gather" | "attack" | "eat" | "place" | "none".
function ActionPick.choose(ctx: Context): string
	if ctx.fireInRange and ctx.hasWood then
		return "fuel"
	end
	if ctx.targetKind == "gather" or ctx.targetKind == "attack" then
		return ctx.targetKind
	end
	if ctx.selectedKind == "food" then
		return "eat"
	end
	if ctx.selectedKind == "placeable" then
		return "place"
	end
	return "none"
end

ActionPick.Labels = {
	fuel = "Add wood",
	gather = "Gather",
	attack = "Attack",
	eat = "Eat",
	place = "Place",
	none = "Act",
} :: { [string]: string }

return ActionPick
