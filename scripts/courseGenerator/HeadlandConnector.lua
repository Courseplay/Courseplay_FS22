--- Connects the individual headland passes around the field boundary or
--- around islands.
---@class HeadlandConnector
local HeadlandConnector = {}

---@param headlands CourseGenerator.Headland[] array of headland passes, the first being the closest to the boundary (so for a field,
--- index 1 is the outermost headland pass, for an island, index 1 is the innermost)
---@param startLocation Vector|number will start working on the outermost headland as close as possible to
---startLocation. If number, will start at that index
---@param workingWidth
---@param turningRadius
---@return Polyline a continuous path covering all headland passes, starting with the outermost (fields)/innermost (islands)
function HeadlandConnector.connectHeadlandsFromOutside(headlands, startLocation, workingWidth, turningRadius)
    local headlandPath = Polyline()
    if #headlands < 1 then
        return headlandPath
    end
    local startIx = type(startLocation) == 'table' and
            headlands[1]:getPolygon():findClosestVertexToPoint(startLocation).ix or
            startLocation
    -- make life easy: make headland polygons always start where the transition to the next headland is.
    -- In _setContext() we already took care of the direction, so the headland is always worked in the
    -- increasing indices
    headlands[1].polygon:rebase(startIx)
    for i = 1, #headlands - 1 do
        local transitionEndIx = headlands[i]:connectTo(headlands[i + 1], 1, workingWidth,
                turningRadius, true)
        -- rebase to the next vertex so the first waypoint of the next headland is right after the transition
        headlands[i + 1].polygon:rebase(transitionEndIx + 1)
        headlandPath:appendMany(headlands[i]:getPath())
    end
    headlandPath:appendMany(headlands[#headlands]:getPath())
    if #headlands == 1 then
        headlandPath:append(headlandPath[1]:clone())
    end
    headlandPath:calculateProperties()
    return headlandPath
end

---@param headlands CourseGenerator.Headland[] array of headland passes, the first being the closest to the boundary (so for a field,
--- index 1 is the outermost headland pass, for an island, index 1 is the innermost)
---@param startLocation Vector|number if Vector, will start working on the innermost headland as close as possible
--- to startLocation. If number, will start at that index
---@param workingWidth
---@param turningRadius
---@return Polyline a continuous path covering all headland passes, starting with the innermost (fields)/outermost (islands)
function HeadlandConnector.connectHeadlandsFromInside(headlands, startLocation, workingWidth, turningRadius)
    local headlandPath = Polyline()
    if #headlands < 1 then
        return headlandPath
    end
    local startIx = type(startLocation) == 'table' and
            headlands[#headlands]:getPolygon():findClosestVertexToPoint(startLocation).ix or
            startLocation
    -- make life easy: make headland polygons always start where the transition to the next headland is.
    -- In _setContext() we already took care of the direction, so the headland is always worked in the
    -- increasing indices
    headlands[#headlands].polygon:rebase(startIx)
    for i = #headlands, 2, -1 do
        local transitionEndIx = headlands[i]:connectTo(headlands[i - 1], 1, workingWidth,
                turningRadius, false)
        -- rebase to the next vertex so the first waypoint of the next headland is right after the transition
        headlands[i - 1].polygon:rebase(transitionEndIx + 1)
        headlandPath:appendMany(headlands[i]:getPath())
    end
    headlandPath:appendMany(headlands[1]:getPath())
    if #headlands == 1 then
        headlandPath:append(headlandPath[1]:clone())
    end
    headlandPath:calculateProperties()
    return headlandPath
end


--- determine the theoretical minimum length of the transition from one headland to another
---(depending on the width and turning radius)
function HeadlandConnector.getTransitionLength(workingWidth, turningRadius)
    -- the angle between the row and the transition path, with turn radius of the vehicle
    local alpha = math.acos(math.min(1, math.abs(((turningRadius - workingWidth / 2) / turningRadius))))
    -- length of the transition calculated from the vehicle's turning radius only, with large widths and
    -- small radii the connector can reach 90 degrees, making two quarter circles
    local transitionLengthFromTurningRadius = 2 * turningRadius * math.sin(alpha)
    -- the maximum radius belonging the the maximum angle
    local radius = (workingWidth / 2) / math.sin(CourseGenerator.cMaxHeadlandConnectorAngle / 2) /
            math.sin(CourseGenerator.cMaxHeadlandConnectorAngle) / 2
    -- and the transition length calculated with that angle
    local transitionLengthFromMaxAngle = 2 * radius * math.sin(CourseGenerator.cMaxHeadlandConnectorAngle)
    if transitionLengthFromMaxAngle > transitionLengthFromTurningRadius then
        -- max angle limits the minimum transition length, use the radius for that angle
        return transitionLengthFromMaxAngle, radius
    else
        -- vehicle's turning radius limits the minimum transition length
        return transitionLengthFromTurningRadius, turningRadius
    end
end
---@class CourseGenerator.HeadlandConnector
CourseGenerator.HeadlandConnector = HeadlandConnector