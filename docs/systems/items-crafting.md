# Items, inventory, gathering, crafting
Tier: full
Purpose: Server-authoritative inventory (hotbar + backpack), tier-gated resource nodes with slow respawn, and crafting at tier 0 (hand) and tier 1 (workbench). All item/recipe/node rows are data in ItemCatalog.
Owner files: src/server/Items/{InventoryService,GatherService,CraftingService}.luau, src/shared/ItemCatalog.luau, src/shared/logic/{Inventory,Crafting,ItemsGather}.luau, tests/ItemTests.luau
Public API:
- InventoryService: get, count, add(player,id,n)->leftover, remove(player,id,n)->bool, getSelected, getSelectedSlot, wearSelected, setUseHandler(fn), sync. Remotes: SelectSlotRequest(slot), UseItemRequest(slot), InventoryUpdate (server->client snapshot).
- GatherService.registerNode(instance, "Tree"|"Rock") / unregisterNode (for ChunkService). Remote: GatherRequest(node).
- CraftingService.registerWorkbench(instance, tier?), availableTier(player). Remote: CraftRequest(recipeId). CraftingService.start() also starts InventoryService and GatherService.
- Items: Wood, Stone, Axe, Pickaxe, Spear, Workbench. Recipes: Axe, Pickaxe, Workbench (tier 0); Spear (tier 1).
Data touched: Tags ResourceNode (Config.Gather.NodeTag), Workbench; node Attributes NodeKind, HitsLeft, Depleted; Player attribute SelectedSlot. No persistence (inventory resets on join until DataService integration).
Invariants:
- Craft is atomic: on any failure inventory is unchanged (tested).
- Crafting without enough materials, unknown recipe, missing workbench, or no room all fail with a reason.
- Tools never stack and lose durability per gather hit; broken tools are removed.
- A node yields only when depleted after HitsToDeplete hits, then respawns after RespawnSeconds.
- Wrong tool or tool below node tier never harvests.
Exploit surface: Handlers check type, then tag/range, then Guard rate limit, then state (depleted, tool, tier, workbench proximity from tagged instances). Client sends only ids/slots/instances; counts, yields, tiers and durability are server-computed. Slot numbers range-checked.
Playtest checklist: 1. Hand gather on a tree is refused. 2. Craft Axe with 3 Wood succeeds, with 2 fails. 3. Axe on tree x4 yields wood, node hides, respawns later. 4. Spear fails away from a workbench, succeeds beside a tagged one.
Status: in progress (server + tests done; client UI, workbench placement, ChunkService node registration pending)
