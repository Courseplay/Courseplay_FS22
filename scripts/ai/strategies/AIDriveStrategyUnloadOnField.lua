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

---@class AIDriveStrategyUnloadOnField : AIDriveStrategyCourse
AIDriveStrategyUnloadOnField = CpObject(AIDriveStrategyCourse)


-- when calculating a course to a trailer, do not end the course right at the target fill node, instead
-- unloadTargetOffset meters before that. This allows for a little distance to stop after the tractor
-- reaches the last waypoint, and the logic in unloadToTrailer() will move the rig to the exact position anyway.
AIDriveStrategyUnloadOnField.unloadTargetOffset = 1.5


AIDriveStrategyUnloadOnField.searchForTrailerDelaySec = 30 

--- Field unload constants
AIDriveStrategyUnloadOnField.siloAreaOffsetFieldUnload = 2
AIDriveStrategyUnloadOnField.unloadCourseLengthFieldUnload = 50


AIDriveStrategyUnloadOnField.activeUnloaders = {}

---------------------------------------------
--- State properties
---------------------------------------------
--[[
    fuelSaveAllowed : boolean              
    proximityControllerDisabled : boolean
]]

---------------------------------------------
--- Shared states
---------------------------------------------
AIDriveStrategyUnloadOnField.myStates = {
	IDLE = { fuelSaveAllowed = true },
    DRIVE_TO_FIELD_UNLOAD_POSITION = { collisionAvoidanceEnabled = true },
    WAITING_UNTIL_FIELD_UNLOAD_IS_ALLOWED = {},
    PREPARE_FOR_FIELD_UNLOAD = {},
    DRIVE_TO_REVERSE_FIELD_UNLOAD_POSITION = {},
    REVERSING_TO_THE_FIELD_UNLOAD_HEAP = {},
    UNLOADING_ON_THE_FIELD = { proximityControllerDisabled = true },
    DRIVE_TO_FIELD_UNLOAD_PARK_POSITION = {},
}


function AIDriveStrategyUnloadOnField:init(...)
    AIDriveStrategyCourse.init(self, ...)

    self.states = CpUtil.initStates(self.states, AIDriveStrategyUnloadOnField.myStates)
    self.state = self.states.INITIAL
    self.debugChannel = CpDebug.DBG_UNLOAD_COMBINE
	self.lastTrailerSearch = 0
end

function AIDriveStrategyUnloadOnField:delete()
    AIDriveStrategyCourse.delete(self)
    AIDriveStrategyUnloadOnField.activeUnloaders[self] = nil
end

------------------------------------------------------------------------------------------------------------------------
-- Start and initialization
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadOnField:startWithoutCourse()
    -- to always have a valid course (for the traffic conflict detector mainly)
    self.course = Course.createStraightForwardCourse(self.vehicle, 25)

    self:startCourse(self.course, 1)
end

function AIDriveStrategyUnloadOnField:getGeneratedCourse(jobParameters)
    return nil
end

function AIDriveStrategyUnloadOnField:setJobParameterValues(jobParameters)
    self.jobParameters = jobParameters
    local x, z = jobParameters.fieldPosition:getPosition()
    self.fieldPolygon = CpFieldUtil.getFieldPolygonAtWorldPosition(x, z)
    local fieldUnloadPosition = jobParameters.fieldUnloadPosition
    if fieldUnloadPosition ~= nil and fieldUnloadPosition.x ~= nil and fieldUnloadPosition.z ~= nil and fieldUnloadPosition.angle ~= nil then
        --- Valid field unload position found and allowed.
        self.fieldUnloadPositionNode = CpUtil.createNode("Field unload position", 
            fieldUnloadPosition.x, fieldUnloadPosition.z, fieldUnloadPosition.angle, nil)
        self.fieldUnloadTurnStartNode = CpUtil.createNode("Reverse field unload turn start position", 
            fieldUnloadPosition.x, fieldUnloadPosition.z, fieldUnloadPosition.angle, nil)
        self.fieldUnloadTurnEndNode = CpUtil.createNode("Reverse field unload turn end position", 
            fieldUnloadPosition.x, fieldUnloadPosition.z, fieldUnloadPosition.angle, nil)
        self.unloadTipSideID = jobParameters.unloadingTipSide:getValue()
    end
end

