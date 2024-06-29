--- This is a point which can move along a polyline or polygon
local Slider = CpObject(cg.LineSegment)

---@param polyline Polyline the polyline (or polygon) the slider can be moved along
---@param ix number index of the vertex we want to base our initial position on
---@param d number distance from polyline[ix] for the initial position
function Slider:init(polyline, ix, d)
    self.polyline = polyline
    self._isAtEnd = false
    self:set(ix, 0)
    self:move(d or 0)
end

function Slider:set(ix, d)
    -- index of the current vertex
    self.ix = ix
    -- distance from the base vertex, always positive
    self.d = d
    self.base = Vector(self:vertex().x, self:vertex().y)
    -- unit vector pointing to the exit heading of the vertex
    self.slope = Vector(1, 0)
    self.slope:setHeading(self:vertex():getExitHeading())
    -- move to the current offset
    self:offset(d, 0)
end

function Slider:vertex(ix)
    return self.polyline:at(ix or self.ix)
end

--- Move d distance along the polyline. Will not move past the ends.
---@param d number distance to move
---@return boolean true if the move was successful, false if the end of the polyline reached before moving the
--- distance required
function Slider:move(d)
    local dRemaining = math.abs(d)
    local ix, offset = self.ix, self.d
    local endReached = false

    local function forward()
        local exitEdge = self:vertex(ix):getExitEdge()
        if not exitEdge then
            -- reached the end of polyline
            offset = 0
            endReached = true
            return false
        end
        local dToEdgeEnd = exitEdge:getLength() - offset
        if dRemaining > dToEdgeEnd then
            ix = ix + 1
            offset = 0
            dRemaining = dRemaining - dToEdgeEnd
        else
            offset = offset + dRemaining
            return false
        end
        return true
    end

    local function backward()
        local entryEdge = self:vertex(ix):getEntryEdge()
        if not entryEdge then
            -- reached the start of polyline
            dRemaining = 0
            endReached = true
            return false
        end
        if dRemaining > offset then
            dRemaining = dRemaining - offset
            ix = ix - 1
            offset = entryEdge:getLength()
        else
            offset = offset - dRemaining
            return false
        end
        return true
    end

    local step = d >= 0 and forward or backward

    while dRemaining > 0 and step() do

    end
    self:set(ix, offset)
    return not endReached
end

---@class cg.Slider : cg.LineSegment
cg.Slider = Slider