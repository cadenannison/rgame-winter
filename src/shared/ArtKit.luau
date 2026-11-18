--!strict
-- Converts the plain number arrays in Config.Art ({x,y,z} / {r,g,b}) to Roblox values. Config stays free
-- of Roblox types so the pure tests can load it.

local ArtKit = {}

function ArtKit.vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

function ArtKit.color(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

function ArtKit.palette(source: { [string]: { number } }): { [string]: Color3 }
	local out: { [string]: Color3 } = {}
	for name, rgb in source do
		out[name] = ArtKit.color(rgb)
	end
	return out
end

return ArtKit
