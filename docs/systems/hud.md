# HUD
Tier: light
Purpose: Client HUD built in code (health/warmth/hunger bars, day, hotbar, compass to camp, mobile action button, first-run hints) plus a Studio-only "/debug" chat bridge.
Owner files: src/client/HUD/HudController.luau, HudConfig.luau, DebugChat.luau, src/shared/logic/HudMath.luau
Public API: HudController.start() (idempotent, called from init.client); DebugChat.start() -> cleanup; HudMath.fraction/compassAngle/nextHint/parseDebug. Reads Remotes.MetersUpdate, InventoryUpdate; sends SelectSlotRequest(slot), GatherRequest(node), AttackRequest(target) on input only; DebugCommand(name, arg) in Studio only.
Data touched: Workspace attribute Config.World.CampAttribute ("CampPosition", Vector3, server-published); Player attribute Config.Inventory.SlotAttribute; tags Config.Gather.NodeTag, Config.Mobs.Tag (client target pick only). No saved data; hint "shown" state is per session.
Invariants: HUD never writes state; no per-tick remotes; all connections/instances cleaned on ScreenGui Destroying; layout is scale-based with UISizeConstraint (phone-safe); chat bridge creates nothing when not RunService:IsStudio().
Exploit surface: client only sends intents; server validates range, cooldown, slot, and DebugService validates and rate limits debug args and is absent on published servers.
Playtest checklist: 1. Play with local player: bars/day update with MetersUpdate, hotbar highlights and click/number keys select slot. 2. Compass arrow turns with camera once CampPosition is set. 3. Emulate a phone: action button shows Gather/Attack near targets, layout fits. 4. Chat "/debug setDay 3", "/debug blizzard on", "/debug darkEvent" and check Output. 5. Hints appear once each.
Status: in progress

## Integration points
- Consumes: Workspace attr Config.World.CampAttribute (HudConfig.CampAttribute reads it from Config); MetersUpdate, InventoryUpdate; tags Config.Gather.NodeTag (tree/rock slots now registered by ChunkService), Config.Mobs.Tag.
- Exposes: nothing server-side. Senders: PlaceRequest (selected placeable, aimed HudConfig.PlaceDistance ahead, server snaps), AddFuelRequest (fire within Config.Fire.AddFuelRange, has Wood), GatherRequest, AttackRequest, UseItemRequest (eat; also tap the selected food slot). One context action (ActionPick.choose: fuel > gather/attack > eat > place) drives the mobile button and the E key on PC.
- Notify(kind, text) -> Toast.luau (length-capped, HudConfig.ToastSeconds).
