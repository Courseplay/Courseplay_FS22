--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2023 Courseplay Dev Team

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

---@class AIDriveStrategySelfUnload : AIDriveStrategyCourse
AIDriveStrategySelfUnload = CpObject(AIDriveStrategyCourse)


-- when moving out of way of another vehicle, move at least so many meters
AIDriveStrategySelfUnload.minDistanceWhenMovingOutOfWay = 5
-- when moving out of way of another vehicle, move at most so many meters
AIDriveStrategySelfUnload.maxDistanceWhenMovingOutOfWay = 25
AIDriveStrategySelfUnload.safeManeuveringDistance = 30 -- distance to keep from a combine not ready to unload
AIDriveStrategySelfUnload.pathfindingRange = 5 -- won't do pathfinding if target is closer than this
AIDriveStrategySelfUnload.proximitySensorRange = 15
AIDriveStrategySelfUnload.maxDirectionDifferenceDeg = 35 -- under this angle the unloader considers itself aligned with the combine
-- Add a short straight section to align with the combine's course in case it is late for the rendezvous
AIDriveStrategySelfUnload.driveToCombineCourseExtensionLength = 10

-- Developer hack: to check the class of an object one should use the is_a() defined in CpObject.lua.
-- However, when we reload classes on the fly during the development, the is_a() calls in other modules still
-- have the old class definition (for example CombineUnloadManager.lua) of this class and thus, is_a() fails.
-- Therefore, use this instead, this is safe after a reload.
AIDriveStrategySelfUnload.isACombineUnloadAIDriver = true

-- when calculating a course to a trailer, do not end the course right at the target fill node, instead
-- unloadTargetOffset meters before that. This allows for a little distance to stop after the tractor
-- reaches the last waypoint, and the logic in unloadToTrailer() will move the rig to the exact position anyway.
AIDriveStrategySelfUnload.unloadTargetOffset = 1.5

--- Offset to apply at the goal marker, so we don't crash with an empty unloader waiting there with the same position.
AIDriveStrategySelfUnload.invertedGoalPositionOffset = -4.5


AIDriveStrategySelfUnload.searchForTrailerDelaySec = 30 


---------------------------------------------
--- State properties
---------------------------------------------
--[[
    fuelSaveAllowed : boolean              
    moveablePipeDisabled : boolean
]]

---------------------------------------------
--- Shared states
---------------------------------------------
AIDriveStrategySelfUnload.myStates = {
	IDLE = { fuelSaveAllowed = true },
    DRIVING_TO_SELF_UNLOAD = {},
    WAITING_UNTIL_UNLOAD_CAN_BEGIN = {},
    UNLOADING_TO_TRAILER = {},
    MOVING_TO_NEXT_FILL_NODE = { moveablePipeDisabled = true },
    MOVING_AWAY_FROM_UNLOAD_TRAILER = { moveablePipeDisabled = true },
}


function AIDriveStrategySelfUnload:init(...)
    AIDriveStrategyCourse.init(self, ...)

    self.states = CpUtil.initStates(self.states, AIDriveStrategySelfUnload.myStates)
    self.state = self.states.INITIAL
    self.debugChannel = CpDebug.DBG_UNLOAD_COMBINE
	self.lastTrailerSearch = 0
end

function AIDriveStrategySelfUnload:delete()
    AIDriveStrategyCourse.delete(self)
end

------------------------------------------------------------------------------------------------------------------------
-- Start and initialization
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategySelfUnload:startWithoutCourse()
    -- to always have a valid course (for the traffic conflict detector mainly)
    self.course = Course.createStraightForwardCourse(self.vehicle, 25)

    self:startCourse(self.course, 1)
end

function AIDriveStrategySelfUnload:getGeneratedCourse(jobParameters)
    return nil
end

function AIDriveStrategySelfUnload:setJobParameterValues(jobParameters)
    self.jobParameters = jobParameters
    local x, z = jobParameters.fieldPosition:getPosition()
    self.fieldPolygon = CpFieldUtil.getFieldPolygonAtWorldPosition(x, z)
end

