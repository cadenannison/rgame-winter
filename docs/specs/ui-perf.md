# Spec: UI, controls and performance

- HUD, map, comms, mobile controls.
- Low-poly cold-palette look and sound.
- Target 30+ FPS on a mid-range phone with capped parts and mobs.

Source: split from docs/GDD.md. Index: docs/GDD.md.

## UI, controls and performance

- **HUD.** Health, warmth and hunger bars, a day counter, a hotbar, a compass that always points to camp, and short contextual hints during a player's first run.
- **Map.** A craftable fog-of-war map reveals explored areas.
- **Comms.** Roblox chat plus a ping wheel with quick calls such as need wood, danger and help.
- **Mobile controls.** One large context action button (attack, gather or interact based on the target) and a tappable hotbar. Ranged weapons get aim assist.
- **Look and sound.** Low-poly stylized parts in a consistent cold palette. Ambient wind, fire crackle, music cues, snow particles, fog and lighting changes for night and blizzards.
- **Performance target.** 30+ FPS on a mid-range phone. StreamingEnabled is on, mob and part counts are capped, and chunks load and unload around players. Agents test against these limits.
