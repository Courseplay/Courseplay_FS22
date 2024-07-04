require('include')
lu.EPS = 0.01

FSDensityMapUtil = {}
function FSDensityMapUtil.getFieldDataAtWorldPosition(x, y, z)
    -- an island is a 100x100 square in the middle of the field
    if math.abs(x) <= 50 and math.abs(z) <= 50 then
        return false, 0
    end
    return true, 0
end

function testIsland()
    local boundary = Polygon({Vertex(-100, -100), Vertex(100, -100), Vertex(100, 100), Vertex(-100, 100)})
    local field = CourseGenerator.Field('test', 1, boundary)
    local islandVertices = CourseGenerator.Island.findIslands(field)
    -- theoretically, the island should have 10,000 vertices but due to the half grid spacing we lose one row.
    lu.assertEquals(#islandVertices, 9900)
end
os.exit(lu.LuaUnit.run())
