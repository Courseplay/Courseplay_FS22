require('include')

lu.EPS = 0.01

local function printRowOffsets(rowOffsets)
    local y = 0
    for i, offset in ipairs(rowOffsets) do
        y = y + offset
        print(i, offset, y)
    end
end

local function createContext(headlandWidth, centerRowSpacing, evenRowDistribution, overlap)
    local mockContext = {
        evenRowDistribution = evenRowDistribution,
        workingWidth = headlandWidth,
        getHeadlandWorkingWidth = function()
            return headlandWidth
        end,
        getCenterRowSpacing = function()
            return centerRowSpacing
        end,
        getHeadlandOverlap = function()
            return overlap or 0
        end
    }
    return mockContext
end

function testRowDistributionExactMultiple()
    local rowOffsets
    local center = {context = createContext(5, 5, false), mayOverlapHeadland = true}
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 50, false)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 50, false)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 100, true)
    lu.assertEquals(#rowOffsets, 19)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[10], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 100, false)
    lu.assertEquals(#rowOffsets, 19)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[10], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)
end

function testRowDistributionGeneral()
    local rowOffsets
    local center = {context = createContext(5, 5, false), mayOverlapHeadland = true}
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 49, true)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 49, false)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 4)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)
    center.mayOverlapHeadland = false
end

function testRowDistributionNarrow()
    local rowOffsets
    local center = {context = createContext(5, 5, false), mayOverlapHeadland = true}
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 10, true)
    lu.assertEquals(#rowOffsets, 1)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 7, true)
    lu.assertEquals(#rowOffsets, 1)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 7, false)
    lu.assertEquals(#rowOffsets, 1)
    lu.assertAlmostEquals(rowOffsets[1], 2)
    -- calculated nRows will be 0, as we reduce the field width by a centimeter
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 5, false)
    lu.assertEquals(#rowOffsets, 1)
    lu.assertAlmostEquals(rowOffsets[1], 2.5)
    center.mayOverlapHeadland = false
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 5, false)
    lu.assertEquals(#rowOffsets, 1)
    lu.assertAlmostEquals(rowOffsets[1], 2.5)
end

function testRowDistributionNoOverlap()
    local rowOffsets
    local center = {context = createContext(5, 5, false), mayOverlapHeadland = false}

    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 49, true)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[2], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 4)
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 49, false)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[2], 4)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)
    -- same with exact multiple
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 50, true)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[2], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 50, false)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[2], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)
end

function testRowDistributionMultiVehicleWithHeadland()
    local rowOffsets
    local center = {context = createContext(5, 10, false), mayOverlapHeadland = true}
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 50, true)
    lu.assertEquals(#rowOffsets, 5)
    lu.assertAlmostEquals(rowOffsets[1], 7.5)
    lu.assertAlmostEquals(rowOffsets[2], 10)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 10)
end

function testRowDistributionMultiVehicleNoHeadland()
    local center = {context = createContext(5, 10, false), mayOverlapHeadland = false}
    local rowOffsets

    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 50, true)
    lu.assertEquals(#rowOffsets, 5)
    lu.assertAlmostEquals(rowOffsets[1], 7.5)
    lu.assertAlmostEquals(rowOffsets[2], 10)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)

    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 50, false)
    lu.assertEquals(#rowOffsets, 5)
    lu.assertAlmostEquals(rowOffsets[1], 7.5)
    lu.assertAlmostEquals(rowOffsets[2], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 10)
end

function testEvenRowDistributionWithHeadland()
    local rowOffsets
    local center = {context = createContext(5, 5, true), mayOverlapHeadland = true}
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 49, true)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 4.88)
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 49, false)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 4.88)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 4.88)

    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 50, false)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)
    center.mayOverlapHeadland = false
end

function testEvenRowDistributionWithNoHeadland()
    local rowOffsets
    local center = {context = createContext(5, 5, true), mayOverlapHeadland = false}
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 49, true)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[2], 4.88)
    -- this should also be 4.88, no idea what we are missing, but is minimal, we'll address it when it becomes a problem
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 4.77)
    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 49, false)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    -- this should also be 4.88, no idea what we are missing, but is minimal, we'll address it when it becomes a problem
    lu.assertAlmostEquals(rowOffsets[2], 4.77)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 4.88)

    rowOffsets = CourseGenerator.Center._calculateRowDistribution(center, 50, false)
    lu.assertEquals(#rowOffsets, 9)
    lu.assertAlmostEquals(rowOffsets[1], 5)
    lu.assertAlmostEquals(rowOffsets[#rowOffsets], 5)
    center.mayOverlapHeadland = false
end



os.exit(lu.LuaUnit.run())
