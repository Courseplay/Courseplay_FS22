require('include')
profiler = require('profile')

lu.EPS = 0.01
function testFieldworkCourse()
    local fields = CourseGenerator.Field.loadSavedFields('fields/Coldborough.xml')
    local field = fields[2]
    local workingWidth = 8
    local turningRadius = 6
    local nHeadlands = 4
    local context = CourseGenerator.FieldworkContext(field, workingWidth, turningRadius, nHeadlands)
    local fieldworkCourse = CourseGenerator.FieldworkCourse(context)
    --profiler.start()
    lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
    print(profiler.report(40))
    context:setBypassIslands(true)
    fieldworkCourse = CourseGenerator.FieldworkCourse(context)
    lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
    context:setHeadlandsWithRoundCorners(1)
    fieldworkCourse = CourseGenerator.FieldworkCourse(context)
    lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
    context:setHeadlandsWithRoundCorners(nHeadlands)
    fieldworkCourse = CourseGenerator.FieldworkCourse(context)
    lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
    nHeadlands = 5
    context:setHeadlands(nHeadlands)
    fieldworkCourse = CourseGenerator.FieldworkCourse(context)
    lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
end
os.exit(lu.LuaUnit.run())
