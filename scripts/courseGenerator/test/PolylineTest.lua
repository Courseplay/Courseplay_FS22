require('include')

function testIterators()
    ---@type Polyline
    local p = Polyline({ Vertex(0, 0), Vertex(0, 1), Vertex(0, 2), Vertex(1, 2) })
    lu.assertEquals(p[1], Vertex(0, 0))
    lu.assertEquals(#p, 4)
    lu.assertEquals(p:getLength(), 3)
    p:append(Vertex(2, 2))
    p:calculateProperties()
    lu.assertEquals(p:getLength(), 4)
    lu.assertEquals(p[5], Vertex(2, 2))
    local e = {}
    for _, edge in p:edges() do
        table.insert(e, edge)
    end
    lu.assertEquals(e[1], cg.LineSegment(0, 0, 0, 1))
    lu.assertEquals(e[2], cg.LineSegment(0, 1, 0, 2))
    lu.assertEquals(e[3], cg.LineSegment(0, 2, 1, 2))
    lu.assertEquals(e[4], cg.LineSegment(1, 2, 2, 2))

    e = {}
    for _, edge in p:edgesBackwards() do
        table.insert(e, edge)
    end
    lu.assertEquals(e[1], cg.LineSegment(1, 2, 2, 2))
    lu.assertEquals(e[2], cg.LineSegment(0, 2, 1, 2))
    lu.assertEquals(e[3], cg.LineSegment(0, 1, 0, 2))
    lu.assertEquals(e[4], cg.LineSegment(0, 0, 0, 1))


    -- index
    lu.assertIsNil(p[0])
    lu.assertIsNil(p[-1])
    lu.assertIsNil(p[#p + 1])
end

function testOffset()
    local p = Polyline({ Vertex(0, 0), Vertex(0, 1), Vertex(0, 2), Vertex(0, 3) })
    local o = p:createOffset(Vertex(0, -1), 1, false)
    o[1]:assertAlmostEquals(Vertex(1, 0))
    o[2]:assertAlmostEquals(Vertex(1, 1))
    o[3]:assertAlmostEquals(Vertex(1, 2))
    o[4]:assertAlmostEquals(Vertex(1, 3))

    o = p:createOffset(Vertex(0, 1), 1, false)
    o[1]:assertAlmostEquals(Vertex(-1, 0))
    o[2]:assertAlmostEquals(Vertex(-1, 1))
    o[3]:assertAlmostEquals(Vertex(-1, 2))
    o[4]:assertAlmostEquals(Vertex(-1, 3))

    p = Polyline({ Vertex(0, 0), Vertex(1, 1), Vertex(2, 2), Vertex(3, 3) })
    o = p:createOffset(Vertex(0, math.sqrt(2)), 1, false)
    o[1]:assertAlmostEquals(Vertex(-1, 1))
    o[2]:assertAlmostEquals(Vertex(0, 2))
    o[3]:assertAlmostEquals(Vertex(1, 3))
    o[4]:assertAlmostEquals(Vertex(2, 4))

    -- inside corner
    p = Polyline({ Vertex(0, 0), Vertex(0, 2), Vertex(2, 2) })
    o = p:createOffset(Vertex(0, -1), 1, false)
    o[1]:assertAlmostEquals(Vertex(1, 0))
    o[2]:assertAlmostEquals(Vertex(1, 1))
    o[3]:assertAlmostEquals(Vertex(2, 1))

    -- outside corner, cut corner
    o = p:createOffset(Vertex(0, 1), 1, false)
    o[1]:assertAlmostEquals(Vertex(-1, 0))
    o[2]:assertAlmostEquals(Vertex(-1, 2))
    o[3]:assertAlmostEquals(Vertex(0, 3))
    o[4]:assertAlmostEquals(Vertex(2, 3))

    -- outside corner, preserve corner
    o = p:createOffset(Vertex(0, 1), 1, true)
    o[1]:assertAlmostEquals(Vertex(-1, 0))
    o[2]:assertAlmostEquals(Vertex(-1, 3))
    o[3]:assertAlmostEquals(Vertex(2, 3))
end

function testEdgeLength()
    local p = Polyline({ Vertex(0, 0), Vertex(0, 2), Vertex(0, 3), Vertex(0, 3.1), Vertex(0, 3.2), Vertex(0, 4) })
    p:ensureMinimumEdgeLength(1)
    p[1]:assertAlmostEquals(Vertex(0, 0))
    p[2]:assertAlmostEquals(Vertex(0, 2))
    p[3]:assertAlmostEquals(Vertex(0, 3))
    p[4]:assertAlmostEquals(Vertex(0, 4))

    lu.EPS = 0.01
    p = Polyline({ Vertex(0, 0), Vertex(5, 0), Vertex(10, 5), Vertex(10, 10) })
    p:calculateProperties()
    lu.assertIsNil(p[1]:getEntryEdge())
    p[1]:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))
    p[4]:getEntryEdge():assertAlmostEquals(cg.LineSegment(10, 5, 10, 10))
    lu.assertIsNil(p[4]:getExitEdge())

    p = Polyline({ Vertex(0, 0), Vertex(5, 0), Vertex(10, 5), Vertex(10, 10), Vertex(10, 15) })
    p:calculateProperties()
    lu.assertAlmostEquals(p[1]:getDistance(), 0)
    lu.assertAlmostEquals(p[2]:getDistance(), 5)
    lu.assertAlmostEquals(p[3]:getDistance(), 5 + math.sqrt(2) * 5)
    lu.assertAlmostEquals(p[4]:getDistance(), 10 + math.sqrt(2) * 5)
    lu.assertAlmostEquals(p[5]:getDistance(), 15 + math.sqrt(2) * 5)
    lu.assertIsNil(p[1]:getEntryEdge())
    p[1]:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))
    p[4]:getEntryEdge():assertAlmostEquals(cg.LineSegment(10, 5, 10, 10))
    p[4]:getExitEdge():assertAlmostEquals(cg.LineSegment(10, 10, 10, 15))
    lu.assertIsNil(p[5]:getExitEdge())

    p = Polyline({ Vertex(0, 0), Vertex(0, 5), Vertex(0, 10), Vertex(5, 10), Vertex(10, 10), Vertex(15, 10), Vertex(20, 10) })
    p:calculateProperties()
    lu.assertAlmostEquals(p[1]:getEntryHeading(), math.pi / 2)
    lu.assertAlmostEquals(p[#p]:getExitHeading(), 0)

    lu.EPS = 0.01
    -- straight
    p = Polyline({ Vertex(0, 0), Vertex(0, 6) })
    p:ensureMaximumEdgeLength(5, math.rad(45))
    lu.assertEquals(#p, 3)
    p[1]:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 0, 3))
    p:ensureMaximumEdgeLength(5, math.rad(45))
    lu.assertEquals(#p, 3)
    -- left turn
    p = Polyline({ Vertex(-1, 0), Vertex(0, 0), Vertex(5, 5) })
    p:ensureMaximumEdgeLength(5, math.rad(46))
    lu.assertEquals(#p, 4)
    p[3]:assertAlmostEquals(Vector(3.27, 1.35))
    -- right turn
    p = Polyline({ Vertex(-1, 0), Vertex(0, 0), Vertex(5, -5) })
    p:ensureMaximumEdgeLength(5, math.rad(46))
    lu.assertEquals(#p, 4)
    p[3]:assertAlmostEquals(Vector(3.27, -1.35))
    -- limit
    p = Polyline({ Vertex(-1, 0), Vertex(0, 0), Vertex(5, -5) })
    p:ensureMaximumEdgeLength(5, math.rad(45))
    lu.assertEquals(#p, 4)
    p[3]:assertAlmostEquals(Vector(2.5, -2.5))
    p = Polyline({ Vertex(-1, 0), Vertex(0, 0), Vertex(5, 5) })
    p:ensureMaximumEdgeLength(5, math.rad(45))
    lu.assertEquals(#p, 4)
    p[3]:assertAlmostEquals(Vector(2.5, 2.5))
end

function testPathBetween()
    local p = Polyline({ Vertex(0, 0), Vertex(0, 5), Vertex(0, 10), Vertex(5, 10), Vertex(10, 10), Vertex(15, 10), Vertex(20, 10) })
    local o = p:_getPathBetween(1, 2)
    lu.assertEquals(#o, 2)
    o[1]:assertAlmostEquals(p[1])
    o[2]:assertAlmostEquals(p[2])
    o = p:_getPathBetween(2, 4)
    lu.assertEquals(#o, 3)
    o[1]:assertAlmostEquals(p[2])
    o[2]:assertAlmostEquals(p[3])
    o[3]:assertAlmostEquals(p[4])

    o = p:_getPathBetween(2, 1)
    lu.assertEquals(#o, 2)
    o[1]:assertAlmostEquals(p[2])
    o[2]:assertAlmostEquals(p[1])
    o = p:_getPathBetween(4, 2)
    lu.assertEquals(#o, 3)
    o[1]:assertAlmostEquals(p[4])
    o[2]:assertAlmostEquals(p[3])
    o[3]:assertAlmostEquals(p[2])
end

function testPathBetweenIntersections()
    local p = Polyline({ Vertex(0, 0), Vertex(0, 5), Vertex(0, 10), Vertex(5, 10), Vertex(10, 10), Vertex(15, 10), Vertex(20, 10) })
    local o = p:_getPathBetweenIntersections(1, 2)
    lu.assertEquals(#o, 1)
    o[1]:assertAlmostEquals(p[2])
    o = p:_getPathBetweenIntersections(2, 4)
    lu.assertEquals(#o, 2)
    o[1]:assertAlmostEquals(p[3])
    o[2]:assertAlmostEquals(p[4])

    o = p:_getPathBetweenIntersections(2, 1)
    lu.assertEquals(#o, 1)
    o[1]:assertAlmostEquals(p[2])
    o = p:_getPathBetweenIntersections(4, 2)
    lu.assertEquals(#o, 2)
    o[1]:assertAlmostEquals(p[4])
    o[2]:assertAlmostEquals(p[3])
end

function testIntersections()
    local p = Polyline({ Vertex(-5, 0), Vertex(0, 0), Vertex(5, 0) })
    local o = Polyline({ Vertex(3, -1), Vertex(0, 1), Vertex(-2, -1), Vertex(-5, 1) })
    local iss = p:getIntersections(o)
    local is = iss[1]
    lu.assertEquals(is.ixA, 1)
    lu.assertEquals(is.ixB, 3)
    is.is:assertAlmostEquals(Vector(-3.5, 0))
    is.edgeA:assertAlmostEquals(cg.LineSegment(-5, 0, 0, 0))
    is = iss[2]
    lu.assertEquals(is.ixA, 1)
    lu.assertEquals(is.ixB, 2)
    is.is:assertAlmostEquals(Vector(-1, 0))
    is.edgeA:assertAlmostEquals(cg.LineSegment(-5, 0, 0, 0))
    is = iss[3]
    lu.assertEquals(is.ixA, 2)
    lu.assertEquals(is.ixB, 1)
    is.is:assertAlmostEquals(Vector(1.5, 0))
    is.edgeA:assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))
    -- same intersections just different index on o (b)
    o = Polyline({ Vertex(-5, 1), Vertex(-2, -1), Vertex(0, 1), Vertex(3, -1) })
    iss = p:getIntersections(o)
    is = iss[1]
    lu.assertEquals(is.ixA, 1)
    lu.assertEquals(is.ixB, 1)
    is.is:assertAlmostEquals(Vector(-3.5, 0))
    is.edgeA:assertAlmostEquals(cg.LineSegment(-5, 0, 0, 0))
    is = iss[2]
    lu.assertEquals(is.ixA, 1)
    lu.assertEquals(is.ixB, 2)
    is.is:assertAlmostEquals(Vector(-1, 0))
    is.edgeA:assertAlmostEquals(cg.LineSegment(-5, 0, 0, 0))
    is = iss[3]
    lu.assertEquals(is.ixA, 2)
    lu.assertEquals(is.ixB, 3)
    is.is:assertAlmostEquals(Vector(1.5, 0))
    is.edgeA:assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))
end

function testGoAround()

    -- goAround()
    -- disable smoothing so assertions are easier
    local minSmoothingAngle = cg.cMinSmoothingAngle
    cg.cMinSmoothingAngle = math.huge

    local p = Polyline({ Vertex(-5, 0), Vertex(0, 0), Vertex(5, 0) })
    local o = Polyline({ Vertex(-5, 1), Vertex(-2, -1), Vertex(0, 1), Vertex(3, -1) })

    p:goAround(o)
    p[1]:assertAlmostEquals(Vector(-5, 0))
    p[2]:assertAlmostEquals(Vector(-3.5, 0))
    p[3]:assertAlmostEquals(Vector(-2, -1))
    p[4]:assertAlmostEquals(Vector(-1, 0))
    p[6]:assertAlmostEquals(Vector(5, 0))

    p = Polyline({ Vertex(-5, 0), Vertex(0, 0), Vertex(5, 0) })
    -- same line just from the other direction should result in the same go around path
    o = Polyline({ Vertex(3, -1), Vertex(0, 1), Vertex(-2, -1), Vertex(-5, 1) })
    p:goAround(o)
    p[1]:assertAlmostEquals(Vector(-5, 0))
    p[2]:assertAlmostEquals(Vector(-3.5, 0))
    p[3]:assertAlmostEquals(Vector(-2, -1))
    p[4]:assertAlmostEquals(Vector(-1, 0))
    p[6]:assertAlmostEquals(Vector(5, 0))
    -- restore smoothing angle to re-enable smoothing
    cg.cMinSmoothingAngle = minSmoothingAngle

    p = Polyline({ Vertex(0, 0), Vertex(0, 1), Vertex(0, 2), Vertex(0, 3), Vertex(0, 4), Vertex(0, 5), Vertex(0, 6) })
    lu.assertEquals(p:moveForward(1, 3), 4)
    lu.assertEquals(p:moveForward(1, 3.01), 5)
    lu.assertEquals(p:moveForward(1, 2.99), 4)
    lu.assertEquals(p:moveForward(2, 3), 5)
    lu.assertIsNil(p:moveForward(5, 3))
end

function testIsEntering()
    -- isEntering()
    local p = Polyline({ Vertex(-5, 0), Vertex(0, 0), Vertex(5, 0) })
    -- clockwise
    local o = Polygon({ Vector(-2, 2), Vector(2, 2), Vector(2, -2), Vector(-2, -2) })
    local iss = p:getIntersections(o)
    iss[1].is:assertAlmostEquals(Vector(-2, 0))
    lu.assertTrue(p:isEntering(o, iss[1]))
    lu.assertFalse(p:isEntering(o, iss[2]))
    p:reverse()
    iss = p:getIntersections(o)
    iss[1].is:assertAlmostEquals(Vector(2, 0))
    lu.assertTrue(p:isEntering(o, iss[1]))
    lu.assertFalse(p:isEntering(o, iss[2]))
    -- counterclockwise
    o:reverse()
    iss = p:getIntersections(o)
    iss[1].is:assertAlmostEquals(Vector(2, 0))
    lu.assertTrue(p:isEntering(o, iss[1]))
    lu.assertFalse(p:isEntering(o, iss[2]))
    p:reverse()
    iss = p:getIntersections(o)
    iss[1].is:assertAlmostEquals(Vector(-2, 0))
    lu.assertTrue(p:isEntering(o, iss[1]))
    lu.assertFalse(p:isEntering(o, iss[2]))

    p = Polyline({ Vertex(-2, 0), Vertex(0, 0), Vertex(2, 0) })
    o = Polygon({ Vector(-2, 2), Vector(2, 2), Vector(2, -2), Vector(-2, -2) })
    iss = p:getIntersections(o)
    lu.assertTrue(p:isEntering(o, iss[1]))
    lu.assertFalse(p:isEntering(o, iss[2]))

    p = Polyline({ Vertex(0, -2), Vertex(0, 0), Vertex(0, 2) })
    o = Polygon({ Vector(-2, 2), Vector(2, 2), Vector(2, -2), Vector(-2, -2) })
    iss = p:getIntersections(o)
    lu.assertTrue(p:isEntering(o, iss[1]))
    lu.assertFalse(p:isEntering(o, iss[2]))
    p:reverse()
    iss = p:getIntersections(o)
    lu.assertTrue(p:isEntering(o, iss[1]))
    lu.assertFalse(p:isEntering(o, iss[2]))

    p = Polyline({ Vertex(0, -2), Vertex(0, 0), Vertex(0, 2) })
    local island = Polygon({ Vector(-1, 1), Vector(1, 1), Vector(1, -1), Vector(-1, -1) })
    iss = p:getIntersections(o, 1, false, { island })
    lu.assertTrue(p:isEntering(o, iss[1]))
    lu.assertFalse(p:isEntering(o, iss[2]))
end

function testShorten()
    lu.EPS = 0.01
    local p = Polyline({ Vertex(0, 0), Vertex(0, 10) })
    p:cutEnd(1)
    p[1]:assertAlmostEquals(Vector(0, 0))
    p[#p]:assertAlmostEquals(Vector(0, 9))
    lu.assertEquals(p:getLength(), 9)

    p:cutStart(1)
    p[1]:assertAlmostEquals(Vector(0, 1))
    p[#p]:assertAlmostEquals(Vector(0, 9))
    lu.assertEquals(p:getLength(), 8)

    p = Polyline({ Vertex(0, 0), Vertex(0, 5), Vertex(0, 10), Vertex(5, 10),
                      Vertex(10, 10), Vertex(15, 10), Vertex(20, 10) })
    lu.assertEquals(p:getLength(), 30)
    p:cutEnd(1)
    p[1]:assertAlmostEquals(Vector(0, 0))
    p[#p]:assertAlmostEquals(Vector(19, 10))
    lu.assertEquals(p:getLength(), 29)
    p:cutStart(1)
    lu.assertEquals(p:getLength(), 28)
    p[1]:assertAlmostEquals(Vector(0, 1))
    p[#p]:assertAlmostEquals(Vector(19, 10))
    p:cutEnd(7)
    lu.assertEquals(p:getLength(), 21)
    p[1]:assertAlmostEquals(Vector(0, 1))
    p[#p]:assertAlmostEquals(Vector(12, 10))
    p:cutStart(7)
    lu.assertAlmostEquals(p:getLength(), 12.38)
    p[1]:assertAlmostEquals(Vector(0, 8))
    p[#p]:assertAlmostEquals(Vector(12, 10))

end

function testTrimAtFirstIntersection()
    local p = Polyline({ Vertex(0, 0), Vertex(5, 0), Vertex(10, 0), Vertex(15, 0), Vertex(20, 0)})
    local o = Polyline({ Vertex(3, 10), Vertex(3, -10)})
    lu.assertEquals(p:getLength(), 20)
    lu.assertEquals(p:getLengthBetween(3), 10)
    p:trimAtFirstIntersection(o)
    lu.assertEquals(p:getLength(), 15)
    p[1]:assertAlmostEquals(Vertex(5, 0))
    p = Polyline({ Vertex(0, 0), Vertex(5, 0), Vertex(10, 0), Vertex(15, 0), Vertex(20, 0)})
    o = Polyline({ Vertex(17, 10), Vertex(17, -10)})
    p:trimAtFirstIntersection(o)
    lu.assertEquals(p:getLength(), 15)
    p[1]:assertAlmostEquals(Vertex(0, 0))
    p[#p]:assertAlmostEquals(Vertex(15, 0))
end

function testLengthBetween()
    local p = Polyline({ Vertex(0, 0), Vertex(5, 0), Vertex(10, 0), Vertex(15, 0), Vertex(20, 0)})
    lu.assertEquals(p:getLengthBetween(1, 2), 5)
    lu.assertEquals(p:getLengthBetween(1), p:getLength())
    lu.assertEquals(p:getLengthBetween(1, #p), p:getLength())
    lu.assertEquals(p:getLengthBetween(#p), 0)
    lu.assertEquals(p:getLengthBetween(#p - 1, #p), 5)
    lu.assertEquals(p:getLengthBetween(2, 4), 10)
end

os.exit(lu.LuaUnit.run())