function AIDriveStrategyUnloadOnField:setAIVehicle(vehicle, jobParameters)
    AIDriveStrategyCourse.setAIVehicle(self, vehicle, jobParameters)
    self.reverser = AIReverseDriver(self.vehicle, self.ppc)
    self.proximityController = ProximityController(self.vehicle, self:getProximitySensorWidth())
    AIDriveStrategyUnloadOnField.activeUnloaders[self] = true
end

--- Waits until a trailer is found to unload into
function AIDriveStrategyUnloadOnField:startWaitingForSomethingToDo()
    if self.state ~= self.states.IDLE then
        self.course = Course.createStraightForwardCourse(self.vehicle, 25)
        self:setNewState(self.states.IDLE)
    end
end

--- Search for trailer target and start the self unload
function AIDriveStrategyUnloadOnField:startUnloadingTrailers()
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
	if self:startUnloadingOnField(controller, false) then
		self:debug('Trailer to unload to found, attempting self unload now')
	else
		self:debug('No trailer for self unload found, keep waiting')
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadOnField:getDriveData(dt, vX, vY, vZ)
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
    elseif self.state == self.states.DRIVE_TO_FIELD_UNLOAD_POSITION then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    elseif self.state == self.states.WAITING_UNTIL_FIELD_UNLOAD_IS_ALLOWED then
        self:waitingUntilFieldUnloadIsAllowed()
    elseif self.state == self.states.PREPARE_FOR_FIELD_UNLOAD then
        self:prepareForFieldUnload()
    elseif self.state == self.states.UNLOADING_ON_THE_FIELD then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
    elseif self.state == self.states.DRIVE_TO_REVERSE_FIELD_UNLOAD_POSITION then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    elseif self.state == self.states.REVERSING_TO_THE_FIELD_UNLOAD_HEAP then
        self:driveToReverseFieldUnloadHeap()
    elseif self.state == self.states.DRIVE_TO_FIELD_UNLOAD_PARK_POSITION then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    end
    self:checkProximitySensors(moveForwards)
    return gx, gz, moveForwards, self.maxSpeed, 100
end

function AIDriveStrategyUnloadOnField:update(dt)
    AIDriveStrategyCourse.update(self, dt)
    self:updateImplementControllers(dt)
end

function AIDriveStrategyUnloadOnField:draw()
	if CpUtil.isVehicleDebugActive(self.vehicle) and CpDebug:isChannelActive(self.debugChannel) then
        if self.course then
            self.course:draw()
        end
        if self.fieldUnloadPositionNode then
            CpUtil.drawDebugNode(self.fieldUnloadPositionNode, 
                false, 3, "Unload position node")
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Event listeners
------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyUnloadOnField:onWaypointPassed(ix, course)
    if course:isLastWaypointIx(ix) then
        self:onLastWaypointPassed()
    end
end

function AIDriveStrategyUnloadOnField:onLastWaypointPassed()
    self:debug('Last waypoint passed')
   	if self.state == self.states.DRIVE_TO_FIELD_UNLOAD_POSITION then
        self:setNewState(self.states.WAITING_UNTIL_FIELD_UNLOAD_IS_ALLOWED)
    elseif self.state == self.states.UNLOADING_ON_THE_FIELD then
        self:onFieldUnloadingFinished()
    elseif self.state == self.states.DRIVE_TO_REVERSE_FIELD_UNLOAD_POSITION then
        self:onReverseFieldUnloadPositionReached()
    elseif self.state == self.states.REVERSING_TO_THE_FIELD_UNLOAD_HEAP then
        self:onReverseFieldUnloadHeapReached()
    elseif self.state == self.states.DRIVE_TO_FIELD_UNLOAD_PARK_POSITION then
        self:onFieldUnloadParkPositionReached()
    end
end

----------------------------------------------------------
-- Implement controller handling.
------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyUnloadOnField:initializeImplementControllers(vehicle)
    local augerWagon, trailer
    augerWagon, self.pipeController = self:addImplementController(vehicle, 
        PipeController, Pipe, {}, nil)
    self:debug('Auger wagon was found: %s', CpUtil.getName(augerWagon))
    trailer, self.trailerController = self:addImplementController(vehicle, 
        TrailerController, Trailer, {}, nil)
    local sugarCaneTrailer = SugarCaneTrailerController.getValidTrailer(vehicle)
    self.trailer = augerWagon or trailer
    if sugarCaneTrailer then 
        self:debug("Found a sugar cane trailer: %s", CpUtil.getName(sugarCaneTrailer))
        self.trailer = sugarCaneTrailer
        self.sugarCaneTrailerController = SugarCaneTrailerController(vehicle, sugarCaneTrailer)
        self:appendImplementController(self.sugarCaneTrailerController)
    end
    self:addImplementController(vehicle, MotorController, Motorized, {})
    self:addImplementController(vehicle, WearableController, Wearable, {})
    self:addImplementController(vehicle, FoldableController, Foldable, {})
