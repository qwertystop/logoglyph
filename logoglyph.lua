-- Logoglyph --
-- v 0.1

-- Written in Lua 5.3, should be 5.1-compatible

-- Constructs small geometric patterns semirandomly, as SVG

local matrix = require "matrix"

-- Reset RNG
math.randomseed(os.time())

-- Simple class function, set up index and meta
function simpleclass(class)
	class.__index = class
	class.new = function (self, obj) return setmetatable(obj, class) end
	return class
end

---------------
-- Classes for different transforms
---------------
Translate = simpleclass{dx = 0, dy = nil}
Scale = simpleclass{sx = 0, sy = nil}
Rotate = simpleclass{ang = 0} -- remember SVG uses degrees but Lua uses radians
SkewX = simpleclass{ang = 0}
SkewY = simpleclass{ang = 0}


---------------
-- Classes for primitive shapes
-- All instances of a shape have the same base parameters,
-- and are modified from there by transforms only.
-- Anchors are used in shifting shapes to align
---------------
-------
-- Circles
-- Center and radius. Anchor is center or edge.
-------
Circle = simpleclass{params = {center = {0, 0}, radius = 1},
                     transforms = {}}
Circle.__index = Circle
function Circle:new(transforms)
	return setmetatable({transforms = transforms}, self)
end

-- 1/centerodds chance of selecting center
-- returns a translation putting {0, 0} on that point
function Circle:getanchortransform(centerodds)
	local rand = math.random(centerodds)
	if rand == 1 then
		return Translate:new(0, 0)
	else
		local angle = math.random() * math.pi / 2
		return Translate:new{dx = math.cos(angle), dy = math.sin(angle)}
	end
end

-- TODO Repeat for other primitives.


