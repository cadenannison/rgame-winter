--!strict
-- World prop generators (art pass 2). Every builder lays low-poly Part geometry into `parent` at `cf`
-- (cf = ground point, +Y up) and returns the Model it made. Pure geometry: no scripts, no gameplay tags;
-- WorldArt places them on chunks/nodes/POIs and /debug gallery world shows each one. Part counts are
-- capped by Config.Art.World (MaxPartsPerTree / MaxPartsPerRock / MaxPartsPerPoi); WorldProps.count
-- measures them. Trees, rocks and decor never collide (the invisible gather node part stays the
-- gameplay object); POI hulls collide where the old block-outs did.
-- Facade: the builders live in Props/ (TreeProps, RockProps, DecorProps, PoiProps; helpers in PropKit).

local PropKit = require(script.Parent:WaitForChild("Props"):WaitForChild("PropKit"))
local TreeProps = require(script.Parent:WaitForChild("Props"):WaitForChild("TreeProps"))
local RockProps = require(script.Parent:WaitForChild("Props"):WaitForChild("RockProps"))
local DecorProps = require(script.Parent:WaitForChild("Props"):WaitForChild("DecorProps"))
local PoiProps = require(script.Parent:WaitForChild("Props"):WaitForChild("PoiProps"))

local WorldProps = {
	count = PropKit.count,
}

local target = WorldProps :: any
for _, module in { TreeProps, RockProps, DecorProps, PoiProps } :: { { [string]: any } } do
	for key, value in module do
		assert(target[key] == nil, `WorldProps.{key} defined twice`)
		target[key] = value
	end
end

return WorldProps :: { count: typeof(PropKit.count) } & typeof(TreeProps) & typeof(RockProps) & typeof(DecorProps) & typeof(PoiProps)