end

function AIDriveStrategyUnloadOnField:isFuelSaveAllowed()
    return self.state.properties.fuelSaveAllowed
end

function AIDriveStrategyUnloadOnField:isMoveablePipeDisabled()
    return self.state.properties.moveablePipeDisabled
end

------------------------------------------------------------------------------------------------------------------------
-- Unloading on the field
------------------------------------------------------------------------------------------------------------------------

--- Is the unloader unloading to a heap?
---@param ignoreDrivingToHeap boolean Ignore unloader, that are driving to the heap
---@return boolean
function AIDriveStrategyUnloadOnField:isUnloadingOnTheField(ignoreDrivingToHeap)
    if self.state == self.states.DRIVE_TO_FIELD_UNLOAD_POSITION and ignoreDrivingToHeap then
        return false
    end
    return true
end

---@return CpHeapBunkerSilo|nil
function AIDriveStrategyUnloadOnField:getFieldUnloadHeap()
    return self.fieldUnloadData and self.fieldUnloadData.heapSilo
end

--- Moves the field unload position to the center front of the heap.
function AIDriveStrategyUnloadOnField:updateFieldPositionByHeapSilo(heapSilo)
    local cx, cz = heapSilo:getFrontCenter()
    setTranslation(self.fieldUnloadPositionNode, cx, 0, cz)
    local dirX, dirZ = heapSilo:getLengthDirection()
    local yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
    setRotation(self.fieldUnloadPositionNode, 0, yRot, 0)
    --- Move the position a little bit inwards.
    local x, _, z = localToWorld(self.fieldUnloadPositionNode, 0, 0, 3)
    local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 3
    setTranslation(self.fieldUnloadPositionNode, x, y, z)
end


--- Starts the unloading on a field with an auger wagon or a trailer.
--- Drives to the heap/ field unload position: 
---     For reverse unloading an offset is applied only if an already existing heap was found.
---     For side unloading the x offset of the discharge node is applied. 
---@param controller UnloadImplementControllerInterface either a PipeController or TrailerController or SugarCaneTrailerController
---@param allowReverseUnloading boolean is unloading at the back allowed?
function AIDriveStrategyUnloadOnField:startUnloadingOnField(controller, allowReverseUnloading)
    --- Create unload course based on tip side setting(discharge node offset)
    local dischargeNodeIndex, dischargeNode, xOffset = 
        controller:getDischargeNodeAndOffsetForTipSide(
            self.unloadTipSideID, true)
    if not xOffset then
        self:info("No valid discharge node for field unload found!")
        self.vehicle:stopCurrentAIJob(AIMessageErrorGroundUnloadNotSupported.new())
        return
    end
    self:debug("Selected tipside: %d, dischargeNodeIndex: %d, xOffset: %.2f", self.unloadTipSideID, dischargeNodeIndex, xOffset)
    self.fieldUnloadData = {
        dischargeNodeIndex = dischargeNodeIndex,
        dischargeNode = dischargeNode,
        xOffset = xOffset,
        controller = controller,
        heapSilo = nil,
        isReverseUnloading = false

    }

    --- Search for a heap at the field unload position 
    --- for reverse unloading or to make sure the pathfinding
    --- is not crossing the heap area.
    local found, heapSilo = BunkerSiloManagerUtil.createHeapBunkerSilo(self.vehicle,
            self.fieldUnloadPositionNode, 0, CpAIJobCombineUnloader.maxHeapLength, -10)

    if found and heapSilo then
        --- Heap was found
        self.fieldUnloadData.heapSilo = heapSilo

        --- Set the unloading node in the center between heap sx/sz and wx/wz.
        self:updateFieldPositionByHeapSilo(heapSilo)

        if allowReverseUnloading then
            --- Reverse unloading is allowed, then check if the tip side xOffset is for reverse unloading <= 1 m.
            self.fieldUnloadData.isReverseUnloading = math.abs(self.fieldUnloadData.xOffset) - 1 <= 0
        end
        local vehicleWidth = AIUtil.getWidth(self.vehicle)
        local siloWidth = heapSilo:getWidth()
        self:debug("Vehicle width: %.2f, silo width: %.2f", vehicleWidth, siloWidth)
        if self.fieldUnloadData.isReverseUnloading then
            --- For reverse unloading the unloader needs to drive parallel to the heap.
            self.fieldUnloadData.xOffset = siloWidth / 2 + 2 * vehicleWidth / 3
        else
            --- Makes sure the x offset for unloading to the side is big enough 
            --- to make sure the unloader doesn't touch the heap. 
            self.fieldUnloadData.xOffset = MathUtil.sign(self.fieldUnloadData.xOffset) *
                    math.max(math.abs(self.fieldUnloadData.xOffset), siloWidth / 2 + 2 * vehicleWidth / 3)
        end

        self:debug("Found a heap for field unloading, reverseUnloading: %s, xOffset: %.2f, silo width: %.2f, vehicle width: %.2f",
                self.fieldUnloadData.isReverseUnloading, self.fieldUnloadData.xOffset, siloWidth, vehicleWidth)
    else
        self:debug("No heap found around the unloading position.")
    end

    --- Callback when the unloading has finished.
    self.fieldUnloadData.controller:setFinishDischargeCallback(self.onFieldUnloadingFinished)
    self:setNewState(self.states.WAITING_FOR_PATHFINDER)
   

    local context = PathfinderControllerContext(self.vehicle, 1)
    context:set(true, self:getAllowReversePathfinding(),
        nil, 0,
        false, nil, 
        nil, nil)
    self.pathfinderController:setCallbacks(self, self.onPathfindingDoneBeforeUnloadingOnField)
    self.pathfinderController:findPathToNode(context, self.fieldUnloadPositionNode, 
        -self.fieldUnloadData.xOffset, -AIUtil.getLength(self.vehicle) * 1.3)
