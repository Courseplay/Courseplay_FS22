--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2022 Peter Vaiko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

Drive strategy for driving to the waypoint where we want to start the fieldwork.

- Make sure everything is raised (maybe folded?)
- Find a path to the start waypoint (first or last worked on), avoiding fruit
- When getting close to the end of the course (to the work start waypoint), give control
  to the field work strategy, which will then drive the last few meters making sure the
  implements are in a working position when reaching the work start waypoint.

]]--

---@class AIDriveStrategyDriveToFieldWorkStart : AIDriveStrategyCourse
AIDriveStrategyDriveToFieldWorkStart = {}
local AIDriveStrategyDriveToFieldWorkStart_mt = Class(AIDriveStrategyDriveToFieldWorkStart, AIDriveStrategyCourse)

AIDriveStrategyDriveToFieldWorkStart.myStates = {
    PREPARE_TO_DRIVE = {},
    WORK_START_REACHED = {},
}

-- minimum distance to the target when this strategy is even used
AIDriveStrategyDriveToFieldWorkStart.minDistanceToDrive = 20

AIDriveStrategyDriveToFieldWorkStart.normalFillLevelFullPercentage = 99.5

function AIDriveStrategyDriveToFieldWorkStart.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyDriveToFieldWorkStart_mt
    end
    local self = AIDriveStrategyCourse.new(customMt)
    AIDriveStrategyCourse.initStates(self, AIDriveStrategyDriveToFieldWorkStart.myStates)
    self.state = self.states.INITIAL
    self.debugChannel = CpDebug.DBG_FIELDWORK
    self.prepareTimeout = 0
    self.emergencyBrake = CpTemporaryObject(true)
    self.multitoolOffset = 0
    return self
end

function AIDriveStrategyDriveToFieldWorkStart:delete()
    AIDriveStrategyDriveToFieldWorkStart:superClass().delete(self)
end

function AIDriveStrategyDriveToFieldWorkStart:initializeImplementControllers(vehicle)
    -- these can't handle the standard Giants AI events to raise, so we need to have the controllers for them
    self:addImplementController(vehicle, PickupController, Pickup, {})
    self:addImplementController(vehicle, CutterController, Cutter, {})
    self:addImplementController(vehicle, SowingMachineController, SowingMachine, {})
end

function AIDriveStrategyDriveToFieldWorkStart:start(course, startIx, jobParameters)
    local distance = course:getDistanceBetweenVehicleAndWaypoint(self.vehicle, startIx)
    if distance < AIDriveStrategyDriveToFieldWorkStart.minDistanceToDrive then
        self:debug('Closer than %.0f m to start waypoint (%d), start fieldwork directly',
                AIDriveStrategyDriveToFieldWorkStart.minDistanceToDrive, startIx)
        self.state = self.states.WORK_START_REACHED
    else
        self:debug('Start driving to work start waypoint')
        local nVehicles = course:getMultiTools()
        self.multitoolOffset = Course.calculateOffsetForMultitools(
                nVehicles,
                nVehicles > 1 and jobParameters.laneOffset:getValue() or 0,
                course:getWorkWidth() / nVehicles)
        self.vehicle:prepareForAIDriving()
        self:startCourseWithPathfinding(course, startIx)
    end
    --- Saves the course start position, so it can be given to the job instance.
    local x, _, z = course:getWaypointPosition(startIx)
    self.startPosition = {x = x, z = z}
end

function AIDriveStrategyDriveToFieldWorkStart:update()
    AIDriveStrategyDriveToFieldWorkStart:superClass().update(self)
    self:updateImplementControllers()
    if self.ppc:getCourse():isTemporary() and CpDebug:isChannelActive(CpDebug.DBG_FIELDWORK, self.vehicle) then
        self.ppc:getCourse():draw()
    end
end

function AIDriveStrategyDriveToFieldWorkStart:isWorkStartReached()
    return self.state == self.states.WORK_START_REACHED
end

function AIDriveStrategyDriveToFieldWorkStart:getStartPosition()
    return self.startPosition
end

