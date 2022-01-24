---@class CourseRecorder
CourseRecorder = CpObject()

function CourseRecorder:init()
    self.recording = false
end

function CourseRecorder:debug(...)
    CpUtil.debugVehicle(CpDebug.DBG_COURSES, self.vehicle, ...)
end

function CourseRecorder:update()
    if not self.recording then return end
    local waypoint = self:getVehiclePositionAsWaypoint()
    local previousWaypoint = self.waypoints[#self.waypoints]
    local dist = previousWaypoint:getDistanceFromVehicle(self.vehicle)
    local angleDiff = math.abs(waypoint.yRot - previousWaypoint.yRot)
    if dist > 5 or angleDiff > math.rad(3) then
        self:addWaypoint(waypoint)
        self:debug('Recorded waypoint %d.', #self.waypoints)
    end
end

function CourseRecorder:start(vehicle)
    self.recording = true
    self.vehicle = vehicle
    self:debug('Course recording started')
    self.waypoints = {}
    self:addWaypoint(self:getVehiclePositionAsWaypoint())
end

function CourseRecorder:stop()
    self.recording = false
    self:debug('Course recording stopped, recorded %d waypoints', #self.waypoints)
end

function CourseRecorder:getRecordedCourse()
    return Course(self.vehicle, self.waypoints)
end

function CourseRecorder:getRecordedWaypoints()
    return self.waypoints
end

function CourseRecorder:addWaypoint(waypoint)
    table.insert(self.waypoints, waypoint)
    g_courseDisplay:addSign(self.vehicle, nil, waypoint.x, waypoint.z, nil,
            math.deg(waypoint.yRot), nil, nil, 'regular');
end

function CourseRecorder:getVehiclePositionAsWaypoint()
    local x, _, z = getWorldTranslation(self.vehicle.rootNode)
    local dirX, _, dirZ = localDirectionToWorld(self.vehicle.rootNode, 0, 0, 1)
    local yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
    return Waypoint({x = x, z = z, yRot = yRot, rev = AIUtil.isReversing(self.vehicle)})
end