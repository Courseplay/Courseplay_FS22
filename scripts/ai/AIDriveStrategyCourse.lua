--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

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

Base class for all Courseplay drive strategies

]]

---@class AIDriveStrategyCourse : AIDriveStrategy
AIDriveStrategyCourse = {}
local AIDriveStrategyCourse_mt = Class(AIDriveStrategyCourse, AIDriveStrategy)

AIDriveStrategyCourse.myStates = {
    INITIAL = {},
    DRIVING_TO_COURSE_START = {}
}

function AIDriveStrategyCourse.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyCourse_mt
    end
    local self = AIDriveStrategy.new(customMt)
    self.debugChannel = CpDebug.DBG_AI_DRIVER
    self:initStates(AIDriveStrategyCourse.myStates)
    self.controllers = {}
    return self
end

--- Aggregation of states from this and all descendant classes
function AIDriveStrategyCourse:initStates(states)
    if self.states == nil then
        self.states = {}
    end
    for key, state in pairs(states) do
        self.states[key] = {name = tostring(key), properties = state}
    end
end

function AIDriveStrategyCourse:getStateAsString()
    return self.state.name
end

function AIDriveStrategyCourse:debug(...)
    CpUtil.debugVehicle(self.debugChannel, self.vehicle, self:getStateAsString() .. ': ' .. string.format(...))
end

function AIDriveStrategyCourse:debugSparse(...)
    if g_updateLoopIndex % 100 == 0 then
        self:debug(...)
    end
end

function AIDriveStrategyCourse:info(...)
    CpUtil.infoVehicle(self.vehicle, self:getStateAsString() .. ': ' .. string.format(...))
end

function AIDriveStrategyCourse:error(...)
    CpUtil.infoVehicle(self.vehicle, self:getStateAsString() .. ': ' .. string.format(...))
end

-- TODO_22
function AIDriveStrategyCourse:setInfoText(text)
    self:debug(text)
end

function AIDriveStrategyCourse:setAIVehicle(vehicle,jobParameters)
    AIDriveStrategyCourse:superClass().setAIVehicle(self, vehicle)
    self:initializeImplementControllers(vehicle)
    ---@type FillLevelManager
    self.fillLevelManager = FillLevelManager(vehicle)
    self.ppc = PurePursuitController(vehicle)
    self.ppc:registerListeners(self, 'onWaypointPassed', 'onWaypointChange')
    -- TODO_22 properly implement this in courseplaySpec
    self.storage = vehicle.spec_courseplaySpec

    self.settings = vehicle:getCpSettings()
    self.courseGeneratorSettings = vehicle:getCourseGeneratorSettings()

    -- for now, pathfinding generated courses can't be driven by towed tools
    self.allowReversePathfinding = AIUtil.getFirstReversingImplementWithWheels(self.vehicle) == nil
    self.turningRadius = AIUtil.getTurningRadius(vehicle)

    self:enableCollisionDetection()
    self:setAllStaticParameters()

    -- TODO: this may or may not be the course we need for the strategy
    local course = vehicle:getFieldWorkCourse()
    if course then
        self:debug('Vehicle has a fieldwork course, figure out where to start')
        
        local startIx = self:getStartingPointWaypointIx(course,jobParameters.startAt:getValue())
        self:start(course, startIx)
    else
        -- some strategies do not need a recorded or generated course to work, they
        -- will create the courses on the fly.
        self:debug('Vehicle has no course, start work without it.')
        self:startWithoutCourse()
    end
end

function AIDriveStrategyCourse:getStartingPointWaypointIx(course,startAt)
    if startAt == CpJobParameters.START_AT_NEAREST_POINT then 
        local _, _, ixClosestRightDirection, _ = course:getNearestWaypoints(self.vehicle:getAIDirectionNode())
        self:debug('Starting course at the closest waypoint in the right direction %d', ixClosestRightDirection)
        return ixClosestRightDirection
    else 
        self:debug('Starting course at the first waypoint')
        return 1
    end
end

function AIDriveStrategyCourse:start(course, startIx)
    self:startCourse(course, startIx)
    self.state = self.states.INITIAL
end

function AIDriveStrategyCourse:startWithoutCourse()
end

function AIDriveStrategyCourse:updateCpStatus(status)
    --- override
end

-----------------------------------------------------------------------------------------------------------------------
--- Implement handling
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyCourse:initializeImplementControllers(vehicle)
end

