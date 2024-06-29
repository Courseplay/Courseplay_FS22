require('include')
---@type Polygon
local headland = Polygon({
    Vector( 0,  2),
    Vector( 5,  1),
    Vector(10,  0),
    Vector(15,  0),
    Vector(20,  0),
    Vector(25,  0),
    Vector(30,  1),
    Vector(35,  2),

    Vector(40, 2),
    Vector(40, 40),
    Vector(0, 40)
})

function testRowCloseToHeadland()
    ---@type Polyline
    local row = cg.Row(10, { Vertex(0, 1), Vertex(40, 1)})
    local is = row:getIntersections(headland, 1)
    lu.assertTrue(row:_isSectionCloseToHeadland(headland, is[1], is[2]))
    row:reverse()
    is = row:getIntersections(headland, 1)
    lu.assertTrue(row:_isSectionCloseToHeadland(headland, is[1], is[2]))
end

function testRowFarFromHeadland()
    ---@type Polyline
    local row = cg.Row(1, { Vertex(0, 1), Vertex(50, 1)})
    local is = row:getIntersections(headland, 1)
    lu.assertFalse(row:_isSectionCloseToHeadland(headland, is[1], is[2]))
    row:reverse()
    is = row:getIntersections(headland, 1)
    lu.assertFalse(row:_isSectionCloseToHeadland(headland, is[1], is[2]))
end

os.exit(lu.LuaUnit.run())
