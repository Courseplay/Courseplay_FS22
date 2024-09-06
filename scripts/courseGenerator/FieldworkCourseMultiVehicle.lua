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
--- The above approach works well for the center, probably the only approach that works for any row pattern so this
--- course will generate the center with the multi-vehicle working width, and provides methods to calculate the
--- center part for the individual vehicles.
---
--- For the headlands though, it is better to generate them with the single working width and then pick and connect
--- the headlands for the individual vehicles.

---@class FieldworkCourseMultiVehicle : CourseGenerator.FieldworkCourse
local FieldworkCourseMultiVehicle = CpObject(CourseGenerator.FieldworkCourse)

---@param context CourseGenerator.FieldworkContext
function FieldworkCourseMultiVehicle:init(context)
    self.logger = Logger('FieldworkCourseMultiVehicle', Logger.level.debug)

    context:setCenterRowSpacing(context.workingWidth * context.nVehicles)
    context:setCenterRowWidthForAdjustment(context.workingWidth * context.nVehicles)

    if context.nHeadlands % context.nVehicles ~= 0 then
        local nHeadlands = context.nHeadlands
        if context.nHeadlands < context.nVehicles then
            context:setHeadlands(context.nVehicles)
        else
            context:setHeadlands(math.ceil(context.nHeadlands / context.nVehicles) * context.nVehicles)
        end
        self.logger:debug('Number of headlands (%d) adjusted to %d, be a multiple of the number of vehicles (%d)',
                nHeadlands, context.nHeadlands, context.nVehicles)
    end

    self:_setContext(context)
    self.headlandPaths = {}
    self.circledIslands = {}
    self.headlandCache = CourseGenerator.CacheMap()

    self.logger:debug('### Generating headlands around the field perimeter ###')
    self:generateHeadlands()

    -- array of headlands for one vehicle, indexed by the vehicle index (1 - nVehicles)
    self.headlandsForVehicle = {}
    for v = 1, self.context.nVehicles do
        self:setupHeadlandsForVehicle(v)
    end

    self.logger:debug('### Setting up islands ###')
    self:setupAndSortIslands()

    if self.context.bypassIslands then
        self:routeHeadlandsAroundBigIslands()
    end

    if self.context.headlandFirst then
        -- connect the headlands first as the center needs to start where the headlands finish
        self.logger:debug('### Connecting headlands (%d) from the outside towards the inside ###', #self.headlands)
        for v = 1, self.context.nVehicles do
            -- create a headland path for each vehicle
            self.headlandPaths[v] = CourseGenerator.HeadlandConnector.connectHeadlandsFromOutside(self.headlandsForVehicle[v],
                    self.context.startLocation, self.context:getHeadlandWorkingWidth(), self.context.turningRadius)
        end
        self:routeHeadlandsAroundSmallIslands()
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
                    endOfLastRow, self.context:getHeadlandWorkingWidth(), self.context.turningRadius)
        end
        self:routeHeadlandsAroundSmallIslands()
    end

    self:_generateCenterForAllVehicles()
    if self.context.bypassIslands then
        self:bypassSmallIslandsInCenter()
        self.logger:debug('### Bypassing big islands in the center: create path around them ###')
        self:circleBigIslands()
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
--- path a vehicle (the one defined in context.positionInGroup) would follow to complete work on the field.
--- The vertices of the path contain WaypointAttributes which provide additional navigation information
--- for the vehicle.
---@return Polyline
function FieldworkCourseMultiVehicle:getPath()
    if not self.path then
        self.path = Polyline()
        if self.context.headlandFirst then
            self.path:appendMany(self:getHeadlandPath(self.context.positionInGroup))
            self.path:appendMany(self:getCenterPath(self.context.positionInGroup))
        else
            self.path:appendMany(self:getCenterPath(self.context.positionInGroup))
            self.path:appendMany(self:getHeadlandPath(self.context.positionInGroup))
        end
        self.path:calculateProperties()
    end
    return self.path
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

--- Pick the headlands this vehicle will need to work on.
---@param v number index of the vehicle in the group
---@return CourseGenerator.Headland[]
function FieldworkCourseMultiVehicle:setupHeadlandsForVehicle(v)
    self.headlandsForVehicle[v] = {}
    for i = v, self.nHeadlands, self.context.nVehicles do
        table.insert(self.headlandsForVehicle[v], self.headlands[i])
    end
end

--- Generate the center path for all vehicles in the group, by offsetting the single, multi-vehicle center path.
function FieldworkCourseMultiVehicle:_generateCenterForAllVehicles()
    self.logger:debug('### Generating center for all vehicles ###')
    self.centerPaths = {}
    for v = 1, self.context.nVehicles do
        local centerPath = Polyline()
        local offsetVector = self:_indexToOffsetVector(v)
        for _, wp in ipairs(self.center:getPath()) do
            local newWp, offsetEdge = wp:clone()
            if wp:getAttributes():isRowEnd() then
                offsetEdge = wp:getEntryEdge():clone():offset(offsetVector.x, offsetVector.y)
                newWp:set(offsetEdge:getEnd().x, offsetEdge:getEnd().y, wp.ix)
            else
                offsetEdge = wp:getExitEdge():clone():offset(offsetVector.x, offsetVector.y)
                newWp:set(offsetEdge:getBase().x, offsetEdge:getBase().y, wp.ix)
            end
            centerPath:append(newWp)
        end
        self.centerPaths[v] = self:_regenerateConnectingPaths(centerPath, self.headlandsForVehicle[v][#self.headlandsForVehicle[v]])
        --self.centerPaths[v] = centerPath
        self.centerPaths[v]:calculateProperties()
    end
end

--- Connecting paths were generated for the single-vehicle center course with the multi-vehicle working width.
--- They
function FieldworkCourseMultiVehicle:_regenerateConnectingPaths(path, innermostHeadlandForVehicle)
    local fixedPath = Polyline()
    local i, firstVertexOfConnectingPath = 1, nil
    repeat
        -- always know on which headland we are
        if path[i]:getAttributes():isOnConnectingPath() then
            if not firstVertexOfConnectingPath then
                self.logger:debug('Found a connecting path at %d', i)
                firstVertexOfConnectingPath = path[i - 1] or path[i]
            end
            i = i + 1
        else
            if firstVertexOfConnectingPath then
                self.logger:debug('Connecting path ended at %d, regenerating on headland %s', i, tostring(path[i]:getAttributes():getHeadlandPassNumber()))
                local connectingPath = self:_findShortestPathOnHeadland(innermostHeadlandForVehicle,
                        firstVertexOfConnectingPath, path[i])
                -- TODO: add attributes
                firstVertexOfConnectingPath = nil
                for _, v in ipairs(connectingPath) do
                    fixedPath:append(v)
                end
            else
                fixedPath:append(path[i])
                i = i + 1
            end
        end
    until i >= #path
    return fixedPath
end

function FieldworkCourseMultiVehicle:_findShortestPathOnHeadland(headland, v1, v2)
    local cv1 = headland:getPolygon():findClosestVertexToPoint(v1)
    local cv2 = headland:getPolygon():findClosestVertexToPoint(v2)
    return headland:getPolygon():getShortestPathBetween(cv1.ix, cv2.ix)
end

---@class CourseGenerator.FieldworkCourseMultiVehicle : CourseGenerator.FieldworkCourse
CourseGenerator.FieldworkCourseMultiVehicle = FieldworkCourseMultiVehicle