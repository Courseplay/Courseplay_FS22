local Offset = {}
Offset.logger = Logger('Offset', Logger.level.debug)
local recursionCount = 0

function Offset.generate(polygon, offsetVector, targetOffset, currentOffset)
    currentOffset = currentOffset or 0
    -- done!
    if currentOffset >= targetOffset then
        recursionCount = 0
        return polygon
    end
    -- limit of the number of recursions based on how far we want to go
    recursionCount = recursionCount + 1
    if recursionCount > math.max(math.floor(targetOffset * 20), 600) then
        Offset.logger:error('Recursion limit reached (%d)', recursionCount)
        recursionCount = 0
        return nil
    end
    -- we'll use the grassfire algorithm and approach the target offset by
    -- iteration, generating headland tracks close enough to the previous one
    -- so the resulting offset polygon can be kept clean (no intersecting edges)
    -- this can be ensured by choosing an offset small enough
    local deltaOffset = math.min(targetOffset, math.max(polygon:getShortestEdgeLength() / 8, 0.1))
    deltaOffset = math.min( deltaOffset, targetOffset - currentOffset )
    currentOffset = currentOffset + deltaOffset
    Offset.logger:trace('recursionCount=%d, targetOffset=%f, deltaOffset=%f, currentOffset=%f',
            recursionCount, targetOffset, deltaOffset, currentOffset)
    -- minLength should be 1, but for target offsets <= 1, LineSegment.connect() will round corners if minLength is 1
    -- TODO: preserveCorners should be set depending on what we are generating.
    polygon = polygon:createOffset(deltaOffset * offsetVector, math.min(1, targetOffset / 2), false)
    if polygon == nil then
        recursionCount = 0
        return nil
    end
    polygon:ensureMinimumEdgeLength(CourseGenerator.cMinEdgeLength)
    polygon:calculateProperties()
    return Offset.generate(polygon, offsetVector, targetOffset, currentOffset)
end

---@class CourseGenerator.Offset
CourseGenerator.Offset = Offset