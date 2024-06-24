require('include')
function testWraparoundIndex()
    local t = { 1, 2, 3, 4, 5, 6 }

    local i = cg.WrapAroundIndex(t, 1)
    lu.assertEquals(i:get(), 1)
    i:set(7)
    lu.assertEquals(i:get(), 1)
    i:set(0)
    lu.assertEquals(i:get(), 6)
    i = i + 1
    lu.assertEquals(i:get(), 1)
    i = i - 1
    lu.assertEquals(i:get(), 6)
end
os.exit(lu.LuaUnit.run())