function AIDriveStrategySelfUnload:setAIVehicle(vehicle, jobParameters)
    AIDriveStrategyCourse.setAIVehicle(self, vehicle, jobParameters)
    self.reverser = AIReverseDriver(self.vehicle, self.ppc)
    self.proximityController = ProximityController(self.vehicle, self:getProximitySensorWidth())
end

--- Waits until a trailer is found to unload into
function AIDriveStrategySelfUnload:startWaitingForSomethingToDo()
    if self.state ~= self.states.IDLE then
        self.course = Course.createStraightForwardCourse(self.vehicle, 25)
        self:setNewState(self.states.IDLE)
    end
end

--- Search for trailer target and start the self unload
function AIDriveStrategySelfUnload:startUnloadingTrailers()
    --- TODO: maybe enable sugar cane unload with autodrive 
    --- and not restrict those trailers to overload only.
	local controller = self.trailerController
	if self.pipeController then 
		self:debug("Unloading an auger wagon")
		controller = self.pipeController
	elseif self.sugarCaneTrailerController then
		self:debug("Unloading an sugar cane trailer")
		controller = self.sugarCaneTrailerController
	else 
		self:debug("Unloading a normal trailer")
	end
	if self:startSelfUnload(controller) then
		self:debug('Trailer to unload found, attempting self unload now')
	else
		self:debug('No trailer for self unload found, keep waiting')
	end
end


------------------------------------------------------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategySelfUnload:getDriveData(dt, vX, vY, vZ)
    self:updateLowFrequencyImplementControllers()

    local moveForwards = not self.ppc:isReversing()
    local gx, gz, _

    ----------------------------------------------------------------
    if not moveForwards then
        local maxSpeed
        gx, gz, maxSpeed = self:getReverseDriveData()
        self:setMaxSpeed(maxSpeed)
    else
        gx, _, gz = self.ppc:getGoalPointPosition()
    end

    if self.state == self.states.INITIAL then
        if not self.startTimer then
            --- Only create one instance of the timer and wait until it finishes.
            self.startTimer = Timer.createOneshot(50, function ()
                --- Pipe measurement seems to be buggy with a few over loaders, like bergman RRW 500,
                --- so a small delay of 50 ms is inserted here before unfolding starts.
                self.vehicle:raiseAIEvent("onAIFieldWorkerStart", "onAIImplementStart")
               	self:startWaitingForSomethingToDo()
                self.startTimer = nil
            end)
        end
        self:setMaxSpeed(0)
    elseif self.state == self.states.WAITING_FOR_PATHFINDER then
        -- just wait for the pathfinder to finish
        self:setMaxSpeed(0)
	elseif self.state == self.states.IDLE then
		self:setMaxSpeed(0)
		if (g_time - self.lastTrailerSearch) > self.searchForTrailerDelaySec * 1000 then
            self:startUnloadingTrailers()
            self.lastTrailerSearch = g_time
        end
    elseif self.state == self.states.DRIVING_TO_SELF_UNLOAD then
        self:driveToSelfUnload()
    elseif self.state == self.states.WAITING_UNTIL_UNLOAD_CAN_BEGIN then
        self:prepareForUnloadToTrailer()
    elseif self.state == self.states.UNLOADING_TO_TRAILER then
        moveForwards = self:unloadToTrailer()
    elseif self.state == self.states.MOVING_TO_NEXT_FILL_NODE then
        moveForwards = self:moveToNextFillNode()
    elseif self.state == self.states.MOVING_AWAY_FROM_UNLOAD_TRAILER then
        self:moveAwayFromUnloadTrailer()
    elseif self.state == self.states.DRIVING_BACK_TO_START_POSITION_WHEN_FULL then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    end
    self:checkProximitySensors(moveForwards)
    return gx, gz, moveForwards, self.maxSpeed, 100
end

function AIDriveStrategySelfUnload:update(dt)
    AIDriveStrategyCourse.update(self, dt)
    self:updateImplementControllers(dt)
end

