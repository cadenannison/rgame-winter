# Events (blizzards + dark events)
Tier: standard
Purpose: Server-only, seed-deterministic schedule of blizzards (every 4-5 days) and dark events (FalseNight, TheQuiet, DeepFreeze); sensory warnings only.
Spec: docs/specs/horror.md. Data: src/shared/data/Events.luau (+ Events.Tuning).
Owner files: src/shared/logic/EventSchedule.luau, src/server/Events/EventService.luau, src/client/Events/EventCues.luau, Phase3/EventsBoot + EventsClient, tests/EventTests.luau.
Public API (EventService): getModifiers() -> {warmthDrain, fuelBurn, dreadGain, huntBonus, nightRules, silence, visibility, spawn} (all capped), isBlizzard(), getActiveDarkEvent(), onBlizzardStart(cb), onEventStart(cb(id)), onEventEnd(cb(id, survivors)), setFullGroupPredicate(fn), setSpawnMultiplierSink(fn(mult)), setSeed(n) before start, forceBlizzard()/forceDark(id) (QA).
Data touched: Workspace attributes DarkEvent (id or ""), Blizzard, BlizzardWarning. Cue remote: Warn*, EventStart/EventEnd with coarse level 0..Cue.MaxLevel. Nothing persisted.
Invariants: no dark event before FirstDay; MinGapSeconds between dark events; MaxPerDay; never overlaps a blizzard (warning..end plus BlizzardBufferSeconds either side); blizzard gap 4-5 days; warnings change no rules; modifiers clamp to Config.Events.Max* and Events.Tuning caps; same seed = same schedule; full group (predicate) blocks FalseNight and TheQuiet.
Exploit surface: no client input. Clients receive no timers, only Cues and visible attributes.
Playtest checklist: 1. Studio debug darkEvent/blizzard force: warning cue, then attribute set, then end. 2. Visibility/tint change client side. 3. No Cue payload carries a timer.
Status: logic + tests done; not playtested (no Studio this round).
