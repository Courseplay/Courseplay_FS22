--- Common functions manipulating parts of a fieldwork course

---@class FieldworkCourseHelper
local FieldworkCourseHelper = {}

FieldworkCourseHelper.logger = Logger('FieldworkCourseHelper')

-- how far to drive beyond the field edge/headland if we hit it at an angle, to cover the row completely
local function getDistanceBetweenRowEndAndFieldBoundary(workingWidth, angle)
    -- with very low angles this becomes too much, in that case you need a headland, so limit it here
    return math.abs(workingWidth / 2 / math.tan(math.max(math.abs(angle), math.pi / 12)))
end

-- if the up/down tracks were perpendicular to the boundary, we'd have to cut them off
-- width/2 meters from the intersection point with the boundary. But if we drive on to the
-- boundary at an angle, we have to drive further if we don't want to miss fruit.
local function getDistanceBetweenRowEndAndHeadland(workingWidth, angle)
    angle = math.max(math.abs(angle), math.pi / 12)
    -- distance between headland centerline and side at an angle
    -- (is width / 2 when angle is 90 degrees)
    local dHeadlandCenterAndSide = math.abs(workingWidth / 2 / math.sin(angle))
    return dHeadlandCenterAndSide - getDistanceBetweenRowEndAndFieldBoundary(workingWidth, angle)
end

--- If polyline is a fieldwork course, intersecting a headland or a field boundary at an angle,
--- adjust the start of the polyline to make sure that there are no missed spots
function FieldworkCourseHelper.adjustLengthAtStart(polyline, workingWidth, angle)
    local offsetStart = 0
    offsetStart = -getDistanceBetweenRowEndAndHeadland(workingWidth, angle)
    if offsetStart >= 0 then
        polyline:extendStart(offsetStart)
    else
        polyline:cutStart(-offsetStart)
    end
end

--- If polyline is a fieldwork course, intersecting a headland or a field boundary at an angle,
--- adjust the end of the polyline to make sure that there are no missed spots
function FieldworkCourseHelper.adjustLengthAtEnd(polyline, workingWidth, angle)
    local offsetEnd = 0
    offsetEnd = -getDistanceBetweenRowEndAndHeadland(workingWidth, angle)
    if offsetEnd >= 0 then
        polyline:extendEnd(offsetEnd)
    else
        polyline:cutEnd(-offsetEnd)
    end
end

--- Find the first two intersections with another polyline or polygon and replace the section
--- between those points with the vertices of the other polyline or polygon.
---@param other Polyline
---@param startIx number index of the vertex we want to start looking for intersections.
---@param circle boolean when true, make a full circle on the other polygon, else just go around and continue
---@return boolean, number true if there was an intersection and we actually went around, index of last vertex
--- after the bypass
function FieldworkCourseHelper.bypassSmallIsland(polyline, workingWidth, other, startIx, circle)
    local intersections = polyline:getIntersections(other, startIx)
    local is1, is2 = intersections[1], intersections[2]
    if is1 and is2 then
        -- we cross other completely, none of our ends are within other, there may be more intersections with other though
        return polyline:goAroundBetweenIntersections(other, circle, is1, is2)
    elseif is1 then
        -- there is one intersection only, one of our ends is within other, and there are no more intersections with other
        -- so, the end of the row is on the island, we have to move it out of the island
        if other:isVectorInside(polyline[#polyline]) then
            polyline.logger:debug('End of row is on an island, removing all vertices after index %d (of %d)',
                    is1.ixA, #polyline)
            CourseGenerator.addDebugPoint(polyline[is1.ixA], tostring(is1.ixA))
            CourseGenerator.addDebugPoint(polyline[#polyline], tostring(polyline[#polyline]))
            polyline:cutEndAtIx(is1.ixA)
            polyline:append(is1.is)
            polyline:calculateProperties()
            FieldworkCourseHelper.adjustLengthAtEnd(polyline, workingWidth, is1:getAngle())
            polyline:setAttribute(#polyline, CourseGenerator.WaypointAttributes.setUsePathfinderToNextWaypoint)
        else
            polyline.logger:debug('Start of row is on an island, removing all vertices up to index %d (of %d)',
                    is1.ixA, #polyline)
            CourseGenerator.addDebugPoint(polyline[is1.ixA], tostring(is1.ixA))
            polyline:cutStartAtIx(is1.ixA + 1)
            polyline:prepend(is1.is)
            polyline:calculateProperties()
            FieldworkCourseHelper.adjustLengthAtStart(polyline, workingWidth, is1:getAngle())
            polyline:setAttribute(1, CourseGenerator.WaypointAttributes.setUsePathfinderToThisWaypoint)
        end
        return false
    end
end

--- Remove glitches from a potentially fuzzy field or island boundary, and then align into the same
--- direction as we want the headlands to be generated
---@param originalBoundary Polygon raw field/island boundary
---@param clockwise boolean if true, we want to generate headlands based on this boundary in the clockwise direction.
--- if boundary has a different orientation, it'll be reversed to match the desired direction
function FieldworkCourseHelper.createUsableBoundary(originalBoundary, clockwise)
    local usableBoundary = originalBoundary:clone()
    -- some field scans are not perfect and have sudden direction changes which screws up the clockwise calculation
    usableBoundary:removeGlitches()
    usableBoundary:ensureMinimumEdgeLength(CourseGenerator.cMinEdgeLength)
    if usableBoundary:isClockwise() ~= clockwise then
        -- all headlands are generated in the same direction as the field boundary,
        -- so if it does not match the required cw/ccw, reverse it
        FieldworkCourseHelper.logger:debug('Boundary clockwise %s, desired %s, reversing boundary', originalBoundary:isClockwise(), clockwise)
        usableBoundary:reverse()
    end
    return usableBoundary
end

function FieldworkCourseHelper.createVirtualHeadland(fieldBoundary, isClockwise, workingWidth)
    -- create a virtual headland to be used by the center generation, so the center does not have towards
    -- know if the boundary is a headland or the actual field boundary. The virtual headland is half working
    -- width wider than the field boundary so the rows in the center cover the area between the original
    -- field boundaries.
    return CourseGenerator.Headland(fieldBoundary, isClockwise, 0, workingWidth / 2, true)
end

---@class CourseGenerator.FieldworkCourseHelper
CourseGenerator.FieldworkCourseHelper = FieldworkCourseHelper