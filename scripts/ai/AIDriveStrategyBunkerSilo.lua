--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
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
]]

--- Drive strategy for bunker silos.
---@class AIDriveStrategyBunkerSilo : AIDriveStrategyCourse
AIDriveStrategyBunkerSilo = {}
local AIDriveStrategyBunkerSilo_mt = Class(AIDriveStrategyBunkerSilo, AIDriveStrategyCourse)

AIDriveStrategyBunkerSilo.myStates = {
    DRIVING_TO_SILO = {},
    DRIVING_TO_PARK_POSITION = {},
    WAITING_AT_PARK_POSITION = {},
    WAITING_FOR_PREPARING = {},
    DRIVING_INTO_SILO = {},
	DRIVING_OUT_OF_SILO = {},
    DRIVING_TURN = {},
    DRIVING_TEMPORARY_OUT_OF_SILO = {}
}

AIDriveStrategyBunkerSilo.siloEndProximitySensorRange = 4
AIDriveStrategyBunkerSilo.isStuckMs = 1000 *15
AIDriveStrategyBunkerSilo.isStuckBackOffset = 8
AIDriveStrategyBunkerSilo.maxDriveIntoTheSiloAttempts = 2

function AIDriveStrategyBunkerSilo.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyBunkerSilo_mt
    end
    ---@type AIDriveStrategyBunkerSilo
    local self = AIDriveStrategyCourse.new(customMt)
    AIDriveStrategyCourse.initStates(self, AIDriveStrategyBunkerSilo.myStates)
    self.state = self.states.DRIVING_TO_SILO

    -- course offsets dynamically set by the AI and added to all tool and other offsets
    self.aiOffsetX, self.aiOffsetZ = 0, 0
    self.debugChannel = CpDebug.DBG_SILO
    ---@type ImplementController[]
    self.controllers = {}
	self.silo = nil
    self.siloController = nil
    self.drivingForwardsIntoSilo = true
    self.turnNode = CpUtil.createNode("turnNode", 0, 0, 0)
    

    self.isStuckTimer = Timer.new(self.isStuckMs)
    self.driveIntoSiloAttempts = 0

    return self
end

function AIDriveStrategyBunkerSilo:delete()
    self.silo:resetTarget(self.vehicle)
    self.isStuckTimer:delete()
    if self.pathfinderNode then
       self.pathfinderNode:destroy()
    end
    if self.parkNode then 
        CpUtil.destroyNode(self.parkNode)
        self.parkNode = nil
    end
    if self.turnNode then 
        CpUtil.destroyNode(self.turnNode)
        self.turnNode = nil
    end

    AIDriveStrategyBunkerSilo:superClass().delete(self)
end

function AIDriveStrategyBunkerSilo:startWithoutCourse(jobParameters)
    self:info('Starting bunker silo mode.')

    self.waitAtParkPosition = jobParameters.waitAtParkPosition:getValue()

    if self.leveler then 
        if AIUtil.isObjectAttachedOnTheBack(self.vehicle, self.leveler) then 
            self.drivingForwardsIntoSilo = false
        end
    else 
        self.drivingForwardsIntoSilo = jobParameters.drivingForwardsIntoSilo:getValue()
    end

    --- Proximity sensor to detect the silo end wall.
    self.siloEndDetectionMarker = self:getEndMarker()
    if self.drivingForwardsIntoSilo then
        self.siloEndProximitySensor = SingleForwardLookingProximitySensorPack(self.vehicle, self.siloEndDetectionMarker, 
                                                                        self.siloEndProximitySensorRange, 1)
    else
        self.siloEndProximitySensor = SingleBackwardLookingProximitySensorPack(self.vehicle, self.siloEndDetectionMarker, 
                                                                        self.siloEndProximitySensorRange, 1)
    end


    --- Setup the silo controller, that handles the driving conditions and coordinations.
	self.siloController = self.silo:setupTarget(self.vehicle, self, self.drivingForwardsIntoSilo)

    if self.silo:isVehicleInSilo(self.vehicle) then 
        self:startDrivingIntoSilo()
    else 
        local course, firstWpIx = self:getDriveIntoSiloCourse()
        self:startCourseWithPathfinding( course, firstWpIx, self:isDriveDirectionReverse())
    end
