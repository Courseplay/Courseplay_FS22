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
    DEFAULT = {},
}

function AIDriveStrategyCourse.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyCourse_mt
    end
    local self = AIDriveStrategy.new(customMt)
    self.debugChannel = CpDebug.DBG_AI_DRIVER
    self:initStates(AIDriveStrategyCourse.myStates)
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

function AIDriveStrategyCourse:debug(...)
    CpUtil.debugVehicle(self.debugChannel, self.vehicle, self.state.name .. ': ' .. string.format(...))
end

function AIDriveStrategyCourse:debugSparse(...)
    if g_updateLoopIndex % 100 == 0 then
        self:debug(...)
    end
end

function AIDriveStrategyCourse:info(...)
    CpUtil.infoVehicle(self.vehicle, self.state.name .. ': ' .. string.format(...))
end

function AIDriveStrategyCourse:error(...)
    CpUtil.infoVehicle(self.vehicle, self.state.name .. ': ' .. string.format(...))
end

function AIDriveStrategyCourse:setAIVehicle(vehicle)
    AIDriveStrategyCourse:superClass().setAIVehicle(self, vehicle)
    ---@type FillLevelManager
    self.fillLevelManager = FillLevelManager(vehicle)
    self.ppc = PurePursuitController(vehicle)
    -- TODO: should probably be the closest waypoint to the target?
    local course = vehicle:getFieldWorkCourse()
    local _, _, ixClosestRightDirection, _ = course:getNearestWaypoints(vehicle:getAIDirectionNode())
    self:debug('Starting course at the closest waypoint in the right direction %d', ixClosestRightDirection)
    self:startCourse(course, ixClosestRightDirection)
end

function AIDriveStrategyCourse:update()
    self.ppc:update()
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
    self:debug('Starting a course, at waypoint %d, no next course set.', ix)
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