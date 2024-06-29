require('include')
lu.EPS = 0.01

---@param startCorner Vector
local function createBlock(pattern, id, nRows, startCorner)
    local block = CourseGenerator.Block(pattern, id)
    local row = CourseGenerator.Row(5, {startCorner, startCorner + Vector(200, 0)})
    for _ = 1, nRows do
        block:addRow(row)
        row = row:createNext(5)
    end
    return block
end

function testBlockSequence()
    local p = CourseGenerator.RowPatternAlternating()

    local b1 = createBlock(p, 1, 10, Vector(0, 1))
    local b2 = createBlock(p, 2, 9, Vector(0, 101))
    local b3 = createBlock(p, 3, 10, Vector(0, 201))

    lu.assertEquals(b1:getNumberOfRows(), 10)
    lu.assertEquals(b2:getNumberOfRows(), 9)
    lu.assertEquals(b3:getNumberOfRows(), 10)

    local startPosition = Vector(0, 0)

    local function calculateFitness(chromosome)
        local blocks, entries = chromosome:getBlockSequenceAndEntries()
        chromosome:setDistance((entries[blocks[1]].position - startPosition):length())
        for i = 1, #blocks - 1 do
            local currentBlock, nextBlock = blocks[i], blocks[i + 1]
            local exit = currentBlock:getExit(entries[currentBlock])
            chromosome:setDistance(chromosome:getDistance() + (exit - entries[nextBlock].position):length())
        end
        chromosome:setFitness(10000 / chromosome:getDistance())
    end

    -- Genetic algorithms do not guarantee the best result, therefore, we run a few
    -- different cases hundred times and check if 99% of the results give the minimum
    local blocksInSequence, entries, distance, bs

    -- entry point in the lower left corner
    startPosition = Vector(0, 0)

    local hits1 = 0
    for i = 1, 100 do -- entry point in the lower right corner
        bs = CourseGenerator.BlockSequencer({b3, b2, b1})
        blocksInSequence, entries, distance = bs:findBlockSequence(calculateFitness)
        if distance < 120 then
            hits1 = hits1 + 1
        end
    end
    lu.assertTrue(hits1 >= 99)

    startPosition = Vector(200, 0)

    local hits2 = 0
    for i = 1, 100 do -- entry point in the lower right corner
        bs = CourseGenerator.BlockSequencer({b3, b2, b1})
        blocksInSequence, entries, distance = bs:findBlockSequence(calculateFitness)
        if distance < 120 then
            hits2 = hits2 + 1
        end
    end
    lu.assertTrue(hits2 >= 99)

    -- somewhere in the middle on the left
    startPosition = Vector(0, 150)

    local hits3 = 0
    for i = 1, 100 do -- entry point in the lower right corner
        bs = CourseGenerator.BlockSequencer({b3, b2, b1})
        blocksInSequence, entries, distance = bs:findBlockSequence(calculateFitness)
        if distance < 220 then
            hits3 = hits3 + 1
        end
    end
    lu.assertTrue(hits3 >= 99)

    print(hits1, hits2, hits3)
end

os.exit(lu.LuaUnit.run())