end

function AIDriveStrategyBunkerSilo:getGeneratedCourse()
    return nil    
end

-----------------------------------------------------------------------------------------------------------------------
--- Implement handling
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyBunkerSilo:initializeImplementControllers(vehicle)
    self.leveler = self:addImplementController(vehicle, LevelerController, Leveler, {})
    self:addImplementController(vehicle, BunkerSiloCompacterController, BunkerSiloCompacter, {})
end

-----------------------------------------------------------------------------------------------------------------------
--- Static parameters (won't change while driving)
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyBunkerSilo:setAllStaticParameters()
    AIDriveStrategyCourse.setAllStaticParameters(self)
    self:setFrontAndBackMarkers()
    self.proximityController:registerIgnoreObjectCallback(self, self.ignoreProximityObject)


    self.isStuckTimer:setFinishCallback(function ()
            self:debug("is stuck, trying to drive out of the silo.")
            if self:isTemporaryOutOfSiloDrivingAllowed() and not self.frozen then 
                if self.driveIntoSiloAttempts >= self.maxDriveIntoTheSiloAttempts then
                    self:debug("Max attempts reached, trying a new approach.")
                    self:startDrivingOutOfSilo()
                else
                    self:startDrivingTemporaryOutOfSilo()
                end
            end
        end)

end

function AIDriveStrategyBunkerSilo:setSilo(silo)
	self.silo = silo	
end

function AIDriveStrategyBunkerSilo:setParkPosition(parkPosition)
    self.parkPosition = parkPosition    
    if self.parkPosition.x ~= nil and self.parkPosition.z ~= nil and self.parkPosition.angle ~= nil then
        self.parkNode = CpUtil.createNode("parkNode", self.parkPosition.x, self.parkPosition.z, self.parkPosition.angle)
    end
end

-----------------------------------------------------------------------------------------------------------------------
--- Event listeners
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyBunkerSilo:onWaypointPassed(ix, course)
    if course:isLastWaypointIx(ix) then
        if self.state == self.states.DRIVING_INTO_SILO then 
            self:startDrivingOutOfSilo()
        elseif self.state == self.states.DRIVING_OUT_OF_SILO then 
            if self:isDrivingToParkPositionAllowed() and self.siloController:hasNearbyUnloader() then
                --- Only allow driving to park position here for now, as the silo interferes with the pathfinder.
                self:startDrivingToParkPositionWithPathfinding()
            else 
                self:startTransitionToNextLane()
            end
        elseif self.state == self.states.DRIVING_TURN then 
            local course = self:getRememberedCourseAndIx()
            self:startDrivingIntoSilo(course)
        elseif self.state == self.states.DRIVING_TO_SILO then
            local course = self:getRememberedCourseAndIx()
            self:startDrivingIntoSilo(course)
            self.vehicle:raiseAIEvent("onAIFieldWorkerStart", "onAIImplementStart")
        elseif self.state == self.states.DRIVING_TO_PARK_POSITION then
            self.state = self.states.WAITING_AT_PARK_POSITION
        elseif self.state == self.states.DRIVING_TEMPORARY_OUT_OF_SILO then
            self:startDrivingIntoSilo(self.lastCourse)
            self.lastCourse = nil
        end
    end
end

function AIDriveStrategyBunkerSilo:getDriveData(dt, vX, vY, vZ)
    local moveForwards = not self.ppc:isReversing()
    local gx, gz, maxSpeed

    if not moveForwards then
        gx, gz, maxSpeed = self:getReverseDriveData()
       -- self:setMaxSpeed(maxSpeed)
    else
        gx, _, gz = self.ppc:getGoalPointPosition()
    end

    local moveForwards = not self.ppc:isReversing()
    self:updateLowFrequencyImplementControllers()
    self:drive()
    AIDriveStrategyFieldWorkCourse.setAITarget(self)

	self:setMaxSpeed(self.settings.bunkerSiloSpeed:getValue())

    self:checkProximitySensors(moveForwards)

    if self:isTemporaryOutOfSiloDrivingAllowed() then
        self.isStuckTimer:startIfNotRunning()
    end

    if self.siloController:hasNearbyUnloader() then 
        if not self:isDrivingToParkPositionAllowed() then 
            self:setMaxSpeed(0) -- Waiting for unloader
            self:setInfoText(InfoTextManager.WAITING_FOR_UNLOADER)
        end
    elseif not self:isDrivingToParkPositionAllowed() then
        self:clearInfoText(InfoTextManager.WAITING_FOR_UNLOADER)
    end
    
    if self.vehicle:getIsAIPreparingToDrive() then 
        self:setMaxSpeed(0) --- Unfolding/folding
    end
    return gx, gz, moveForwards, self.maxSpeed, 100
end

function AIDriveStrategyBunkerSilo:isTemporaryOutOfSiloDrivingAllowed()
    return (self.state == self.states.DRIVING_INTO_SILO or self.state == self.states.DRIVING_TURN) and 
            AIUtil.isStopped(self.vehicle) 
            and not self.siloController:hasNearbyUnloader() 
            and not self.proximityController:isStopped()
end

function AIDriveStrategyBunkerSilo:checkProximitySensors(moveForwards)
    AIDriveStrategyBunkerSilo:superClass().checkProximitySensors(self, moveForwards)
  
end

function AIDriveStrategyBunkerSilo:update(dt)
    AIDriveStrategyBunkerSilo:superClass().update(self, dt)
    self:updateImplementControllers(dt)

    if CpDebug:isChannelActive(self.debugChannel, self.vehicle) then
        if self.course then
            -- TODO_22 check user setting
            if self.course:isTemporary() then
                self.course:draw()
            elseif self.ppc:getCourse():isTemporary() then
                self.ppc:getCourse():draw()
            end
        end
        DebugUtil.drawDebugNode(self.siloEndDetectionMarker, "siloEndDetectionMarker", false, 1)

        local frontMarkerNode, backMarkerNode = Markers.getMarkerNodes(self.vehicle)
        DebugUtil.drawDebugNode(frontMarkerNode, "FrontMarker", false, 1)
        DebugUtil.drawDebugNode(backMarkerNode, "BackMarker", false, 1)
        if self.parkNode then 
            DebugUtil.drawDebugNode(self.parkNode, "ParkNode", true, 3)
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------
--- Bunker silo interactions
-----------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyBunkerSilo:drive()
    if self.state == self.states.DRIVING_INTO_SILO then

        local _, _, closestObject = self.siloEndProximitySensor:getClosestObjectDistanceAndRootVehicle()
        if self.silo:isTheSameSilo(closestObject) then
            self:debug("End wall detected.")
            self:startDrivingOutOfSilo()
        end

        local isEndReached, maxSpeed = self.siloController:isEndReached(self:getEndMarker(), self:getEndOffset())
        if isEndReached then 
            self:debug("End is reached.")
            self:startDrivingOutOfSilo()
        end
        self:setMaxSpeed(maxSpeed)

        if self:isDrivingToParkPositionAllowed() then
            if self.siloController:hasNearbyUnloader() then 
           --     self:startDrivingToParkPositionWithPathfinding()
            end
        end

    elseif self.state == self.states.DRIVING_OUT_OF_SILO then
        if self:isDrivingToParkPositionAllowed() then
            if self.siloController:hasNearbyUnloader() then 
              --  self:startDrivingToParkPositionWithPathfinding()
            end
        end
    elseif self.state == self.states.WAITING_FOR_PATHFINDER then
        self:setMaxSpeed(0)
    elseif self.state == self.states.WAITING_AT_PARK_POSITION then
        self:setMaxSpeed(0)
        self:setInfoText(InfoTextManager.WAITING_FOR_UNLOADER)
        if not self.siloController:hasNearbyUnloader() then
            local course, firstWpIx = self:getDriveIntoSiloCourse()
            self:startCourseWithPathfinding( course, firstWpIx, self:isDriveDirectionReverse())
            self:clearInfoText(InfoTextManager.WAITING_FOR_UNLOADER)
        end
    elseif self.state == self.states.DRIVING_TURN then 
        self:setMaxSpeed(self.settings.turnSpeed:getValue())
    end
end

function AIDriveStrategyBunkerSilo:isWaitingAtParkPosition()
    return self.state == self.states.WAITING_AT_PARK_POSITION
end

function AIDriveStrategyBunkerSilo:isWaitingForUnloaders()
    return self:isDrivingToParkPositionAllowed() and self.state == self.states.WAITING_AT_PARK_POSITION or self.siloController:hasNearbyUnloader()
end

function AIDriveStrategyBunkerSilo:isDrivingToParkPositionAllowed()
    return self.waitAtParkPosition and self.parkNode ~= nil
end

--- Is the drive direction to drive into the silo reverse?
function AIDriveStrategyBunkerSilo:isDriveDirectionReverse()
    return not self.drivingForwardsIntoSilo
end

--- Starts the straight silo lane earlier. (Driving into the silo)
function AIDriveStrategyBunkerSilo:getStartOffset()
    local offset = self:isDriveDirectionReverse() and self.backMarkerDistance + 2 or self.frontMarkerDistance
    return - 2 * offset
end

--- Makes sure the straight silo lane stops later. (Driving out of the silo)
function AIDriveStrategyBunkerSilo:getEndOffset()
    local offset = self:isDriveDirectionReverse() and self.backMarkerDistance + 3 or self.frontMarkerDistance
    return 5 * offset
end

function AIDriveStrategyBunkerSilo:getEndMarker()
    return self:isDriveDirectionReverse() and Markers.getBackMarkerNode(self.vehicle) or
            Markers.getFrontMarkerNode(self.vehicle)
end

--- Gets the work width.
function AIDriveStrategyBunkerSilo:getWorkWidth()
    return self.settings.bunkerSiloWorkWidth:getValue()
end

function AIDriveStrategyBunkerSilo:startTransitionToNextLane()
    local course, firstWpIx = self:getDriveIntoSiloCourse()
        
    local x, y, z = course:getWaypointPosition(1)
    local yRot = course:getWaypointYRotation(1)
    setTranslation(self.turnNode, x, y, z)
    setRotation(self.turnNode, 0, yRot, 0)
    if self:isDriveDirectionReverse() then
        --- Enables reverse path finding.
        setRotation(self.turnNode, 0, yRot + math.pi, 0)
    end

    local path = PathfinderUtil.findAnalyticPath(self:getReedsSheppSolver(), self.vehicle:getAIDirectionNode(), 0, self.turnNode,
    0, 0, self.turningRadius)
    if not path or #path == 0 then
        self:debug('Could not find ReedsShepp path, skipping turn!')
        self:startDrivingIntoSilo(course)
    else 
        self:rememberCourse(course, 1)
        self:debug('Found ReedsShepp turn path and prepended it.')
        local turnCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        self:startCourse(turnCourse, 1)
        self.state = self.states.DRIVING_TURN
        self:debug("Started driving turn to next lane.")
    end
end

function AIDriveStrategyBunkerSilo:getReedsSheppSolver()

    local forwardToReversePathWords = {
    --    ReedsShepp.PathWords.LfRbLb,
    --    ReedsShepp.PathWords.RfLbRb,
    --    ReedsShepp.PathWords.LfRfLb, 
     --   ReedsShepp.PathWords.RfLfRb,
        ReedsShepp.PathWords.LfRufLubRb,
        --LbRubLufRf = {},
        ReedsShepp.PathWords.RfLufRubLb,
        --RbLubRufLf = {},
    }
    
    local reverseToForwardPathWords = {
        ReedsShepp.PathWords.LbRfLf,
        ReedsShepp.PathWords.RbLfRf,
        ReedsShepp.PathWords.LbRbLf,
        ReedsShepp.PathWords.RbLbRf,
    }
    
    local pathWords = self:isDriveDirectionReverse() and forwardToReversePathWords or ReedsShepp.PathWords
    return ReedsSheppSolver()
end

--- Starts driving into the silo.
function AIDriveStrategyBunkerSilo:startDrivingIntoSilo(oldCourse)
    local firstWpIx
    if not oldCourse then 
        self.course, firstWpIx = self:getDriveIntoSiloCourse()
    else 
        self.course = oldCourse
        firstWpIx = self:getNearestWaypoints(oldCourse, self:isDriveDirectionReverse())
    end
    self:startCourse(self.course, firstWpIx)
    self.state = self.states.DRIVING_INTO_SILO
    self:lowerImplements()
    self:debug("Started driving into the silo.")
end

--- Start driving out of silo.
function AIDriveStrategyBunkerSilo:startDrivingOutOfSilo()
    local firstWpIx
    self.course, firstWpIx = self:getDriveOutOfSiloCourse(self.course)
    self:startCourse(self.course, firstWpIx)
    self.state = self.states.DRIVING_OUT_OF_SILO
    self:raiseImplements()
    self:debug("Started driving out of the silo.")
    self.driveIntoSiloAttempts = 0
end

function AIDriveStrategyBunkerSilo:startDrivingTemporaryOutOfSilo()
    self.lastCourse = self.course
    local driveDirection = self:isDriveDirectionReverse()
    if driveDirection then
		self.course = Course.createStraightForwardCourse(self.vehicle, self.isStuckBackOffset, 0)
	else 
        self.course = Course.createStraightReverseCourse(self.vehicle, self.isStuckBackOffset, 0)
	end
    self:startCourse(self.course, 1)
    self.state = self.states.DRIVING_TEMPORARY_OUT_OF_SILO
    self:raiseImplements()
    self.driveIntoSiloAttempts = self.driveIntoSiloAttempts + 1
    self:debug("Started driving temporary out of the silo. Attempts until now: %d", self.driveIntoSiloAttempts)
end

--- Create a straight course into the silo.
---@return Course generated course 
---@return number first waypoint of the course relative to the vehicle position.
function AIDriveStrategyBunkerSilo:getDriveIntoSiloCourse()
	local driveDirection = self:isDriveDirectionReverse()
	
    local startPos, endPos = self.siloController:getTarget(self:getWorkWidth())
    local x, z = unpack(startPos)
    local dx, dz = unpack(endPos)

    local course = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 0, 
                                                self:getStartOffset(), 0, 3, driveDirection)

	local firstWpIx = self:getNearestWaypoints(course, driveDirection)
	return course, firstWpIx
