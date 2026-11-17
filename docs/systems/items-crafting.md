# Items, inventory, gathering, crafting
Tier: full
Purpose: Server-authoritative inventory (hotbar + backpack), tier-gated resource nodes with slow respawn, and crafting at tier 0 (hand) and tier 1 (workbench). All item/recipe/node rows are data in ItemCatalog.
Owner files: src/server/Items/{InventoryService,GatherService,CraftingService}.luau, src/shared/ItemCatalog.luau, src/shared/logic/{Inventory,Crafting,ItemsGather}.luau, tests/ItemTests.luau
Public API:
- InventoryService: get, count, add(player,id,n)->leftover, remove(player,id,n)->bool, getSelected, getSelectedSlot, wearSelected, setUseHandler(fn), sync. Remotes: SelectSlotRequest(slot), UseItemRequest(slot), InventoryUpdate (server->client snapshot).
- GatherService.registerNode(instance, "Tree"|"Rock") / unregisterNode (for ChunkService). Remote: GatherRequest(node).
- CraftingService.registerStation(instance, station, tier?) / registerWorkbench, nearStations(player) -> {[station]: true} (Config.Craft.Stations Tag+Range; server re-checks at CraftRequest), availableTier (legacy). Remote: CraftRequest(recipeId). CraftingService.start() also starts InventoryService and GatherService.
- Items: Wood, Stone, Axe, Pickaxe, Spear, Workbench, Campfire, RawMeat, Hide. Recipes: Axe, Pickaxe, Workbench, Campfire (tier 0); Spear (tier 1).
Data touched: Tags ResourceNode (Config.Gather.NodeTag), Workbench; node Attributes NodeKind, HitsLeft, Depleted; Player attribute SelectedSlot. No persistence (inventory resets on join until DataService integration).
Invariants:
- Craft is atomic: on any failure inventory is unchanged (tested).
- Crafting without enough materials, unknown recipe, missing workbench, or no room all fail with a reason.
- Tools never stack and lose durability per gather hit; broken tools are removed.
- A node yields only when depleted after HitsToDeplete hits, then respawns after RespawnSeconds.
- Wrong tool or tool below node tier never harvests.
Recipe.station (ItemCatalog) names the required Config.Craft.Stations entry; Crafting.craft/status take the near-stations table and fail with NeedStation. Exploit surface: Handlers check type, then tag/range, then Guard rate limit, then state (depleted, tool, tier, workbench proximity from tagged instances). Client sends only ids/slots/instances; counts, yields, tiers and durability are server-computed. Slot numbers range-checked.
Playtest checklist: 1. Hand gather on a tree is refused. 2. Craft Axe with 3 Wood succeeds, with 2 fails. 3. Axe on tree x4 yields wood, node hides, respawns later. 4. Spear fails away from a workbench, succeeds beside a tagged one.
Status: in progress (server, placement, food, client senders and tests done)

## Placement (PlacementService)
- Owner files: src/server/Items/PlacementService.luau, src/shared/logic/Placement.luau, tests/PlacementTests.luau, ItemCatalog.Structures, Config.Build.
- Remote PlaceRequest(structureId: string, position: Vector3, rotationY: number). Order: type-check -> sanity (known structure, finite vector, rotation bound) -> Guard rate limit (Net.PlaceRateInterval) -> state (alive, not downed, Placement.check: range, MinSpacing, per-player cap, Fire.MaxPerTeam, holds the item; ground raycast into Workspace.Chunks) -> act (remove 1 item, then build).
- Build range: Placement.check also needs the snapped point inside the BuildRadius of a lit fire (FireService.getLitFires) unless Config.Build.RangeExempt[structure] (Campfire, SleepingBag); refusal OutOfBuildRange -> toast "Too far from the fire". Snapping: XZ to Build.GridStep, rotation to Build.RotationStep. Workbench -> CraftingService.registerWorkbench(part, tier); Campfire -> tag Config.Fire.Tag + FireService.register. Structures live in Workspace.Structures with attrs StructureId, OwnerUserId.

## Integration points
- Exposes: InventoryService.{count, add, remove, getSelected, wearSelected} (used by FireService wood spender, MobService weapon damage/drops, PlacementService cost); GatherService.registerNode (ChunkService); CraftingService.registerWorkbench (PlacementService); handleGather/handleCraft/handlePlace (QA/server path, full validation).
- Consumes: Config.Inventory.StarterItems (starter Axe on join); FireService.register/count; Workspace.Chunks for ground.
- Catalog changes: Campfire item/recipe (5 Wood, 2 Stone), RawMeat (food), Hide; Pickaxe is wood-only (4 Wood) so stone is obtainable; Spear damage = Config.Combat.SpearDamage.
- Food: FoodService.install() (init.server, before start) registers InventoryService.setUseHandler; UseItemRequest(slot) -> type, slot range, Guard (UseRateInterval) -> state (Consume.eat: food, alive, not downed, hunger not full) -> act (SurvivalService.feed clamped gain, consume 1, Notify "eat"). Hunger value is data: ItemCatalog RawMeat.hunger = Config.Food.RawMeatHunger. InventoryService.handleUse = QA path.
- Held item (client UX pass): src/server/Items/HeldItem.luau builds a visual Tool (Config.Held.ToolName, attr ItemId, handle from Config.Held.Visuals) in the character for the selected slot on every sync and on CharacterAdded; cleaned on PlayerRemoving. Visual only; gameplay reads the selected stack.
- Inventory: HotbarSize 9 (keys 1-9), BackpackSize 15 (total unchanged at 24).
- Gather refusal toast: "<verb>: needs <tool>" from ItemCatalog.Nodes verb/toolId (Chop/Axe, Mine/Pickaxe).
- Studio debug: "give <itemId>" grants Config.Debug.GiveCount (handler in init.server).

## Placement ghost and shared validator (round 3)
- shared/logic/Placement.validate(Check) -> {ok, reason} is the only rule set (snap, reach, lit-fire build radius, RangeExempt, spacing/overlap, caps, item). PlacementService calls it with server data; the client ghost (src/client/HUD/PlacementGhost.luau) calls it with client-visible data for tint and reason. Placement.check is the tuple wrapper. Server still re-validates at the place action.
- Ghost: Part copy of the structure (Config.Build.Ghost), no collision/scripts, CanQuery false, snapped aim from mouse ray (PC) or screen centre (touch) against the chunk ground, green/red tint, reason text from Ghost.ReasonText, R / Rotate button rotates by Build.RotationStep, destroyed on deselect. HUD place() sends the ghost position and rotation; QA bridge: ghostAim, ghostState, ghostRotate.
- QA: tools/qa/placement-preview.luau (client, 9 lines).