--- Normal update function called every frame.
--- For releasing the helper in the controller, use this one.
function AIDriveStrategyCourse:updateImplementControllers()
    for _, controller in pairs(self.controllers) do
        ---@type ImplementController
        if controller:isEnabled() then
            controller:update()
        end
    end
end

--- Called in the low frequency function for the helper.
function AIDriveStrategyCourse:updateLowFrequencyImplementControllers()
    for _, controller in pairs(self.controllers) do
        ---@type ImplementController
        if controller:isEnabled() then
            -- we don't know yet if we even need anything from the controller other than the speed.
            local _, _, _, maxSpeed = controller:getDriveData()
            if maxSpeed then
                self:setMaxSpeed(maxSpeed)
            end
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------
--- Static parameters (won't change while driving)
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyCourse:setAllStaticParameters()
    -- set strategy specific parameters before starting
end

function AIDriveStrategyCourse:update()
    self.ppc:update()
    self:updatePathfinding()
end

function AIDriveStrategyCourse:getDriveData(dt, vX, vY, vZ)
    local moveForwards = not self.ppc:isReversing()
    local gx, _, gz = self.ppc:getGoalPointPosition()
    return gx, gz, moveForwards, self.maxSpeed, 100
end

--- Set the maximum speed. The idea is that self.maxSpeed is reset at the beginning of every loop and
-- every function calls setMaxSpeed() and the speed will be set to the minimum
-- speed set in this loop.
function AIDriveStrategyCourse:setMaxSpeed(speed)
    if self.maxSpeedUpdatedLoopIndex == nil or self.maxSpeedUpdatedLoopIndex ~= g_updateLoopIndex then
        -- new loop, reset max speed
        self.maxSpeed = self.vehicle:getSpeedLimit(true)
        self.maxSpeedUpdatedLoopIndex = g_updateLoopIndex
    end
    self.maxSpeed = math.min(self.maxSpeed, speed)
end

--- Start a course and continue with nextCourse at ix when done
---@param tempCourse Course
---@param nextCourse Course
---@param ix number
function AIDriveStrategyCourse:startCourse(course, ix)
    self:debug('Starting a course, at waypoint %d (of %d).', ix, course:getNumberOfWaypoints())
    self.course = course
    self.ppc:setCourse(self.course)
    self.ppc:initialize(ix)
end

--- @param msgReference string as defined in globalInfoText.msgReference
function AIDriveStrategyCourse:clearInfoText(msgReference)
    -- TODO_22
    if msgReference then
        self:debug('clearInfoText: %s', msgReference)
    end
end

function AIDriveStrategyCourse:getFillLevelInfoText()
    -- TODO_22
    self:debug('getFillLevelInfoText')
    return 'getFillLevelInfoText'
end

-----------------------------------------------------------------------------------------------------------------------
--- Event listeners
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyCourse:onWaypointChange(ix, course)
end

function AIDriveStrategyCourse:onWaypointPassed(ix, course)
end

------------------------------------------------------------------------------------------------------------------------
--- Pathfinding
---------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyCourse:getAllowReversePathfinding()
    return self.allowReversePathfinding and self.settings.allowReversePathfinding:getValue()
end

function AIDriveStrategyCourse:setPathfindingDoneCallback(object, func)
    self.pathfindingDoneObject = object
    self.pathfindingDoneCallbackFunc = func
end

function AIDriveStrategyCourse:updatePathfinding()
    if self.pathfinder and self.pathfinder:isActive() then
        self:setMaxSpeed(0)
        local done, path = self.pathfinder:resume()
        if done then
            self.pathfindingDoneCallbackFunc(self.pathfindingDoneObject, path)
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Collision
---------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyCourse:disableCollisionDetection()
    if self.vehicle then
        CourseplaySpec.disableCollisionDetection(self.vehicle)
    end
end

function AIDriveStrategyCourse:enableCollisionDetection()
    if self.vehicle then
        CourseplaySpec.enableCollisionDetection(self.vehicle)
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Course helpers
---------------------------------------------------------------------------------------------------------------------------

--- Are we within distance meters of the last waypoint (measured on the course, not direct path)?
function AIDriveStrategyCourse:isCloseToCourseEnd(distance)
    return self.course:getDistanceToLastWaypoint(self.ppc:getCurrentWaypointIx()) < distance
end

--- Are we within distance meters of the first waypoint (measured on the course, not direct path)?
function AIDriveStrategyCourse:isCloseToCourseStart(distance)
    return self.course:getDistanceFromFirstWaypoint(self.ppc:getCurrentWaypointIx()) < distance
end
