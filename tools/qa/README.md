# tools/qa
One self-contained snippet per system: `tools/qa/<system>.luau`, run in one MCP call during Play (local player, start_play), printing `PASS name` / `FAIL name: reason` lines. No helper code written through MCP. Target <10K tokens per playtest.

Load-failure hook (Studio only): set ReplicatedStorage attribute QAForceLoadFailure = "data" (before the player's profile loads) or "spawn" (at runtime, then kill the character) to force the LoadFailed path with no src edit. Expect Player attribute LoadFailed=true, the client message, and a kick after ~1s.
