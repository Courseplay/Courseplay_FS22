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

Drive strategy for driving a field work course

]]--

---@class AIDriveStrategyFieldWorkCourse : AIDriveStrategyCourse
AIDriveStrategyFieldWorkCourse = {}
local AIDriveStrategyFieldWorkCourse_mt = Class(AIDriveStrategyFieldWorkCourse, AIDriveStrategyCourse)

AIDriveStrategyFieldWorkCourse.myStates = {
    INITIAL = {},
    WORKING = {},
    UNLOAD_OR_REFILL_ON_FIELD = {},
    WAITING_FOR_UNLOAD_OR_REFILL ={}, -- while on the field
    ON_CONNECTING_TRACK = {},
    WAITING_FOR_LOWER = {},
    WAITING_FOR_LOWER_DELAYED = {},
    WAITING_FOR_STOP = {},
    WAITING_FOR_WEATHER = {},
    TURNING = {},
    TEMPORARY = {},
}

function AIDriveStrategyFieldWorkCourse.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyFieldWorkCourse_mt
    end
    local self = AIDriveStrategyCourse.new(customMt)
    AIDriveStrategyCourse.initStates(self, AIDriveStrategyFieldWorkCourse.myStates)
    self.state = self.states.INITIAL
    return self
end

function AIDriveStrategyCourse:getDriveData(dt, vX, vY, vZ)
    local moveForwards = not self.ppc:isReversing()
    local gx, _, gz = self.ppc:getGoalPointPosition()
    local maxSpeed = self.vehicle:getSpeedLimit(true)

    if self.state == self.states.INITIAL then
        self:lowerImplements()
        self.state = self.states.WAITING_FOR_LOWER
    elseif self.state == self.states.WAITING_FOR_LOWER then
        if self.vehicle:getCanAIFieldWorkerContinueWork() then
            self:debug('all tools ready, start working')
            self.state = self.states.WORKING
        else
            self:debugSparse('waiting for all tools to lower')
            maxSpeed = 0
        end
    elseif self.state == self.states.WAITING_FOR_LOWER_DELAYED then
        -- getCanAIVehicleContinueWork() seems to return false when the implement being lowered/raised (moving) but
        -- true otherwise. Due to some timing issues it may return true just after we started lowering it, so this
        -- here delays the check for another cycle.
        self.state = self.states.WAITING_FOR_LOWER
        maxSpeed = 0
    elseif self.state == self.states.WORKING then
        maxSpeed = self.vehicle:getSpeedLimit(true)
    end
    return gx, gz, moveForwards, maxSpeed, 100
end

function AIDriveStrategyFieldWorkCourse:lowerImplements()
    for _, implement in pairs(self.vehicle:getAttachedAIImplements()) do
        implement.object:aiImplementStartLine()
    end
    self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_START_LINE)

    if AIUtil.hasAIImplementWithSpecialization(self.vehicle, SowingMachine) or self.ppc:isReversing() then
        -- sowing machines want to stop while the implement is being lowered
        -- also, when reversing, we assume that we'll switch to forward, so stop while lowering, then start forward
        self.state = self.states.WAITING_FOR_LOWER_DELAYED
    end
end

function AIDriveStrategyFieldWorkCourse:raiseImplements()
    for _, implement in pairs(self.vehicle:getAttachedAIImplements()) do
        implement.object:aiImplementEndLine()
    end
    self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
end

function AIDriveStrategyFieldWorkCourse:updateAIFieldWorkerDriveStrategies()
    local driveStrategyFollowFieldWorkCourse = AIDriveStrategyFieldWorkCourse.new()
    driveStrategyFollowFieldWorkCourse:setAIVehicle(self)
    -- TODO: messing around with AIFieldWorker spec internals is not the best idea, should rather implement
    -- our own specialization
    for i, strategy in ipairs(self.spec_aiFieldWorker.driveStrategies) do
        if strategy.getDriveStraightData then
            CpUtil.debugVehicle(1, self, 'Replacing fieldwork helper drive strategy with Courseplay drive strategy')
            self.spec_aiFieldWorker.driveStrategies[i]:delete()
            self.spec_aiFieldWorker.driveStrategies[i] = driveStrategyFollowFieldWorkCourse
        end
    end
end

AIFieldWorker.updateAIFieldWorkerDriveStrategies = Utils.appendedFunction(AIFieldWorker.updateAIFieldWorkerDriveStrategies,
        AIDriveStrategyFieldWorkCourse.updateAIFieldWorkerDriveStrategies)