end

--- Create a straight course out of the silo.
---@param driveInCourse Course drive into the course, which will be inverted.
---@return Course generated course 
---@return number first waypoint of the course relative to the vehicle position.
function AIDriveStrategyBunkerSilo:getDriveOutOfSiloCourse(driveInCourse)
	local driveDirection = self:isDriveDirectionReverse()
    local x, _, z, dx, dz
    if driveInCourse then
        x, _, z = driveInCourse:getWaypointPosition(driveInCourse:getNumberOfWaypoints())
        dx, _, dz = driveInCourse:getWaypointPosition(1)
    else 
        local startPos, endPos = self.siloController:getLastTarget()
        x, z = unpack(endPos)
        dx, dz = unpack(startPos)
    end

	local course = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 0, -self:getEndOffset(), 
    self:getEndOffset(), 3, not driveDirection)
	local firstWpIx = self:getNearestWaypoints(course, not driveDirection)
	return course, firstWpIx
end

function AIDriveStrategyBunkerSilo:getNearestWaypoints(course, reverse)
    if reverse then 
        local ix = course:getNextRevWaypointIxFromVehiclePosition(1, self.vehicle:getAIDirectionNode(), 10)
        return ix
    end
    local firstWpIx = course:getNearestWaypoints(self.vehicle:getAIDirectionNode())
    return firstWpIx
