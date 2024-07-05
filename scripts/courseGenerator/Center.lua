--- Generate the up/down rows covering the center part of the field,
--- within the headlands (or a virtual headland if there no headlands are needed, the
--- virtual headland half working width wider than the field, so the Center does not
--- have to know if this is a field boundary or a real headland)
--- Split the center area into blocks if needed and connect the headland with first block
--- and the blocks with each other
---@class Center
local Center = CpObject()

---@param context CourseGenerator.FieldworkContext
---@param boundary Polygon the field boundary
---@param headland CourseGenerator.Headland|nil the innermost headland if exists
---@param startLocation Vector location of the vehicle before it starts working on the center.
---@param bigIslands CourseGenerator.Island[] islands too big to circle
function Center:init(context, boundary, headland, startLocation, bigIslands)
    self.logger = Logger('Center', Logger.level.trace)
    self.context = context
    if headland == nil then
        -- if there are no headlands, we generate a virtual one, from the field boundary
        -- so using this later is equivalent of having an actual headland
        local virtualHeadland = CourseGenerator.FieldworkCourseHelper.createVirtualHeadland(boundary, self.context.headlandClockwise,
                self.context.workingWidth)
        if self.context.sharpenCorners then
            virtualHeadland:sharpenCorners(self.context.turningRadius)
        end
        self.headlandPolygon = virtualHeadland:getPolygon()
        CourseGenerator.addDebugPolyline(self.headlandPolygon, { 1, 1, 0, 0.5 })
        self.headland = virtualHeadland
        self.mayOverlapHeadland = false
    else
        self.headlandPolygon = headland:getPolygon()
        self.headland = headland
        self.mayOverlapHeadland = true
    end
    self.useBaselineEdge = self.context.useBaselineEdge
    self.boundary = boundary
    self.startLocation = startLocation
    self.bigIslands = bigIslands
    -- All the blocks we divided the center into
    self.blocks = {}
    -- For each block, there is a path leading to it either from the previous block or from the headland.
    -- The connecting path always has at least one vertex. A path with just one vertex can safely be skipped
    -- as that vertex overlaps with the first vertex of the block
    self.connectingPaths = {}
end

---@return Polyline
function Center:getPath()
    if not self.path then
        self.path = Polyline()
        for i = 1, #self.blocks do
            self.path:appendMany(self.connectingPaths[i])
            self.path:appendMany(self.blocks[i]:getPath())
        end
    end
    self.path:calculateProperties()
    return self.path
end

---@return CourseGenerator.Block[]
function Center:getBlocks()
    return self.blocks
end

--- The list of paths connecting the blocks of the field center. The first entry is
--- the path from the end of the headland to the first block, the second entry is the path
--- from the exit of the first block to the entry of the second, and so on.
--- There is always a connecting path for each block. The connecting path may be empty or have
--- just one vertex. An empty path or one with just one vertex can safely be skipped as that vertex
--- overlaps with the first vertex of the block
------@return Polyline[]
function Center:getConnectingPaths()
    return self.connectingPaths
end

--- Return the set of rows covering the entire field center, uncut. For debug purposes only.
---@return CourseGenerator.Row[]
function Center:getDebugRows()
    return self.rows
end

