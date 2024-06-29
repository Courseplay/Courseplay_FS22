--- These functions help to create curved paths, especially rows 
--- following a (curved) edge of a field.

---@class CurvedPathHelper
local CurvedPathHelper = {}

local logger = Logger('CurvedPathHelper')

---@param boundary Polygon the boundary, usually headland or virtual headland. Rows must cover the area within the
--- boundary - working width / 2
---@param baselineLocation Vector the field edge closest to this location will be the one the generated rows follow
---@param workingWidth number distance
---@param nRows number how many rows to generate. If not given, keep generating until the area
---@param firstRowWidth number|nil optional width of the first row (offset between the baseline and the first row.
--- All other rows will be offset by workingWidth
--- within boundary is covered.
function CurvedPathHelper.generateCurvedUpDownRows(boundary, baselineLocation, workingWidth, turningRadius, nRows,
                                                   firstRowWidth)
    local rows = {}
    nRows = nRows or 300
    local function getIntersectionsExtending(row)
        local intersections, extensions = {}, 0
        repeat
            intersections = row:getIntersections(boundary, 1)
            local evenNumberOfIntersections = #intersections % 2 == 0
            if #intersections < 2 or not evenNumberOfIntersections then
                row:extendStart(50)
                row:extendEnd(50)
                extensions = extensions + 1
            end
        until (#intersections > 1 and evenNumberOfIntersections) or extensions > 3
        if #intersections > 1 and extensions > 0 then
            logger:debug('Row %d extended to intersect boundary', #rows + 1)
        elseif #intersections < 2 then
            logger:debug('Row %d could not be extended to intersect boundary (tries: %d)', #rows + 1, extensions)
        end
        return intersections
    end

    --- Create a baseline for the up/down rows, which is not necessarily straight, instead, it follows a section
    --- of the field boundary. This way some odd-shaped fields can be covered with less turns.
    local closest = boundary:findClosestVertexToPoint(baselineLocation or boundary:at(1))
    local baseline = CourseGenerator.Row(workingWidth)
    CurvedPathHelper.findLongestStraightSection(boundary, closest.ix, turningRadius, baseline)

    baseline:extendStart(50)
    baseline:extendEnd(50)
    -- always generate inwards
    local offset = boundary:isClockwise() and -workingWidth or workingWidth
    local row, intersections = baseline
    repeat
        if firstRowWidth and #rows == 0 then
            row = row:createNext(offset / 2)
        else
            row = row:createNext(offset)
        end
        intersections = getIntersectionsExtending(row)
        table.insert(rows, row)
    until #rows >= nRows or #intersections < 2
    if #intersections < 2 then
        -- last row does not intersect boundary, it is invalid, should not be considered
        table.remove(rows)
    end
    return rows
end

---@param boundary Polyline
---@param ix number the vertex of the boundary to start the search at
---@param radiusThreshold number straight section ends when the radius is under this threshold
---@param section CourseGenerator.Row empty row passed in to hold the straight section around ix
---@return CourseGenerator.Row the straight section as a row, same object as passed in as the section
function CurvedPathHelper.findLongestStraightSection(boundary, ix, radiusThreshold, section)
    local i, n, j = ix, 1
    -- max one round only (n <) self:at(currentIx):getXte(r)
    while n < #boundary and boundary:at(i):getXte(radiusThreshold) < CourseGenerator.cMaxCrossTrackErrorForCurvedRows do
        section:append((boundary:at(i)):clone())
        i = i - 1
        n = n + 1
    end
    section:reverse()
    j, n = ix + 1, 1
    while n < #boundary and boundary:at(j):getXte(radiusThreshold) < CourseGenerator.cMaxCrossTrackErrorForCurvedRows do
        section:append((boundary:at(j)):clone())
        j = j + 1
        n = n + 1
    end
    section:calculateProperties()
    -- no straight section found, bail out here
    logger:debug('Longest straight section found %d vertices, %.1f m (%d - %d - %d)',
            #section, section:getLength(), i, ix, j)
    CourseGenerator.addDebugPolyline(section)
    return section
end

---@class CourseGenerator.CurvedPathHelper
CourseGenerator.CurvedPathHelper = CurvedPathHelper