end

--- Stops the driver, as the silo was deleted.
function AIDriveStrategyBunkerSilo:stopSiloWasDeleted()
    self.vehicle:stopCurrentAIJob(AIMessageErrorUnknown.new())
end

-----------------------------------------------------------------------------------------------------------------------
--- Leveler interactions
-----------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyBunkerSilo:isLevelerLoweringAllowed()
    return self.state == self.states.DRIVING_INTO_SILO
end

--- Ignores the bunker silo for the proximity sensors.
function AIDriveStrategyBunkerSilo:ignoreProximityObject(object, vehicle)
    if self.silo:isTheSameSilo(object) then
        return true 
    end
    --- This ignores the terrain.
    if object == nil then
        return true
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Pathfinding
---------------------------------------------------------------------------------------------------------------------------
---@param course Course
---@param ix number
function AIDriveStrategyBunkerSilo:startCourseWithPathfinding(course, ix, isReverse)
    if not self.pathfinder or not self.pathfinder:isActive() then
        -- set a course so the PPC is able to do its updates.
        self.course = course
        self.ppc:setCourse(self.course)
        self.ppc:initialize(ix)
        self:rememberCourse(course, ix)
        local x, _, z = course:getWaypointPosition(ix)
        self:debug('offsetx %.1f, x %.1f, z %.1f', course.offsetX, x, z)
        self.state = self.states.WAITING_FOR_PATHFINDER    
        self.pathfindingStartedAt = g_currentMission.time
        local done, path
        local _, steeringLength = AIUtil.getSteeringParameters(self.vehicle)
        -- always drive a behind the target waypoint so there's room to straighten out towed implements
        -- a bit before start working
        self:debug('Pathfinding to waypoint %d, with zOffset min(%.1f, %.1f)', ix, -self.frontMarkerDistance, -steeringLength)

        if not self.pathfinderNode then 
            self.pathfinderNode = WaypointNode('pathfinderNode')
        end
        self.pathfinderNode:setToWaypoint(course, 1)
        if isReverse then
            --- Enables reverse path finding.
            local _, yRot, _ = getRotation(self.pathfinderNode.node)
            setRotation(self.pathfinderNode.node, 0, yRot + math.pi, 0)
        end

        self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToNode(self.vehicle, self.pathfinderNode.node,
            0, 0, true)

        if done then
            return self:onPathfindingDoneToCourseStart(path)
        else
            self:setPathfindingDoneCallback(self, self.onPathfindingDoneToCourseStart)
            return true
        end
    else
        self:info('Pathfinder already active!')
        self.state = self.states.DRIVING_TO_SILO
        return false
    end
