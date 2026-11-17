# Art log
Every imported asset: id, creator, source. No branded or copyrighted content. Strip all scripts from imported models.

| asset | id | creator | source | notes |
|---|---|---|---|---|
| SwingSound, ChopSound, MobHitSound, CraftSound, DenySound | rbxasset://sounds/* | Roblox | engine-bundled | placeholders in src/shared/Assets.luau |

## Needed assets (human must supply ids in src/shared/Assets.luau)
- SwingAnimation: R15 one-shot tool swing (empty now -> procedural arm swing).
- SwingSound, ChopSound (wood chop / stone hit), MobHitSound, CraftSound, DenySound: replace the engine placeholders.

- WolfGrowlSound, DuskSound, DawnSound: empty now (silent). Growl (~1s, low), soft dusk cue, soft dawn cue. BiteSound is the engine placeholder rbxasset://sounds/uuhhh.mp3; replace with a real hurt/bite sound.

Part counts per built area: (record here)