---@return Vertex the location of the last waypoint of the last row worked in the middle.
function Center:generate()
    -- first, we split the field into blocks. Simple convex fields have just one block only,
    -- but odd shaped, concave fields or fields with island may have more blocks
    if self.useBaselineEdge then
        self.rows = CourseGenerator.CurvedPathHelper.generateCurvedUpDownRows(self.headlandPolygon, self.context.baselineEdge,
                self.context.workingWidth, self.context.turningRadius, nil)
    else
        local angle = self.context.autoRowAngle and self:_findBestRowAngle() or self.context.rowAngle
        self.rows = self:_generateStraightUpDownRows(angle)
    end
    local blocks = self:_splitIntoBlocks(self.rows, self.headland)

    if #blocks < 1 then
        self.logger:debug('No blocks could be generated')
        return
    end

    -- now connect all blocks
    -- if there are more than one block, we need to figure out in what sequence those blocks
    -- should be worked on and where to enter each block, to minimize the idle driving on the
    -- headland from one block to the other

    -- clear cache for the block sequencer
    self.closestVertexCache, self.pathCache = CourseGenerator.CacheMap(2), CourseGenerator.CacheMap(3)

    -- first run of the genetic search will restrict connecting path between blocks to the same
    -- headland, that is, the entry to the next block must be adjacent to the headland where the
    -- exit of the previous block is.
    -- Sometimes there may be no solution (or the genetic algorithm can't deliver one, probably because
    -- of converging some other local minimum, no idea why), then we relax this constraint and allow
    -- connecting paths switching between headlands, just to deliver some solution. This solution may
    -- or may not work, but most likely won't be a pretty one.
    local strict = true

    ---@param sequencedBlocks CourseGenerator.Block[] an array of blocks in the sequence they should be worked on
    ---@param entries CourseGenerator.RowPattern.Entry[] entries for each block are in the entries table, indexed by
    --- the block itself
    ---@return number, Polyline[] total distance to travel on the headland (from the start location to the
    --- entry of the first block, then from the exit of the first block to the entry of the second block, etc.)
    --- The array of polylines represent the path on the headland, again, first element is the path to the entry
    --- of the first block, the second between the first and second block, and so on)
    local function calculateDistanceAndConnectingPaths(sequencedBlocks, entries)
        -- check if we can get from the start position to the first entry
        local firstEntry = entries[sequencedBlocks[1]].position
        local distance, path = 0, {}
        if firstEntry:getAttributes():_getAtHeadland() ~= self.headland then
            -- first entry not on headland, this isn't a valid entry
            return math.huge
        else
            -- entry is on the headland, now figure out the distance to travel on the headland
            -- from the start position to the entry
            local pathOnHeadland = self:_findShortestPathOnHeadland(self.headland, self.startLocation, firstEntry)
            distance = pathOnHeadland:getLength()
            table.insert(path, pathOnHeadland)
        end
        -- now we are ready to work on the blocks
        for i = 1, #sequencedBlocks - 1 do
            local currentBlock, nextBlock = sequencedBlocks[i], sequencedBlocks[i + 1]
            local exit = currentBlock:getExit(entries[currentBlock])
            local entryToNextBlock = entries[nextBlock].position
            local entryHeadland = entryToNextBlock:getAttributes():_getAtHeadland()
            if exit:getAttributes():_getAtHeadland() ~= entryHeadland then
                -- the entry to the next block is not on the same headland as the exit from the previous,
                -- this is an invalid solution
                if strict then
                    return math.huge
                else
                    distance = distance + 1000
                    table.insert(path, Polyline())
                end
            else
                local pathOnHeadland = self:_findShortestPathOnHeadland(entryHeadland, exit, entryToNextBlock)
                distance = distance + pathOnHeadland:getLength()
                table.insert(path, pathOnHeadland)
            end
        end
        return distance, path
    end

    local function calculateFitness(chromosome)
        local sequencedBlocks, entries = chromosome:getBlockSequenceAndEntries()
        local distance, _ = calculateDistanceAndConnectingPaths(sequencedBlocks, entries)
        chromosome:setDistance(distance)
        chromosome:setFitness(10000 / distance)
    end

    local blocksInSequence, entries, _ = CourseGenerator.BlockSequencer(blocks):findBlockSequence(calculateFitness)
    if blocksInSequence == nil then
        self.logger:warning('Could not find a valid path on headland between blocks, retry with allowing connections between different headland')
        strict = false
        blocksInSequence, entries, _ = CourseGenerator.BlockSequencer(blocks):findBlockSequence(calculateFitness)
    end
    _, self.connectingPaths = calculateDistanceAndConnectingPaths(blocksInSequence, entries)
    self.blocks = blocksInSequence
    local lastLocation = self.startLocation
    for _, b in ipairs(self.blocks) do
        lastLocation = b:finalize(entries[b])
    end
    self:_wrapUpConnectingPaths()
    self.logger:debug('Found %d block(s), %d connecting path(s).', #self.blocks, #self.connectingPaths)
    if not strict then
        self.context:addError('Could not find the shortest path on headland between blocks')
    end
    return lastLocation
end

--- We drive around small islands, making sure to drive a complete circle around them when the course first
--- crosses them.
---@param circle boolean when true, make a full circle on the other polygon, else just go around and continue
function Center:bypassSmallIsland(islandHeadlandPolygon, circle)
    local thisIslandCircled = circle
    -- first the up/down rows in each block ...
    for _, block in ipairs(self.blocks) do
        thisIslandCircled = block:bypassSmallIsland(islandHeadlandPolygon, not thisIslandCircled) or thisIslandCircled
    end
    -- and then we have those connecting paths between the blocks
    for _, connectingPath in ipairs(self.connectingPaths) do
        if #connectingPath > 1 then
            thisIslandCircled = CourseGenerator.FieldworkCourseHelper.bypassSmallIsland(connectingPath, self.context.workingWidth,
                    islandHeadlandPolygon, 1, not thisIslandCircled) or thisIslandCircled
        end
    end
end

--- Connecting paths should also drive around big islands
function Center:bypassBigIsland(islandHeadlandPolygon)
    for _, connectingPath in ipairs(self.connectingPaths) do
        if #connectingPath > 1 then
            CourseGenerator.FieldworkCourseHelper.bypassSmallIsland(connectingPath, self.context.workingWidth,
                    islandHeadlandPolygon, 1, false)
        end
    end
end

---------------------------------------------------------------------------------------------------------------------------
--- Private functions
------------------------------------------------------------------------------------------------------------------------
function Center:_generateStraightUpDownRows(rowAngle, suppressLog)
    local baseline = self:_createStraightBaseline(rowAngle)
    local _, dMin, _, dMax = self.headlandPolygon:findClosestAndFarthestVertexToLineSegment(baseline[1]:getExitEdge())

    -- make the best effort to have the row that overlaps the headland (or the last row when there is no headland)
    -- the last row we work on. This usually works for the alternating/skip pattern, no guarantee for other patterns.
    local startLocationDistance = baseline[1]:getExitEdge():getDistanceFrom(self.context.startLocation)
    local overlapLast = startLocationDistance < (dMin + dMax) / 2
    if self.mayOverlapHeadland and not self.context.headlandFirst then
        overlapLast = not overlapLast
    end
    -- move the baseline to the edge of the area we want to cover
    baseline = baseline:createNext(dMin)
    local rowOffsets = self:_calculateRowDistribution(
            self.context.workingWidth, dMax - dMin, self.context.evenRowDistribution, overlapLast)

    local rows = {}
    local row = baseline:createNext(rowOffsets[1])
    table.insert(rows, row)
    for i = 2, #rowOffsets do
        row = row:createNext(rowOffsets[i])
        table.insert(rows, row)
    end
    if not suppressLog then
        self.logger:debug('Created %d rows at %.0f° to cover an area %.1f wide, %.1f/%.1f m',
                #rowOffsets, math.deg(rowAngle), dMax - dMin, rowOffsets[1], rowOffsets[#rowOffsets] or 0)
        self.logger:debug('    even distribution %s, remainder last %s', self.context.evenRowDistribution, overlapLast)
        self.logger:debug('    dMin: %1.f, dMax: %.1f, startLocationDistance: %.1f', dMin, dMax, startLocationDistance)
    end
    return rows
end

function Center:_calculateSmallBlockPenalty(blocks, nTotalRows)
    local nResult = 0
    -- no penalty if there's only one block
    if #blocks == 1 then
        return nResult
    end
    for _, b in ipairs(blocks) do
        local percentageOfRowsInBlock = 100 * (b:getNumberOfRows() / nTotalRows)
        if percentageOfRowsInBlock < CourseGenerator.cSmallBlockRowPercentageLimit then
            nResult = nResult + CourseGenerator.cSmallBlockRowPercentageLimit - percentageOfRowsInBlock
        end
    end
    return nResult
end

function Center:_findBestRowAngle()
    local minScore, minRows, bestAngle = math.huge, math.huge, 0
    local longestEdgeDirection = self.headlandPolygon:getLongestEdgeDirection()
    self.logger:debug('  longest edge direction %.1f', math.deg(longestEdgeDirection))
    for a = -90, 90, 1 do
        local rows = self:_generateStraightUpDownRows(math.rad(a), true)
        local blocks = self:_splitIntoBlocks(rows, self.headland)
        local smallBlockPenalty = self:_calculateSmallBlockPenalty(blocks, #rows)
        -- Prefer angles closest to the direction of the longest edge of the field
        -- sin(a - longestEdgeDirection) will be 0 when angle is the closest.
        local notLongestEdgePenalty = 5 * math.abs(math.sin(CpMathUtil.getDeltaAngle(math.rad(a), longestEdgeDirection)))
        local score = 6 * #blocks + #rows + smallBlockPenalty + notLongestEdgePenalty
        self.logger:trace('  %dº - rows: %d blocks: %d small block penalty: %.1f not longest edge penalty: %.1f score: %.3f',
                a, #rows, #blocks, smallBlockPenalty, notLongestEdgePenalty, score)
        if score < minScore then
            minScore = score
            bestAngle = math.rad(a)
        end
    end
    self.logger:debug('  best row angle is %.1f', math.deg(bestAngle))
    return bestAngle
end

---@return CourseGenerator.Row
function Center:_createStraightBaseline(rowAngle)
    -- Set up a baseline. This goes through the lower left or right corner of the bounding box, at the requested
    -- angle, and long enough that when shifted (offset copies are created), will cover the field at any angle.
    local x1, y1, x2, y2 = self.headlandPolygon:getBoundingBox()
    -- add a little margin so all lines are a little longer than they should be, this way
    -- we guarantee that the first intersection with the boundary will always be well defined and won't
    -- fall exactly on the boundary.
    local margin = 1
    local w, h = x2 - x1 + margin, y2 - y1 + margin
    local baselineStart, baselineEnd
    if rowAngle >= 0 then
        local lowerLeft = Vector(x1 - margin / 2, y1 - margin / 2)
        baselineStart = lowerLeft - Vector(h * math.sin(rowAngle), 0):setHeading(-rowAngle)
        baselineEnd = lowerLeft + Vector(w * math.cos(rowAngle), 0):setHeading(-rowAngle)
    else
        local lowerRight = Vector(x2 + margin / 2, y1 - margin / 2)
        baselineStart = lowerRight - Vector(w * math.cos(rowAngle), 0):setHeading(-rowAngle)
        baselineEnd = lowerRight + Vector(h * math.sin(rowAngle), 0):setHeading(-rowAngle)
    end
    return CourseGenerator.Row(self.context.workingWidth, { baselineStart, baselineEnd })
end

--- Calculate how many rows we need with a given work width to fully cover a field and how far apart those
--- rows should be. Usually the field width can't be divided with the working width without remainder.
--- There are several ways to deal with the remainder:
---   1. reduce the width of each row so they all have the same width. This results in overlap in every row
---      and if multiple vehicles work with the same course they may collide anywhere
---   2. reduce the width of one row (the second or second last) only, others remain same as working width.
---      We must do this if there is no headland, as the very first and the very last row must be of working
---      width, in order to remain on the field. Can be combined with #1.
---   3. leave the width of all rows the same working width. Here, part of the first or last row will be
---      outside of the field (work width * number of rows > field width). We always do this if there is a headland,
---      as the remainder will overlap with the headland.
---@param workingWidth
---@param fieldWidth number distance between the headland centerlines we need to fill with rows. If there is no
--- headland, this is the distance between the virtual headland centerlines, which is half working width wider than
--- the actual field boundary.
---@param sameWidth boolean make all rows of the same width (#1 above)
---@param overlapLast boolean where should the overlapping row be in the sequence we create, true if at the end,
--- false at the beginning
---@return number, number, number, number number of rows, offset of first row from the field edge, offset of
--- rows from the previous row for the next rows, offset of last row from the next to last row.
function Center:_calculateRowDistribution(workingWidth, fieldWidth, sameWidth, overlapLast)
    local nRows = math.floor(fieldWidth / workingWidth)
    if nRows == 0 then
        -- only one row fits between the headlands
        if overlapLast then
            return { workingWidth / 2 }
        else
            return { fieldWidth - workingWidth / 2 }
        end
    else
        local width
        if sameWidth then
            -- #1
            width = (fieldWidth - workingWidth) / (nRows - 1)
        else
            -- #2 and #3
            width = workingWidth
        end
        local firstRowOffset
        local rowOffsets = {}
        if self.mayOverlapHeadland then
            -- #3 we have headlands
            if overlapLast then
                firstRowOffset = workingWidth
            else
                firstRowOffset = fieldWidth - (workingWidth + width * (nRows - 1))
            end
            rowOffsets = { firstRowOffset }
            for _ = firstRowOffset, fieldWidth, width do
                table.insert(rowOffsets, width)
            end
        else
            -- #2, no headlands
            for _ = workingWidth, fieldWidth - workingWidth, width do
                table.insert(rowOffsets, width)
            end
            if overlapLast then
                table.insert(rowOffsets, fieldWidth - (workingWidth + width * #rowOffsets))
            else
                rowOffsets[2] = fieldWidth - (workingWidth + width * #rowOffsets)
                table.insert(rowOffsets, width)
            end

        end
        return rowOffsets
    end
end

---@param rows CourseGenerator.Row[]
---@param headland CourseGenerator.Headland
function Center:_splitIntoBlocks(rows, headland)
    local blocks = {}
    local openBlocks = {}
    local function closeBlocks(rowNumber)
        local n = 0
        for block, lastRowNumber in pairs(openBlocks) do
            if rowNumber == nil or lastRowNumber ~= rowNumber then
                blocks = blocks or {}
                table.insert(blocks, block)
                openBlocks[block] = nil
                n = n + 1
            end
        end
        self.logger:trace('  closed %d blocks for row %s', n, rowNumber)
    end

    -- assign a unique id to each block
    local blockId = 1

    for i, row in ipairs(rows) do
        self.logger:trace('%s', row)
        local sections = row:split(headland, self.bigIslands, false, self.context.enableSmallOverlapsWithHeadland)
        self.logger:trace('Row %d has %d section(s)', i, #sections)
        -- first check if there is a block which overlaps with more than one section
        -- if that's the case, close the open blocks. This forces the creation of new blocks
        -- for these sections, to make sure that if there
        -- is an island or peninsula in the field, we do not end up with an L shaped block
        -- (the island being between the L's legs) so that 180º turns would go through the island.
        for block, _ in pairs(openBlocks) do
            local nSectionsOverlapThisBlock = 0
            for _, section in ipairs(sections) do
                if block:overlaps(section) then
                    nSectionsOverlapThisBlock = nSectionsOverlapThisBlock + 1
                end
            end
            if nSectionsOverlapThisBlock > 1 then
                self.logger:trace('%d sections overlap the same block, closing open blocks', nSectionsOverlapThisBlock)
                closeBlocks()
                break
            end
        end
        for j, section in ipairs(sections) do
            -- with how many existing blocks does this row overlap?
            local overlappedBlocks = {}
            for block, _ in pairs(openBlocks) do
                if block:overlaps(section) then
                    table.insert(overlappedBlocks, block)
                end
            end
            self.logger:trace('  %.1f m, %d vertices, overlaps with %d block(s)',
                    section:getLength(), #section, #overlappedBlocks)
            if #overlappedBlocks == 0 or #overlappedBlocks > 1 then
                local newBlock = CourseGenerator.Block(self.context.rowPattern, blockId)
                blockId = blockId + 1
                newBlock:addRow(section)
                -- remember that we added a section for row #i
                openBlocks[newBlock] = i
                self.logger:trace('  %d block(s) closed, opened a new one', #overlappedBlocks)
            else
                -- overlaps with exactly one block, add this row to the overlapped block
                overlappedBlocks[1]:addRow(section)
                -- remember that we added a section for row #i
                openBlocks[overlappedBlocks[1]] = i
            end
        end
        -- close all open blocks where we did not add a section of this row
        -- as we want all blocks to have a series of rows without gaps
        closeBlocks(i)
    end
    closeBlocks()
    return blocks
end

--- Find the shortest path on the headland between two positions (between the headland vertices
--- closest to v1 and v2).
--- This is used by the genetic algorithm and called thousands of times when the fitness of new
--- generations are calculated. As the population consists of the same blocks and same entry/exit
--- points (and thus, same paths), just in different order, we cache the entries/exits/paths for
--- a better performance.
---@param headland CourseGenerator.Headland
---@param v1 Vector
---@param v2 Vector
---@return Polyline always has at least one vertex
function Center:_findShortestPathOnHeadland(headland, v1, v2)
    local cv1 = self.closestVertexCache:getWithLambda(headland, v1,
            function()
                return headland:getPolygon():findClosestVertexToPoint(v1)
            end)
    local cv2 = self.closestVertexCache:getWithLambda(headland, v2,
            function()
                return headland:getPolygon():findClosestVertexToPoint(v2)
            end)
    return self.pathCache:getWithLambda(headland, v1, v2,
            function()
                return headland:getPolygon():getShortestPathBetween(cv1.ix, cv2.ix)
            end)
end

function Center:_wrapUpConnectingPaths()
    if self.context.nHeadlands == 0 then
        self.logger:debug('There is no headland, remove connecting path(s).')
        for i = 1, #self.blocks do
            -- instead of the connecting track use pathfinder to the entry of the next block
            self.connectingPaths[i] = {}
            self.blocks[i]:getEntryVertex():getAttributes():setUsePathfinderToThisWaypoint()
            self.blocks[i]:getExitVertex():getAttributes():setUsePathfinderToNextWaypoint()
        end
    else
        for _, c in ipairs(self.connectingPaths) do
            c:setAttribute(nil, CourseGenerator.WaypointAttributes.setOnConnectingPath)
            c:setAttribute(nil, CourseGenerator.WaypointAttributes.setHeadlandTurn, nil)
        end
    end
end

---@class CourseGenerator.Center
CourseGenerator.Center = Center