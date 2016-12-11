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
-- All shapes have a getanchortransform function, returning a random point on the edge
-- or in the center of the shape, in coordinates local to that shape's primitive.
-- If a shape is instantiated with params other than the default, getanchortransform
-- may not align to the shape.
---------------
-------
-- Circles
-- Primitive: Center at origin, radius 1.
-- No ellipse primitive - emergent, just unevenly scale a circle.
-------
Circle = simpleclass{params = {cx = 0, cy = 0, r = 1},
			transforms = {}}


-- Selects a point from center or any point on edge
-- 1/centerodds chance of selecting center (thus, configurable)
-- Equal chance of any point on edge to any other point, if not center
-- Returns a translation putting (0, 0) on selected point
function Circle.getanchortransform(centerodds)
	local rand = math.random(centerodds)
	if rand == 1 then
		return Translate:new(0, 0)
	else
		local angle = math.random() * math.pi * 2
		return Translate:new{dx = math.cos(angle), dy = math.sin(angle)}
	end
end

-------
-- Line
-- Primitive: (0, 0) to (1, 0)
-------
Line = simpleclass{params = {x1 = 0, y1 = 0; x2 = 1, y2 = 0},
		transforms = {}}

-- Selects a random point on the line
-- Since everything is a transform from (1, 0), this is simple.
function Line.getanchortransform()
	return Translate:new{dx = math.random(), dy = 0}
end

-------
-- RegPolygon
-- Points on a radius-1 circle
-- Anchors: Corners or center
-- TODO extend to all-points-on-shape
-- Actually a class-factory - input side number, get class for that many sides
-------
RegPolygon = simpleclass{params = {sides = sides, x = 0, y = 0},
		transforms = {}}

-- Selects a random corner of the shape, or the center
-- Equal chance of all corners, 1/centerodds chance of center
function RegPolygon:getanchortransform(centerodds)
	local rand = math.random(centerodds)
	if rand == 1 then
		return Translate:new{0, 0}
	else
		local angle = ((math.pi * 2) 
			/ (math.random(self.params.sides) / self.params.sides))
		return Translate:new{dx = math.cos(angle), dy = math.cos(angle)}
	end
end
-------
-- Polyline
-- TODO get the main functionality working first
-- Lines specifically connected at ends
-- Anchor at corner or end
-- Random angle, random length within bounds
-------
