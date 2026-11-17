--!strict
-- Pure context-action choice for click / E / the mobile button (client display only; the server re-validates).

export type Context = {
	fireInRange: boolean,
	hasWood: boolean,
	targetKind: string, -- "gather" | "attack" | "none"
	selectedKind: string?, -- ItemCatalog kind of the selected hotbar item
	selectedId: string?, -- ItemCatalog id of the selected hotbar item
}

local ActionPick = {}

-- Returns "fuel" | "gather" | "attack" | "eat" | "place" | "none".
-- The selected item states intent first (eat food, place a placeable, fuel with wood in hand),
-- then the target under aim/nearest, then fuel as the fallback when nothing is targeted.
function ActionPick.choose(ctx: Context): string
	if ctx.selectedKind == "food" then
		return "eat"
	end
	if ctx.selectedKind == "placeable" then
		return "place"
	end
	if
		ctx.fireInRange
		and ctx.hasWood
		and (ctx.selectedId == "Wood" or ctx.targetKind == "none")
	then
		return "fuel"
	end
	if ctx.targetKind == "gather" or ctx.targetKind == "attack" then
		return ctx.targetKind
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