function AIDriveStrategySelfUnload:draw()
	if CpUtil.isVehicleDebugActive(self.vehicle) and CpDebug:isChannelActive(self.debugChannel) then
        if self.course then
            self.course:draw()
        end
        if self.targetNode then
            CpUtil.drawDebugNode(self.targetNode, 
                false, 0, 'Target')
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Event listeners
------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategySelfUnload:onWaypointPassed(ix, course)
    if course:isLastWaypointIx(ix) then
        self:onLastWaypointPassed()
    end
end

function AIDriveStrategySelfUnload:onLastWaypointPassed()
    self:debug('Last waypoint passed')
   	if self.state == self.states.DRIVING_TO_SELF_UNLOAD then
        self:onLastWaypointPassedWhenDrivingToSelfUnload()
    elseif self.state == self.states.MOVING_TO_NEXT_FILL_NODE then
        -- should just for safety
        self:startMovingAwayFromUnloadTrailer()
    elseif self.state == self.states.MOVING_AWAY_FROM_UNLOAD_TRAILER then
        self:onMovedAwayFromUnloadTrailer()
    end
end

----------------------------------------------------------
-- Implement controller handling.
------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategySelfUnload:initializeImplementControllers(vehicle)
    local augerWagon, trailer
    augerWagon, self.pipeController = self:addImplementController(vehicle, 
        PipeController, Pipe, {}, nil)
    self:debug('Auger wagon found: %s', CpUtil.getName(augerWagon))
    trailer, self.trailerController = self:addImplementController(vehicle, 
        TrailerController, Trailer, {}, nil)
    local sugarCaneTrailer = SugarCaneTrailerController.getValidTrailer(vehicle)
    self.trailer = trailer or augerWagon
    if sugarCaneTrailer then 
        self:debug('Sugar cane trailer found: %s', CpUtil.getName(sugarCaneTrailer))
        self.trailer = sugarCaneTrailer
        self.sugarCaneTrailerController = SugarCaneTrailerController(vehicle, sugarCaneTrailer)
        self:appendImplementController(self.sugarCaneTrailerController)
    end
    self:addImplementController(vehicle, MotorController, Motorized, {}, nil)
    self:addImplementController(vehicle, WearableController, Wearable, {}, nil)
    self:addImplementController(vehicle, FoldableController, Foldable, {})
end

function AIDriveStrategySelfUnload:isFuelSaveAllowed()
    return self.state.properties.fuelSaveAllowed
end

function AIDriveStrategySelfUnload:isMoveablePipeDisabled()
    return self.state.properties.moveablePipeDisabled
end

-----------------------------------------------------------------------------------------------------------------------
--- Self unload
-----------------------------------------------------------------------------------------------------------------------

function AIDriveStrategySelfUnload:getSelfUnloadTargetParameters(xOffset)
    return SelfUnloadHelper:getTargetParameters(
            self.fieldPolygon,
            self.vehicle,
    -- TODO: this is just a shot in the dark there should be a better way to find out what we have in
    -- the trailer
            self.trailer:getFillUnitFirstSupportedFillType(1),
            xOffset)
end

--- Find a path to the best trailer to unload
---@param controller UnloadImplementControllerInterface
---@param ignoreFruit boolean|nil if true, do not attempt to avoid fruit
function AIDriveStrategySelfUnload:startSelfUnload(controller, ignoreFruit)
    self:setNewState(self.states.WAITING_FOR_PATHFINDER)
    local _
    self.dischargeNodeIndex, self.dischargeNode, self.xOffset = controller:getDischargeNodeAndOffsetForTipSide() 
    self.targetNode, self.alignLength, _, self.unloadTrailer = self:getSelfUnloadTargetParameters(self.xOffset)
    if not self.targetNode  then
        return false
    end
    self.unloadController = controller
    self.zOffset = controller:getUnloadOffsetZ(self.dischargeNode)

    -- little straight section parallel to the trailer to align better
    self:debug('Align course relative to target node from %.1f to %.1f, pipe offset %.1f',
            -self.alignLength + 1, -self.zOffset - self.unloadTargetOffset, self.zOffset)

    local context = PathfinderControllerContext(self.vehicle, 1)
    context:set(true, self:getAllowReversePathfinding(),
        nil, 0.1,
        true, nil, 
        nil, nil)
    self.pathfinderController:setCallbacks(self, self.onStartSelfUnloadPathfindingDone, self.onStartSelfUnloadPathfindingFailed)
    self.pathfinderController:findPathToNode(context, self.targetNode, -self.xOffset, -self.alignLength)
    return true
