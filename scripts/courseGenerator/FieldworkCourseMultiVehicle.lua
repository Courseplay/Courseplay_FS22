--- A fieldwork course for multiple vehicles
--- Previously, these courses were generated just like any other course, only with a different working width.
--- The working width was simply the working width of a single vehicle multiplied by the number of vehicles.
--- Then, when the vehicle was started and its position in the group was known, the course for that vehicle was
--- calculated by offsetting the course by the working width of the vehicle times the position in the group.
---
--- We could still follow that approach but a lot of information will be lost when the offset courses are generated.
--- At that point, most of the semantics of the original course are lost and makes it difficult to restore, things
--- like headland/center transitions, connecting paths, etc.
---
--- The above approach works well for the center though, probably the only approach that works for any row pattern so
--- this class generates the center with the multi-vehicle working width, and then calculates the offset path for each
--- individual vehicle.
---
--- For the headlands though, it is better to generate them with the single working width and then pick and connect
--- the headlands for the individual vehicles.
---
--- The drawback of using different working widths for the headland and the center is that the headlands are used
--- to cut the rows at the end in the center. Also, headlands around the islands used to detect if a row has to
--- be routed around the island or not. Therefore, when cutting rows and bypassing islands, we must use a headland
--- with the combined working width for these to work correctly.
---
--- This currently may be a bit backwards as the multi-vehicle course is derived from the single vehicle course, but
--- in reality, it is probably the opposite: the single vehicle course is a special case of the multi-vehicle course.

