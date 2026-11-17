# HUD
Tier: light
Purpose: Client HUD built in code (health/warmth/hunger bars, day, 9-slot hotbar with item name, compass to camp, crafting panel, target prompts, action feedback, first-run hint chain, mobile action button) plus Studio-only "/debug" chat and client QA bridges.
Owner files: src/client/HUD/{HudController,HudConfig,DebugChat,Toast,Feedback,CraftPanel,TargetPrompt,OnboardingHints,QABridge}.luau, src/shared/logic/{HudMath,ActionPick,Onboarding}.luau, tests/PlayabilityTests.luau
Public API: HudController.start() (idempotent, called from init.client); DebugChat.start() -> cleanup; HudMath.fraction/compassAngle/nextHint/parseDebug. Reads Remotes.MetersUpdate, InventoryUpdate; sends SelectSlotRequest(slot), GatherRequest(node), AttackRequest(target) on input only; DebugCommand(name, arg) in Studio only.
Data touched: Workspace attribute Config.World.CampAttribute ("CampPosition", Vector3, server-published); Player attribute Config.Inventory.SlotAttribute; tags Config.Gather.NodeTag, Config.Mobs.Tag (client target pick only). No saved data; hint "shown" state is per session.
Invariants: HUD never writes state; no per-tick remotes; all connections/instances cleaned on ScreenGui Destroying; layout is scale-based with UISizeConstraint (phone-safe); chat bridge creates nothing when not RunService:IsStudio().
Exploit surface: client only sends intents; server validates range, cooldown, slot, and DebugService validates and rate limits debug args and is absent on published servers.
Playtest checklist: 0. tools/qa/player-path.luau (Client datamodel) must PASS; docs/PLAYABILITY.md applies. 1. Play with local player: bars/day update with MetersUpdate, hotbar highlights and keys 1-9 / click / wheel select, item shows in hand. 2. Compass arrow turns with camera once CampPosition is set. 3. Emulate a phone: action button shows Gather/Attack near targets, layout fits. 4. Chat "/debug setDay 3", "/debug give Wood", "/debug spawnMob ArcticHare" and check Output. 5. Onboarding tips advance on the real actions and hide when done; reactive hints appear once each.
Status: in progress

## Integration points
- Consumes: Workspace attr Config.World.CampAttribute (HudConfig.CampAttribute reads it from Config); MetersUpdate, InventoryUpdate; tags Config.Gather.NodeTag (tree/rock slots now registered by ChunkService), Config.Mobs.Tag.
- Exposes: nothing server-side. Senders: PlaceRequest (selected placeable, aimed HudConfig.PlaceDistance ahead, server snaps), AddFuelRequest (fire within Config.Fire.AddFuelRange, has Wood), GatherRequest, AttackRequest, UseItemRequest (eat; also tap the selected food slot). One context action (ActionPick.choose: fuel > gather/attack > eat > place) drives the mobile button and the E key on PC.
- Notify(kind, text) -> Toast.luau (length-capped, HudConfig.ToastSeconds).

## Input and feedback (client UX pass)
- Hotbar: keys 1-9, click/tap, mouse wheel (ContextActionService at High priority, sunk so it does not zoom; Shift+wheel zooms). Selection is predicted locally and confirmed by InventoryUpdate / Player attr SelectedSlot; SelectSlotRequest is throttled to Config.Net.SelectRateInterval. CoreGui Backpack disabled.
- Context action (left click, E, mobile Act): ActionPick.choose -> eat (food held) > place (placeable held) > fuel (wood held, or nothing targeted, fire in range) > gather/attack target > none. Target = candidate nearest the mouse ray (Config.Feedback.AimSlack) else nearest within Config.Feedback.PromptRange.
- TargetPrompt billboard: "Chop [Click/E]" / "Chop: needs Axe" (ItemCatalog.Nodes verb/toolId) with hits-left bar; "Hunt Hare" with health bar; "Add wood".
- Feedback.luau: swing (Assets.SwingAnimation or procedural shoulder tween), sounds from shared/Assets ("" = silent), hit burst + sound on the server's HitsLeft/Depleted/MobHealth attribute change for targets we hit (watched for 2 s), mob flash (Highlight). Deny sound on Notify kinds gather/craft/build.
- CraftPanel: C or the always-visible Craft button; recipes up to Config.Craft.MaxTier (Crafting.listForTier), have/need counts, greyed with reason (Crafting.status, client-side tier from tagged workbenches), inventory counts. Row click = CraftRequest.
- OnboardingHints: shared/logic/Onboarding.STEPS equipAxe, chop, openCraft, craftCampfire, placeCampfire, addWood, eat; credited from confirmed selection and inventory deltas following our own request (2 s window). Per session (KNOWN_ISSUES).
- QABridge (Studio only): PlayerScripts[Config.Debug.ClientBridgeName] BindableFunction; Invoke(fn, ...) with fn in selectSlot, selectItem, wheel, toggleCraft, craft, action, gather, attack, place, eat, fuel, state. Same functions as the inputs.

- Round 3: HudController starts FireMeter and PlacementGhost; place() uses ghost.target(). See docs/systems/items-crafting.md and survival.md.
