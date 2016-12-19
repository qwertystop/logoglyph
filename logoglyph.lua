-- Logoglyph --
-- v 0.1
-- Written in Lua 5.3, should be 5.1-compatible (I don't think I've used anything new)
-- Constructs small geometric patterns semirandomly, as SVG
---------------

---------------
-- Requirements
---------------
local pl = require "pl.import_into"() -- penlight

---------------
-- Help
---------------
local function help()
	local info = {
		"Logoglyph: A script producing random SVGs from \n"
		.. "primitive shapes with chained transformations.",
		"\n",
		"Arguments (all 'chances' are 0 < arg < 1):",
		"--quantity:\tHow many images to write?",
		"--morehapes:\tChance of adding another shape at each step.",
		"--centerodds:\tChance of centering a new shape in a previous shape,\n"
		.. "\t\tinstead of putting it on the edge.",
		"--moretransforms:\tChance of chaining another transform after adding one.",
		"--translate:\tPortion of transformations to be translations\n"
		.."\t\t(relative to other four)",
		"--rotate:\tPortion of transformations to be rotations\n"
		.."(\t\trelative to other four)",
		"--scale:\tPortion of transformations to be scales\n"
		.."\t\t(relative to other four)",
		"--skewx:\tPortion of transformations to be skews on the X direction\n"
		.."\t\t(relative to other four)",
		"--skewy:\tPortion of transformations to be skews on the Y direction\n"
		.."\t\t(relative to other four)",
		"--output:\tDirectory to write files into"
	}
	print(table.concat(info, '\n'))
end

--------------
-- Utilities
--------------
local function sum(tab)
	local sum = 0
	for _, v in pairs(tab) do
		sum = sum + v
	end
	return sum
end

---------------
-- Classes for different transforms
---------------
-- Random initializers are common to multiple transforms
local TwoArgTransform = pl.class {
	_name = "twoArgTransform";

	_init = function(self, x, y)
		self.x = x
		self.y = y
	end;

	newRand = function (self)
			return self(math.random() * 2 * 10 - 10,
					math.random() * 2 * 10 - 10)
	end;
}

local Translate = pl.class {
	_name = "Translate";

	_base = TwoArgTransform;

	asSvgAttribute = function (self)
		return ('translate(' .. self.x .. ',' .. self.y .. ') ')
	end
}

local Scale = pl.class {
	_name = "Scale";

	_base = TwoArgTransform;

	asSvgAttribute = function (self)
		return ('scale(' .. self.x .. ',' .. self.y .. ') ')
	end
}

local oneArgTransform = pl.class {
	_name = "oneArgTransform";

	_init = function (self, ang)
		self.ang = ang
	end;

	newRand = function (self)
		return self(math.random() * 2 * math.pi)
	end
}

local Rotate = pl.class {
	_name = "Rotate";

	_base = oneArgTransform;

	asSvgAttribute = function (self)
		return ('rotate(' .. self.ang .. ') ')
	end
}

local SkewX = pl.class {
	_name = "SkewX";

	_base = oneArgTransform;

	asSvgAttribute = function (self)
		return ('skewX(' .. self.ang .. ') ')
	end
}

local SkewY = pl.class {
	_name = "SkewY";

	_base = oneArgTransform;

	asSvgAttribute = function (self)
		return ('skewY(' .. self.ang .. ') ')
	end
}

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

local Shape = pl.class{
	_init = function (self)
		self.transforms = pl.List.new()
		self.children = pl.List.new()
	end
}

-------
-- Circles
-- Primitive: Center at origin, radius 100.
-- No ellipse primitive - emergent, just unevenly scale a circle.
-------
local Circle = pl.class{
	_name = "Circle";
	
	_base = Shape;
	
	_init = function (self)
		self:super()
		self.cx = 0
		self.cy = 0
		self.r = 10
	end;
	
	-- centerodds/1 chance of selecting center (thus, configurable)
	-- Equal chance of any point on edge to any other point, if not center
	-- Returns a translation putting (0, 0) on selected point
	getAnchorTransform = function (self, centerodds)
		if math.random() < centerodds then
			return Translate(0, 0)
		else
			local angle = math.random() * math.pi * 2
			return Translate(math.cos(angle) * 100,
					math.sin(angle) * 100)
		end
	end;

	asSvgElement = function (self)
		return '<circle cx="0" cy="0" r="100" />\n'
	end;
}


-------
-- Line
-- Primitive: (0, 0) to (100, 0)
-------
local Line = pl.class{
	_name = "Line";

	_base = Shape;

	_init = function (self)	
		self:super()
		self.x1 = 0
		self.y1 = 0
		self.x2 = 100
		self.y2 = 0
	end;

	-- Selects a random point on the line
	-- Since everything is a transform from (100, 0), this is simple.
	-- Consumes one argument to keep a consistent interface, ignores it.
	getAnchorTransform = function (self, _)
		return Translate(math.random() * 100, 0)
	end;

	asSvgElement = function (self)
		return '<line x1="0" y1="0" x2="100" y2="0" />\n'
	end;
}

