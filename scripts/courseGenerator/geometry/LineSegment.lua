local LineSegment = CpObject()

--- A line segment between two points, directed from P1 to P2
---@param x1 number P1's x coordinate
---@param y1 number P1's y coordinate
---@param x2 number P2's x coordinate
---@param x2 number P2's y coordinate
function LineSegment:init(x1, y1, x2, y2)
    -- vector from origin to P1 is the base vector
    self.base = Vector(x1, y1)
    -- vector from P1 to P2
    self.slope = Vector(x2 - x1, y2 - y1)
end

--- Create a line segment from two points (vectors)
---@param p1 Vector to P1
---@param p2 Vector to P2
function LineSegment.fromVectors(v1, v2)
    return LineSegment(v1.x, v1.y, v2.x, v2.y)
end

function LineSegment:clone()
    local clone = LineSegment(0, 0, 0, 0)
    clone.base = self.base:clone()
    clone.slope = self.slope:clone()
    return clone
end

--- Get the base (starting point) of the line segment
---@return Vector
function LineSegment:getBase()
    return self.base
end

--- Set the base (starting point) of the line segment
---@param v Vector
function LineSegment:setBase(v)
    self.base = v:clone()
end

--- Get the end point of the line segment
---@return Vector
function LineSegment:getEnd()
    return self.base + self.slope
end

--- Set the end point of the line segment
---@param v Vector
function LineSegment:setEnd(v)
    self.slope = v - self.base
end

--- Get the heading of the line segment in radians
function LineSegment:getHeading()
    return self.slope:heading()
end

function LineSegment:setHeading(h)
    self.slope:setHeading(h)
end

function LineSegment:setLength(l)
    self.slope:setLength(l)
end

---@return number
function LineSegment:getLength()
    return self.slope:length()
end

---@return State3D
function LineSegment:getBaseAsState3D()
    return State3D(self.base.x, self.base.y, self:getHeading())
end

---@return State3D
function LineSegment:getEndAsState3D()
    local e = self:getEnd()
    return State3D(e.x, e.y, self:getHeading())
end


--- Move the segment in the direction of the offset vector
---@param dx number x offset relative to the segment, 1 is forward one unit, -1 back, etc.
---@param dy number y offset relative to the segment, 1 is left one unit, -1 right, etc.
function LineSegment:offset(dx, dy)
    local length = math.sqrt(dx^2 + dy^2)
    local offsetAngle = math.atan2(dy, dx) + self.slope:heading()
    self.base.x = self.base.x + length * math.cos(offsetAngle)
    self.base.y = self.base.y + length * math.sin(offsetAngle)
end

function LineSegment.__eq(a, b)
    return a.base == b.base and a.slope == b.slope
end

function LineSegment:__tostring()
    return string.format('%s -> %s', self:getBase(), self:getEnd())
end

function LineSegment:almostEquals(other)
    local margin = 0.0001
    return math.abs(self.base.x - other.base.x) <= margin and
            math.abs(self.base.y - other.base.y) <= margin and
            math.abs(self.slope.x - other.slope.x) <= margin and
            math.abs(self.slope.y - other.slope.y) <= margin
end

-- for tests only
function LineSegment:assertAlmostEquals(other)
    if not self:almostEquals(other) then
        error(string.format('FAILURE: expected: %s, actual: %s', other, self), 1)
    end
end

function LineSegment:calculateIntersectionParameters(other)
    local determinant = self.slope.x * other.slope.y - other.slope.x * self.slope.y
    if math.abs(determinant) < 0.00000001 then
        return nil
    end
    local s = (-self.slope.y * (self.base.x - other.base.x) + self.slope.x * (self.base.y - other.base.y)) / determinant
    local t = (other.slope.x * (self.base.y - other.base.y) - other.slope.y * (self.base.x - other.base.x)) / determinant
    return s, t
end

--- Does this line intersect an other?
---@param other CourseGenerator.LineSegment
---@return Vector intersection point or nil
function LineSegment:intersects(other)
    local s, t = self:calculateIntersectionParameters(other)
    if not s then
        -- no intersection
        return nil
    end
    if t >= 0 and t <= 1 and s >= 0 and s <= 1 then
        -- the two segments intersect
        return self.base + t * self.slope
    else
        return nil
    end
end

--- Extend this segment by length units.
---@param length number if positive, the segment extended forward (base remains the same), if negative,
--- the segment is extended backwards (base moved backwards).
--- In either case, the segment's new length will be the original length + length.
function LineSegment:extend(length)
    if length < 0 then
        local slope = self.slope:clone()
        slope:setLength(length)
        self.base = self.base + slope
    end
    self.slope:setLength(self.slope:length() + math.abs(length))
end

--- Extend this segment to intersect an other. Other is considered here as a line, not just a
--- segment so for the two to actually intersect, you may need to extend other too.
--- Will extend in any direction, forward or backward.
---@param other CourseGenerator.LineSegment
---@return boolean true if extended, false if there was no intersection point
function LineSegment:extendTo(other)
    local s, t = self:calculateIntersectionParameters(other)
    if not s then return false end
    if t > 0 then
        self.slope = t * self.slope
    else
        local currentEnd = self:getEnd()
        self.base = self.base + t * self.slope
        self.slope = currentEnd - self.base
    end
    return true
end

