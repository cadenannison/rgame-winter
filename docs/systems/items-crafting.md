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
- Inventory: HotbarSize 9 (keys 1-9), BackpackSize 27 (total 36; superseded by the Items round below).
- Gather refusal toast: "<verb>: needs <tool>" from ItemCatalog.Nodes verb/toolId (Chop/Axe, Mine/Pickaxe).
- Studio debug: "give <itemId>" grants Config.Debug.GiveCount (handler in init.server).

## Placement ghost and shared validator (round 3)
- shared/logic/Placement.validate(Check) -> {ok, reason} is the only rule set (snap, reach, lit-fire build radius, RangeExempt, spacing/overlap, caps, item). PlacementService calls it with server data; the client ghost (src/client/HUD/PlacementGhost.luau) calls it with client-visible data for tint and reason. Placement.check is the tuple wrapper. Server still re-validates at the place action.
- Ghost: Part copy of the structure (Config.Build.Ghost), no collision/scripts, CanQuery false, snapped aim from mouse ray (PC) or screen centre (touch) against the chunk ground, green/red tint, reason text from Ghost.ReasonText, R / Rotate button rotates by Build.RotationStep, destroyed on deselect. HUD place() sends the ghost position and rotation; QA bridge: ghostAim, ghostState, ghostRotate.
- QA: tools/qa/placement-preview.luau (client, 9 lines).

## Items round: inventory revamp, equipment, storage chests
Owner files add: src/server/Items/{ItemDrop,StorageService,ClothingService}.luau, src/shared/logic/{InventoryMove,Equipment}.luau, src/client/Storage/{BackpackPanel,EquipmentViewport,InventoryUiConfig,StorageController,InventoryMirror}.luau, tests/{InventoryTests,EquipmentTests}.luau.
- Stack sizes: Config.Items (category defaults + per-item entries) stamped onto every item by ItemCatalog (ItemCatalog.stackOf). data/Items.luau mirrors it (Arrow = ammo 30). Items carrying durability never merge (torches, flares, tools), so they occupy one slot each; Torch stack 10 is therefore only the cap.
- Single move path: remote InventoryMove {from, to?, count, rev?, expect?} (to = nil is shift-click quick move). Addresses {kind="inv",slot} | {kind="equip",slot=<Config.Equipment.Slots id>} | {kind="chest",id,slot}. InventoryService.onMove order: parse (type, range) -> Guard rate limit (Config.Storage.MoveRateInterval) -> state (alive, not downed, equipment loaded, open chest in reach via StorageService provider) -> act (shared/logic/InventoryMove.perform: atomic merge / swap / split / equip rules / quick move). Refusals toast (Notify) and fire InventoryMoveResult {ok=false, reason}; the client shakes the target slot.
- Equipment: Equipment (pure) = Inventory of Config.Equipment.Slots; Equipment.accepts uses ItemCatalog equipSlot (accessories fit either accessory slot). Worn gear leaves the grid, persists in profile.equipment (written on every change, validated on load: unknown items/slots dropped), and only worn pieces feed ColdResistance (ClothingLogic.equipped, capped Config.Clothing.MaxColdResistance; ClothingService updates on change and each Biome.UpdateInterval). InventoryService.clearEquipment(player) is the run-end/death hook. Held-for-rejoin keeps worn gear with the inventory.
- Storage chests: craft 8 wood at Workbench tier 1 (data/Recipes from Config.Storage). StorageService: 9 slots per chest, shared by the party, open via ProximityPrompt (client) or StorageOpenRequest, closes on distance/death. Revision counter = Config.Storage.RevisionAttribute (bumped on each change, sent in StorageState). A move carries the revision the client saw plus the item id it saw at the source: stale = server re-syncs the viewer and applies only if the source still holds that item and the move is otherwise valid. StorageService.canPickUp (non-empty refuses), ownedCount/placeRefusal (MaxPerPlayer, called by PlacementService).
- Grants: InventoryService.grant(player, id, count) -> (added, dropped): same stack rules, overflow dropped at the feet (ItemDrop pickup prompt) with an "Inventory full" toast. add/canAdd/remove keep their signatures. GatherService holds the last hit when the yield does not fit (nothing is lost).
- Client: BackpackPanel (B / Backpack button): equipment + rotating character viewport, 27-slot grid, hotbar row, chest grid when a chest is open. Drag and drop, right-click or long-press (Config.Inventory.SplitHoldSeconds) to take half, shift-click quick move, tap-select then tap-destination on phones; slots >= 44 px, columns shrink on narrow screens. Unbreakable items show no durability label (Repair.durabilityLabel).
- Tests: tests/InventoryTests.luau, tests/EquipmentTests.luau, storage cases in tests/ProgressionTests.luau.
