--[[

A 2D transform, which has a position, an orientation and, optionally, parents or children.
The position and orientation of a child is always relative to the parent.

The orientation (or heading or rotation) is in radians, 0 is in the direction of the
X axis and increases counterclockwise.

]]

--- A transform which has a parent, by default the root transform
---@class Transform
Transform = CpObject()
function Transform:init(name, parent)
    self.name = name
    -- a unit vector representing the rotation (heading or direction or orientation)
    self.rotation = Vector(1, 0)
    -- this is my translation in the world
    self.translation = Vector(0, 0)
    self.parentTransform = parent or RootTransform
end

--- Get world translation (with all the parents) in the x, y system
function Transform:getWorldTranslationVector()

    local worldVector = self.parentTransform and self.parentTransform:getWorldTranslationVector() or Vector(0, 0)
    local localVector = self.translation:clone()
    localVector:rotate(self.parentTransform and self.parentTransform:getWorldRotation() or 0)
    return worldVector + localVector
end

function Transform:getWorldTranslation()
    local wV = self:getWorldTranslationVector()
    return wV.x, wV.y
end

function Transform:getWorldRotation()
    return self.rotation:heading() + (self.parentTransform and self.parentTransform:getWorldRotation() or 0)
end

function Transform:setParent(otherTransform)
    self.parentTransform = otherTransform
end

function Transform:setTranslation(x, y)
    self.translation:set(x, y)
end

function Transform:setRotation(rot)
    self.rotation:setHeading(rot)
end

function Transform:getRotation()
    return transform.rotation:heading()
end

---@param transform : Transform
function Transform:localToWorld(dx, dy)
    local worldVector = self:getWorldTranslationVector()
    local xVector = Vector(1, 0)
    xVector:setHeading(self:getWorldRotation())
    xVector:setLength(dx)
    local yVector = Vector(1, 0)
    yVector:setHeading(self:getWorldRotation())
    yVector:rotate(math.pi / 2)
    yVector:setLength(dy)
    local worldPos = worldVector + xVector + yVector
    return worldPos.x, worldPos.y
end

function Transform:worldToLocal(x, y)
    local wx, wy = self:getWorldTranslation()
    local dx = x - wx
    local dy = y - wy
    local yRot = self:getWorldRotation()
    local lx = math.cos(-yRot) * dx - math.sin(-yRot) * dy
    local ly = math.cos(-yRot) * dy + math.sin(-yRot) * dx
    return lx, ly
end

function Transform:localDirectionToWorld(dx, dy)
    local v = Vector(dx, dy)
    local rot = self:getWorldRotation()
    v:setHeading(rot)
    return v.x, v.y
end

--[[

localToLocal(node2, node1, x2, y2, z2)

Transforms the point (x2, y2, z2) in node2's coordinate system into node1's coordinate system.

localToLocal(node2, node1, x2, y2, z2) is equivalent to:
wx, wy, wz = localToWorld(node2, x2, y2, y2)
x, y, z = worldToLocal(node1, wx, wy, wz)

]]--

RootTransform = Transform('root')
RootTransform:setParent(nil)

---@class CourseGenerator.Transform
CourseGenerator.Transform = Transform