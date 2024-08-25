--- This is to encapsulate the specifics of a field center with rows already existing.
--- This is useful for fields with predefined rows, like vineyards.
---@class CenterPredefinedRows : Center
local CenterPredefinedRows = CpObject(CourseGenerator.Center)

---@param context CourseGenerator.FieldworkContext
---@param boundary Polygon the field boundary
---@param headland CourseGenerator.Headland|nil the innermost headland if exists
---@param startLocation Vector location of the vehicle before it starts working on the center.
---@param bigIslands CourseGenerator.Island[] islands too big to circle
---@param rows CourseGenerator.Row[] the last row of the center (before cut), this will be added to the ones generated
function CenterPredefinedRows:init(context, boundary, headland, startLocation, bigIslands, rows)
    CourseGenerator.Center.init(self, context, boundary, headland, startLocation, bigIslands)
    self.logger = Logger('CenterPredefinedRows', Logger.level.trace)
    -- for now, assume all rows are straight, and override the generate method below
    self.useBaselineEdge = false
    self.rows = rows
end

function CenterPredefinedRows:_generateStraightUpDownRows(rowAngle, suppressLog)
    -- nothing to do we already have the rows
    return self.rows
end

---@class CourseGenerator.CenterPredefinedRows : CourseGenerator.Center
CourseGenerator.CenterPredefinedRows = CenterPredefinedRows