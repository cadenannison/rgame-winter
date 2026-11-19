--!strict
-- Optional uploaded icon sprites: itemId -> "rbxassetid://..." . ItemIcon.create uses an ImageLabel when an
-- entry exists, else the ViewportFrame model icon. Add an entry to swap an item's icon, no caller changes.
-- (Separate from Assets.luau because that table is a flat string map; this is Assets.Icons in the PM contract.)
local Icons: { [string]: string } = {}

return Icons