end

function AIDriveStrategySelfUnload:onStartSelfUnloadPathfindingDone(controller, success, path, goalNodeInvalid)
    if success then 
        self:debug("Found a valid path for self unloading")
        local selfUnloadCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        local selfUnloadAlignCourse = Course.createFromNode(self.vehicle, self.targetNode,
                -self.xOffset, -self.alignLength + 1,
                -self.zOffset - self.unloadTargetOffset,
                1, false)
        selfUnloadCourse:append(selfUnloadAlignCourse)
        self:setNewState(self.states.DRIVING_TO_SELF_UNLOAD)
        self:startCourse(selfUnloadCourse, 1)
    else 
        self:info("No valid path for self unload found!")
        self.vehicle:stopCurrentAIJob(AIMessageCpErrorNoPathFound.new())
    end
end

function AIDriveStrategySelfUnload:onStartSelfUnloadPathfindingFailed(controller, wasLastRetry, numberOfFails)
    self:debug("Retrying once with fruit disabled.")
    local context = self.pathfinderController:getLastContext()
    context:ignoreFruit()
    self.pathfinderController:findPathToNode(context, self.targetNode, -self.xOffset, -self.alignLength)
end

------------------------------------------------------------------------------------------------------------------------
-- Driving to a trailer to unload an auger wagon
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategySelfUnload:driveToSelfUnload()
    if self.course:isCloseToLastWaypoint(25) then
        -- disable one side of the proximity sensors to avoid being blocked by the trailer or its tractor
        -- TODO: make it work with pipe on the right side
        if self.xOffset > 0 then
            self.proximityController:disableLeftSide()
        elseif self.xOffset < 0 then
            self.proximityController:disableRightSide()
        end
    end
    -- slow down towards the end of course
    if self.course:isCloseToLastWaypoint(5) then
        self:setMaxSpeed(5)
    elseif self.course:isCloseToLastWaypoint(15) then
        self:setMaxSpeed(self.settings.turnSpeed:getValue())
    else
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    end
end

function AIDriveStrategySelfUnload:onLastWaypointPassedWhenDrivingToSelfUnload()
    self:setNewState(self.states.WAITING_UNTIL_UNLOAD_CAN_BEGIN)
end

------------------------------------------------------------------------------------------------------------------------
-- Once at the trailer, waiting for the auger wagon's pipe to open
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategySelfUnload:prepareForUnloadToTrailer()
    self:setMaxSpeed(0)
    if self.unloadController:prepareForUnload() then
        self.unloadController:setFinishDischargeCallback(self.finishedUnloadingToTrailerCallback)
        self.unloadController:startDischarge(self.dischargeNode)
        self:setNewState(self.states.UNLOADING_TO_TRAILER)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Unload the auger wagon into the trailer
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategySelfUnload:unloadToTrailer()
    local _, _, dz = localToLocal( self.dischargeNode.node, self.targetNode, 0, 0, 0)
    -- move forward or backward slowly until the pipe is within 20 cm of target
    self:setMaxSpeed((math.abs(dz) > 0.2) and 1 or 0)
    -- forward or backward
    return dz < 0
end

function AIDriveStrategySelfUnload:finishedUnloadingToTrailerCallback(controller, fillLevelPercentage)
    self:debug("Finished unloading to %s", CpUtil.getName(self.unloadTrailer))
	self:debug('Unloading to trailer ended, my fill level percentage is %.1f', fillLevelPercentage)
	if fillLevelPercentage < 10 then
		self:startMovingAwayFromUnloadTrailer()
	else
        local unloadTrailer, _
        self.targetNode, _, _, unloadTrailer = self:getSelfUnloadTargetParameters(self.xOffset)
        if self.targetNode and unloadTrailer == self.unloadTrailer then
            self:debug('Still fill level percentage leftover %.1f and the same trailer (%s) seems to have capacity',
                fillLevelPercentage, CpUtil.getName(unloadTrailer))
            self:startMovingToNextFillNode(self.targetNode)
        else
            -- done with this trailer, move away from it and wait for the
            self:debug('Still fill level percentage leftover %.1f but done with this trailer (%s) as it is full',
                fillLevelPercentage, CpUtil.getName(self.unloadTrailer))
            self:startMovingAwayFromUnloadTrailer(true)
        end
	end