-------
-- RegPolygon
-- Points on a radius-100 circle
-- Anchors: Corners or center
-- TODO anchor possibilities extend to all-points-on-shape? Maybe, maybe not.
-------
local RegPolygon = pl.class{
	_name = "RegPolygon";

	_base = Shape;
	
	_init = function (self)
		self:super()
		self.cx = 0
		self.cy = 0
		self.sides = math.random(10)
	end;

	-- Selects a random corner of the shape, or the center
	-- Equal chance of all corners, centerodds/1 chance of center
	getAnchorTransform = function (self, centerodds)
		if math.random() < centerodds then
			return Translate(0, 0)
		else
			local angle = ((math.pi * 2) 
				/ (math.random(self.sides) / self.sides))
			return Translate(math.cos(angle) * 100,
					math.sin(angle) * 100)
		end
	end;

	 asSvgElement = function (self)
		local pointset = {}
		for i = 1, self.sides do
			angle = (math.pi * 2) / (i / self.sides)
			table.insert(pointset, tostring(math.cos(angle) * 100))
			table.insert(pointset, tostring(math.sin(angle) * 100))
		end
		return table.concat({
			'<polygon points="', 
			table.concat(pointset, ' '),
			'" />\n'
		}, '')
	end
}
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
-- moretransforms: likelihood of continuing (n / 1)
-- weights = {translate = n1, scale = n2, rotate = n3, skewx = n4, skewy = n5}
local function randTransform(weights, moretransforms)
	local funList = pl.List.new()
	for key, val in pairs {
			translate = Translate,
			scale = Scale,
			rotate = Rotate,
			skewx = SkewX,
			skewy = SkewY} do
		for i = 1, weights[key] do
			funList:append(val)
		end
	end

	local weightsum = sum(weights)
	assert(#funList == weightsum, "list " .. #funList .. " sum " .. weightsum)

	local transformList = pl.List.new()
	while math.random() < moretransforms do
		local selection = math.random(weightsum)
		transformList:append(funList[selection]:newRand())
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
	local base = shapes[math.random(3)]()
	base.transforms:append(base:getAnchorTransform(centerodds))
	if othershape then
		base.transforms:append(othershape:getAnchorTransform(centerodds))
		othershape.children:append(base)
	end
	return base
end

-- Create a full scenegraph (returns root).
-- Pass a table containing configuration:
-- 'moretransforms' = odds of adding another transform, (n / 1)
-- 'moreshapes' = odds of adding another shape, (n / 1)
-- 'centerodds' (see randShape)
-- and weights for randTransform
local function makeScenegraph(config)
	-- Minimum two shapes
	local shapes = pl.List.new()
	table.insert(shapes, randShape(config.centerodds, nil))
	repeat
		-- Add transforms to last shape
		shapes[#shapes].transforms:extend(
				randTransform(config.weights, config.moretransforms))
		-- Pick a shape from the list to make the parent of the new shape
		local parent = shapes[math.random(#shapes)]
		shapes:append(randShape(config.centerodds, parent))
		-- repeat
	until math.random() < config.moreshapes
	return shapes[1] -- returning root of scene, not the whole list
end

-- Write an individual object as SVG - this function handles the generic parts
-- (groups, transforms, children)
local function writeObjectSvg(shape)
	-- Open a group
	io.write('<g ')
	-- Include all transforms
	if #(shape.transforms) > 0 then
		io.write('transform="')
		for k, v in ipairs(shape.transforms) do
			io.write(v:asSvgAttribute())
		end
		io.write('" ')
	end
	io.write('>\n')
	-- Include specific given object...
	io.write(shape:asSvgElement())
	-- ...and given object's children, recursively 
	for k, v in ipairs(shape.children) do
		writeObjectSvg(v)
	end
	io.write('</g>\n')
end

-- Write the SVG of scenegraph "source" into file named "target"
local function writeSceneSvg(source, target)
	if target then
		io.output(io.open(target, 'w'))
	else
		io.output(io.stdout)
	end
	-- boilerplate start
	local boilerplate = table.concat({
		'<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
		'<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="1000" height="1000" ',
		'\t\tviewBox="-500 -500 1000 1000" ',
		'\t\tpreserveAspectRatio="meet" > ',
		'\t\t<g style="fill:none;stroke:black;stroke-width:10;stroke-opacity:1" >',
	}, '\n')
	io.write(boilerplate)
	-- write all shapes, depth-first through the tree, from the root
	writeObjectSvg(source)
	io.write('</g></svg>')
end

-----------------
-- Execution
-----------------

-- Seed RNG at start
math.randomseed(os.time())


-- define the main function
local function main()
	local valueFlags = {quantity = true,
			moreshapes = true,
			centerodds = true,
			moretransforms = true,
			translate = true,
			scale = true,
			rotate = true,
			skewx = true,
			skewy = true,
			output = true,
			help = true}

	local flags, _ = pl.app.parse_args(nil, valueFlags)
	if #_ > 0 then
		help()
	else
		local weights = {}
		-- bundle it up more nicely for later passing
		for t in pl.List.iterate{"translate", "rotate", "scale", "skewx", "skewy"} do
			weights[t] = tonumber(flags[t])
		end

		-- TODO add a tag to lock reading from the folder and prevent
		-- overwriting old with new files by working from highest number
		-- TODO base folder directly on args for organization
		if not pl.path.exists(flags.output) then
			assert (pl.dir.makepath(flags.output),
				"Could not make or access target dir")
		end
		
		-- make all requested scenes
		for i = 1, flags.quantity do
			local scene = makeScenegraph {
				moreshapes = tonumber(flags.moreshapes),
				centerodds = tonumber(flags.centerodds),
				moretransforms = tonumber(flags.moretransforms),
				weights = weights}
			writeSceneSvg(scene,
					pl.path.join(flags.output,
							tostring(i) .. '.svg'))
		end
	end
end

-- and BEGIN!
main()