end

function AIDriveStrategyUnloadOnField:onPathfindingDoneBeforeUnloadingOnField(controller, success, path, goalNodeInvalid)
    if success then
        self:setNewState(self.states.DRIVE_TO_FIELD_UNLOAD_POSITION)
        local course = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)

        --- Append straight alignment segment
        local x, _, z = course:getWaypointPosition(course:getNumberOfWaypoints())
        local _, _, dz = worldToLocal(self.fieldUnloadPositionNode, x, 0, z)
        local zOffset = 0
        if not self.fieldUnloadData.isReverseUnloading then
            --- For Side unloading make sure the discharge node is aligned correctly with the field unload node.
            zOffset = -self.fieldUnloadData.controller:getUnloadOffsetZ(self.fieldUnloadData.dischargeNode)
        end
        course:append(Course.createFromNode(self.vehicle, self.fieldUnloadPositionNode,
                -self.fieldUnloadData.xOffset, dz, zOffset, 3, false))
        self:startCourse(course, 1)
    else 
        self:info("Could not find a path to the field unload position!")
        self.vehicle:stopCurrentAIJob(AIMessageCpErrorNoPathFound.new())
    end
end

--- Checks if the silo is clear for unloading and not another unloader is currently unloading there.
function AIDriveStrategyUnloadOnField:waitingUntilFieldUnloadIsAllowed()
    self:setMaxSpeed(0)
    for strategy, _ in pairs(self.activeUnloaders) do
        if strategy ~= self then
            if strategy:isUnloadingOnTheField(true) then
                if self.fieldUnloadData.heapSilo and self.fieldUnloadData.heapSilo:isOverlappingWith(strategy:getFieldUnloadHeap()) then
                    self:debug("Is waiting for unloader: %s", CpUtil.getName(strategy:getVehicle()))
                    return
                end
            end
        end
    end
    self:onFieldUnloadPositionReached()
end

