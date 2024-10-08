require('include')
function testVector()
    local a, b = Vector(0, 10), Vector(5, 5)
    a:projection(b):assertAlmostEquals(Vector(0, 5))
    a:rejection(b):assertAlmostEquals(Vector(5, 0))
    a, b = Vector(0, 5), Vector(10, 10)
    a:projection(b):assertAlmostEquals(Vector(0, 10))
    a:rejection(b):assertAlmostEquals(Vector(10, 0))
    a, b = Vector(0, 10), Vector(-5, 5)
    a:projection(b):assertAlmostEquals(Vector(0, 5))
    a:rejection(b):assertAlmostEquals(Vector(-5, 0))
end
os.exit(lu.LuaUnit.run())