require('include')

function testLineSegment()
    local s1 = CourseGenerator.LineSegment(-5, 5, 5, 5)
    lu.assertEquals(s1:intersects(CourseGenerator.LineSegment(0, 0, 0, 10)), Vector(0, 5))
    lu.assertEquals(s1:intersects(CourseGenerator.LineSegment(-5, 0, 5, 10)), Vector(0, 5))
    lu.assertIsNil(s1:intersects(CourseGenerator.LineSegment(-5, 5, 5, 5)))
    lu.assertIsNil(s1:intersects(CourseGenerator.LineSegment(0, 0, 0, 1)))
    lu.assertIsNil(s1:intersects(CourseGenerator.LineSegment(-5, 10, 5, 11)))
    lu.assertIsNil(s1:intersects(CourseGenerator.LineSegment(-10, -2, 10, -2)))

    s1:offset(5, -5)
    lu.assertIsTrue(s1:almostEquals(CourseGenerator.LineSegment(0, 0, 10, 0)))
    s1:offset(0, -1)
    lu.assertIsTrue(s1:almostEquals(CourseGenerator.LineSegment(0, -1, 10, -1)))
    s1:offset(-1, 2)
    lu.assertIsTrue(s1:almostEquals(CourseGenerator.LineSegment(-1, 1, 9, 1)))

    s1 = CourseGenerator.LineSegment(0, 0, 1, 0)
    lu.assertIsTrue(s1:extendTo(CourseGenerator.LineSegment(2, -1, 2, 1)))
    s1:assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 2, 0))
    lu.assertIsTrue(s1:extendTo(CourseGenerator.LineSegment(-2, -1, -2, 1)))
    s1:assertAlmostEquals(CourseGenerator.LineSegment(-2, 0, 2, 0))
    lu.assertIsFalse(s1:extendTo(CourseGenerator.LineSegment(-2, -1, -2, -1)))
    s1 = CourseGenerator.LineSegment(-4, 0, -2, 0)
    lu.assertIsTrue(s1:extendTo(CourseGenerator.LineSegment(-2, -2, 2, 2)))
    s1:assertAlmostEquals(CourseGenerator.LineSegment(-4, 0, 0, 0))
    s1 = CourseGenerator.LineSegment(0, 0, 1, 0)
    lu.assertIsTrue(s1:extendTo(CourseGenerator.LineSegment(2, 0, 2, 1)))
    s1:assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 2, 0))
    s1 = CourseGenerator.LineSegment(0, 0, 0, 1)
    lu.assertIsTrue(s1:extendTo(CourseGenerator.LineSegment(-2, 3, 2, 3)))
    s1:assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 0, 3))
    s1 = CourseGenerator.LineSegment(0, 2, 3, 2)
    lu.assertIsTrue(s1:extendTo(CourseGenerator.LineSegment(0, 0, 0, 2)))
    s1:assertAlmostEquals(CourseGenerator.LineSegment(0, 2, 3, 2))

    -- connect
    local a, b, c
    -- ends already clean
    a, b = CourseGenerator.LineSegment(0, 0, 0, 2), CourseGenerator.LineSegment(0, 2, 2, 2)
    c = CourseGenerator.LineSegment.connect(a, b, 1, false)
    lu.assertIsNil(c)
    a:assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 0, 2))
    b:assertAlmostEquals(CourseGenerator.LineSegment(0, 2, 2, 2))
    -- b's end clipped
    a, b = CourseGenerator.LineSegment(0, 0, 0, 2), CourseGenerator.LineSegment(-1, 2, 2, 2)
    c = CourseGenerator.LineSegment.connect(a, b, 1, false)
    lu.assertIsNil(c)
    a:assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 0, 2))
    b:assertAlmostEquals(CourseGenerator.LineSegment(0, 2, 2, 2))
    -- a's end clipped
    a, b = CourseGenerator.LineSegment(0, 0, 0, 3), CourseGenerator.LineSegment(0, 2, 2, 2)
    c = CourseGenerator.LineSegment.connect(a, b, 1, false)
    lu.assertIsNil(c)
    a:assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 0, 2))
    b:assertAlmostEquals(CourseGenerator.LineSegment(0, 2, 2, 2))
    -- both ends must be clipped
    a, b = CourseGenerator.LineSegment(0, 0, 0, 3), CourseGenerator.LineSegment(-1, 2, 2, 2)
    c = CourseGenerator.LineSegment.connect(a, b, 1, false)
    lu.assertIsNil(c)
    a:assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 0, 2))
    b:assertAlmostEquals(CourseGenerator.LineSegment(0, 2, 2, 2))
    -- big gap, cut corner
    a, b = CourseGenerator.LineSegment(0, 0, 0, 1), CourseGenerator.LineSegment(1, 2, 3, 2)
    c = CourseGenerator.LineSegment.connect(a, b, 1, false)
    c:assertAlmostEquals(CourseGenerator.LineSegment(0, 1, 1, 2))
    a:assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 0, 1))
    b:assertAlmostEquals(CourseGenerator.LineSegment(1, 2, 3, 2))
    -- big gap, preserve corner
    a, b = CourseGenerator.LineSegment(0, 0, 0, 1), CourseGenerator.LineSegment(0, 2, 3, 2)
    c = CourseGenerator.LineSegment.connect(a, b, 1, true)
    lu.assertIsNil(c)
    a:assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 0, 2))
    b:assertAlmostEquals(CourseGenerator.LineSegment(0, 2, 3, 2))
    -- gap too small
    a, b = CourseGenerator.LineSegment(0, 0, 0, 1), CourseGenerator.LineSegment(1, 2, 3, 2)
    c = CourseGenerator.LineSegment.connect(a, b, 10, false)
    lu.assertIsNil(c)
    a:assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 0.5, 1.5))
    b:assertAlmostEquals(CourseGenerator.LineSegment(0.5, 1.5, 3, 2))

    -- Radius

    -- epsilon for assertAlmostEquals
    lu.EPS = 0.01

    -- parallel
    lu.assertEquals(CourseGenerator.LineSegment(0, 0, 5, 0):getRadiusTo(CourseGenerator.LineSegment(10, 0, 10, 0)), math.huge)
    lu.assertEquals(CourseGenerator.LineSegment(0, 0, 5, 0):getRadiusTo(CourseGenerator.LineSegment(0, 2, 5, 2)), math.huge)
    -- invalid cases
    lu.assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 5, 0):getRadiusTo(CourseGenerator.LineSegment(10, 0, 15, 1)), 0)
    lu.assertAlmostEquals(CourseGenerator.LineSegment(10, 0, 15, 1):getRadiusTo(CourseGenerator.LineSegment(0, 0, 5, 0)), 0)
    lu.assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 5, 0):getRadiusTo(CourseGenerator.LineSegment(10, 1, 15, 0)), 0)
    -- almost parallel
    lu.assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 5, 0):getRadiusTo(CourseGenerator.LineSegment(10, 0.1, 15, 0.2)), 500.05)

    -- small angle
    lu.assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 5, 0):getRadiusTo(CourseGenerator.LineSegment(10, 1, 0, 2)), 0.5)

    -- 90 degrees
    lu.assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 5, 0):getRadiusTo(CourseGenerator.LineSegment(10, 5, 10, 10)), 5)
    lu.assertAlmostEquals(CourseGenerator.LineSegment(10, 10, 10, 5):getRadiusTo(CourseGenerator.LineSegment(5, 0, 0, 0)), 5)

    -- ~45 degrees
    lu.assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 5, 0):getRadiusTo(CourseGenerator.LineSegment(15, 5, 20, 10)), 17.07)
    lu.assertAlmostEquals(CourseGenerator.LineSegment(0, 0, 5, 0):getRadiusTo(CourseGenerator.LineSegment(15, -5, 20, -10)), 17.07)

    a = CourseGenerator.LineSegment(0, 0, 10, 0)
    local p = Vector(5, 5)
    lu.assertEquals(a:getDistanceFrom(p), 5)
    lu.assertIsTrue(a:isPointOnLeft(Vector(5, 5)))
    lu.assertIsTrue(a:isPointOnLeft(Vector(5, 0)))
    lu.assertIsTrue(a:isPointOnLeft(Vector(-15, 1)))
    lu.assertIsTrue(a:isPointOnLeft(Vector(15, 1)))
    lu.assertIsFalse(a:isPointOnLeft(Vector(5, -5)))
    lu.assertIsFalse(a:isPointOnLeft(Vector(-15, -1)))
    lu.assertIsFalse(a:isPointOnLeft(Vector(15, -1)))

    a = CourseGenerator.LineSegment(3, 3, 13, 3)
    p = Vector(8, 8)
    lu.assertEquals(a:getDistanceFrom(p), 5)

    a = CourseGenerator.LineSegment(-1, 0, 0, 20)
    lu.assertIsFalse(a:isPointOnLeft(Vector(5, 5)))
    lu.assertIsTrue(a:isPointOnLeft(Vector(-5, 5)))

    a = CourseGenerator.LineSegment(0, 0, 0, 20)
    lu.assertIsFalse(a:isPointOnLeft(Vector(5, 5)))
    lu.assertIsTrue(a:isPointOnLeft(Vector(-5, 5)))

    a = CourseGenerator.LineSegment(0, 0, 0, -20)
    lu.assertIsFalse(a:isPointOnLeft(Vector(-5, 5)))
    lu.assertIsTrue(a:isPointOnLeft(Vector(5, 5)))

    -- overlaps
    a = CourseGenerator.LineSegment(-5, -1, 5, -3)
    b = CourseGenerator.LineSegment(-10, 1, 0, 2)
    lu.assertIsTrue(a:overlaps(b))
    lu.assertIsTrue(b:overlaps(a))

    b = CourseGenerator.LineSegment(-1, 1, 0, 2)
    lu.assertIsTrue(a:overlaps(b))
    lu.assertIsTrue(b:overlaps(a))

    b = CourseGenerator.LineSegment(-10, 1, 10, 2)
    lu.assertIsTrue(a:overlaps(b))
    lu.assertIsTrue(b:overlaps(a))

    b = CourseGenerator.LineSegment(-15, 1, -5.5, 2)
    lu.assertIsFalse(a:overlaps(b))
    lu.assertIsFalse(b:overlaps(a))
end

function testExtend()
    lu.EPS = 0.01
    local a = CourseGenerator.LineSegment(1, 1, 10, 10)
    a:extend(math.sqrt(2))
    a:getEnd():assertAlmostEquals(Vector(11, 11))
    a:getBase():assertAlmostEquals(Vector(1, 1))
    a:extend(-math.sqrt(2))
    a:getBase():assertAlmostEquals(Vector(0, 0))
end

os.exit(lu.LuaUnit.run())