--- Called when the driver reaches the field unloading position.
function AIDriveStrategyUnloadOnField:onFieldUnloadPositionReached()

    --- Re-scan heap, as another unloader might have deformed it
    local found, heapSilo = BunkerSiloManagerUtil.createHeapBunkerSilo(self.vehicle,
            self.fieldUnloadPositionNode, 0, CpAIJobCombineUnloader.maxHeapLength, -10)
    if found and heapSilo then
        self:updateFieldPositionByHeapSilo(heapSilo)
        self.fieldUnloadData.heapSilo = heapSilo
    end

    if self.fieldUnloadData.isReverseUnloading then

        --- Trying to unload at the back of the trailer.
        --- Creating an alignment course to reach the heap end.
        local length = self.fieldUnloadData.heapSilo:getLength() + 5
        local alignmentCourse = Course.createStraightForwardCourse(self.vehicle,
                length, -self.fieldUnloadData.xOffset, self.fieldUnloadPositionNode)

        local _, steeringLength = AIUtil.getSteeringParameters(self.vehicle)
        local alignLength = math.max(self.vehicle.size.length / 2, steeringLength, self.turningRadius / 2) * 3

        local x, _, z = localToWorld(self.fieldUnloadPositionNode, 0, 0, length + alignLength)
        local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 3

        local dirX, _, dirZ = localDirectionToWorld(self.fieldUnloadPositionNode, 0, 0, 1)
        setTranslation(self.fieldUnloadTurnEndNode, x, y, z)
        local yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
        setRotation(self.fieldUnloadTurnEndNode, 0, yRot, 0)

        x, _, z = localToWorld(self.fieldUnloadPositionNode, -self.fieldUnloadData.xOffset, 0, length)
        y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 3
        setTranslation(self.fieldUnloadTurnStartNode, x, y, z)
        setRotation(self.fieldUnloadTurnStartNode, 0, yRot, 0)

        self:debug("Starting pathfinding to the reverse unload turn end node with align length: %.2f and steering length: %.2f, turn radius: %.2f",
                alignLength, steeringLength, self.turningRadius)
        local path = PathfinderUtil.findAnalyticPath(PathfinderUtil.dubinsSolver, self.fieldUnloadTurnStartNode,
                0, self.fieldUnloadTurnEndNode, 0, 3, self.turningRadius)
        if not path or #path == 0 then
            self:debug("Reverse alignment course creation failed!")
        else
            --- Adds the transition turn segment
            local alignmentTurnSegmentCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
            alignmentCourse:append(alignmentTurnSegmentCourse)

            --- Add a small straight segment at the end 
            --- to straighten the trailer out.
            alignmentCourse:append(Course.createStraightForwardCourse(self.vehicle,
                    AIUtil.getLength(self.vehicle), 0, self.fieldUnloadTurnEndNode))

            self:setNewState(self.states.DRIVE_TO_REVERSE_FIELD_UNLOAD_POSITION)
            self:startCourse(alignmentCourse, 1)
            self:debug("Starting to drive to the reverse unloading position for field unload.")
            return
        end
    end

    self:setNewState(self.states.PREPARE_FOR_FIELD_UNLOAD)
    self:debug("Field unload position reached and start preparing for unload.")
end

--- Driver is in front of the heap and ready to drive backwards to the heap end now.
function AIDriveStrategyUnloadOnField:onReverseFieldUnloadPositionReached()
    local course = Course.createFromNodeToNode(self.vehicle,
            self.vehicle:getAIDirectionNode(), self.fieldUnloadPositionNode,
            0, 0, 5, 3, true)
    self:setNewState(self.states.REVERSING_TO_THE_FIELD_UNLOAD_HEAP)
    self:startCourse(course, 1)
end

--- Reverse driving to the heap.
function AIDriveStrategyUnloadOnField:driveToReverseFieldUnloadHeap()
    --- Checks if the heap end was reached.
    local node = self.fieldUnloadData.dischargeNode.node
    if self.fieldUnloadData.heapSilo:isNodeInSilo(node) then
        self:onReverseFieldUnloadHeapReached()
    end
end

function AIDriveStrategyUnloadOnField:onReverseFieldUnloadHeapReached()
    self:setNewState(self.states.PREPARE_FOR_FIELD_UNLOAD)
    self:debug("Reverse field unload position reached and start preparing for unload.")
end

--- Prepares the auger wagon/trailer for unloading.
--- Waits for the pipe of the auger wagon to unfold.
--- After that unload and use a straight forward course.
function AIDriveStrategyUnloadOnField:prepareForFieldUnload()
    self:setMaxSpeed(0)
    if self.fieldUnloadData.controller:prepareForUnload() then
        self:debug("Finished preparing for unloading.")
        self:setNewState(self.states.UNLOADING_ON_THE_FIELD)

        if not self.fieldUnloadData.controller:startDischargeToGround(self.fieldUnloadData.dischargeNode) then
            self:info("Could not start discharge to ground!")
            self.vehicle:stopCurrentAIJob(AIMessageErrorGroundUnloadNotSupported.new())
            return
        end

        --- For now we create a simple straight forward course to unload.
        local xOffset = self.fieldUnloadData.isReverseUnloading and 0 or -self.fieldUnloadData.xOffset
        local length = self.unloadCourseLengthFieldUnload
        if self.fieldUnloadData.heapSilo and not self.fieldUnloadData.isReverseUnloading then
            length = length + self.fieldUnloadData.heapSilo:getLength()
        end
        local unloadCourse = Course.createStraightForwardCourse(self.vehicle, length, xOffset, self.fieldUnloadPositionNode)
        self:startCourse(unloadCourse, 1)
        self:debug("Started unload course with a length of %d and offset of %.2f", length, xOffset)
    end
