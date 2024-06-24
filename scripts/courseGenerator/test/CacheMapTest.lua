require('include')
function testCacheMap()
    local c = cg.CacheMap()

    lu.assertNil(c:get(1))
    lu.assertEquals(c:getWithLambda(1, function () return 100 end), 100)
    lu.assertEquals(c:get(1), 100)
    lu.assertEquals(c:getWithLambda(1, function () return 200 end), 100)

    c = cg.CacheMap(2)
    lu.assertNil(c:get(1, 1))
    lu.assertEquals(c:getWithLambda(1, 1, function () return 100 end), 100)
    lu.assertEquals(c:get(1, 1), 100)
    lu.assertEquals(c:getWithLambda(1, 1, function () return 200 end), 100)
    lu.assertNil(c:get(2, 2))
    lu.assertEquals(c:getWithLambda(2, 2, function () return 200 end), 200)
    lu.assertEquals(c:get(2, 2), 200)
    lu.assertEquals(c:getWithLambda(2, 2, function () return 100 end), 200)
    lu.assertEquals(c:get(1, 1), 100)

    local key = {}
    c = cg.CacheMap(3)
    lu.assertNil(c:get('a', 1, key))
    lu.assertEquals(c:getWithLambda('a', 1, key, function () return 100 end), 100)
    lu.assertEquals(c:get('a', 1, key), 100)
    c:put('b', key, 100, 111)
    lu.assertEquals(c:get('b', key, 100), 111)

end
os.exit(lu.LuaUnit.run())