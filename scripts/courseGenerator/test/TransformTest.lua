require('include')
require('Vector')
require('Transform')

-- epsilon for assertAlmostEquals
lu.EPS = 0.01

---
--- Test the MockNode transformation functions
--- To validate these tests, just copy/paste it starting from here, into the Giants script editor and run it.
--- In the Giants editor, these calls are executed by the Giants engine and should deliver the same results.
---
function testTransform()
    local t = CourseGenerator.Transform('test')
    t:setTranslation(10, 11)
    local x, y = t:getWorldTranslation()
    lu.assertAlmostEquals(x, 10)
    lu.assertAlmostEquals(y, 11)

    x, y = t:localToWorld(0, 0)
    lu.assertAlmostEquals(x, 10)
    lu.assertAlmostEquals(y, 11)

    local dx, dy = t:worldToLocal(10, 11)
    lu.assertAlmostEquals(dx, 0)
    lu.assertAlmostEquals(dy, 0)

    x, y = t:localToWorld(0, 1)
    lu.assertAlmostEquals(x, 10)
    lu.assertAlmostEquals(y, 12)

    x, y = t:localToWorld(2, 0)
    lu.assertAlmostEquals(x, 12)
    lu.assertAlmostEquals(y, 11)

    dx, dy = t:worldToLocal(10, 12)
    lu.assertAlmostEquals(dx, 0)
    lu.assertAlmostEquals(dy, 1)

    dx, dy = t:worldToLocal(10, 10)
    lu.assertAlmostEquals(dx, 0)
    lu.assertAlmostEquals(dy, -1)

    dx, dy = t:worldToLocal(11, 10)
    lu.assertAlmostEquals(dx, 1)
    lu.assertAlmostEquals(dy, -1)

    x, y = t:localToWorld(1, 0)
    lu.assertAlmostEquals(x, 11)
    lu.assertAlmostEquals(y, 11)

    x, y = t:localToWorld(1, 1)
    lu.assertAlmostEquals(x, 11)
    lu.assertAlmostEquals(y, 12)

    t:setRotation(math.pi)
    x, y = t:getWorldTranslation()
    lu.assertAlmostEquals(x, 10)
    lu.assertAlmostEquals(y, 11)

    x, y = t:localToWorld(0, 1)
    lu.assertAlmostEquals(x, 10)
    lu.assertAlmostEquals(y, 10)

    t:setRotation(math.pi / 2)
    x, y = t:localToWorld(0, 1)
    lu.assertAlmostEquals(x, 9)
    lu.assertAlmostEquals(y, 11)

    t:setRotation(-math.pi / 2)
    x, y = t:localToWorld(0, 1)
    lu.assertAlmostEquals(x, 11)
    lu.assertAlmostEquals(y, 11)

    dx, dy = t:worldToLocal(9, 11)
    lu.assertAlmostEquals(dx, 0)
    lu.assertAlmostEquals(dy, -1)

    x, y = t:localToWorld(1, 1)
    lu.assertAlmostEquals(x, 11)
    lu.assertAlmostEquals(y, 10)

    local child = Transform('child', t)
    x, y = t:localToWorld(0, 0)
    lu.assertAlmostEquals(x, 10)
    lu.assertAlmostEquals(y, 11)

    x, y = child:localToWorld(1, 1)
    lu.assertAlmostEquals(x, 11)
    lu.assertAlmostEquals(y, 10)

    child:setTranslation(0, 1)
    x, y = child:getWorldTranslation()
    lu.assertAlmostEquals(x, 11)
    lu.assertAlmostEquals(y, 11)

    x, y = child:localToWorld(0, 0)
    lu.assertAlmostEquals(x, 11)
    lu.assertAlmostEquals(y, 11)

    x, y = child:localToWorld(1, 1)
    lu.assertAlmostEquals(x, 12)
    lu.assertAlmostEquals(y, 10)

    local grandChild = Transform('grandChild', child)
    x, y = grandChild:localToWorld(1, 1)
    lu.assertAlmostEquals(x, 12)
    lu.assertAlmostEquals(y, 10)

    grandChild:setTranslation(0, 1)
    x, y = grandChild:getWorldTranslation()
    lu.assertAlmostEquals(x, 12)
    lu.assertAlmostEquals(y, 11)
    x, y = grandChild:localToWorld(1, 1)
    lu.assertAlmostEquals(x, 13)
    lu.assertAlmostEquals(y, 10)

    grandChild:setRotation(math.pi / 2)
    x, y = grandChild:getWorldTranslation()
    lu.assertAlmostEquals(x, 12)
    lu.assertAlmostEquals(y, 11)

    x, y = grandChild:localToWorld(1, 1)
    lu.assertAlmostEquals(x, 13)
    lu.assertAlmostEquals(y, 12)
end
os.exit(lu.LuaUnit.run())