--- Tidy up two line segments to make sure they ends touch (but never intersect) and there are no gaps between them.
--- If segments intersect, the parts beyond the intersection point are clipped. 
--- If there is a gap between them and preserveCorners is true, extend them until they meet.
--- If preserveCorners is false, add a new segment filling the gap, unless the gap is less than minLength, in that
--- case, move first's end and second's start together into the same point.
---@param first CourseGenerator.LineSegment the first line segment, adjusted in place (input/output)
---@param second CourseGenerator.LineSegment second line segment, adjusted in place (input/output)
---@param minLength number
---@param preserveCorners boolean
---@return CourseGenerator.LineSegment if a new segment needs to connect first and second, it is returned here, otherwise nil
function LineSegment.connect(first, second, minLength, preserveCorners)
    local intersectionPoint = second:intersects(first)
    if intersectionPoint then
        -- intersect with the previous one, so just end the previous edge at the intersection point
        -- and start the new one at the same intersection point, cutting out the loop
        first:setEnd(intersectionPoint)
        -- end point stays where it is
        local newOffsetEnd = second:getEnd()
        second:setBase(intersectionPoint)
        second:setEnd(newOffsetEnd)
    else
        -- do not intersect with the previous edge, we have three options here:
        -- 1. if the end of the previous edge and the start of the new are very close, we
        --    just want to use a point between the two instead to avoid ending up with many
        --    very short segments
        -- 2. if they are further apart, we can add a line segment between them. This will
        --    result in corners being cut, for instance a 90 degree turn will end up with
        --    a 45 degree segment cutting the corner
        -- 3. if they are further apart, and we don't want to cut corners, we can extend the
        --    segments until they intersect.
        if (second:getBase() - first:getEnd()):length() < minLength then
            -- #1 ends too close, replace them with a point in the middle
            local vertexInTheMiddle = (first:getEnd() + second:getBase()) / 2
            -- end point stays where it is
            local newOffsetEnd = second:getEnd()
            first:setEnd(vertexInTheMiddle)
            second:setBase(vertexInTheMiddle)
            second:setEnd(newOffsetEnd)
        elseif preserveCorners then
            -- #3
            first:extendTo(second)
            second:extendTo(first)
        else
            -- #2: add a segment in between
            return CourseGenerator.LineSegment.fromVectors(first:getEnd(), second:getBase())
        end
    end
end

--- Get the theoretical turn radius to get to 'to', where we start at our end point in our direction
--- and end up at the base of 'other', pointing to other's direction
--- In other words, get the radius of a circle where self and other are both tangents
---@param other CourseGenerator.LineSegment
---@return number radius to reach other, 0 if can't be found
function LineSegment:getRadiusTo(other)
    local dA = CpMathUtil.getDeltaAngle(other:getHeading(), self:getHeading())
    --if math.abs( dA ) < 0.05 then return math.huge end
    local s, t = self:calculateIntersectionParameters(other)
    -- they are parallel
    if not s then return math.huge end
    if t > 0 and s < 0 then
        -- intersection in front of entry and behind other
        local dFrom = t * self:getLength()
        local dTo = -s * other:getLength()
        local r = math.abs( math.min(dFrom, dTo) / math.tan(dA / 2))
        return r
    else
        if math.abs(t) < 0.01 or math.abs(s) < 0.01 then
            -- if t or s 0, the intersection point is on my end or other's base
            return 0
        else
            -- all other cases are invalid, as the intersection must be in front of me and behind other.
            return 0
        end
    end
end

---@param point Vector
---@return number distance of point from the line segment (measured perpendicular to the segment, length of the rejection vector)
function LineSegment:getDistanceFrom(point)
    local v = point - self.base
    return self.slope:rejection(v):length()
end

---@param point Vector
---@return boolean is point on the left side of the line segment (looking towards the end of the line segment)
function LineSegment:isPointOnLeft(point)
    local v = point - self.base
    return CpMathUtil.getDeltaAngle(v:heading(), self.slope:heading()) <= 0
end

--- Assuming that this segment intersects the other, and the other is part of a polygon with the given
--- chirality, is this segment entering the polygon? (its start is outside of the polygon, its end is inside)
---@param clockwise boolean is the polygon clockwise?
---@param other CourseGenerator.LineSegment and edge of the polygon
---@return boolean if this segment is entering the polygon
function LineSegment:isEntering(clockwise, other)
    if clockwise then
        -- if the start of my intersecting edge is left of the polygon's intersecting edge and
        -- the polygon is clockwise, I'm entering the polygon here
        return other:isPointOnLeft(self.base)
    else
        -- similarly, to enter a counterclockwise polygon, my intersecting edge start vertex
        -- must be on the right when entering the polygon
        return not other:isPointOnLeft(self.base)
    end
end


---@param point Vector
function LineSegment:getScalarProjection(point)
    local v = point - self.base
    return self.slope:scalarProjection(v)
end

--- Does this and the other line segment overlap.
--- This works by checking if the projection of any of the endpoints of one segment is
--- on the other segment, so the segments need to be more or less parallel to get
--- useful results.
--- Also note that if a:overlaps(b) is true then b:overlaps(a) is also true
---@param other CourseGenerator.LineSegment
---@return boolean
function LineSegment:overlaps(other)
    local function isPointOverLineSegment(p, s)
        local scalarProjection = s:getScalarProjection(p)
        return scalarProjection >= 0 and scalarProjection <= s:getLength()
    end
    if isPointOverLineSegment(other:getBase(), self) then
        return true
    end
    if isPointOverLineSegment(other:getEnd(), self) then
        return true
    end
    if isPointOverLineSegment(self:getBase(), other) then
        return true
    end
    if isPointOverLineSegment(self:getEnd(), other) then
        return true
    end
    return false
end

---@class CourseGenerator.LineSegment
CourseGenerator.LineSegment = LineSegment