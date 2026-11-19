# ART PASS 4 CONTRACT (items, worn gear, structures)
Written by the orchestrator before the agents start. Agents: edit ONLY the files you own. Shared files (Config/init.luau, Assets.luau, IconAssets.luau, Remotes.luau, docs) belong to the orchestrator; ask via your report.
Style: stylised low-poly, cold palette, Part-built. No Creator Store assets (if ever: sanitise all scripts + credit in CREDITS.md). Per-agent tuning lives in your Config module only. Every file --!strict; `scripts/check.sh` must pass; no commits; no playtests (headless tests only).

## Shared APIs
### ItemModels (Agent A) - src/shared/ItemModels.luau (Roblox Parts; used by server + client)
- `ItemModels.build(itemId: string, mode: "icon" | "drop" | "held"): Model?` fresh Part-built Model, PrimaryPart set, <= Config.ArtItems.ModelMaxParts (icon/held) or DropMaxParts (drop) BaseParts, CanCollide/CanQuery/CanTouch false, Anchored false for held/drop. nil only for unknown id. A generic fallback shape per `kind` when no bespoke builder exists. Covers EVERY id in ItemCatalog.Items (tests: tests/ItemModelsCoverage asserts this).
- `ItemModels.bounds(itemId): Vector3` model size for camera framing.
### ItemIcon (Agent A) - src/client/Storage/ItemIcon.luau
- `ItemIcon.create(parent: Instance, itemId: string, size: UDim2): ItemIconHandle` where handle = `{ frame: GuiObject, setItem: (string?) -> (), destroy: () -> () }`.
- Backend 2 first: if `IconAssets[itemId]` is non-empty -> ImageLabel. Else backend 1: ViewportFrame, ONE shared camera config, cached model per itemId (clone), live-viewport cap Config.ArtItems.MaxLiveViewports with TextLabel fallback above the cap; viewport only while the slot is occupied AND visible; released on destroy/hidden.
- All slot UI keeps using SlotLayout + SlotViewModel; no ad-hoc index math.
### Gear (Agent B) - server only
- `GearService` (src/server/Items/GearService.luau): `start()`, `refresh(player)` (rebuild from InventoryService's equipment), `clear(player)`. Hooks: InventoryService calls `GearService.refresh` after equip/unequip sync, `clear` inside clearEquipment and PlayerRemoving; CharacterAdded re-applies. Needs only a one-line call-in to InventoryService (Agent B may edit those lines only).
- `GearModels` (src/server/Art/GearModels.luau): `GearModels.build(itemId: string, slot: string, character: Model): { BasePart }` Part-built, welded (WeldConstraint) to the R15 part named in Config.ArtGear.Rig[slot], parent = a Folder named Config.ArtGear.FolderName under the character (replicates). Total <= Config.ArtGear.MaxPartsPerPlayer across all slots. Each part stamped Attribute Config.ArtGear.PartAttribute = slot. CanCollide=false, Massless=true, no scripts. Must not overlap HeldItem's right-hand tool (Hands gear sits on the glove area, not the grip) nor Animate (no Motor6D).
- Gear coverage: every item in ItemCatalog.Items with equipSlot (Head, Body, Legs, Feet, Hands, Neck, Accessory1/2).
### Structures / chests / signs (Agent C)
- Owns: src/server/World/Structures/StructureKitA|B.luau, src/shared/logic/StructurePlanKitA.luau, PlanKitB.luau (and PoiPlan only where unavoidable), src/server/Art/ChestArt.luau, src/client/Loot/Chest*.luau, src/shared/logic/ChestStyle.luau, src/server/Art/Gallery.luau, research-station sign code, new files src/server/Art/Structures/*.
- Rules: rings 1-2 single story (Config.ArtStructures.MaxSingleStoryRing); chests/signs fixed orientation (never face player; no BillboardGui for sign text -> SurfaceGui on the sign part); chest glow = <= Config.ArtStructures.ChestGlowEmitters particle emitters within ChestGlowMaxStuds; beam rare+ only, <= BeamMaxStuds, client-side near-only (BeamNearStuds); Perf.MaxLiveParts stays 6000; one massive structure live at a time; dressing lazy near players.

## File ownership (exclusive)
- A: src/shared/ItemModels.luau, src/client/Storage/* (ItemIcon, BackpackPanel, InventoryUiConfig, slot UI), src/client/HUD hotbar slot visuals (HudWidgets hotbar section only), shared/logic/{ItemTooltip,SlotLayout,SlotViewModel}, src/server/Items/{ItemDrop,HeldItem}, Config/ArtItems.luau, Config.Ui.Held, tests for these.
- B: src/server/Art/GearModels.luau, src/server/Items/GearService.luau, Config/ArtGear.luau, tests/GearTests.
- C: as listed above, Config/ArtStructures.luau.
- Orchestrator: Config/init.luau, Assets.luau, IconAssets.luau, Remotes.luau, docs/*.
