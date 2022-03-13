lu = require("luaunit")
package.path = package.path .. ";../?.lua;../courseGenerator/?.lua;../pathfinder/?.lua"
require('CpObject')
require('geo')
require('State3D')
require('AnalyticSolution')

local function p(x, y)
    return {x = x, y = y}
end

local function assertPointsEqual(a, b)
    lu.assertEquals(#a, #b)
    for i = 1, #a do
        lu.assertEquals(a[i].x, b[i].x, string.format('at index %d', i))
        lu.assertEquals(a[i].y, b[i].y, string.format('at index %d', i))
    end
end

local vertices = {
    p(10, 0),
    p(15, 0),
    p(20, 0),
    p(20, 5),
    p(20, 10),
    p(20, 15),
    p(20, 20),
    p(15, 20),
    p(10, 20),
    p(5, 20),
    p(0, 20),
    p(0, 15),
    p(0, 10),
    p(0, 5),
    p(0, 0),
    p(5, 0),
    -- overlap with the first few waypoints to simulate a connecting track on the headland
    p(10, 0),
    -- not exactly the same coordinates as it could be a calculated offset course
    p(15.01, 0),
    p(20, 0),
    p(20, 5),
}

local headland = Polygon:new(vertices)

local s = headland:getSectionBetweenPoints(State3D(11, 0, 0), State3D(12, 0, 0))
assertPointsEqual(s, {p(10, 0)})
s = headland:getSectionBetweenPoints(State3D(12, 0, 0), State3D(11, 0, 0))
assertPointsEqual(s, {p(10, 0)})

s = headland:getSectionBetweenPoints(State3D(12, 0, 0), State3D(9, 0, 0))
assertPointsEqual(s, {p(10, 0)})
s = headland:getSectionBetweenPoints(State3D(9, 0, 0), State3D(12, 0, 0))
assertPointsEqual(s, {p(10, 0)})

-- offset course test
s = headland:getSectionBetweenPoints(State3D(9, 0, 0), State3D(17, 0, 0), 0.1)
assertPointsEqual(s, {p(10, 0), p(15, 0)})
s = headland:getSectionBetweenPoints(State3D(17, 0, 0), State3D(9, 0, 0), 0.1)
assertPointsEqual(s, {p(15, 0), p(10, 0)})

s = headland:getSectionBetweenPoints(State3D(8, 0, 0), State3D(9, 0, 0))
assertPointsEqual(s, {p(10, 0)})
s = headland:getSectionBetweenPoints(State3D(9, 0, 0), State3D(8, 0, 0))
assertPointsEqual(s, {p(10, 0)})

s = headland:getSectionBetweenPoints(State3D(8, 1, 0), State3D(9, 2, 0))
assertPointsEqual(s, {p(10, 0)})

s = headland:getSectionBetweenPoints(State3D(19, 0, 0), State3D(20, 6, 0))
assertPointsEqual(s, {p(20, 0), p(20, 5)})

-- another offset with overlap test
s = headland:getSectionBetweenPoints(State3D(20, 11, 0), State3D(16, 0, 0), 0.1)
assertPointsEqual(s, {p(20, 10), p(20, 5), p(20, 0), p(15, 0)})

-- another offset with overlap test
s = headland:getSectionBetweenPoints(
        State3D(16, 0, 0),
        State3D(20, 11, 0),
        0.1
)
assertPointsEqual(s, {
    p(15, 0),
    p(20, 0),
    p(20, 5),
    p(20, 10),
})