end

-- Start moving to the next fill node of the same trailer
function AIDriveStrategySelfUnload:startMovingToNextFillNode(newSelfUnloadTargetNode)
    local _, _, dz = localToLocal(newSelfUnloadTargetNode, self.vehicle:getAIDirectionNode(),
            0, 0, -self.zOffset)
    local selfUnloadCourse
    if dz > 0 then
        -- next fill node is in front of us, move forward
        selfUnloadCourse = Course.createFromNode(self.vehicle, self.vehicle:getAIDirectionNode(),
                0, 0, dz + 2, 1, false)
    else
        -- next fill node behind us, need to reverse
        local reverserNode = AIUtil.getReverserNode(self.vehicle, self.trailer)
        selfUnloadCourse = Course.createFromNode(self.vehicle, reverserNode, 
            0, 0, dz - 2, 1, true)
    end
    self:debug('Course to next target node of the same trailer created, dz = %.1f', dz)
    self:setNewState(self.states.MOVING_TO_NEXT_FILL_NODE)
    self:startCourse(selfUnloadCourse, 1)
end

-- Move forward or backward until we can discharge again
function AIDriveStrategySelfUnload:moveToNextFillNode()
    local currentDischargeNode = self.dischargeNode
    local _, _, dz = localToLocal(currentDischargeNode.node, self.targetNode, 0, 0, 0)

    -- move forward or backward slowly towards the target fill node
    self:setMaxSpeed((math.abs(dz) > 0.2) and 1 or 0)

    if self.trailer:getCanDischargeToObject(currentDischargeNode) then
        self:debug('Can discharge again, moving closer to the fill node')
        self:setNewState(self.states.UNLOADING_TO_TRAILER)
    end

    return dz < 0
end

-- Move a bit forward and away from the trailer/tractor we just unloaded into so the
-- pathfinder won't have problems when search for a path to the combine
---@param attemptToUnloadAgainAfterMovedAway boolean|nil after moved away, attempt to find a trailer to unload
--- again as the auger wagon isn't empty yet
function AIDriveStrategySelfUnload:startMovingAwayFromUnloadTrailer(attemptToUnloadAgainAfterMovedAway)
    self.attemptToUnloadAgainAfterMovedAway = attemptToUnloadAgainAfterMovedAway
    self.course = Course.createStraightForwardCourse(self.vehicle, self.maxDistanceWhenMovingOutOfWay,
            -self.xOffset / 2)
    self:setNewState(self.states.MOVING_AWAY_FROM_UNLOAD_TRAILER)
    self:startCourse(self.course, 1)
end

function AIDriveStrategySelfUnload:moveAwayFromUnloadTrailer()
    local _, _, dz = localToLocal(self.unloadTrailer.rootNode, Markers.getBackMarkerNode(self.vehicle), 0, 0, 0)
    -- (conveniently ignoring the length offset)
    -- move until our tractor's back marker does not overlap the trailer or it's tractor
    if dz < -math.max(self.unloadTrailer.size.length / 2, self.unloadTrailer.rootVehicle.size.length / 2) then
        self:onMovedAwayFromUnloadTrailer()
    else
        self:setMaxSpeed(5)
    end
end

function AIDriveStrategySelfUnload:onMovedAwayFromUnloadTrailer()
    self.proximityController:enableBothSides()
    if self.attemptToUnloadAgainAfterMovedAway then
        self:debug('Moved away from trailer so the pathfinder will work, look for another trailer')
        self:startUnloadingTrailers()
    else
        self:debug('Finished the over loading protocol')
        self:finishTask()
    end
end
