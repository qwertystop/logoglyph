-- Logoglyph --
-- v 0.1
-- Written in Lua 5.3, should be 5.1-compatible (I don't think I've used anything new)
-- Constructs small geometric patterns semirandomly, as SVG
---------------

---------------
-- Requirements
---------------
local lfs = require "lfs" -- luafilesystem
local argparse = require "argparse"

---------------
-- Utilities
---------------
-- Simple classmaking function, set up index and meta
-- Does not provide for inheritance
-- Does provide for (extremely simplified) type-checking
local function simpleclass(class, typename)
	class.__index = class
	class.name = typename
	class.is_a = function(self, askname) return self.name == askname end
	class.new = function(self, obj)
		local obj = obj or {}
		return setmetatable(obj, class)
	end
	return class
end

-- Lazy initializer for empty-table fields
local function lazyInit(paramname)
	return function(self)
		local _t = {} -- auto-initialize to new empty table
		self[paramname] = function(self) return _t end
		return _t
	end
end

local function sum(tab)
	local _sum = 0
	for key, val in pairs(tab) do
		_sum = _sum + val
	end
	return _sum
end

local function partial(f, arg)
	return function(...)
		return f(arg, ...)
	end
end

---------------
-- Arguments
---------------
local parser = argparse()
	:name "Logoglyph v0.1"
	:description "Constructs small patterns randomly, as SVG, by repeated transformation of primitives"
parser:option "-q --quantity"
	:convert(tonumber)
	:description "How many images to draw?"

parser:option "-s --moreshapes"
	:convert(tonumber)
	:description "Odds of adding another component shape after each addition (vs. stopping)  (0 <= m < 1)"

parser:option "-c --centerodds"
	:convert(tonumber)
	:description "Odds of anchoring a shape in the center of another (vs. an edge) (0 <= c <= 1)"

parser:option "-C --continue"
	:convert(tonumber)
	:description "Odds of adding another chained transformation after each addition (vs. stopping)  (0 <= m < 1)"


for key, val in pairs{"translate", "scale", "rotate", "skewx", "skewy"} do
	parser:option("--" .. val)
		:convert(tonumber)
		:description("Likelihood of choosing this transformation "
				.. "when applying a transformation, "
				.. "relative to the other four.")
end

parser:option "-t --translatemax"
	:convert(tonumber)
	:description "Maximum distance for one translation"

parser:option "-r --scalemax"
	:convert(tonumber)
	:description "Maximum magnitude of scaling"

parser:option "-o --output"
	:description "Directory to write files to (default writes everything to stdout)"

---------------
-- Classes for different transforms
---------------
-- Random initializers are common to multiple transforms
local function randAngleInit(self)
	return self:new{ang = math.random() * 2 * math.pi}
end

local function twoRandInit(self, magnitude)
	return self:new{x = math.random() * 2 * magnitude - magnitude,
			y = math.random() * 2 * magnitude - magnitude}
end

local Translate = simpleclass({x = 0, y = 0}, "Translate")
Translate.newRand = twoRandInit
function Translate:asSVGAttribute()
	return ('transform="translate(' .. self.x .. ',' .. self.y .. ')"')
end

local Scale = simpleclass({x = 0, y = 0}, "Scale")
Scale.newRand = twoRandInit
function Scale:asSVGAttribute()
	return ('transform="scale(' .. self.x .. ',' .. self.y .. ')"')
end

local Rotate = simpleclass({ang = 0}, "Rotate") -- remember SVG uses degrees but Lua uses radians
Rotate.newRand = randAngleInit
function Rotate:asSVGAttribute()
	return ('transform="rotate(' .. self.ang .. ')"')
end

local SkewX = simpleclass({ang = 0}, "SkewX")
SkewX.newRand = randAngleInit
function SkewX:asSVGAttribute()
	return ('transform="skewX(' .. self.ang .. ')"')
end

local SkewY = simpleclass({ang = 0}, "SkewY")
SkewY.newRand = randAngleInit
function SkewY:asSVGAttribute()
	return ('transform="skewY(' .. self.ang .. ')"')
end

---------------
-- Classes for primitive shapes
-- All instances of a shape have the same base parameters,
-- and are modified from there by transforms only.
-- Anchors are used in shifting shapes to align
-- All shapes have a getAnchorTransform function, returning a random point on the edge
-- or in the center of the shape, in coordinates local to that shape's primitive.
-- If a shape is instantiated with params other than the default, getAnchorTransform
-- may not align to the shape.
---------------
-------
-- Circles
-- Primitive: Center at origin, radius 100.
-- No ellipse primitive - emergent, just unevenly scale a circle.
-------
local Circle = simpleclass({params = {cx = 0, cy = 0, r = 100},
		getTransforms = lazyInit "getTransforms",
		getChildren = lazyInit "getChildren"},
		"Circle")


-- Selects a point from center or any point on edge
-- centerodds/1 chance of selecting center (thus, configurable)
-- Equal chance of any point on edge to any other point, if not center
-- Returns a translation putting (0, 0) on selected point
function Circle:getAnchorTransform(centerodds)
	if math.random() < centerodds then
		return Translate:new{x = 0, y = 0}
	else
		local angle = math.random() * math.pi * 2
		return Translate:new{x = math.cos(angle) * 100, y = math.sin(angle) * 100}
	end
end

function Circle:asSVGElement()
	return '<use xlink:href"#BaseCircle"/>'
end

