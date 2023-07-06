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

Drive strategy for pickup up the header of an trailer, 
which needs to be attached to the harvester.

The trailer gets detached immediately 
and the harvester picks up the cutter from the trailer.
After that a bit of space is made between the harvester and the trailer
and the strategy finishes.

]]--

---@class AIDriveStrategyAttachHeader : AIDriveStrategyCourse
AIDriveStrategyAttachHeader = {}
local AIDriveStrategyAttachHeader_mt = Class(AIDriveStrategyAttachHeader, AIDriveStrategyCourse)

AIDriveStrategyAttachHeader.myStates = {
    WAITING_FOR_DETACH_TO_FINISH = {},
    DRIVING_TO_HEADER = {},
    DRIVING_TO_CUTTER = {},
    WAITING_FOR_ATTACH_TO_START = {},
    WAITING_FOR_ATTACH_TO_FINISH = {},
    REVERSING_FROM_CUTTER = {}
}

function AIDriveStrategyAttachHeader.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyAttachHeader_mt
    end
    local self = AIDriveStrategyCourse.new(customMt)
    AIDriveStrategyCourse.initStates(self, AIDriveStrategyAttachHeader.myStates)
    self.state = self.states.INITIAL
    self.debugChannel = CpDebug.DBG_FIELDWORK
    return self
end

function AIDriveStrategyAttachHeader:isGeneratedCourseNeeded()
    return false
end

function AIDriveStrategyAttachHeader:delete()
    if self.cutterNode then 
        CpUtil.destroyNode(self.cutterNode)
    end
    AIDriveStrategyAttachHeader:superClass().delete(self)
end

function AIDriveStrategyAttachHeader:initializeImplementControllers(vehicle)
    self.trailer = AIUtil.getImplementWithSpecialization(self.vehicle, DynamicMountAttacher)
    self.dynamicMountAttacherController = DynamicMountAttacherController(vehicle, self.trailer)
    self.attachableController = AttachableController(vehicle, self.trailer)
    self.attachableCutterController = AttachableController(vehicle, self.dynamicMountAttacherController:getMountedImplement())
    self.attacherJointController = AttacherJointController(vehicle,vehicle)
    self:appendImplementController(self.attacherJointController)
end

function AIDriveStrategyAttachHeader:setAllStaticParameters()
    AIDriveStrategyAttachHeader:superClass().setAllStaticParameters(self)
    -- make sure we have a good turning radius set
    self.turningRadius = AIUtil.getTurningRadius(self.vehicle)
    self.proximityController:registerIgnoreObjectCallback(self, self.ignoreProximityObject)
end

function AIDriveStrategyAttachHeader:startWithoutCourse(jobParameters)
    self.course = Course.createStraightForwardCourse(self.vehicle, 25)
    self:startCourse(self.course, 1)
end

function AIDriveStrategyAttachHeader:update(dt)
    -- to always have a valid course (for the traffic conflict detector mainly)
    AIDriveStrategyAttachHeader:superClass().update(self, dt)
    self:updateImplementControllers(dt)
    if self.cutterNode then 
        CpUtil.drawDebugNode(self.cutterNode)
    end
    if CpDebug:isChannelActive(CpDebug.DBG_PATHFINDER, self.vehicle) then
        if self.pathfinder then
            PathfinderUtil.showNodes(self.pathfinder)
        end
    end
    if self.course and  self.course:isTemporary() then
        self.course:draw()
    elseif self.ppc:getCourse() and self.ppc:getCourse():isTemporary() then
        self.ppc:getCourse():draw()
    end
end

