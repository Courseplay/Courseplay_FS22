require('include')
lu.EPS = 0.01
function testHeadlandConnector()
    lu.assertAlmostEquals(CourseGenerator.HeadlandConnector.getTransitionLength(10, 5), 10)
    lu.assertAlmostEquals(CourseGenerator.HeadlandConnector.getTransitionLength(10, 5.1), 10.2)
    lu.assertAlmostEquals(CourseGenerator.HeadlandConnector.getTransitionLength(10, 4.9), 9.8)
    lu.assertAlmostEquals(CourseGenerator.HeadlandConnector.getTransitionLength(10, 4.999), 10)
    lu.assertAlmostEquals(CourseGenerator.HeadlandConnector.getTransitionLength(10, 10), 2 * 10 * math.cos(math.rad(30)))
    lu.assertAlmostEquals(CourseGenerator.HeadlandConnector.getTransitionLength(3, 6), 7.93)
    lu.assertAlmostEquals(CourseGenerator.HeadlandConnector.getTransitionLength(3, 5), 7.14)
end
os.exit(lu.LuaUnit.run())