-------
-- Line
-- Primitive: (0, 0) to (100, 0)
-------
local Line = simpleclass({params = {x1 = 0, y1 = 0; x2 = 100, y2 = 0},
		getTransforms = lazyInit "getTransforms",
		getChildren = lazyInit "getChildren"},
		"Line")

-- Selects a random point on the line
-- Since everything is a transform from (100, 0), this is simple.
-- Consumes one argument to keep a consistent interface, ignores it.
function Line:getAnchorTransform(_)
	return Translate:new{x = math.random() * 100, y = 0}
end

function Line:asSVGElement()
	return '<use xlink:href"#BaseCircle"/>'
end

-------
-- RegPolygon
-- Points on a radius-100 circle
-- Anchors: Corners or center
-- TODO extend to all-points-on-shape? Maybe, maybe not.
-------
local RegPolygon = simpleclass({params = {sides = sides, x = 0, y = 0},
		getTransforms = lazyInit "getTransforms",
		children = lazyInit "getChildren"},
		"RegPolygon")

-- Selects a random corner of the shape, or the center
-- Equal chance of all corners, centerodds/1 chance of center
function RegPolygon:getAnchorTransform(centerodds)
	if math.random() < centerodds then
		return Translate:new{0, 0}
	else
		local angle = ((math.pi * 2) 
			/ (math.random(self.params.sides) / self.params.sides))
		return Translate:new{x = math.cos(angle) * 100, y = math.sin(angle) * 100}
	end
end

function RegPolygon:asSVGElement()
	local pointset = {}
	for i = 0, (self.params.sides - 1) do
		angle = (math.pi * 2) / (i / self.params.sides)
		table.insert(pointset, tostring(math.cos(angle) * 100))
		table.insert(pointset, tostring(math.sin(angle) * 100))
	end
	return table.concat({'<polygon fill="none" stroke="black" stroke-width="10" points="', 
		table.concat(pointset, ' '), '"/>'}, '')
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
local function randTransform(weights, continue, translatemax, scalemax)
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
local function randShape(centerodds, othershape)
	local shapes = {Circle, Line, RegPolygon}
	local base = shapes[math.random(3)]:new({})
	print(base.name)
	table.insert(base:getTransforms(),
			base:getAnchorTransform(centerodds))
	if othershape then
		table.insert(base:getTransforms(),
			othershape:getAnchorTransform(centerodds))
		table.insert(othershape:getChildren(), base)
	end
	return base
end

-- Create a full scenegraph (returns root).
-- Pass a table containing configuration:

-- 'moreshapes' = odds of adding another shape, (n / 1)
-- 'centerodds' (see randShape)
-- and all parameters to randTransform (weights, continue, translatemax, scalemax)
local function makeScenegraph(config)
	-- Minimum two shapes
	local shapes = {}
	table.insert(shapes, randShape(config.centerodds))
	repeat
		-- Add transforms to last shape
		table.insert(shapes[#shapes]:getTransforms(),
				randTransform(config.weights, config.continue,
						config.translatemax, config.scalemax))
		-- Pick a shape from the list to make the parent of the new shape
		local parent = shapes[math.random(#shapes)]
		table.insert(shapes, randShape(config.centerodds, parent))
		-- repeat
	until math.random() < config.moreshapes
	return shapes[1] -- returning root of scene, not the whole list
end

-- Write an individual object as SVG - this function handles the generic parts
-- (groups, transforms, children)
local function writeObjectSVG(shape)
	-- Open a group
	io.write('<g ')
	-- Include all transforms
	for k, v in ipairs(shape:getTransforms()) do
		if v then
			io.write(v:asSVGAttribute())
		end
	end
	io.write('>')
	-- Include this specific object
	shape:asSVGElement()
	-- This object's children, recursively 
	for k, v in ipairs(self:getChildren()) do
		writeObjectSVG(v)
	end
	io.write('</g>')
end

-- Write the SVG of scenegraph "source" into file named "target"
local function writeSceneSVG(source, target)
	if target then
		io.output(io.open(target, 'w'))
	else
		io.output(io.stdout)
	end
	-- boilerplate start
	io.write('<svg version="1.1" width="1000" height="1000"',
		        'viewBox="-500 -500 1000 1000"',
		        'preserveAspectRatio="meet" >',
		   '<defs>',
		     '<g fill="none" stroke="black" stroke-width="10" >',
		       '<circle id="BaseCircle" cx="0" cy="0" r="100" />',
		       '<line id="BaseLine" x1="0" y1="0" x2="100" y2="0" />',
		     '</g>',
		   '</defs>')
	-- write all shapes, depth-first through the tree, from the root
	writeObjectSVG(source)
	io.write('</svg>')
end

-----------------
-- Execution
-----------------

-- Seed RNG at start
math.randomseed(os.time())

-- define the main function
local function main()
	local args = parser:parse()
	args.weights = {}
	-- bundle it up more nicely for later passing
	for k, v in pairs{"translate", "rotate", "scale", "skewx", "skewy"} do
		args.weights[v] = args[v]
		args[v] = nil
	end

	-- make directory if it doesn't exist
	-- TODO add a tag to lock reading from the folder and prevent
	-- overwriting old with new files by working from highest number
	-- TODO base folder directly on args for organization
	if not lfs.chdir(args.output) then
		assert (lfs.mkdir(args.output), "Could not make or access target dir")
		lfs.chdir(args.output)
	end
	
	-- make all requested scenes
	for i = 1, args.quantity do
		local scene = makeScenegraph(args)
		writeSceneSVG(scene, tostring(i) .. '.svg')
	end
end

-- and BEGIN!
main()
