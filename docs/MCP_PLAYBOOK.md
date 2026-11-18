# MCP Playbook

## Division of labor
- Rojo owns scripts (src/). MCP owns instances, properties and playtesting. Never write script Source through MCP.
- UI is built in code. MCP builds world/set dressing only, via idempotent builders in tools/.

## Token discipline
Exact paths, shallow depth, filtered output (errors/warnings), one batched call, no re-inspection of what you just wrote, no whole-tree dumps, no screenshots unless the brief asks (max 5).

## Verify loop
Edit -> scripts/check.sh -> Rojo sync -> scripted playtest (tools/qa, local player via start_play) -> fix. Stop after 3 failed fixes and report a diagnosis.

## Builders are the source of truth
Map, art and lighting come from tools/map and tools/art scripts: idempotent (delete then recreate own output), deterministic (seeded), no script left in the place, values recorded in the system doc. Playtests are tools/qa/<system>.luau: one MCP call, PASS/FAIL lines.

## SAVE NEEDED
Agents cannot save the place. After any MCP instance work, end the report with SAVE NEEDED; the human saves (Cmd+S).

## Safety
MCP clients can read and modify the open place: run only trusted agents and keep a Version History checkpoint before big edits.

## Studio target
Act only on the Studio whose placeId is 130366229723914 (fill in after publishing). Pass its studio id on every call. If more than one Studio is open, stop and ask. Playtest with a local player (start_play), never server-only.
