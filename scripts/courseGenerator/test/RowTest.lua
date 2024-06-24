require('include')
---@type cg.Polygon
local headland = cg.Polygon({
    cg.Vector( 0,  2),
    cg.Vector( 5,  1),
    cg.Vector(10,  0),
    cg.Vector(15,  0),
    cg.Vector(20,  0),
    cg.Vector(25,  0),
    cg.Vector(30,  1),
    cg.Vector(35,  2),

    cg.Vector(40, 2),
    cg.Vector(40, 40),
    cg.Vector(0, 40)
})

function testRowCloseToHeadland()
    ---@type cg.Polyline
    local row = cg.Row(10, { cg.Vertex(0, 1), cg.Vertex(40, 1)})
    local is = row:getIntersections(headland, 1)
    lu.assertTrue(row:_isSectionCloseToHeadland(headland, is[1], is[2]))
    row:reverse()
    is = row:getIntersections(headland, 1)
    lu.assertTrue(row:_isSectionCloseToHeadland(headland, is[1], is[2]))
end

function testRowFarFromHeadland()
    ---@type cg.Polyline
    local row = cg.Row(1, { cg.Vertex(0, 1), cg.Vertex(50, 1)})
    local is = row:getIntersections(headland, 1)
    lu.assertFalse(row:_isSectionCloseToHeadland(headland, is[1], is[2]))
    row:reverse()
    is = row:getIntersections(headland, 1)
    lu.assertFalse(row:_isSectionCloseToHeadland(headland, is[1], is[2]))
end

os.exit(lu.LuaUnit.run())