function AIDriveStrategyDriveToFieldWorkStart:getDriveData(dt, vX, vY, vZ)
    local moveForwards = not self.ppc:isReversing()
    local gx, gz

    if not moveForwards then
        local maxSpeed
        gx, gz, maxSpeed = self:getReverseDriveData()
        self:setMaxSpeed(maxSpeed)
    else
        gx, _, gz = self.ppc:getGoalPointPosition()
    end

    if self.state == self.states.WAITING_FOR_PATHFINDER then
        self:setMaxSpeed(0)
    elseif self.state == self.states.PREPARE_TO_DRIVE then
        self:setMaxSpeed(0)
        local isReadyToDrive, blockingVehicle = self.vehicle:getIsAIReadyToDrive()
        if isReadyToDrive then
            self.state = self.states.DRIVING_TO_WORK_START_WAYPOINT
            self:debug('Ready to drive to work start')
        else
            self:debugSparse('Not ready to drive because of %s, preparing ...', CpUtil.getName(blockingVehicle))
            if not self.vehicle:getIsAIPreparingToDrive() then
                self.prepareTimeout = self.prepareTimeout + dt
                if 2000 < self.prepareTimeout then
                    self:debug('Timeout preparing, continue anyway')
                    self.state = self.states.DRIVING_TO_WORK_START_WAYPOINT
                end
            end
        end
    elseif self.state == self.states.DRIVING_TO_WORK_START_WAYPOINT then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    elseif self.state == self.states.WORK_START_REACHED then
        if self.emergencyBrake:get() then
            self:debugSparse('Work start reached but field work did not start...')
            self:setMaxSpeed(0)
        else
            self:setMaxSpeed(self.settings.turnSpeed:getValue())
        end
    end
    return gx, gz, moveForwards, self.maxSpeed, 100
end

------------------------------------------------------------------------------------------------------------------------
--- Pathfinding
---------------------------------------------------------------------------------------------------------------------------
---@param course Course
---@param ix number
function AIDriveStrategyDriveToFieldWorkStart:startCourseWithPathfinding(course, ix)
    if not self.pathfinder or not self.pathfinder:isActive() then
        -- set a course so the PPC is able to do its updates.
        self.course = course
        self.ppc:setCourse(self.course)
        self.ppc:initialize(ix)
        self:rememberCourse(course, ix)
        self:setFrontAndBackMarkers()
        local x, _, z = course:getWaypointPosition(ix)
        self.state = self.states.WAITING_FOR_PATHFINDER
        local fieldNum = CpFieldUtil.getFieldIdAtWorldPosition(x, z)
        -- if there is fruit at the target, create an area around it where the pathfinder ignores the fruit
        -- so there's no penalty driving there. This is to speed up pathfinding when start harvesting for instance
        local fruitAtTarget = PathfinderUtil.hasFruit(x, z, self.workWidth, self.workWidth)
        self.pathfindingStartedAt = g_currentMission.time
        local done, path
        self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToWaypoint(self.vehicle, course:getWaypoint(ix),
                self.multitoolOffset, math.min(-self.frontMarkerDistance, 0), self:getAllowReversePathfinding(), fieldNum, nil, ix < 3 and math.huge, nil, nil,
                fruitAtTarget and PathfinderUtil.Area(x, z, 2 * self.workWidth))
        if done then
            return self:onPathfindingDoneToCourseStart(path)
        else
            self:setPathfindingDoneCallback(self, self.onPathfindingDoneToCourseStart)
            return true
        end
    else
        self:info('Pathfinder already active')
        self.state = self.states.PREPARE_TO_DRIVE
        return false
    end
end

function AIDriveStrategyDriveToFieldWorkStart:onPathfindingDoneToCourseStart(path)
    local fieldWorkCourse, ix = self:getRememberedCourseAndIx()
    local courseToStart
    if path and #path > 2 then
        self:debug('Pathfinding to start fieldwork finished with %d waypoints (%d ms)',
                #path, g_currentMission.time - (self.pathfindingStartedAt or 0))
        courseToStart = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
    else
        self:debug('Pathfinding to start fieldwork failed, using alignment course instead')
        courseToStart = self:createAlignmentCourse(fieldWorkCourse, ix)
    end
    self.state = self.states.PREPARE_TO_DRIVE
    self:startCourse(courseToStart, 1)
end

-----------------------------------------------------------------------------------------------------------------------
--- Event listeners
-----------------------------------------------------------------------------------------------------------------------
---@param course Course
function AIDriveStrategyDriveToFieldWorkStart:onWaypointChange(ix, course)
    if course:isCloseToLastWaypoint(15) then
        self.state = self.states.WORK_START_REACHED
        -- just in case no one takes the wheel in a few seconds
        self.emergencyBrake:set(false, 2000)
        self:debug('Almost at the work start waypoint, preparing for work')
        -- let the field work strategy know where to continue
        self.vehicle:getJob():setStartFieldWorkCourse(course, ix)
    end
end