end

--- Finished unloading and search for a park course that is on the opposite xOffset from the heap.
function AIDriveStrategyUnloadOnField:onFieldUnloadingFinished()
    local x, _, z = localToWorld(self.fieldUnloadPositionNode, 0, 0, 0)
    setTranslation(self.fieldUnloadTurnEndNode, x, 0, z)
    local dirX, _, dirZ = localDirectionToWorld(self.fieldUnloadPositionNode, 0, 0, 1)
    local rotY = MathUtil.getYRotationFromDirection(dirX, dirZ)
    setRotation(self.fieldUnloadTurnEndNode, 0, rotY + math.pi, 0)

    if not self.fieldUnloadData.heapSilo then
        --- Set the valid heap, when trying to drive to the park position 
        --- after creating the heap for the first time.
        --- This makes sure that the park position doesn't cross the heap. 
        local found, heapSilo = BunkerSiloManagerUtil.createHeapBunkerSilo(self.vehicle,
                self.fieldUnloadPositionNode, 0, CpAIJobCombineUnloader.maxHeapLength, -2)

        if found and heapSilo then
            self:updateFieldPositionByHeapSilo(heapSilo)
            local vehicleWidth = AIUtil.getWidth(self.vehicle)
            local siloWidth = heapSilo:getWidth()
            self:debug("Vehicle width: %.2f, silo width: %.2f", vehicleWidth, siloWidth)
            if self.fieldUnloadData.xOffset == 0 then
                --- First time park position for reverse unload offset always on the left of the heap.
                self.fieldUnloadData.xOffset = siloWidth / 2 + 2 * vehicleWidth / 3
            else
                self.fieldUnloadData.xOffset = MathUtil.sign(self.fieldUnloadData.xOffset) *
                        math.max(math.abs(self.fieldUnloadData.xOffset), siloWidth / 2 + 2 * vehicleWidth / 3)
            end
            self:debug("Found a heap for field unloading park position xOffset: %.2f", self.fieldUnloadData.xOffset)
        end
    end

    self:setNewState(self.states.WAITING_FOR_PATHFINDER)
    self:debug("Disabling off-field penalty for driving to the park position.")
    
    local context = PathfinderControllerContext(self.vehicle, 1)
    context:set(true, self:getAllowReversePathfinding(),
        nil, 0,
        false, nil, 
        nil, nil)
    self.pathfinderController:setCallbacks(self, self.onPathfindingDoneBeforeDrivingToFieldUnloadParkPosition)
    self.pathfinderController:findPathToNode(context, self.fieldUnloadTurnEndNode, 
        -self.fieldUnloadData.xOffset * 1.5, -AIUtil.getLength(self.vehicle))
end

--- Course to the park position found.
function AIDriveStrategyUnloadOnField:onPathfindingDoneBeforeDrivingToFieldUnloadParkPosition(controller, success, path, goalNodeInvalid)
    if success then
        self:setNewState(self.states.DRIVE_TO_FIELD_UNLOAD_PARK_POSITION)
        local course = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)

        --- Append straight alignment segment
        local x, _, z = course:getWaypointPosition(course:getNumberOfWaypoints())
        local _, _, dz = worldToLocal(self.fieldUnloadTurnEndNode, x, 0, z)
        course:append(Course.createFromNode(self.vehicle, self.fieldUnloadTurnEndNode,
                -self.fieldUnloadData.xOffset * 1.5, dz, 0, 1, false))
        self:startCourse(course, 1)
    else
        self:debug("No path to the field unload park position found!")
        self:finishTask()
    end
end

function AIDriveStrategyUnloadOnField:onFieldUnloadParkPositionReached()
    self:debug("Field unload finished and park position reached.")
    self:finishTask()
end