---@class FieldworkCourseMultiVehicle : CourseGenerator.FieldworkCourse
local FieldworkCourseMultiVehicle = CpObject(CourseGenerator.FieldworkCourse)
--- nHeadlands: must be the total number of headlands (each of working width) around the field. So with nVehicles == 2,
--- nHeadlands == 4, each vehicle will work on 2 headlands. We'll round it up to the multiple of nVehicles.
--- workingWidth: this is the actual working width of a single vehicle.
---
---@param context CourseGenerator.FieldworkContext
function FieldworkCourseMultiVehicle:init(context)
    self.logger = Logger('FieldworkCourseMultiVehicle', Logger.level.debug)

    context:setCenterRowSpacing(context.workingWidth * context.nVehicles)
    context:setCenterRowWidthForAdjustment(context.workingWidth * context.nVehicles)

    if context.nHeadlands % context.nVehicles ~= 0 then
        local origHeadlands = context.nHeadlands
        if context.nHeadlands < context.nVehicles then
            context:setHeadlands(context.nVehicles)
            context:setIslandHeadlands(context.nVehicles)
        else
            local nHeadlands = math.ceil(context.nHeadlands / context.nVehicles) * context.nVehicles
            context:setHeadlands(nHeadlands)
            context:setIslandHeadlands(nHeadlands)
        end
        self.logger:debug('Number of headlands (%d) adjusted to %d, be a multiple of the number of vehicles (%d)',
                origHeadlands, context.nHeadlands, context.nVehicles)
    end

    self:_setContext(context)
    -- these are 2D arrays, since we have everything for each vehicle, therefore, first index is the vehicle
    self.paths = {}
    self.headlandPaths = {}
    self.centerPaths = {}
    self.circledBigIslands = {}

    self.circledIslands = {}
    self.headlandCache = CourseGenerator.CacheMap()

    self.logger:debug('### Generating headlands around the field perimeter ###')
    self:generateHeadlands()
    self:_setupHeadlandsForVehicles()

    self.logger:debug('### Setting up islands ###')
    self:setupAndSortIslands()
    self:_setupIslandHeadlandsForVehicles()

    if self.context.bypassIslands then
        self:routeHeadlandsAroundBigIslands()
    end

    if self.context.headlandFirst then
        -- connect the headlands first as the center needs to start where the headlands finish
        self.logger:debug('### Connecting headlands (%d) from the outside towards the inside ###', #self.headlands)
        for v = 1, self.context.nVehicles do
            -- create a headland path for each vehicle
            self.headlandPaths[v] = CourseGenerator.HeadlandConnector.connectHeadlandsFromOutside(self.headlandsForVehicle[v],
            -- TODO is this really the headland working width? Not the combined width?
                    self.context.startLocation, self.context:getHeadlandWorkingWidth(), self.context.turningRadius)
            self:routeHeadlandsAroundSmallIslands(self.headlandPaths[v])
        end
        self.logger:debug('### Generating up/down rows ###')
        self:generateCenter()
    else
        -- here, make the center first as we want to start on the headlands where the center was finished
        self.logger:debug('### Generating up/down rows ###')
        local endOfLastRow = self:generateCenter()
        self.logger:debug('### Connecting headlands (%d) from the inside towards the outside ###', #self.headlands)
        for v = 1, self.context.nVehicles do
            -- create a headland path for each vehicle
            self.headlandPaths[v] = CourseGenerator.HeadlandConnector.connectHeadlandsFromInside(self.headlandsForVehicle[v],
            -- TODO is this really the headland working width? Not the combined width?
                    endOfLastRow, self.context:getHeadlandWorkingWidth(), self.context.turningRadius)
            self:routeHeadlandsAroundSmallIslands(self.headlandPaths[v])
        end
    end

    if self.context.bypassIslands then
        self:bypassSmallIslandsInCenter()
    end

    self:_generateCenterForAllVehicles()

    if self.context.bypassIslands then
        self.logger:debug('### Bypassing big islands in the center: create path around them ###')
        for i, _, path in self:pathIterator() do
            -- this will modify the path in place
            self:circleBigIslands(path, i)
        end
    end
end

---@return Polyline
function FieldworkCourseMultiVehicle:getHeadlandPath(position)
    local headlandIx = self:_positionToHeadlandIndex(position, self.context.headlandClockwise)
    self.logger:debug('Getting headland %d for position %d', headlandIx, position)
    return self.headlandPaths[headlandIx]
end

--- Get the center path for a given vehicle in the group.
---@return Polyline
function FieldworkCourseMultiVehicle:getCenterPath(position)
    local centerIx = self:_positionToIndex(position)
    self.logger:debug('Getting center path %d for position %d', centerIx, position)
    return self.center and self.centerPaths[centerIx] or Polyline()
end

--- Returns a continuous Polyline covering the entire field. This is the
--- path a vehicle would follow to complete work on the field.
--- The vertices of the path contain WaypointAttributes which provide additional navigation information
--- for the vehicle.
---@param position number an integer defining the position of this vehicle within the group
---@return Polyline[]
function FieldworkCourseMultiVehicle:getPath(position)
    position = position or 1
    if not self.paths[position] then
        self.paths[position] = Polyline()
        if self.context.headlandFirst then
            self.paths[position]:appendMany(self:getHeadlandPath(position))
            self.paths[position]:appendMany(self:getCenterPath(position))
        else
            self.paths[position]:appendMany(self:getCenterPath(position))
            self.paths[position]:appendMany(self:getHeadlandPath(position))
        end
        self.paths[position]:calculateProperties()
    end
    return self.paths[position]
end

--- Iterates through the paths of all vehicles of the multi-vehicle group.
---@return number, number, Polyline[] index, position and path for each vehicle
function FieldworkCourseMultiVehicle:pathIterator()
    local last = math.floor(self.context.nVehicles / 2)
    local position = -last - 1
    local i = 0
    return function()
        if position < last then
            if position == -1 and self.context.nVehicles % 2 == 0 then
                -- with even number of vehicles there is no 0 position, so skip that
                position = position + 2
            else
                position = position + 1
            end
            i = i + 1
            return i, position, self:getPath(position)
        end
    end
end

--- Get the index of the headland for a given vehicle in the group.
---@param position number an integer defining the position of this vehicle within the group
---@param clockwise boolean are the headlands clockwise?
---@return CourseGenerator.Headland[]
function FieldworkCourseMultiVehicle:_positionToHeadlandIndex(position, clockwise)
    if not clockwise then
        -- when going clockwise, headland 1 is the outermost, and the leftmost. When going counter-clockwise, headland 1
        -- is the innermost, and the rightmost. So we need to reverse the position
        position = -position
    end
    return self:_positionToIndex(position)
end

--- We generate a course for each vehicle in the group and place the courses in an array (there is a separate array for
--- headland parts and for center parts). This function maps the position notation from the game to an index in those
--- arrays.
---@param position number an integer defining the position of this vehicle within the group, negative numbers are to
--- the left, positives to the right. For example, a -2 means that this is the second vehicle to the left (and thus,
--- there are at least 4 vehicles in the group), a 0 means the vehicle in the middle (for groups with odd number of
--- vehicles)
---@return number index of the course for the given position
function FieldworkCourseMultiVehicle:_positionToIndex(position)
    if self.context.nVehicles % 2 == 0 then
        -- even number of vehicles, there is no 0 position
        if position < 0 then
            return position + self.context.nVehicles / 2 + 1
        else
            return position + self.context.nVehicles / 2
        end
    else
        return position + math.floor(self.context.nVehicles / 2) + 1
    end
end

--- Calculate the offset vector to be used to generate the rows for a vehicle in the group.
---@return Vector
function FieldworkCourseMultiVehicle:_indexToOffsetVector(ix)
    local totalWidth = self.context.workingWidth * self.context.nVehicles
    local leftmostVehicleOffset = totalWidth / 2 - self.context.workingWidth / 2
    return Vector(0, leftmostVehicleOffset - (ix - 1) * self.context.workingWidth)
end

--- Pick the headlands each vehicle will need to work on.
---@return CourseGenerator.Headland[]
function FieldworkCourseMultiVehicle:_setupHeadlandsForVehicles()
    -- array of headlands for each vehicle, indexed by the vehicle index (1 .. nVehicles)
    self.headlandsForVehicle = {}
    for v = 1, self.context.nVehicles do
        self.headlandsForVehicle[v] = {}
        for i = v, self.nHeadlands, self.context.nVehicles do
            table.insert(self.headlandsForVehicle[v], self.headlands[i])
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Up/down rows
------------------------------------------------------------------------------------------------------------------------
function FieldworkCourseMultiVehicle:generateCenter()
    -- if there are no headlands, or there are, but we start working in the middle, then use the
    -- designated start location, otherwise the point where the innermost headland ends.
    if #self.headlands == 0 then
        self.center = CourseGenerator.Center(self.context, self.boundary, nil, self.context.startLocation, self.bigIslands)
    else
        -- The center is generated with the combined width of all vehicles and it assumes that the headland
        -- is of the same width. This is however not the case, since we generate the headlands with the single
        -- working width. We need a boundary for the center which is the same as the innermost headland would be
        -- if it had been generated with the combined width.
        local centerBoundary
        local referenceHeadland = self.headlands[#self.headlands - math.floor(self.context.nVehicles / 2)]
        -- But for the row length adjustment for angled headlands, we need to calculate with the combined working width.
        self.context:setHeadlandWidthForAdjustment(self.context.nVehicles * self.context.workingWidth)
        if self.context.nVehicles % 2 ~= 0 then
            -- odd number of vehicles, we already have that headland
            centerBoundary = referenceHeadland
        else
            centerBoundary = CourseGenerator.Headland(referenceHeadland:getPolygon(), self.context.headlandClockwise,
                    #self.headlands - 1, self.context:getHeadlandWorkingWidth() / 2, false)
        end
        CourseGenerator.addDebugPolyline(centerBoundary:getPolygon())
        local innerMostHeadlandPolygon = self.headlands[#self.headlands]:getPolygon()
        self.center = CourseGenerator.Center(self.context, self.boundary, centerBoundary,
                self.context.headlandFirst and
                        innerMostHeadlandPolygon[#innerMostHeadlandPolygon] or
                        self.context.startLocation,
                self.bigIslands)
    end
    return self.center:generate()
end

function FieldworkCourseMultiVehicle:bypassSmallIslandsInCenter()
    self.logger:debug('### Bypassing small islands in the center ###')
    for _, island in pairs(self.smallIslands) do
        self.logger:debug('Bypassing small island %d on the center', island:getId())
        -- just like when adjusting row lengths, we need here a headland with the combined working width so
        -- we can reliably detect if a row has to be routed around the island or not
        local offset = self.context.nVehicles * self.context.workingWidth / 2 - self.context.workingWidth / 2
        local referenceHeadland = CourseGenerator.Headland(island:getInnermostHeadland():getPolygon(),
                self.context.islandHeadlandClockwise, 1, offset, true)
        CourseGenerator.addDebugPolyline(referenceHeadland:getPolygon())
        self.center:bypassSmallIsland(referenceHeadland:getPolygon(), not self.circledIslands[island])
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Helper functions for circleBigIsland(), to override in derived classes, like in FieldworkCourseMultiVehicle
--- where the logic of getting the headlands is different.
function FieldworkCourseMultiVehicle:getIslandHeadlands(island, vehicle)
    return self.islandHeadlandsForVehicle[vehicle][island]
end

--- Here we only have one vehicle, so we only need to circle an island once and ignore the vehicle.
function FieldworkCourseMultiVehicle:isBigIslandCircled(island, vehicle)
    return self.circledBigIslands[vehicle][island]
end

function FieldworkCourseMultiVehicle:setBigIslandCircled(island, vehicle)
    self.circledBigIslands[vehicle][island] = true
end

--- Set up everything needed to circle the big islands.
---@return CourseGenerator.Headland[]
function FieldworkCourseMultiVehicle:_setupIslandHeadlandsForVehicles()
    self.islandHeadlandsForVehicle = {}
    for v = 1, self.context.nVehicles do
        -- two dimensional array of island headlands for each vehicle and island,
        -- indexed by the vehicle index (1 .. nVehicles) and by the island
        self.islandHeadlandsForVehicle[v] = {}
        -- two dimensional array indexed by the vehicle index and with the island. If the entry exists,
        -- this vehicle circled the island
        self.circledBigIslands[v] = {}
        for _, island in pairs(self.bigIslands) do
            self.islandHeadlandsForVehicle[v][island] = {}
            for i = v, #island:getHeadlands(), self.context.nVehicles do
                table.insert(self.islandHeadlandsForVehicle[v][island], island:getHeadlands()[i])
            end
        end
    end
end
------------------------------------------------------------------------------------------------------------------------
--- Generate the center path for all vehicles in the group, by offsetting the single, multi-vehicle center path.
function FieldworkCourseMultiVehicle:_generateCenterForAllVehicles()
    self.logger:debug('### Generating center for all vehicles ###')
    for v = 1, self.context.nVehicles do
        local offsetPath = Polyline()
        local offsetVector = self:_indexToOffsetVector(v)
        local rowOffsetVector = offsetVector:clone()
        self.logger:debug('  Generating center for vehicle %d, offset %.1f', v, offsetVector.y)
        local i, path = 1, self.center:getPath()
        repeat
            local wp = path[i]
            if wp:getAttributes():isRowStart() then
                if self.context.useSameTurnWidth then
                    -- at each turn, vehicles shift positions, so the turn width is the same for all vehicles
                    rowOffsetVector = -rowOffsetVector
                end
                i = self:_offsetRow(path, i, rowOffsetVector, offsetPath)
            elseif wp:getAttributes():isOnConnectingPath() then
                i = self:_offsetConnectingPath(path, i, offsetVector, offsetPath)
            else
                offsetPath:append(wp:clone())
                i = i + 1
            end
        until i > #path
        self.centerPaths[v] = offsetPath
        self.centerPaths[v]:calculateProperties()
        self.logger:debug('  path for vehicle %d with %d waypoints generated', v, #self.centerPaths[v])
    end
end

--- Generate offset of a section
---@param polyline Polyline the original path
---@param offsetVector Vector offset vector, the direction and length of the offset (left: y > 0, right: y < 0)
local function _generateOffsetSection(polyline, offsetVector)
    local offsetUnitVector = offsetVector / offsetVector:length()
    return CourseGenerator.Offset.generate(polyline, offsetUnitVector, offsetVector:length())
end

--- Append a newly generated offset section to the offset path, copying the attributes from the original section.
--- Preserve the attributes from first and last original waypoint, since they are likely special, such as a row
--- start or end.
---@param original Polyline the original path
---@param offset Polyline the offset path
---@param offsetPath Polyline the path to append the offset path to
local function _appendOffsetSection(original, offset, offsetPath)
    -- copy the attributes of the first vertex
    offset[1]:setAttributes(original[1]:getAttributes())
    offsetPath:append(offset[1])
    -- copy the attributes of the last vertex
    offset[#offset]:setAttributes(original[#original]:getAttributes())
    for j = 2, #offset - 1 do
        -- attributes in between
        offset[j]:setAttributes(original[2]:getAttributes())
        offsetPath:append(offset[j])
    end
    offsetPath:append(offset[#offset])
end

--- Find and offset a row, starting at ix in the path.
---@param path Polyline the original path
---@param ix number start of the section in path to offset
---@param offsetVector Vector the vector to offset the path
---@param offsetPath Polyline the path to append the offset path to
---@return number index of the next waypoint after the row end
function FieldworkCourseMultiVehicle:_offsetRow(path, ix, offsetVector, offsetPath)
    -- extract the row to a polyline
    local i, row = ix, Polyline()
    repeat
        row:append(path[i])
        i = i + 1
    until i > #path or path[i]:getAttributes():isRowEnd()
    row:append(path[i])
    local offsetRow = _generateOffsetSection(row, offsetVector)
    _appendOffsetSection(row, offsetRow, offsetPath)
    return i + 1
end

--- Find and offset a connecting path, starting at ix in the path. This is very similar
---@param path Polyline the original path
---@param ix number start of the section in path to offset
---@param offsetVector Vector the vector to offset the path
---@param offsetPath Polyline the path to append the offset path to
---@return number index of the next waypoint after the row end
function FieldworkCourseMultiVehicle:_offsetConnectingPath(path, ix, offsetVector, offsetPath)
    -- extract the row to a polyline
    local i, section = ix, Polyline()
    repeat
        section:append(path[i])
        i = i + 1
    until i > #path or not path[i]:getAttributes():isOnConnectingPath()
    local offsetConnectingPath = _generateOffsetSection(section, offsetVector)
    _appendOffsetSection(section, offsetConnectingPath, offsetPath)
    return i
end

function FieldworkCourseMultiVehicle:__tostring()
    local str = string.format('Vehicles: %d', self.context.nVehicles)
    for _, position, path in self:pathIterator() do
        str = str .. string.format(', position %d: %d waypoints', position, #path)
    end
    return str
end


---@class CourseGenerator.FieldworkCourseMultiVehicle : CourseGenerator.FieldworkCourse
CourseGenerator.FieldworkCourseMultiVehicle = FieldworkCourseMultiVehicle