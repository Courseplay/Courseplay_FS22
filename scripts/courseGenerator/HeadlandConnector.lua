--- Connects the individual headland passes around the field boundary or
--- around islands.
---@class HeadlandConnector
local HeadlandConnector = {}

---@param headlands cg.Headland[] array of headland passes, the first being the closest to the boundary (so for a field,
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

---@param headlands cg.Headland[] array of headland passes, the first being the closest to the boundary (so for a field,
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
---(depending on the width and radius)
function HeadlandConnector.getTransitionLength(workingWidth, turningRadius)
    local transitionLength
    if turningRadius - workingWidth / 2 < 0.1 then
        -- can make two half turns within the working width
        transitionLength = 2 * turningRadius
    else
        local alpha = math.abs(math.acos((turningRadius - workingWidth / 2) / turningRadius) / 2)
        transitionLength = 2 * workingWidth / 2 / math.tan(alpha)
    end
    return transitionLength
end
---@class cg.HeadlandConnector
cg.HeadlandConnector = HeadlandConnector