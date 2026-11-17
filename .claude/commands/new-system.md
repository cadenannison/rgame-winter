---
description: Scaffold a new system (spec doc, architecture row, stub files)
argument-hint: <SystemName>
---
Create system "$ARGUMENTS":
1. Create docs/systems/$ARGUMENTS.md from docs/systems/_TEMPLATE.md (Status: planned; choose a Tier).
2. Add a row to the systems table in docs/ARCHITECTURE.md.
3. Stub `--!strict` Luau files in the right realm folders (src/server, src/client, src/shared; pure logic in src/shared/logic/) and list them under Owner files.
4. Run scripts/check.sh. Do not commit or push.