end

function AIDriveStrategyBunkerSilo:onPathfindingDoneToCourseStart(path)
    local course, ix = self:getRememberedCourseAndIx()
    if path and #path > 2 then
        self:debug('Pathfinding to silo finished with %d waypoints (%d ms)',
                #path, g_currentMission.time - (self.pathfindingStartedAt or 0))
        course = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        ix = 1
        self.state = self.states.DRIVING_TO_SILO
        self:startCourse(course, ix)
    else
        self:debug('Pathfinding to silo failed, directly start.')
        self:startDrivingIntoSilo(course)
        self.vehicle:raiseAIEvent("onAIFieldWorkerStart", "onAIImplementStart")
    end
end


function AIDriveStrategyBunkerSilo:startDrivingToParkPositionWithPathfinding()
    if not self:isDrivingToParkPositionAllowed() then 
        self:debug("Driving to park position is not allowed!")
        return 
    end
    self.vehicle:prepareForAIDriving()



    if not self.pathfinder or not self.pathfinder:isActive() then
        self.state = self.states.WAITING_FOR_PATHFINDER    
        self.pathfindingStartedAt = g_currentMission.time
        local done, path
        local _, steeringLength = AIUtil.getSteeringParameters(self.vehicle)
    
        self:debug('Pathfinding to park position, with zOffset min(%.1f, %.1f)', -self.frontMarkerDistance, -steeringLength)

        self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToNode(self.vehicle, self.parkNode,
            0, 0, true)

        if done then
            return self:onPathfindingDoneToParkPosition(path)
        else
            self:setPathfindingDoneCallback(self, self.onPathfindingDoneToParkPosition)
            return true
        end
    else
        self:info('Pathfinder already active!')
        self.state = self.states.DRIVING_TO_PARK_POSITION
        return false
    end
end

function AIDriveStrategyBunkerSilo:onPathfindingDoneToParkPosition(path)
    if path and #path > 2 then
        self:debug('Pathfinding to park position finished with %d waypoints (%d ms)',
                #path, g_currentMission.time - (self.pathfindingStartedAt or 0))
        local course = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        self.state = self.states.DRIVING_TO_PARK_POSITION
        self:startCourse(course, 1)
    else
        self:debug('Pathfinding park position failed, directly start.')
        self:startDrivingIntoSilo()
    end
end

