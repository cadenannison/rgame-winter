--!strict
-- Idempotent hub builder (art pass 1). Run once in Studio via MCP execute_luau (Edit datamodel); it
-- destroys and rebuilds Workspace.Lobby from src/server/Art (HubBuilder/HubProps, synced by Rojo).
-- Requires ServerStorage.ArtAssets (sanitized Creator Store models, see docs/CREDITS.md); missing models
-- fall back to Part-built props. Leaves no script in the place. Run servers destroy the folder at boot.
return require(game:GetService("ServerScriptService").Server.Art.HubBuilder).build()
