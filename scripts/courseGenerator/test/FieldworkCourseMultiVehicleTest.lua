require('include')
profiler = require('profile')

lu.EPS = 0.01
function testFieldworkCourseMultiVehicle()
    local mockContext = {
        nVehicles = 2,
        workingWidth = 10
    }
    local mockFieldworkCourse = {
        context = mockContext
    }
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 1):assertAlmostEquals(Vector(0, 5))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 2):assertAlmostEquals(Vector(0, -5))
    mockContext.nVehicles = 3
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 1):assertAlmostEquals(Vector(0, 10))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 2):assertAlmostEquals(Vector(0, 0))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 3):assertAlmostEquals(Vector(0, -10))
    mockContext.nVehicles = 4
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 1):assertAlmostEquals(Vector(0, 15))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 2):assertAlmostEquals(Vector(0, 5))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 3):assertAlmostEquals(Vector(0, -5))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 4):assertAlmostEquals(Vector(0, -15))
    mockContext.nVehicles = 5
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 1):assertAlmostEquals(Vector(0, 20))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 2):assertAlmostEquals(Vector(0, 10))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 3):assertAlmostEquals(Vector(0, 0))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 4):assertAlmostEquals(Vector(0, -10))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 5):assertAlmostEquals(Vector(0, -20))
    mockContext.nVehicles = 6
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 1):assertAlmostEquals(Vector(0, 25))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 2):assertAlmostEquals(Vector(0, 15))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 3):assertAlmostEquals(Vector(0, 5))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 4):assertAlmostEquals(Vector(0, -5))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 5):assertAlmostEquals(Vector(0, -15))
    CourseGenerator.FieldworkCourseMultiVehicle._indexToOffsetVector(mockFieldworkCourse, 6):assertAlmostEquals(Vector(0, -25))

end
os.exit(lu.LuaUnit.run())
