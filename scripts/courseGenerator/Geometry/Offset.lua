local Offset = {}
Offset.logger = Logger('Offset')
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
    polygon = polygon:createOffset(deltaOffset * offsetVector, 1, false)
    if polygon == nil then
        recursionCount = 0
        return nil
    end
    polygon:ensureMinimumEdgeLength(cg.cMinEdgeLength)
    polygon:calculateProperties()
    return Offset.generate(polygon, offsetVector, targetOffset, currentOffset)
end

---@class cg.Offset
cg.Offset = Offset