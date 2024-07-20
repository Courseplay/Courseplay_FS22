require('include')
lu.EPS = 0.01
function testHeadlandConnector()
    local l, r = CourseGenerator.HeadlandConnector.getTransitionLength(10, 5)
    lu.assertNotAlmostEquals(r, 5)
    lu.assertTrue(l > 10 / math.tan(CourseGenerator.cMaxHeadlandConnectorAngle))
    l, r = CourseGenerator.HeadlandConnector.getTransitionLength(10, 15)
    lu.assertAlmostEquals(r, 15)
    lu.assertTrue(l > 10 / math.tan(CourseGenerator.cMaxHeadlandConnectorAngle))
end
os.exit(lu.LuaUnit.run())

