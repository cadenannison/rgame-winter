# Items, inventory, gathering, crafting
Tier: full
Purpose: Server-authoritative inventory (hotbar + backpack), tier-gated resource nodes with slow respawn, and crafting at tier 0 (hand) and tier 1 (workbench). All item/recipe/node rows are data in ItemCatalog.
Owner files: src/server/Items/{InventoryService,GatherService,CraftingService}.luau, src/shared/ItemCatalog.luau, src/shared/logic/{Inventory,Crafting,ItemsGather}.luau, tests/ItemTests.luau
Public API:
- InventoryService: get, count, add(player,id,n)->leftover, remove(player,id,n)->bool, getSelected, getSelectedSlot, wearSelected, setUseHandler(fn), sync. Remotes: SelectSlotRequest(slot), UseItemRequest(slot), InventoryUpdate (server->client snapshot).
- GatherService.registerNode(instance, "Tree"|"Rock") / unregisterNode (for ChunkService). Remote: GatherRequest(node).
- CraftingService.registerWorkbench(instance, tier?), availableTier(player). Remote: CraftRequest(recipeId). CraftingService.start() also starts InventoryService and GatherService.
- Items: Wood, Stone, Axe, Pickaxe, Spear, Workbench, Campfire, RawMeat, Hide. Recipes: Axe, Pickaxe, Workbench, Campfire (tier 0); Spear (tier 1).
Data touched: Tags ResourceNode (Config.Gather.NodeTag), Workbench; node Attributes NodeKind, HitsLeft, Depleted; Player attribute SelectedSlot. No persistence (inventory resets on join until DataService integration).
Invariants:
- Craft is atomic: on any failure inventory is unchanged (tested).
- Crafting without enough materials, unknown recipe, missing workbench, or no room all fail with a reason.
- Tools never stack and lose durability per gather hit; broken tools are removed.
- A node yields only when depleted after HitsToDeplete hits, then respawns after RespawnSeconds.
- Wrong tool or tool below node tier never harvests.
Exploit surface: Handlers check type, then tag/range, then Guard rate limit, then state (depleted, tool, tier, workbench proximity from tagged instances). Client sends only ids/slots/instances; counts, yields, tiers and durability are server-computed. Slot numbers range-checked.
Playtest checklist: 1. Hand gather on a tree is refused. 2. Craft Axe with 3 Wood succeeds, with 2 fails. 3. Axe on tree x4 yields wood, node hides, respawns later. 4. Spear fails away from a workbench, succeeds beside a tagged one.
Status: in progress (server, placement, node registration and tests done; client build UI and food use handler pending)

## Placement (PlacementService)
- Owner files: src/server/Items/PlacementService.luau, src/shared/logic/Placement.luau, tests/PlacementTests.luau, ItemCatalog.Structures, Config.Build.
- Remote PlaceRequest(structureId: string, position: Vector3, rotationY: number). Order: type-check -> sanity (known structure, finite vector, rotation bound) -> Guard rate limit (Net.PlaceRateInterval) -> state (alive, not downed, Placement.check: range, MinSpacing, per-player cap, Fire.MaxPerTeam, holds the item; ground raycast into Workspace.Chunks) -> act (remove 1 item, then build).
- Snapping: XZ to Build.GridStep, rotation to Build.RotationStep. Workbench -> CraftingService.registerWorkbench(part, tier); Campfire -> tag Config.Fire.Tag + FireService.register. Structures live in Workspace.Structures with attrs StructureId, OwnerUserId.

## Integration points
- Exposes: InventoryService.{count, add, remove, getSelected, wearSelected} (used by FireService wood spender, MobService weapon damage/drops, PlacementService cost); GatherService.registerNode (ChunkService); CraftingService.registerWorkbench (PlacementService); handleGather/handleCraft/handlePlace (QA/server path, full validation).
- Consumes: Config.Inventory.StarterItems (starter Axe on join); FireService.register/count; Workspace.Chunks for ground.
- Catalog changes: Campfire item/recipe (5 Wood, 2 Stone), RawMeat (food), Hide; Pickaxe is wood-only (4 Wood) so stone is obtainable; Spear damage = Config.Combat.SpearDamage.
