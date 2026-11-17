--!strict
-- Pure context-action choice for click / E / the mobile button (client display only; the server re-validates).

export type Context = {
	fireInRange: boolean,
	hasWood: boolean,
	targetKind: string, -- "gather" | "attack" | "none"
	selectedKind: string?, -- ItemCatalog kind of the selected hotbar item
	selectedId: string?, -- ItemCatalog id of the selected hotbar item
	craftStation: boolean?, -- a crafting station is in range (and nearer than any upgradable fire)
	upgradeAvailable: boolean?, -- an upgradable fire is in range
}

local ActionPick = {}

-- Returns "fuel" | "gather" | "attack" | "eat" | "place" | "craft" | "upgrade" | "none".
-- The selected item states intent first (eat food, place a placeable, fuel with wood in hand),
-- then the target under aim/nearest, then fuel as the fallback when nothing is targeted.
function ActionPick.choose(ctx: Context): string
	if ctx.selectedKind == "food" then
		return "eat"
	end
	if ctx.selectedKind == "placeable" then
		return "place"
	end
	local canFuel = ctx.fireInRange and ctx.hasWood
	if canFuel and ctx.selectedId == "Wood" then
		return "fuel"
	end
	if ctx.targetKind == "gather" or ctx.targetKind == "attack" then
		return ctx.targetKind
	end
	if ctx.craftStation == true then
		return "craft"
	end
	if ctx.upgradeAvailable == true then
		return "upgrade"
	end
	if canFuel then
		return "fuel"
	end
	return "none"
end

ActionPick.Labels = {
	fuel = "Add wood",
	gather = "Gather",
	attack = "Attack",
	eat = "Eat",
	place = "Place",
	craft = "Craft",
	upgrade = "Upgrade fire",
	none = "Act",
} :: { [string]: string }

return ActionPick
