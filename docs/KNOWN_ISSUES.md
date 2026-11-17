# Known issues

- Unloading and reloading a chunk resets its depleted nodes. Chunk unload destroys node state (Depleted/HitsLeft attributes), so a reload rebuilds the nodes full and an exhausted tree or rock reappears instantly. Not fixed; needs depleted-node timers kept outside the chunk (e.g. in GatherService keyed by node slot id).
- Onboarding progress is per session. The hint chain restarts on rejoin; persisting it needs a ProfileSchema field + migration (DataService owner).
- Swing animation and action sounds use fallbacks. Assets.SwingAnimation is empty (procedural arm swing, local only, other players do not see it) and the sounds are engine rbxasset placeholders; ids listed in docs/ART.md.
- Placement has no ghost preview. A placeable lands HudConfig.PlaceDistance ahead of the character; refusals come back as toasts.
- Studio logs one warning not from this repo: rbxassetid://203785492 "Asset type does not match requested type" (place content or a plugin).
