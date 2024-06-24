require('include')

function testLineSegment()
    local s1 = cg.LineSegment(-5, 5, 5, 5)
    lu.assertEquals(s1:intersects(cg.LineSegment(0, 0, 0, 10)), cg.Vector(0, 5))
    lu.assertEquals(s1:intersects(cg.LineSegment(-5, 0, 5, 10)), cg.Vector(0, 5))
    lu.assertIsNil(s1:intersects(cg.LineSegment(-5, 5, 5, 5)))
    lu.assertIsNil(s1:intersects(cg.LineSegment(0, 0, 0, 1)))
    lu.assertIsNil(s1:intersects(cg.LineSegment(-5, 10, 5, 11)))
    lu.assertIsNil(s1:intersects(cg.LineSegment(-10, -2, 10, -2)))

    s1:offset(5, -5)
    lu.assertIsTrue(s1:almostEquals(cg.LineSegment(0, 0, 10, 0)))
    s1:offset(0, -1)
    lu.assertIsTrue(s1:almostEquals(cg.LineSegment(0, -1, 10, -1)))
    s1:offset(-1, 2)
    lu.assertIsTrue(s1:almostEquals(cg.LineSegment(-1, 1, 9, 1)))

    s1 = cg.LineSegment(0, 0, 1, 0)
    lu.assertIsTrue(s1:extendTo(cg.LineSegment(2, -1, 2, 1)))
    s1:assertAlmostEquals(cg.LineSegment(0, 0, 2, 0))
    lu.assertIsTrue(s1:extendTo(cg.LineSegment(-2, -1, -2, 1)))
    s1:assertAlmostEquals(cg.LineSegment(-2, 0, 2, 0))
    lu.assertIsFalse(s1:extendTo(cg.LineSegment(-2, -1, -2, -1)))
    s1 = cg.LineSegment(-4, 0, -2, 0)
    lu.assertIsTrue(s1:extendTo(cg.LineSegment(-2, -2, 2, 2)))
    s1:assertAlmostEquals(cg.LineSegment(-4, 0, 0, 0))
    s1 = cg.LineSegment(0, 0, 1, 0)
    lu.assertIsTrue(s1:extendTo(cg.LineSegment(2, 0, 2, 1)))
    s1:assertAlmostEquals(cg.LineSegment(0, 0, 2, 0))
    s1 = cg.LineSegment(0, 0, 0, 1)
    lu.assertIsTrue(s1:extendTo(cg.LineSegment(-2, 3, 2, 3)))
    s1:assertAlmostEquals(cg.LineSegment(0, 0, 0, 3))
    s1 = cg.LineSegment(0, 2, 3, 2)
    lu.assertIsTrue(s1:extendTo(cg.LineSegment(0, 0, 0, 2)))
    s1:assertAlmostEquals(cg.LineSegment(0, 2, 3, 2))

    -- connect
    local a, b, c
    -- ends already clean
    a, b = cg.LineSegment(0, 0, 0, 2), cg.LineSegment(0, 2, 2, 2)
    c = cg.LineSegment.connect(a, b, 1, false)
    lu.assertIsNil(c)
    a:assertAlmostEquals(cg.LineSegment(0, 0, 0, 2))
    b:assertAlmostEquals(cg.LineSegment(0, 2, 2, 2))
    -- b's end clipped
    a, b = cg.LineSegment(0, 0, 0, 2), cg.LineSegment(-1, 2, 2, 2)
    c = cg.LineSegment.connect(a, b, 1, false)
    lu.assertIsNil(c)
    a:assertAlmostEquals(cg.LineSegment(0, 0, 0, 2))
    b:assertAlmostEquals(cg.LineSegment(0, 2, 2, 2))
    -- a's end clipped
    a, b = cg.LineSegment(0, 0, 0, 3), cg.LineSegment(0, 2, 2, 2)
    c = cg.LineSegment.connect(a, b, 1, false)
    lu.assertIsNil(c)
    a:assertAlmostEquals(cg.LineSegment(0, 0, 0, 2))
    b:assertAlmostEquals(cg.LineSegment(0, 2, 2, 2))
    -- both ends must be clipped
    a, b = cg.LineSegment(0, 0, 0, 3), cg.LineSegment(-1, 2, 2, 2)
    c = cg.LineSegment.connect(a, b, 1, false)
    lu.assertIsNil(c)
    a:assertAlmostEquals(cg.LineSegment(0, 0, 0, 2))
    b:assertAlmostEquals(cg.LineSegment(0, 2, 2, 2))
    -- big gap, cut corner
    a, b = cg.LineSegment(0, 0, 0, 1), cg.LineSegment(1, 2, 3, 2)
    c = cg.LineSegment.connect(a, b, 1, false)
    c:assertAlmostEquals(cg.LineSegment(0, 1, 1, 2))
    a:assertAlmostEquals(cg.LineSegment(0, 0, 0, 1))
    b:assertAlmostEquals(cg.LineSegment(1, 2, 3, 2))
    -- big gap, preserve corner
    a, b = cg.LineSegment(0, 0, 0, 1), cg.LineSegment(0, 2, 3, 2)
    c = cg.LineSegment.connect(a, b, 1, true)
    lu.assertIsNil(c)
    a:assertAlmostEquals(cg.LineSegment(0, 0, 0, 2))
    b:assertAlmostEquals(cg.LineSegment(0, 2, 3, 2))
    -- gap too small
    a, b = cg.LineSegment(0, 0, 0, 1), cg.LineSegment(1, 2, 3, 2)
    c = cg.LineSegment.connect(a, b, 10, false)
    lu.assertIsNil(c)
    a:assertAlmostEquals(cg.LineSegment(0, 0, 0.5, 1.5))
    b:assertAlmostEquals(cg.LineSegment(0.5, 1.5, 3, 2))

    -- Radius

    -- epsilon for assertAlmostEquals
    lu.EPS = 0.01

    -- parallel
    lu.assertEquals(cg.LineSegment(0, 0, 5, 0):getRadiusTo(cg.LineSegment(10, 0, 10, 0)), math.huge)
    lu.assertEquals(cg.LineSegment(0, 0, 5, 0):getRadiusTo(cg.LineSegment(0, 2, 5, 2)), math.huge)
    -- invalid cases
    lu.assertAlmostEquals(cg.LineSegment(0, 0, 5, 0):getRadiusTo(cg.LineSegment(10, 0, 15, 1)), 0)
    lu.assertAlmostEquals(cg.LineSegment(10, 0, 15, 1):getRadiusTo(cg.LineSegment(0, 0, 5, 0)), 0)
    lu.assertAlmostEquals(cg.LineSegment(0, 0, 5, 0):getRadiusTo(cg.LineSegment(10, 1, 15, 0)), 0)
    -- almost parallel
    lu.assertAlmostEquals(cg.LineSegment(0, 0, 5, 0):getRadiusTo(cg.LineSegment(10, 0.1, 15, 0.2)), 500.05)

    -- small angle
    lu.assertAlmostEquals(cg.LineSegment(0, 0, 5, 0):getRadiusTo(cg.LineSegment(10, 1, 0, 2)), 0.5)

    -- 90 degrees
    lu.assertAlmostEquals(cg.LineSegment(0, 0, 5, 0):getRadiusTo(cg.LineSegment(10, 5, 10, 10)), 5)
    lu.assertAlmostEquals(cg.LineSegment(10, 10, 10, 5):getRadiusTo(cg.LineSegment(5, 0, 0, 0)), 5)

    -- ~45 degrees
    lu.assertAlmostEquals(cg.LineSegment(0, 0, 5, 0):getRadiusTo(cg.LineSegment(15, 5, 20, 10)), 17.07)
    lu.assertAlmostEquals(cg.LineSegment(0, 0, 5, 0):getRadiusTo(cg.LineSegment(15, -5, 20, -10)), 17.07)

    a = cg.LineSegment(0, 0, 10, 0)
    local p = cg.Vector(5, 5)
    lu.assertEquals(a:getDistanceFrom(p), 5)
    lu.assertIsTrue(a:isPointOnLeft(cg.Vector(5, 5)))
    lu.assertIsTrue(a:isPointOnLeft(cg.Vector(5, 0)))
    lu.assertIsTrue(a:isPointOnLeft(cg.Vector(-15, 1)))
    lu.assertIsTrue(a:isPointOnLeft(cg.Vector(15, 1)))
    lu.assertIsFalse(a:isPointOnLeft(cg.Vector(5, -5)))
    lu.assertIsFalse(a:isPointOnLeft(cg.Vector(-15, -1)))
    lu.assertIsFalse(a:isPointOnLeft(cg.Vector(15, -1)))

    a = cg.LineSegment(3, 3, 13, 3)
    p = cg.Vector(8, 8)
    lu.assertEquals(a:getDistanceFrom(p), 5)

    a = cg.LineSegment(-1, 0, 0, 20)
    lu.assertIsFalse(a:isPointOnLeft(cg.Vector(5, 5)))
    lu.assertIsTrue(a:isPointOnLeft(cg.Vector(-5, 5)))

    a = cg.LineSegment(0, 0, 0, 20)
    lu.assertIsFalse(a:isPointOnLeft(cg.Vector(5, 5)))
    lu.assertIsTrue(a:isPointOnLeft(cg.Vector(-5, 5)))

    a = cg.LineSegment(0, 0, 0, -20)
    lu.assertIsFalse(a:isPointOnLeft(cg.Vector(-5, 5)))
    lu.assertIsTrue(a:isPointOnLeft(cg.Vector(5, 5)))

    -- overlaps
    a = cg.LineSegment(-5, -1, 5, -3)
    b = cg.LineSegment(-10, 1, 0, 2)
    lu.assertIsTrue(a:overlaps(b))
    lu.assertIsTrue(b:overlaps(a))

    b = cg.LineSegment(-1, 1, 0, 2)
    lu.assertIsTrue(a:overlaps(b))
    lu.assertIsTrue(b:overlaps(a))

    b = cg.LineSegment(-10, 1, 10, 2)
    lu.assertIsTrue(a:overlaps(b))
    lu.assertIsTrue(b:overlaps(a))

    b = cg.LineSegment(-15, 1, -5.5, 2)
    lu.assertIsFalse(a:overlaps(b))
    lu.assertIsFalse(b:overlaps(a))
end

function testExtend()
    lu.EPS = 0.01
    local a = cg.LineSegment(1, 1, 10, 10)
    a:extend(math.sqrt(2))
    a:getEnd():assertAlmostEquals(cg.Vector(11, 11))
    a:getBase():assertAlmostEquals(cg.Vector(1, 1))
    a:extend(-math.sqrt(2))
    a:getBase():assertAlmostEquals(cg.Vector(0, 0))
end

os.exit(lu.LuaUnit.run())

