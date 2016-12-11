-- Logoglyph --
-- v 0.1

-- Written in Lua 5.3, should be 5.1-compatible

-- Constructs small geometric patterns semirandomly, as SVG

local matrix = require "matrix"

-- Reset RNG
math.randomseed(os.time())

---------------
-- Classes for different transforms
---------------
-- Random initializers are common to multiple transforms
function randAngleInit(self)
	return self:new{ang = math.random() * 2 * math.pi}
end

function twoRandInit(self, magnitude)
	return self:new{x = math.random() * 2 * magnitude - magnitude,
			y = math.random() * 2 * magnitude - magnitude}
end

Translate = simpleclass({x = 0, y = 0}, "Translate")
Translate.newRand = twoRandInit

Scale = simpleclass({x = 0, y = 0}, "Scale")
Scale.newRand = twoRandInit

Rotate = simpleclass({ang = 0}, "Rotate") -- remember SVG uses degrees but Lua uses radians
Rotate.newRand = randAngleInit

SkewX = simpleclass({ang = 0}, "SkewX")
SkewX.newRand = randAngleInit

SkewY = simpleclass({ang = 0}, "SkewY")
SkewY.newRand = randAngleInit

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
Circle = simpleclass({params = {cx = 0, cy = 0, r = 1},
		getTransforms = lazyInit "getTransforms",
		getChildren = lazyInit "getChildren"},
		"RegPolygon")


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
		return Translate:new{x = math.cos(angle), y = math.sin(angle)}
	end
end

-------
-- Line
-- Primitive: (0, 0) to (1, 0)
-------
Line = simpleclass({params = {x1 = 0, y1 = 0; x2 = 1, y2 = 0},
		getTransforms = lazyInit "getTransforms",
		getChildren = lazyInit "getChildren"},
		"RegPolygon")

-- Selects a random point on the line
-- Since everything is a transform from (1, 0), this is simple.
-- Consumes one argument to keep a consistent interface, ignores it.
function Line.getanchortransform(_)
	return Translate:new{x = math.random(), y = 0}
end

-------
-- RegPolygon
-- Points on a radius-1 circle
-- Anchors: Corners or center
-- TODO extend to all-points-on-shape? Maybe, maybe not.
-------
RegPolygon = simpleclass({params = {sides = sides, x = 0, y = 0},
		transforms = lazyInit "getTransforms",
		children = lazyInit "getChildren"},
		"RegPolygon")

-- Selects a random corner of the shape, or the center
-- Equal chance of all corners, 1/centerodds chance of center
function RegPolygon:getanchortransform(centerodds)
	local rand = math.random(centerodds)
	if rand == 1 then
		return Translate:new{0, 0}
	else
		local angle = ((math.pi * 2) 
			/ (math.random(self.params.sides) / self.params.sides))
		return Translate:new{x = math.cos(angle), y = math.cos(angle)}
	end
end
-------
-- Polyline
-- TODO get the main functionality working first
-- Lines specifically connected at ends
-- Anchor at corner or end
-- Random angle, random length within bounds
-------


---------------
-- Scene generation
---------------
-- Create a random chain of transforms
-- Weights provided by argument
-- odds of any given transform (n / sum, must be ints),
-- continue: likelihood of continuing (n / 1)
-- weights = {translate = n1, scale = n2, rotate = n3, skewx = n4, skewy = n5}
function randTransform(weights, continue, translatemax, scalemax)
	local funList = {}
	for i = 1, weights.translate do
		table.insert(funList, partial(
				partial(Translate.newRand, Translate),
				translatemax))
	end
	for i = 1, weights.scale do
		table.insert(funList, partial(
				partial(Scale.newRand, Scale),
				scalemax))
	end
	for key, val in pairs{rotate = Rotate, skewx = SkewX, skewy = SkewY} do
		for i = 1, weights[key] do
			table.insert(funList, partial(val.newRand, val))
		end
	end

	local weightsum = sum(weights)
	assert(#funList == weightsum, "list " .. #funList .. " sum " .. weightsum)

	local transformList = {}
	while math.random() < continue do
		local selection = math.random(weightsum)
		local item = nil
		table.insert(transformList, funList[selection]())
	end
	return transformList
end

-- Create a random shape,
-- with a random anchor on the new shape matched to
-- a random anchor on the given other shape
-- and make the new shape a child of the other.
-- Other shape is optional.
-- centerodds required, certain shapes use it
function randShape(centerodds, othershape)
	local shapes = {Circle, Line, RegPolygon}
	local base = shapes[math.random(3)]:new()
	table.insert(base:getTransforms(),
			base:getanchortransform(centerodds))
	if othershape then
		table.insert(base:getTransforms(),
			othershape:getanchortransform(centerodds))
		table.insert(othershape:getChildren())
	end
end

-- Create a full scenegraph.
-- Pass a table containing configuration:
-- 'more' = odds of adding another shape, (n / 1)
-- 'centerodds' (see randShape)
-- and all parameters to randTransform (weights, continue, translatemax, rotatemax)
function makeScenegraph(config)
	return nil -- TODO
end

---------------
-- Utilities
---------------
-- Simple classmaking function, set up index and meta
-- Does not provide for inheritance
-- Does provide for (extremely simplified) type-checking
function simpleclass(class, typename)
	class.__index = class
	class.name = typename
	class.is_a = function(self, askname) return self.name == askname end
	class.new = function(self, obj) return setmetatable(obj, class) end
	return class
end

-- Lazy initializer for empty-table fields
function lazyInit(paramname)
	return function(self)
		local _t = {} -- auto-initialize to new empty table
		self[paramname] = function(self) return _t end
		return _t
	end
end

function sum(tab)
	local _sum = 0
	for key, val in pairs(tab) do
		_sum = _sum + val
	end
	return _sum
end

function partial(f, arg)
	return function(...)
		return f(arg, ...)
	end
end
