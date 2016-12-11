


-- Classes for primitive shapes
Circle = {params = {origin = 0, radius = 1},
          transforms = {},
          anchors = {{0, 0}, {0, 1}, {1, 0}, {0, -1}, {-1, 0}}} -- TODO diagonals
Circle.__index = Circle
function Circle:new(tfm)
  return setmetatable({transforms = tfm}, self)
end

-- TODO Repeat for other primitives.
-- TODO class for rotate, scale, translate
-- TODO something to calculate translation to match up one anchor with another