function AIDriveStrategyAttachHeader:getDriveData(dt, vX, vY, vZ)
    self:updateLowFrequencyImplementControllers()
    
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
    elseif self.state == self.states.INITIAL then
        self:setMaxSpeed(0)
        self.attachableController:detach()
        self.state = self.states.WAITING_FOR_DETACH_TO_FINISH
    elseif self.state == self.states.WAITING_FOR_DETACH_TO_FINISH then
        self:setMaxSpeed(0)
        if not self.attachableController:isDetachActive() then 
            Markers.setMarkerNodes(self.vehicle)
            self:setFrontAndBackMarkers()
            self:startPathfindingToCutter()
            --- Detach has finished, so need make sure the reverse driver gets updated.
            self.reverser = AIReverseDriver(self.vehicle, self.ppc)
        end
    elseif self.state == self.states.DRIVING_TO_HEADER then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    elseif self.state == self.states.DRIVING_TO_CUTTER then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        if self.attacherJointController:canAttachCutter() then      
            Timer.createOneshot(150, function()
                self.state = self.states.WAITING_FOR_ATTACH_TO_START
            end)
        end
    elseif self.state == self.states.WAITING_FOR_ATTACH_TO_START then
        self:setMaxSpeed(0)
        if self.attacherJointController:attach() or self.attacherJointController:isAttachActive() then 
            self.state = self.states.WAITING_FOR_ATTACH_TO_FINISH
        else
            self.vehicle:stopCurrentAIJob(AIMessageErrorCutterNotSupported.new())
        end
    elseif self.state == self.states.WAITING_FOR_ATTACH_TO_FINISH then
        self:setMaxSpeed(0)
        if not self.attacherJointController:isAttachActive() then
            Markers.setMarkerNodes(self.vehicle)
            local course = Course.createStraightReverseCourse(self.vehicle,1.5*self.turningRadius,0)
            self:startCourse(course, 1)
            self.state = self.states.REVERSING_FROM_CUTTER
        end
    elseif self.state == self.states.REVERSING_FROM_CUTTER then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
    end

    self:checkProximitySensors(moveForwards)
    return gx, gz, moveForwards, self.maxSpeed, 100
end

function AIDriveStrategyAttachHeader:ignoreProximityObject(object, vehicle, moveForwards)
    if self.state == self.states.DRIVING_TO_CUTTER then 
        if vehicle == self.trailer then 
            return true
        end
        if vehicle == self.dynamicMountAttacherController:getMountedImplement() then 
            return true
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------
--- Pathfinding
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyAttachHeader:startPathfindingToCutter()
    if not self.pathfinder or not self.pathfinder:isActive() then
        self.state = self.states.WAITING_FOR_PATHFINDER
        local goalNode = self.dynamicMountAttacherController:getCutterJointPositionNode()
        local x, _, z = getWorldTranslation(goalNode)
        local dirX, _, dirZ = localDirectionToWorld(self.dynamicMountAttacherController:getMountedImplement().rootNode, 0, 0, 1)
        local rotY = MathUtil.getYRotationFromDirection(dirX, dirZ)
        self.cutterNode = CpUtil.createNode("cutterNode", x, z, rotY)
        local done, path, goalNodeInvalid
        self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToNode(
            self.vehicle, self.cutterNode, 0, -1.5*self.turningRadius,
            false, nil, nil )
        if done then
            return self:onPathfindingDoneToCutter(path, goalNodeInvalid)
        else
            self:setPathfindingDoneCallback(self, self.onPathfindingDoneToCutter)
            return true
        end
    else
        self:debug('Pathfinder already active')
    end
end

function AIDriveStrategyAttachHeader:onPathfindingDoneToCutter(path, goalNodeInvalid)
    if path and #path > 2 then
        local course = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        self:startCourse(course, 1)
        self.state = self.states.DRIVING_TO_HEADER
        return true
    else
        self:debug("Failed to find path to header!")
        
        --self.vehicle:stopCurrentAIJob(AIMessageCpErrorNoPathFound.new())
        return false
    end
end

-----------------------------------------------------------------------------------------------------------------------
--- Event listeners
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyAttachHeader:onWaypointPassed(ix, course)
    if course:isLastWaypointIx(ix) then
        if self.state == self.states.DRIVING_TO_HEADER then
            local course = Course.createFromNodeToNode(self.vehicle, self.vehicle:getAIDirectionNode(), 
                self.cutterNode, 0, 0, 0, 3, false)
            self:startCourse(course, 1)
            self.state = self.states.DRIVING_TO_CUTTER
        elseif self.state == self.states.DRIVING_TO_CUTTER then
            local course = Course.createStraightReverseCourse(self.vehicle,1.5*self.turningRadius,0)
            self:startCourse(course, 1)
            self.state = self.states.REVERSING_FROM_CUTTER
        elseif self.state == self.states.REVERSING_FROM_CUTTER then
            self.vehicle:getJob():onFinishAttachCutter()
        end
    end
end
