local SplineHelper = {}

--- Smoothing polylines/polygons as in https://faculty.cc.gatech.edu/~jarek/courses/handouts/curves.pdf
---@param p Polyline
---@param from number start index
---@param to number end index (may be less than from, to wrap around a polygon's end
---@param s number tuck factor
local function tuck(p, from, to, s)
    for _, cv, pv, nv in p:vertices(from, to) do
        if pv and cv and nv then
            if not cv.isCorner and cv.dA and math.abs(cv.dA) > CourseGenerator.cMinSmoothingAngle then
                local m = (pv + nv) / 2
                local cm = m - cv
                cv.x, cv.y = cv.x + s * cm.x, cv.y + s * cm.y
            end
        end
    end
    p:calculateProperties(from, to)
end

--- Add a vertex between existing ones
local function refine(p, from, to)
    -- iterate through the existing table but do not insert the
    -- new points, only remember the index where they would end up
    -- (as we do not want to modify the table while iterating)
    local verticesToInsert = {}
    local ix = p:getRawIndex(from)
    for i, cv, _, nv in p:vertices(from, to) do
        -- initialize ix to the first value of i
        if nv and cv then
            if not cv.isCorner and cv.dA and math.abs(cv.dA) > CourseGenerator.cMinSmoothingAngle then
                local m = (nv + cv) / 2
                local newVertex = cv:clone()
                newVertex.x, newVertex.y = m.x, m.y
                ix = ix + 1
                table.insert(verticesToInsert, {ix = ix, vertex = newVertex})
            end
        end
        ix = ix + 1
    end
    for _, v in ipairs(verticesToInsert) do
        table.insert(p, v.ix, v.vertex )
    end
    p:calculateProperties(from, to + #verticesToInsert)
end

---@return number the index where
function SplineHelper.smooth(p, order, from, to)
    if (order <= 0) then
        return
    else
        local origSize = #p
        refine(p, from, to)
        to = to + #p - origSize
        tuck(p, from, to, 0.5)
        tuck(p, from, to, -0.15)
        SplineHelper.smooth(p, order - 1, from, to)
    end
    return to
end

---@class SplineHelper
CourseGenerator.SplineHelper = SplineHelper