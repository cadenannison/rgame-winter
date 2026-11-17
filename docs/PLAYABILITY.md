# Playability checklist
Every client-facing brief must pass all of these before it is done. Check them in a local-player playtest (start_play), and emulate a phone for the mobile items.

## Input (PC and mobile)
- [ ] Every action has a PC input (key and/or click) and a mobile input (on-screen button or tap). No action is PC-only or reachable only by a debug path.
- [ ] Hotbar: keys 1-9, click/tap and mouse wheel all select; the wheel does not also zoom the camera.
- [ ] Buttons are at least 44 px on a phone and nothing overlaps the Roblox jump button or thumbstick.
- [ ] Default CoreGui that fights our input (for example the Backpack) is disabled.

## Placement ghost (any placeable)
- [ ] While a placeable is selected a transparent ghost of the structure shows on the ground, grid-snapped, following the mouse (PC) or screen centre (mobile).
- [ ] Green when valid, red when not, with the reason as text ("Too far from the fire", "Blocked").
- [ ] Rotate: R on PC, an on-screen Rotate button (>= 44 px, clear of the Act and jump buttons) on mobile. Confirm: click / E / Act.
- [ ] Ghost has no collision, no scripts, CanQuery false, and is destroyed on deselect.
- [ ] Server stays authoritative: the ghost and PlacementService both call shared/logic/Placement.validate; the server re-validates at the place action.

## Prompt (the player can see what to do)
- [ ] Every interactable shows a prompt when it is in range or aimed at: the verb plus the input ("Chop [Click/E]" / "[Act]").
- [ ] When a requirement is missing, the prompt says so before the attempt ("Chop: needs Axe", "needs workbench").
- [ ] Unavailable options are greyed out with the reason, not hidden.

## Hint (the player is taught)
- [ ] A new mechanic has a first-run hint that completes on the real action, not on a timer.
- [ ] Hints stop once their step is done and never nag again.

## Feedback (the player sees it worked or why it did not)
- [ ] Every action gives immediate local feedback (swing, sound, highlight) and a confirm from server state (particles, flash, count change).
- [ ] Every server refusal reaches the player as readable text (toast), never a raw reason code.
- [ ] Progress is visible for multi-step actions (hits left, health bar, fuel).
- [ ] Sounds and animations come from shared/Assets; a missing id falls back silently and is listed in docs/ART.md.

## Fairness and tuning
- [ ] Every target the player is asked to reach is reachable: chase targets are slower than WALK_SPEED or pause; reach >= the client pick range.
- [ ] All tuning values live in shared/Config (none inline).

## QA
- [ ] A tools/qa scenario drives the real client handlers through the Studio-only client bridge (Config.Debug.ClientBridgeName), not raw remotes, and prints <= 10 PASS/FAIL lines.
