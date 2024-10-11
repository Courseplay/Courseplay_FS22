require('include')
lu.EPS = 0.01
function testField()
    local fields = CourseGenerator.Field.loadSavedFields('fields/Coldborough.xml')
    lu.assertEquals(#fields, 9)
    lu.assertEquals(#fields[8].boundary, 90)
    local field = fields[8]
    local center = field:getCenter()
    lu.assertAlmostEquals(center.x, 381.41, 0.1)
    lu.assertAlmostEquals(center.y, 31.3, 0.1)
    local x1, y1, x2, y2 = field:getBoundingBox()
    lu.assertAlmostEquals(x1, 307.18)
    lu.assertAlmostEquals(y1, -80.66)
    lu.assertAlmostEquals(x2, 452.82)
    lu.assertAlmostEquals(y2, 157.16)
end
os.exit(lu.LuaUnit.run())
