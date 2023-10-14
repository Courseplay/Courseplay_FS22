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
]]--

--[[

How do we make sure the unloader does not collide with the combine?

1. ProximitySensor

The ProximitySensor is a generic AIDriver feature.

The combine has a proximity sensor on the back and will slow down and stop
if something is in range.

The unloader has a proximity sensor on the front to prevent running into the combine
and to swerve other vehicles in case of a head on collision for example.

In some states, for instance when unloading choppers, the tractor disables the generic
speed control as it has to drive very close to the chopper.

There is an additional proximity sensor dedicated to following the chopper. This has
all controlling features disabled.

2. Turns

The combine stops when discharging during a turn, so at the end of a row or headland turn
it won't start the turn until it is empty.

3. Combine Ready For Unload

The unloader can also ask the combine if it is ready to unload (isReadyToUnload()), as we
expect the combine to know best when it is going to perform some maneuvers.

4. Cooperative Collision Avoidance Using the TrafficController

This is currently screwed up...

---------------------------------------------
--- Unload target possibilities
---------------------------------------------

1. Combines working on an field(no chopper!)

2. Silo loader picking up fill types dropped to the ground(heap) on the field or near the field.

---------------------------------------------
--- Unload the loaded fill volume possibilities
---------------------------------------------

1. Auger wagon can unload to nearby trailers

2. Trailer can be sent to unload either with Autodrive or Giants unloader.

3. Unloading on the field, which means dropping it on the ground to create an heap.

]]--

--- Strategy to unload combines or stationary silo loaders.
---@class AIDriveStrategyUnloadCombine : AIDriveStrategyCourse
---@field combineUnloadStates table
---@field trailerUnloadStates table
---@field fieldUnloadStates table
AIDriveStrategyUnloadCombine = {}
local AIDriveStrategyUnloadCombine_mt = Class(AIDriveStrategyUnloadCombine, AIDriveStrategyCourse)

-- when moving out of way of another vehicle, move at least so many meters
AIDriveStrategyUnloadCombine.minDistanceWhenMovingOutOfWay = 5
-- when moving out of way of another vehicle, move at most so many meters
AIDriveStrategyUnloadCombine.maxDistanceWhenMovingOutOfWay = 25
AIDriveStrategyUnloadCombine.safeManeuveringDistance = 30 -- distance to keep from a combine not ready to unload
AIDriveStrategyUnloadCombine.pathfindingRange = 5 -- won't do pathfinding if target is closer than this
AIDriveStrategyUnloadCombine.proximitySensorRange = 15
AIDriveStrategyUnloadCombine.maxDirectionDifferenceDeg = 35 -- under this angle the unloader considers itself aligned with the combine
-- Add a short straight section to align with the combine's course in case it is late for the rendezvous
AIDriveStrategyUnloadCombine.driveToCombineCourseExtensionLength = 10

-- Developer hack: to check the class of an object one should use the is_a() defined in CpObject.lua.
-- However, when we reload classes on the fly during the development, the is_a() calls in other modules still
-- have the old class definition (for example CombineUnloadManager.lua) of this class and thus, is_a() fails.
-- Therefore, use this instead, this is safe after a reload.
AIDriveStrategyUnloadCombine.isACombineUnloadAIDriver = true

-- when calculating a course to a trailer, do not end the course right at the target fill node, instead
-- unloadTargetOffset meters before that. This allows for a little distance to stop after the tractor
-- reaches the last waypoint, and the logic in unloadAugerWagon() will move the rig to the exact position anyway.
AIDriveStrategyUnloadCombine.unloadTargetOffset = 1.5

--- Offset to apply at the goal marker, so we don't crash with an empty unloader waiting there with the same position.
AIDriveStrategyUnloadCombine.invertedGoalPositionOffset = -4.5

--- Field unload constants
AIDriveStrategyUnloadCombine.siloAreaOffsetFieldUnload = 2
AIDriveStrategyUnloadCombine.unloadCourseLengthFieldUnload = 50

--- Unload modes
AIDriveStrategyUnloadCombine.UNLOAD_TYPES = {
    COMBINE = 1,
    SILO_LOADER = 2
}

---------------------------------------------
--- State properties
---------------------------------------------
--[[
    fuelSaveAllowed : boolean              
    collisionAvoidanceEnabled : boolean
    proximityControllerDisabled : boolean
    openCoverAllowed : boolean
    moveablePipeDisabled : boolean
    vehicle : table|nil
]]

---------------------------------------------
--- Shared states
---------------------------------------------
AIDriveStrategyUnloadCombine.myStates = {
    IDLE = { fuelSaveAllowed = true }, --- Only allow fuel save, if the unloader is waiting for a combine.
    WAITING_FOR_PATHFINDER = {},

    --- States to maneuver away from combines and so on.
    --- No need to be assigned to a combine!
    MOVING_BACK = { vehicle = nil },
    MOVING_BACK_WITH_TRAILER_FULL = { vehicle = nil }, -- moving back from a combine we just unloaded (not assigned anymore)
    BACKING_UP_FOR_REVERSING_COMBINE = { vehicle = nil }, -- reversing as long as the combine is reversing
    MOVING_AWAY_FROM_OTHER_VEHICLE = { vehicle = nil }, -- moving until we have enough space between us and an other vehicle
    WAITING_FOR_MANEUVERING_COMBINE = {},
    DRIVING_BACK_TO_START_POSITION_WHEN_FULL = {} --- Drives to the start position with a trailer attached and gives control to giants or AD there.
}

-------------------------------------------------
--- Unloading of a combine or silo loader states
--- Needs an assigned vehicle to work!
-------------------------------------------------
AIDriveStrategyUnloadCombine.myCombineUnloadStates = {
    DRIVING_TO_COMBINE = { collisionAvoidanceEnabled = true },
    DRIVING_TO_MOVING_COMBINE = { collisionAvoidanceEnabled = true },
    UNLOADING_MOVING_COMBINE = { openCoverAllowed = true },
    UNLOADING_STOPPED_COMBINE = { openCoverAllowed = true },
}

---------------------------------------------
--- Unloading into trailer states
---------------------------------------------
AIDriveStrategyUnloadCombine.myTrailerUnloadStates = {
    DRIVING_TO_SELF_UNLOAD = { collisionAvoidanceEnabled = true },
    WAITING_FOR_AUGER_PIPE_TO_OPEN = {},
    UNLOADING_AUGER_WAGON = {},
    MOVING_TO_NEXT_FILL_NODE = { moveablePipeDisabled = true },
    MOVING_AWAY_FROM_UNLOAD_TRAILER = { moveablePipeDisabled = true },
}

---------------------------------------------
--- Field unload states states
---------------------------------------------
AIDriveStrategyUnloadCombine.myFieldUnloadStates = {
    DRIVE_TO_FIELD_UNLOAD_POSITION = { collisionAvoidanceEnabled = true },
    WAITING_UNTIL_FIELD_UNLOAD_IS_ALLOWED = {},
    PREPARE_FOR_FIELD_UNLOAD = {},
    DRIVE_TO_REVERSE_FIELD_UNLOAD_POSITION = {},
    REVERSING_TO_THE_FIELD_UNLOAD_HEAP = {},
    UNLOADING_ON_THE_FIELD = { proximityControllerDisabled = true },
    DRIVE_TO_FIELD_UNLOAD_PARK_POSITION = {},
}

function AIDriveStrategyUnloadCombine.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyUnloadCombine_mt
    end
    local self = AIDriveStrategyCourse.new(customMt)

    self.combineUnloadStates = CpUtil.initStates(self.combineUnloadStates, AIDriveStrategyUnloadCombine.myCombineUnloadStates)
    self.trailerUnloadStates = CpUtil.initStates(self.trailerUnloadStates, AIDriveStrategyUnloadCombine.myTrailerUnloadStates)
    self.fieldUnloadStates = CpUtil.initStates(self.fieldUnloadStates, AIDriveStrategyUnloadCombine.myFieldUnloadStates)

    self.states = CpUtil.initStates(self.states, AIDriveStrategyUnloadCombine.myStates)
    --- Copies all references to the self.states table
    self.states = CpUtil.copyStates(self.states, self.combineUnloadStates)
    self.states = CpUtil.copyStates(self.states, self.trailerUnloadStates)
    self.states = CpUtil.copyStates(self.states, self.fieldUnloadStates)

    self.state = self.states.INITIAL
    self.debugChannel = CpDebug.DBG_UNLOAD_COMBINE
    ---@type ImplementController[]
    self.controllers = {}
    self.combineOffset = 0
    self.distanceToCombine = math.huge
    self.distanceToFront = 0
    self.combineToUnloadReversing = 0
    self.doNotSwerveForVehicle = CpTemporaryObject()
    self.justFinishedPathfindingForDistance = CpTemporaryObject()
    self.vehicleInFrontOfUS = CpTemporaryObject()
    self.blockedVehicleReversing = CpTemporaryObject(false)
    self.driveUnloadNowRequested = CpTemporaryObject(false)
    self.movingAwayDelay = CpTemporaryObject(false)
    self.checkForTrailerToUnloadTo = CpTemporaryObject(true)
    self:resetPathfinder()
    self.unloadTargetType = self.UNLOAD_TYPES.COMBINE
    return self
end

function AIDriveStrategyUnloadCombine:delete()
    if self.fieldUnloadPositionNode then
        CpUtil.destroyNode(self.fieldUnloadPositionNode)
        CpUtil.destroyNode(self.fieldUnloadTurnStartNode)
        CpUtil.destroyNode(self.fieldUnloadTurnEndNode)
    end
    self:releaseCombine()
    AIDriveStrategyUnloadCombine:superClass().delete(self)
end

------------------------------------------------------------------------------------------------------------------------
-- Start and initialization
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startWithoutCourse()
    -- to always have a valid course (for the traffic conflict detector mainly)
    self.course = Course.createStraightForwardCourse(self.vehicle, 25)

    self:startCourse(self.course, 1)

    self:info('Starting combine unload')

    for _, implement in pairs(self.vehicle:getAttachedImplements()) do
        self:info(' - %s', CpUtil.getName(implement.object))
    end
end

function AIDriveStrategyUnloadCombine:getGeneratedCourse(jobParameters)
    return nil
end

function AIDriveStrategyUnloadCombine:setJobParameterValues(jobParameters)
    self.jobParameters = jobParameters
    local x, z = jobParameters.fieldPosition:getPosition()
    self.fieldPolygon = CpFieldUtil.getFieldPolygonAtWorldPosition(x, z)
    x, z = jobParameters.startPosition:getPosition()
    local angle = jobParameters.startPosition:getAngle()
    if x ~= nil and z ~= nil and angle ~= nil then
        --- Additionally safety check, if the position is on the field or near it.
        if CpMathUtil.isPointInPolygon(self.fieldPolygon, x, z)
                or CpMathUtil.getClosestDistanceToPolygonEdge(self.fieldPolygon, x, z) < 2 * CpAIJobCombineUnloader.minStartDistanceToField then
            --- Goal position marker set in the ai menu rotated by 180 degree.
            self.invertedStartPositionMarkerNode = CpUtil.createNode("Inverted Start position marker",
                    x, z, angle + math.pi)
            self:debug("Valid goal position marker was set.")
        else
            self:debug("Start position is too far away from the field for a valid goal position!")
        end
    else
        self:debug("Invalid start position found!")
    end
    if jobParameters.useFieldUnload:getValue() and not jobParameters.useFieldUnload:getIsDisabled() then
        local fieldUnloadPosition = jobParameters.fieldUnloadPosition
        if fieldUnloadPosition ~= nil and fieldUnloadPosition.x ~= nil and fieldUnloadPosition.z ~= nil and fieldUnloadPosition.angle ~= nil then
            --- Valid field unload position found and allowed.
            self.fieldUnloadPositionNode = CpUtil.createNode("Field unload position", fieldUnloadPosition.x, fieldUnloadPosition.z, fieldUnloadPosition.angle, nil)
            self.fieldUnloadTurnStartNode = CpUtil.createNode("Reverse field unload turn start position", fieldUnloadPosition.x, fieldUnloadPosition.z, fieldUnloadPosition.angle, nil)
            self.fieldUnloadTurnEndNode = CpUtil.createNode("Reverse field unload turn end position", fieldUnloadPosition.x, fieldUnloadPosition.z, fieldUnloadPosition.angle, nil)
            self.unloadTipSideID = jobParameters.unloadingTipSide:getValue()
        end
    end
    --- Setup the unload target mode.
    if jobParameters.unloadTarget:getValue() == CpCombineUnloaderJobParameters.UNLOAD_COMBINE then
        self.unloadTargetType = self.UNLOAD_TYPES.COMBINE
        self:debug("Unload target is a combine.")
    else
        self.unloadTargetType = self.UNLOAD_TYPES.SILO_LOADER
        self:debug("Unload target is a silo loader.")
    end
end

--- Gets the unload target drive strategy target.
function AIDriveStrategyUnloadCombine:getUnloadTargetType()
    return self.unloadTargetType
end

function AIDriveStrategyUnloadCombine:setAIVehicle(vehicle, jobParameters)
    AIDriveStrategyUnloadCombine:superClass().setAIVehicle(self, vehicle)
    self.reverser = AIReverseDriver(self.vehicle, self.ppc)
    self.collisionAvoidanceController = CollisionAvoidanceController(self.vehicle, self)
    self.proximityController = ProximityController(self.vehicle, self:getProximitySensorWidth())
    self.proximityController:registerIsSlowdownEnabledCallback(self, AIDriveStrategyUnloadCombine.isProximitySpeedControlEnabled)
    self.proximityController:registerBlockingVehicleListener(self, AIDriveStrategyUnloadCombine.onBlockingVehicle)
    self.proximityController:registerIgnoreObjectCallback(self, AIDriveStrategyUnloadCombine.ignoreProximityObject)
    -- remove any course already loaded (for instance to not to interfere with the fieldworker proximity controller)
    vehicle:resetCpCourses()
    self:resetPathfinder()
end

function AIDriveStrategyUnloadCombine:initializeImplementControllers(vehicle)
    self.augerWagon, self.pipeController = self:addImplementController(vehicle, PipeController, Pipe, {}, nil)
    self:debug('Auger wagon found: %s', self.augerWagon ~= nil)
    self.trailer, self.trailerController = self:addImplementController(vehicle, TrailerController, Trailer, {}, nil)
    self:addImplementController(vehicle, MotorController, Motorized, {}, nil)
    self:addImplementController(vehicle, WearableController, Wearable, {}, nil)
    self:addImplementController(vehicle, CoverController, Cover, {}, nil)
    self:addImplementController(vehicle, FoldableController, Foldable, {})
end

function AIDriveStrategyUnloadCombine:resetPathfinder()
    self.maxFruitPercent = 10
    -- prefer driving on field, don't do this too aggressively until we take into account the field owner
    -- otherwise we'll be driving through others' fields
    self.offFieldPenalty = PathfinderUtil.defaultOffFieldPenalty
    self.pathfinderFailureCount = 0
end

function AIDriveStrategyUnloadCombine:isProximitySpeedControlEnabled()
    return true
end

function AIDriveStrategyUnloadCombine:ignoreProximityObject(object, vehicle, moveForwards, hitTerrain)
    return self.state == self.states.UNLOADING_ON_THE_FIELD and hitTerrain
end

function AIDriveStrategyUnloadCombine:checkCollisionWarning()
    if self.state.properties.collisionAvoidanceEnabled and
            self.collisionAvoidanceController:isCollisionWarningActive() then
        self:debugSparse('Collision warning, waiting...')
        self:setMaxSpeed(0)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:getDriveData(dt, vX, vY, vZ)
    self:updateLowFrequencyImplementControllers()

    local moveForwards = not self.ppc:isReversing()
    local gx, gz

    ----------------------------------------------------------------
    if not moveForwards then
        local maxSpeed
        gx, gz, maxSpeed = self:getReverseDriveData()
        self:setMaxSpeed(maxSpeed)
    else
        gx, _, gz = self.ppc:getGoalPointPosition()
    end

    -- make sure if we have a combine we stay registered
    if self.combineToUnload and self.combineToUnload:getIsCpActive() then
        local strategy = self.combineToUnload:getCpDriveStrategy()
        if strategy then
            if strategy.registerUnloader then
                strategy:registerUnloader(self)
            else
                -- combine may have been stopped and restarted, so CP is active again but not yet the combine strategy,
                -- for instance it is now driving to work start, so it can't accept a registration
                self:debug('Lost my combine')
                self:startWaitingForSomethingToDo()
            end
        end
    end

    if self.combineToUnload == nil or not self.combineToUnload:getIsCpActive() then
        if CpUtil.isStateOneOf(self.state, self.combineUnloadStates) then

        end
    end

    if self:hasToWaitForAssignedCombine() then
        --- Safety check to make sure a combine is assigned, when needed.
        self:setMaxSpeed(0)
        self:debugSparse("Combine to unload lost during unload, waiting for something todo.")
        if self:isDriveUnloadNowRequested() then
            self:debug('Drive unload now requested')
            self:startUnloadingTrailers()
        end
    elseif self.state == self.states.INITIAL then
        if not self.startTimer then
            --- Only create one instance of the timer and wait until it finishes.
            self.startTimer = Timer.createOneshot(50, function ()
                --- Pipe measurement seems to be buggy with a few over loaders, like bergman RRW 500,
                --- so a small delay of 50 ms is inserted here before unfolding starts.
                self.vehicle:raiseAIEvent("onAIFieldWorkerStart", "onAIImplementStart")
                self.state = self.states.IDLE
                self.startTimer = nil
            end)
        end
        self:setMaxSpeed(0)
    elseif self.state == self.states.IDLE then
        -- nothing to do right now, wait for one of the following:
        -- - combine calls
        -- - user sends us to unload the trailer
        -- - a trailer appears where we can unload our auger wagon if full
        self:setMaxSpeed(0)

        if self:isDriveUnloadNowRequested() then
            self:debug('Drive unload now requested')
            self:startUnloadingTrailers()
        elseif self.checkForTrailerToUnloadTo:get() and self:getAllTrailersFull(self.settings.fullThreshold:getValue()) then
            -- every now and then check if should attempt to unload our trailer/auger wagon
            self.checkForTrailerToUnloadTo:set(false, 10000)
            self:debug('Trailers over %d fill level', self.settings.fullThreshold:getValue())
            self:startUnloadingTrailers()
        end
    elseif self.state == self.states.WAITING_FOR_PATHFINDER then
        -- just wait for the pathfinder to finish
        self:setMaxSpeed(0)

    elseif self.state == self.states.DRIVING_TO_COMBINE then

        self:driveToCombine()

    elseif self.state == self.states.DRIVING_TO_MOVING_COMBINE then

        self:driveToMovingCombine()

    elseif self.state == self.states.UNLOADING_STOPPED_COMBINE then

        self:unloadStoppedCombine()
    elseif self.state == self.states.WAITING_FOR_MANEUVERING_COMBINE then

        self:waitForManeuveringCombine()

    elseif self.state == self.states.BACKING_UP_FOR_REVERSING_COMBINE then
        -- reversing combine asking us to move
        self:moveOutOfWay()

    elseif self.state == self.states.UNLOADING_MOVING_COMBINE then

        self:unloadMovingCombine(dt)

    elseif self.state == self.states.MOVING_AWAY_FROM_OTHER_VEHICLE then
        -- someone is blocking us or we are blocking someone
        self:moveAwayFromOtherVehicle()

    elseif self.state == self.states.MOVING_BACK_WITH_TRAILER_FULL then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        -- drive back until the combine backmarker is 3m behind us to have some room for the pathfinder
        local _, _, dz = self:getDistanceFromCombine(self.state.properties.vehicle)
        if dz > -3 then
            self:startUnloadingTrailers()
        end

    elseif self.state == self.states.MOVING_BACK then

        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        -- drive back until the combine is in front of us
        local _, _, dz = self:getDistanceFromCombine(self.state.properties.vehicle)
        if dz > 0 then
            self:startWaitingForSomethingToDo()
        end

    elseif self.state == self.states.DRIVING_TO_SELF_UNLOAD then
        self:driveToSelfUnload()
    elseif self.state == self.states.WAITING_FOR_AUGER_PIPE_TO_OPEN then
        self:waitForAugerPipeToOpen()
    elseif self.state == self.states.UNLOADING_AUGER_WAGON then
        moveForwards = self:unloadAugerWagon()
    elseif self.state == self.states.MOVING_TO_NEXT_FILL_NODE then
        moveForwards = self:moveToNextFillNode()
    elseif self.state == self.states.MOVING_AWAY_FROM_UNLOAD_TRAILER then
        self:moveAwayFromUnloadTrailer()
    elseif self.state == self.states.DRIVING_BACK_TO_START_POSITION_WHEN_FULL then
        self:setMaxSpeed(self:getFieldSpeed())
        ---------------------------------------------
        --- Unloading on the field
        ---------------------------------------------
    elseif self.state == self.states.DRIVE_TO_FIELD_UNLOAD_POSITION then
        self:setMaxSpeed(self:getFieldSpeed())
    elseif self.state == self.states.WAITING_UNTIL_FIELD_UNLOAD_IS_ALLOWED then
        self:waitingUntilFieldUnloadIsAllowed()
    elseif self.state == self.states.PREPARE_FOR_FIELD_UNLOAD then
        self:prepareForFieldUnload()
    elseif self.state == self.states.UNLOADING_ON_THE_FIELD then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
    elseif self.state == self.states.DRIVE_TO_REVERSE_FIELD_UNLOAD_POSITION then
        self:setMaxSpeed(self:getFieldSpeed())
    elseif self.state == self.states.REVERSING_TO_THE_FIELD_UNLOAD_HEAP then
        self:driveToReverseFieldUnloadHeap()
    elseif self.state == self.states.DRIVE_TO_FIELD_UNLOAD_PARK_POSITION then
        self:setMaxSpeed(self:getFieldSpeed())
    end

    self:checkProximitySensors(moveForwards)

    self:checkCollisionWarning()
    return gx, gz, moveForwards, self.maxSpeed, 100
end

function AIDriveStrategyUnloadCombine:hasToWaitForAssignedCombine()
    if CpUtil.isStateOneOf(self.state, self.combineUnloadStates) then
        return self.combineToUnload == nil or not self.combineToUnload:getIsCpActive() or self.combineToUnload:getCpDriveStrategy() == nil
    end
    return false
end

function AIDriveStrategyUnloadCombine:startWaitingForSomethingToDo()
    if self.state ~= self.states.IDLE then
        self:releaseCombine()
        self.course = Course.createStraightForwardCourse(self.vehicle, 25)
        self:setNewState(self.states.IDLE)
    end
end

function AIDriveStrategyUnloadCombine:driveBesideCombine()
    -- we don't want a moving target
    self:fixAutoAimNode()
    local targetNode = self:getTrailersTargetNode()
    local _, offsetZ = self:getPipeOffset(self.combineToUnload)
    -- TODO: this - 1 is a workaround the fact that we use a simple P controller instead of a PI
    local _, _, dz = localToLocal(targetNode, self.combineToUnload:getAIDirectionNode(), 0, 0, -offsetZ - 2)
    -- use a factor to make sure we reach the pipe fast, but be more gentle while discharging
    local factor = self.combineToUnload:getCpDriveStrategy():isDischarging() and 0.5 or 2
    local speed = self.combineToUnload.lastSpeedReal * 3600 + MathUtil.clamp(-dz * factor, -10, 15)

    -- slow down while the pipe is unfolding to avoid crashing onto it
    if self.combineToUnload:getCpDriveStrategy():isPipeMoving() then
        speed = (math.min(speed, self.combineToUnload:getLastSpeed() + 2))
    end

    self:renderText(0, 0.02, "%s: driveBesideCombine: dz = %.1f, speed = %.1f, factor = %.1f",
            CpUtil.getName(self.vehicle), dz, speed, factor)

    if CpUtil.isVehicleDebugActive(self.vehicle) and CpDebug:isChannelActive(self.debugChannel) then
        DebugUtil.drawDebugNode(targetNode, 'target')
    end
    self:setMaxSpeed(math.max(0, speed))
end

function AIDriveStrategyUnloadCombine:onWaypointPassed(ix, course)
    if course:isLastWaypointIx(ix) then
        self:onLastWaypointPassed()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- On last waypoint
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:onLastWaypointPassed()
    self:debug('Last waypoint passed')
    if self.state == self.states.DRIVING_TO_COMBINE then
        if self:isOkToStartUnloadingCombine() then
            -- Right behind the combine, aligned, go for the pipe
            self:startUnloadingCombine()
        else
            self:startWaitingForSomethingToDo()
        end
    elseif self.state == self.states.DRIVING_TO_MOVING_COMBINE then
        self:startCourseFollowingCombine()
    elseif self.state == self.states.BACKING_UP_FOR_REVERSING_COMBINE then
        self:setNewState(self.stateAfterMovedOutOfWay)
        self:startRememberedCourse()
    elseif self.state == self.states.MOVING_AWAY_FROM_OTHER_VEHICLE then
        self:startWaitingForSomethingToDo()
    elseif self.state == self.states.DRIVING_BACK_TO_START_POSITION_WHEN_FULL then
        self:debug('Inverted goal position reached, so give control back to the job.')
        self.vehicle:getJob():onTrailerFull(self.vehicle, self)
        ---------------------------------------------
        --- Self unload
        ---------------------------------------------
    elseif self.state == self.states.DRIVING_TO_SELF_UNLOAD then
        self:onLastWaypointPassedWhenDrivingToSelfUnload()
    elseif self.state == self.states.MOVING_TO_NEXT_FILL_NODE then
        -- should just for safety
        self:startMovingAwayFromUnloadTrailer()
    elseif self.state == self.states.MOVING_AWAY_FROM_UNLOAD_TRAILER then
        self:onMovedAwayFromUnloadTrailer()
        ---------------------------------------------
        --- Unloading on the field
        ---------------------------------------------
    elseif self.state == self.states.DRIVE_TO_FIELD_UNLOAD_POSITION then
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

function AIDriveStrategyUnloadCombine:setFieldSpeed()
    if self.course then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    end
end

function AIDriveStrategyUnloadCombine:getFieldSpeed()
    return self.settings.fieldSpeed:getValue()
end

function AIDriveStrategyUnloadCombine:setNewState(newState)
    self.lastState = self.state
    self.state = newState
    self:debug('setNewState: %s', self.state.name)
end

function AIDriveStrategyUnloadCombine:getCourseToAlignTo(vehicle, offset)
    local waypoints = {}
    for i = -20, 20, 5 do
        local x, y, z = localToWorld(vehicle.rootNode, offset, 0, i)
        local point = { cx = x;
                        cy = y;
                        cz = z;
        }
        table.insert(waypoints, point)
    end
    local tempCourse = Course(self.vehicle, waypoints)
    return tempCourse
end

function AIDriveStrategyUnloadCombine:getTrailersTargetNode()
    local trailer = AIUtil.getImplementOrVehicleWithSpecialization(self.vehicle, Trailer)
    if trailer then
        if self.combineToUnload:getCpDriveStrategy():canLoadTrailer(trailer) then
            local targetNode = trailer:getFillUnitAutoAimTargetNode(1)
            if targetNode then
                return targetNode
            else
                self:debugSparse('Can\'t find trailer target node')
            end
        else
            self:debugSparse('Combine says it can\'t load trailer')
            --TODO: maybe then send the unloader away if activated?
        end
    else
        self:debugSparse('Can\'t find trailer')
    end
    return trailer.rootNode
end

function AIDriveStrategyUnloadCombine:getPipesBaseNode(combine)
    return g_combineUnloadManager:getPipesBaseNode(combine)
end

function AIDriveStrategyUnloadCombine:getCombineIsTurning()
    return self.combineToUnload:getCpDriveStrategy() and self.combineToUnload:getCpDriveStrategy():isTurning()
end

---@return number, number x and z offset of the pipe's end from the combine's root node in the Giants coordinate system
---(x > 0 left, z > 0 forward) corrected with the manual offset settings
function AIDriveStrategyUnloadCombine:getPipeOffset(combine)
    -- TODO: unloader offset
    return combine:getCpDriveStrategy():getPipeOffset(-self.settings.toolOffsetX:getValue(), self.settings.toolOffsetZ:getValue())
end

function AIDriveStrategyUnloadCombine:getCombinesMeasuredBackDistance()
    return self.combineToUnload:getCpDriveStrategy():getMeasuredBackDistance()
end

function AIDriveStrategyUnloadCombine:getAllTrailersFull(fullThresholdPercentage)
    return FillLevelManager.areAllTrailersFull(self.vehicle, fullThresholdPercentage)
end

--- Fill level in %.
function AIDriveStrategyUnloadCombine:getFillLevelPercentage()
    return FillLevelManager.getTotalTrailerFillLevelPercentage(self.vehicle)
end

function AIDriveStrategyUnloadCombine:isDriveUnloadNowRequested()
    if self.driveUnloadNowRequested:get() then
        self.driveUnloadNowRequested:reset()
        self:debug('User requested drive unload now')
        return true
    end
    return false
end

--- Request to start unloading the trailer at our earliest convenience. We won't directly start it from
--- here, just set this flag, as we may be in the middle of something, or may want to back up before
--- starting on the (self)unload course.
function AIDriveStrategyUnloadCombine:requestDriveUnloadNow()
    -- will reset automatically after a second so we don't have to worry about it getting stuck :)
    self.driveUnloadNowRequested:set(true, 1000)
end

function AIDriveStrategyUnloadCombine:releaseCombine()
    self.combineJustUnloaded = nil
    if self.combineToUnload and self.combineToUnload:getIsCpActive() then
        local strategy = self.combineToUnload:getCpDriveStrategy()
        if strategy and strategy.deregisterUnloader then
            strategy:deregisterUnloader(self)
        end
        self.combineJustUnloaded = self.combineToUnload
    end
    self.combineToUnload = nil
end

------------------------------------------------------------------------------------------------------------------------
-- Implement controller handling.
------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyUnloadCombine:isFuelSaveAllowed()
    return self.state.properties.fuelSaveAllowed
end

function AIDriveStrategyUnloadCombine:isCoverOpeningAllowed()
    return self.state.properties.openCoverAllowed
end

function AIDriveStrategyUnloadCombine:isMoveablePipeDisabled()
    return self.state.properties.moveablePipeDisabled
end

------------------------------------------------------------------------------------------------------------------------
-- Fill node handling
------------------------------------------------------------------------------------------------------------------------
-- Make sure the autoAimTargetNode is not moving with the fill level
function AIDriveStrategyUnloadCombine:fixAutoAimNode()
    self.autoAimNodeFixed = true
end

-- Release the auto aim target to restore default behaviour
function AIDriveStrategyUnloadCombine:releaseAutoAimNode()
    self.autoAimNodeFixed = false
end

function AIDriveStrategyUnloadCombine:isAutoAimNodeFixed()
    return self.autoAimNodeFixed
end

-- Make sure the autoAimTargetNode is not moving with the fill level (which adds realism trying to
-- distribute the load more evenly in the trailer but makes life difficult for us)
-- TODO: instead of turning it off completely, could try to reduce the range it is adjusted
function AIDriveStrategyUnloadCombine:updateFillUnitAutoAimTarget(superFunc, fillUnit)
    local tractor = self.getAttacherVehicle and self:getAttacherVehicle() or nil
    if tractor and tractor.cp.driver and tractor.cp.driver.isAutoAimNodeFixed and tractor.cp.driver:isAutoAimNodeFixed() then
        local autoAimTarget = fillUnit.autoAimTarget
        if autoAimTarget.node ~= nil then
            if autoAimTarget.startZ ~= nil and autoAimTarget.endZ ~= nil then
                setTranslation(autoAimTarget.node, autoAimTarget.baseTrans[1], autoAimTarget.baseTrans[2], autoAimTarget.startZ)
            end
        end
    else
        superFunc(self, fillUnit)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Who I am?
------------------------------------------------------------------------------------------------------------------------
---@param vehicle table
---@return boolean true if vehicle is an active Courseplay controlled unloader, in combine unload mode
function AIDriveStrategyUnloadCombine.isActiveCpCombineUnloader(vehicle)
    if vehicle.getIsCpCombineUnloaderActive and vehicle:getIsCpCombineUnloaderActive() then
        local strategy = vehicle:getCpDriveStrategy()
        if strategy then
            local unloadTargetType = strategy:getUnloadTargetType()
            if unloadTargetType ~= nil then
                return unloadTargetType == AIDriveStrategyUnloadCombine.UNLOAD_TYPES.COMBINE
            end
        end
    end
    return false
end

---@param vehicle table
---@return boolean true if vehicle is an active Courseplay controlled unloader, in silo loader mode
function AIDriveStrategyUnloadCombine.isActiveCpSiloLoader(vehicle)
    if vehicle.getIsCpCombineUnloaderActive and vehicle:getIsCpCombineUnloaderActive() then
        local strategy = vehicle:getCpDriveStrategy()
        if strategy then
            local unloadTargetType = strategy:getUnloadTargetType()
            if unloadTargetType ~= nil then
                return unloadTargetType == AIDriveStrategyUnloadCombine.UNLOAD_TYPES.SILO_LOADER
            end
        end
    end
    return false
end


------------------------------------------------------------------------------------------------------------------------
-- Where I am?
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:isWithinSafeManeuveringDistance(vehicle)
    local d = calcDistanceFrom(self.vehicle.rootNode, vehicle:getAIDirectionNode())
    return d < self.safeManeuveringDistance
end

function AIDriveStrategyUnloadCombine:debugIf(enabled, ...)
    if enabled then
        self:debug(...)
    end
end

--- Is the vehicle lined up with the pipes, based on the two offset values and a tolerance
---@param dx number side offset of the vehicle from the combine's centerline, left > 0 > right
---@param pipeOffset number side offset of the pipe from the combine's centerline
---@param tolerance number +- tolerance in relation of the pipe offset
function AIDriveStrategyUnloadCombine:isLinedUpWithPipe(dx, pipeOffset, tolerance)
    -- if the pipe is on the right side (has a negative offset), turn it over to the left side
    -- so we are always comparing positive numbers
    local myDx = pipeOffset > 0 and dx or -dx
    local myPipeOffset = pipeOffset > 0 and pipeOffset or -pipeOffset
    return myDx > myPipeOffset * (1 - tolerance) and myDx < myPipeOffset * (1 + tolerance)
end

function AIDriveStrategyUnloadCombine:isBehindAndAlignedToCombine(debugEnabled)
    local dx, _, dz = localToLocal(self.vehicle.rootNode, self.combineToUnload:getAIDirectionNode(), 0, 0, 0)
    local pipeOffset = self:getPipeOffset(self.combineToUnload)
    if dz > 0 then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: dz > 0')
        return false
    end
    -- TODO: this does not take the pipe's side into account, and will return true when we are at the
    -- wrong side of the combine. That happens rarely as we
    if not self:isLinedUpWithPipe(dx, pipeOffset, 0.5) then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: dx > 1.5 pipe offset (%.1f > 1.5 * %.1f)', dx, pipeOffset)
        return false
    end
    local d = MathUtil.vector2Length(dx, dz)
    if d > 30 then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: too far from combine (%.1f > 30)', d)
        return false
    end
    if not CpMathUtil.isSameDirection(self.vehicle:getAIDirectionNode(), self.combineToUnload:getAIDirectionNode(),
            AIDriveStrategyUnloadCombine.maxDirectionDifferenceDeg) then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: direction difference is > %d)',
                AIDriveStrategyUnloadCombine.maxDirectionDifferenceDeg)
        return false
    end
    -- close enough and approximately same direction and behind and not too far to the left or right, about the same
    -- direction
    return true
end

--- In front of the combine, right distance from pipe to start unloading and the combine is moving
function AIDriveStrategyUnloadCombine:isInFrontAndAlignedToMovingCombine(debugEnabled)
    local dx, _, dz = localToLocal(self.vehicle.rootNode, self.combineToUnload:getAIDirectionNode(), 0, 0, 0)
    local pipeOffset = self:getPipeOffset(self.combineToUnload)
    if dz < 0 then
        self:debugIf(debugEnabled, 'isInFrontAndAlignedToMovingCombine: dz < 0')
        return false
    end
    if MathUtil.vector2Length(dx, dz) > 30 then
        self:debugIf(debugEnabled, 'isInFrontAndAlignedToMovingCombine: more than 30 m from combine')
        return false
    end
    if not self:isLinedUpWithPipe(dx, pipeOffset, 0.5) then
        self:debugIf(debugEnabled,
                'isInFrontAndAlignedToMovingCombine: dx (%.1f) not between 0.5 and 1.5 pipe offset (%.1f)', dx, pipeOffset)
        return false
    end
    if not CpMathUtil.isSameDirection(self.vehicle:getAIDirectionNode(), self.combineToUnload:getAIDirectionNode(),
            AIDriveStrategyUnloadCombine.maxDirectionDifferenceDeg) then
        self:debugIf(debugEnabled, 'isInFrontAndAlignedToMovingCombine: direction difference is > %d)',
                AIDriveStrategyUnloadCombine.maxDirectionDifferenceDeg)
        return false
    end
    if self.combineToUnload:getCpDriveStrategy():willWaitForUnloadToFinish() then
        self:debugIf(debugEnabled, 'isInFrontAndAlignedToMovingCombine: combine is not moving')
        return false
    end
    -- in front of the combine, close enough and approximately same direction, about pipe offset side distance
    -- and is not waiting (stopped) for the unloader
    return true
end

function AIDriveStrategyUnloadCombine:isOkToStartUnloadingCombine()
    if self.combineToUnload:getCpDriveStrategy():isReadyToUnload(true) then
        return self:isBehindAndAlignedToCombine() or self:isInFrontAndAlignedToMovingCombine()
    else
        self:debugSparse('combine not ready to unload, waiting')
        return false
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Start the course to unload the trailers
---@param waitForCombineIfNotFull boolean when not full, and no trailer found, start waiting for the combine
--- instead of just stopping
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startUnloadingTrailers()
    self:setMaxSpeed(0)
    self:releaseCombine()

    if self.fieldUnloadPositionNode then
        if self.augerWagon then
            self:debug('Starting unloading on the field with an auger wagon.')
            self:startUnloadingOnField(self.pipeController, false)
        else
            self:debug('Starting unloading on the field with a trailer.')
            self:startUnloadingOnField(self.trailerController, true)
        end
        return
    end

    if self.augerWagon then
        self:debug('Have auger wagon, looking for a trailer.')
        if self:startSelfUnload() then
            self:debug('Trailer to unload to found, attempting self unload now')
        else
            self:debug('No trailer for self unload found, keep waiting')
            self:startWaitingForSomethingToDo()
        end
    else
        --- Trailer attached
        if self.invertedStartPositionMarkerNode then
            --- The start position is valid, so drive in there before releasing and giving control to giants or AD.
            self:debug('Trailer is full and a valid start position is set, so drive there before AD or giants can take over.')
            self:startPathfindingToInvertedGoalPositionMarker()
        else
            --- No valid start position was set, so release the driver and give control to giants or AD.
            self:debug('Full and have no auger wagon, stop, so eventually AD can take over.')
            self.vehicle:getJob():onTrailerFull(self.vehicle, self)
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Start to unload the combine (driving to the pipe/closer to combine)
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startUnloadingCombine()
    if self.combineToUnload:getCpDriveStrategy():willWaitForUnloadToFinish() then
        self:debug('Close enough to a stopped combine, drive to pipe')
        self:startUnloadingStoppedCombine()
    else
        self:debug('Close enough to moving combine, copy combine course and follow')
        self:startCourseFollowingCombine()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Start to unload a stopped combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startUnloadingStoppedCombine()
    -- get a path to the pipe, make the pipe 0.5 m longer so the path will be 0.5 more to the outside to make
    -- sure we don't bump into the pipe
    local offsetX, offsetZ = self:getPipeOffset(self.combineToUnload)
    local unloadCourse = Course.createFromNode(self.vehicle, self:getCombineRootNode(), offsetX, offsetZ - 5, 30, 2, false)
    self:startCourse(unloadCourse, 1)
    -- make sure to get to the course as soon as possible
    self.ppc:setShortLookaheadDistance()
    self:setNewState(self.states.UNLOADING_STOPPED_COMBINE)
end

---@return Course fieldwork course of the combine
---@return number approximate waypoint index of the combine's current position
function AIDriveStrategyUnloadCombine:setupFollowCourse()
    ---@type Course
    self.combineCourse = self.combineToUnload:getCpDriveStrategy():getFieldworkCourse()
    if not self.combineCourse then
        -- TODO: handle this more gracefully, or even better, don't even allow selecting combines with no course
        self:debugSparse('Waiting for combine to set up a course, can\'t follow')
        return
    end
    local followCourse = self.combineCourse:copy(self.vehicle)
    -- relevant waypoint is the closest to the combine, prefer that so our PPC will get us on course with the proper offset faster
    local followCourseIx = self.combineToUnload:getCpDriveStrategy():getClosestFieldworkWaypointIx() or self.combineCourse:getCurrentWaypointIx()
    return followCourse, followCourseIx
end

------------------------------------------------------------------------------------------------------------------------
-- Start following a combine a course
-- This assumes we are in a good position to do that and can start on the course without pathfinding
-- or alignment, that is, we only call this when isOkToStartUnloadingCombine() says it is ok
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startCourseFollowingCombine()
    local startIx
    self.followCourse, startIx = self:setupFollowCourse()
    self.combineOffset = self:getPipeOffset(self.combineToUnload)
    self.followCourse:setOffset(-self.combineOffset, 0)
    -- try to find the waypoint closest to the vehicle, as startIx we got is right beside the combine
    -- which may be far away and if that's our target, PPC will be slow to bring us back on the course
    -- and we may end up between the end of the pipe and the combine
    -- use a higher look ahead as we may be in front of the combine
    local startSearchAt = startIx - 5
    local nextFwdIx, found = self.followCourse:getNextFwdWaypointIxFromVehiclePosition(startSearchAt > 0 and startSearchAt or 1,
            self.vehicle:getAIDirectionNode(), self.combineToUnload:getCpDriveStrategy():getWorkWidth(), 20)
    if found then
        startIx = nextFwdIx
    end
    self:debug('Will follow combine\'s course at waypoint %d, side offset %.1f', startIx, self.followCourse.offsetX)
    self:startCourse(self.followCourse, startIx)
    self:setNewState(self.states.UNLOADING_MOVING_COMBINE)
end

---@param dontRelax boolean do not relax pathfinder constraint on failure
function AIDriveStrategyUnloadCombine:isPathFound(path, goalNodeInvalid, goalDescriptor, dontRelax)
    if path and #path > 2 then
        self:debug('Found path (%d waypoints, %d ms)', #path, g_time - (self.pathfindingStartedAt or 0))
        self:resetPathfinder()
        return true
    else
        if goalNodeInvalid then
            self:error('No path found to %s, goal occupied by a vehicle, waiting...', goalDescriptor)
            return false
        elseif not dontRelax then
            self.pathfinderFailureCount = self.pathfinderFailureCount + 1
            if self.pathfinderFailureCount > 1 then
                self:error('No path found to %s in %d ms, pathfinder failed at least twice, trying a path through crop and relaxing pathfinder field constraint...',
                        goalDescriptor,
                        g_time - (self.pathfindingStartedAt or 0))
                self.maxFruitPercent = math.huge
            elseif self.pathfinderFailureCount == 1 then
                self.offFieldPenalty = self.offFieldPenalty / 2
                self:error('No path found to %s in %d ms, pathfinder failed once, relaxing pathfinder field constraint (%.1f)...',
                        goalDescriptor,
                        g_time - (self.pathfindingStartedAt or 0),
                        self.offFieldPenalty)
            end
            return false
        end
    end
end
function AIDriveStrategyUnloadCombine:getCombineToUnload()
    return self.combineToUnload
end

function AIDriveStrategyUnloadCombine:getCombineRootNode()
    -- for attached harvesters this gets the root node of the harvester as that is our reference point to the
    -- pipe offsets
    return self.combineToUnload:getCpDriveStrategy():getCombine().rootNode
end

function AIDriveStrategyUnloadCombine:onPathfindingDoneToMovingCombine(path, goalNodeInvalid)
    if self:isPathFound(path, goalNodeInvalid, CpUtil.getName(self.combineToUnload)) and self.state == self.states.WAITING_FOR_PATHFINDER then
        local driveToCombineCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        -- add a short straight section to align in case we get there before the combine
        -- pathfinding does not guarantee the last section points into the target direction so we may
        -- end up not parallel to the combine's course when we extend the pathfinder course in the direction of the
        -- last waypoint. Therefore, use the rendezvousWaypoint's direction instead
        local dx = self.rendezvousWaypoint and self.rendezvousWaypoint.dx
        local dz = self.rendezvousWaypoint and self.rendezvousWaypoint.dz
        driveToCombineCourse:extend(AIDriveStrategyUnloadCombine.driveToCombineCourseExtensionLength, dx, dz)
        self:startCourse(driveToCombineCourse, 1)
        self:setNewState(self.states.DRIVING_TO_MOVING_COMBINE)
        return true
    else
        self:startWaitingForSomethingToDo()
        return false
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Pathfinding to combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startPathfindingToCombine(onPathfindingDoneFunc, xOffset, zOffset)
    local x, z = self:getPipeOffset(self.combineToUnload)
    xOffset = xOffset or x
    zOffset = zOffset or z
    -- TODO: here we may have to pass in the combine to ignore once we start driving to a moving combine, at least
    -- when it is on the headland.
    if self:isPathfindingNeeded(self.vehicle, self:getCombineRootNode(), xOffset, zOffset) then
        self:setNewState(self.states.WAITING_FOR_PATHFINDER)
        self:startPathfinding(self:getCombineRootNode(), xOffset, zOffset,
                CpFieldUtil.getFieldNumUnderVehicle(self.combineToUnload), {}, onPathfindingDoneFunc)
    else
        self:debug('Can\'t start pathfinding, too close?')
        if self:isOkToStartUnloadingCombine() then
            self:startUnloadingCombine()
        else
            self:startWaitingForSomethingToDo()
        end
    end
end

function AIDriveStrategyUnloadCombine:onPathfindingDoneToCombine(path, goalNodeInvalid)
    if self:isPathFound(path, goalNodeInvalid, CpUtil.getName(self.combineToUnload)) and self.state == self.states.WAITING_FOR_PATHFINDER then
        local driveToCombineCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        self:startCourse(driveToCombineCourse, 1)
        self:setNewState(self.states.DRIVING_TO_COMBINE)
        return true
    else
        self:startWaitingForSomethingToDo()
        return false
    end
end

--- Is this position in the area I'm assigned to work?
---@param x number
---@param z number
---@param outwardsOffset number
---@return boolean
function AIDriveStrategyUnloadCombine:isServingPosition(x, z, outwardsOffset)
    local closestDistance = CpMathUtil.getClosestDistanceToPolygonEdge(self.fieldPolygon, x, z)
    return closestDistance < outwardsOffset or CpMathUtil.isPointInPolygon(self.fieldPolygon, x, z)
end

--- Am I ready to be assigned to a combine in need?
function AIDriveStrategyUnloadCombine:isIdle()
    return self.state == self.states.IDLE
end

--- Get the Dubins path length and the estimated seconds en-route to gaol
---@param goal State3D
function AIDriveStrategyUnloadCombine:getDistanceAndEte(goal)
    local start = PathfinderUtil.getVehiclePositionAsState3D(self.vehicle)
    local solution = PathfinderUtil.dubinsSolver:solve(start, goal, self.turningRadius)
    local dubinsPathLength = solution:getLength(self.turningRadius)
    local estimatedSecondsEnroute = dubinsPathLength / (self.settings.fieldSpeed:getValue() / 3.6) + 3 -- add a few seconds to allow for starting the engine/accelerating
    return dubinsPathLength, estimatedSecondsEnroute
end

--- Get the Dubins path length and the estimated seconds en-route to vehicle
---@param vehicle table the other vehicle
function AIDriveStrategyUnloadCombine:getDistanceAndEteToVehicle(vehicle)
    local goal = PathfinderUtil.getVehiclePositionAsState3D(vehicle)
    return self:getDistanceAndEte(goal)
end

--- Get the Dubins path length and the estimated seconds en-route to a waypoint
---@param waypoint Waypoint
function AIDriveStrategyUnloadCombine:getDistanceAndEteToWaypoint(waypoint)
    local goal = PathfinderUtil.getWaypointAsState3D(waypoint, 0, 0)
    return self:getDistanceAndEte(goal)
end

--- Interface function for a combine to call the unloader.
---@param combine table the combine vehicle calling
---@param waypoint Waypoint if given, the combine wants to meet the unloader at this waypoint, otherwise wants the
--- unloader to come to the combine.
---@return boolean true if the unloader has accepted the request
function AIDriveStrategyUnloadCombine:call(combine, waypoint)
    if waypoint then
        -- combine set up a rendezvous waypoint for us, go there
        local xOffset, zOffset = self:getPipeOffset(combine)
        if self:isPathfindingNeeded(self.vehicle, waypoint, xOffset, zOffset, 25) then
            self.rendezvousWaypoint = waypoint
            self.combineToUnload = combine
            self:setNewState(self.states.WAITING_FOR_PATHFINDER)
            -- just in case, as the combine may give us a rendezvous waypoint
            -- where it is full, make sure we are behind the combine
            zOffset = -self:getCombinesMeasuredBackDistance() - 5
            self:debug('call: Start pathfinding to rendezvous waypoint, xOffset = %.1f, zOffset = %.1f', xOffset, zOffset)
            self:startPathfinding(self.rendezvousWaypoint, xOffset, zOffset,
                    CpFieldUtil.getFieldNumUnderVehicle(self.combineToUnload),
                    { self.combineToUnload }, self.onPathfindingDoneToMovingCombine)
            return true
        else
            self:debug('call: Rendezvous waypoint to moving combine too close, wait a bit')
            self:startWaitingForSomethingToDo()
            return false
        end
    else
        -- combine wants us to drive directly to it
        self:debug('call: Combine is waiting for unload, start finding path to combine')
        self.combineToUnload = combine
        local zOffset
        if self.combineToUnload:getCpDriveStrategy():isWaitingForUnloadAfterPulledBack() then
            -- combine pulled back so it's pipe is now out of the fruit. In this case, if the unloader is in front
            -- of the combine, it sometimes finds a path between the combine and the fruit to the pipe, we are trying to
            -- fix it here: the target is behind the combine, not under the pipe. When we get there, we may need another
            -- (short) pathfinding to get under the pipe.
            zOffset = -self:getCombinesMeasuredBackDistance() - 10
        else
            -- allow trailer space to align after sharp turns (noticed it more affects potato/sugarbeet harvesters with
            -- pipes close to vehicle)
            local pipeLength = math.abs(self:getPipeOffset(self.combineToUnload))
            -- allow for more align space for shorter pipes
            zOffset = -self:getCombinesMeasuredBackDistance() - (pipeLength > 6 and 2 or 10)
        end
        self:startPathfindingToCombine(self.onPathfindingDoneToCombine, nil, zOffset)
        return true
    end
end

------------------------------------------------------------------------------------------------------------------------
-- target can be a waypoint or a node, return a node
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:getTargetNode(target)
    local targetNode
    if type(target) ~= 'number' then
        -- target is a waypoint
        if not AIDriveStrategyUnloadCombine.helperNode then
            AIDriveStrategyUnloadCombine.helperNode = CpUtil.createNode('combineUnloadAIDriverHelper', target.x, target.z, target.yRot)
        end
        setTranslation(AIDriveStrategyUnloadCombine.helperNode, target.x, target.y, target.z)
        setRotation(AIDriveStrategyUnloadCombine.helperNode, 0, target.yRot, 0)
        targetNode = AIDriveStrategyUnloadCombine.helperNode
    elseif entityExists(target) then
        -- target is a node
        targetNode = target
    else
        self:debug('Target is not a waypoint or node')
    end
    return targetNode
end

function AIDriveStrategyUnloadCombine:getOffFieldPenalty(combineToUnload)
    local offFieldPenalty = self.offFieldPenalty
    if combineToUnload then
        if combineToUnload:getCpDriveStrategy():isOnHeadland(1) then
            -- when the combine is on the first headland, chances are that we have to drive off-field to it,
            -- so make the life easier for the pathfinder
            offFieldPenalty = PathfinderUtil.defaultOffFieldPenalty / 5
            self:debug('Combine is on first headland, reducing off-field penalty for pathfinder to %.1f', offFieldPenalty)
        elseif combineToUnload:getCpDriveStrategy():isOnHeadland(2) then
            -- reduce less when on the second headland, there's more chance we'll be able to get to the combine
            -- on the headland
            offFieldPenalty = PathfinderUtil.defaultOffFieldPenalty / 3
            self:debug('Combine is on second headland, reducing off-field penalty for pathfinder to %.1f', offFieldPenalty)
        end
    end
    return offFieldPenalty
end

------------------------------------------------------------------------------------------------------------------------
-- Check if it makes sense to start pathfinding to the target
-- This should avoid generating a big circle path to a point a few meters ahead or behind
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:isPathfindingNeeded(vehicle, target, xOffset, zOffset, range, sameDirectionThresholdDeg)
    local targetNode = self:getTargetNode(target)
    if not targetNode then
        return false
    end
    local startNode = vehicle:getAIDirectionNode()
    local dx, _, dz = localToLocal(targetNode, startNode, xOffset, 0, zOffset)
    local d = MathUtil.vector2Length(dx, dz)
    local sameDirection = CpMathUtil.isSameDirection(startNode, targetNode, sameDirectionThresholdDeg or 30)
    if d < (range or self.pathfindingRange) and sameDirection then
        self:debug('No pathfinding needed, d = %.1f, same direction %s', d, tostring(sameDirection))
        return false
    else
        self:debug('Ok to start pathfinding, d = %.1f, same direction %s', d, tostring(sameDirection))
        return true
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Is there fruit at the target (node or waypoint)
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:isFruitAt(target, xOffset, zOffset)
    local targetNode = self:getTargetNode(target)
    if not targetNode then
        return false
    end
    local x, _, z = localToWorld(targetNode, xOffset, 0, zOffset)
    local hasFruit = PathfinderUtil.hasFruit(x, z, 1, 1)
    self:debug('isFruitAt %s, x = %.1f, z = %.1f (xOffset = %.1f, zOffset = %.1f', tostring(hasFruit), x, z, xOffset, zOffset)
    return hasFruit
end

------------------------------------------------------------------------------------------------------------------------
-- Generic pathfinder wrapper
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startPathfinding(
        target, xOffset, zOffset, fieldNum, vehiclesToIgnore,
        pathfindingCallbackFunc, areaToAvoid)
    if not self.pathfinder or not self.pathfinder:isActive() then

        if self:isFruitAt(target, xOffset, zOffset) then
            self:info('There is fruit at the target, disabling fruit avoidance')
            self.maxFruitPercent = math.huge
        end

        self.offFieldPenalty = self:getOffFieldPenalty(self.combineToUnload)
        local maxFruitPercent
        if self.settings.avoidFruit:getValue() then
            maxFruitPercent = self.maxFruitPercent
        else
            maxFruitPercent = math.huge
        end
        self:debug('Start pathfinding, fieldNum %d, maxFruitPercent %.1f, offFieldPenalty %.1f, xOffset %.1f, zOffset %.1f',
                fieldNum, maxFruitPercent, self.offFieldPenalty, xOffset, zOffset)

        local done, path, goalNodeInvalid
        self.pathfindingStartedAt = g_time

        local areaToAvoid = areaToAvoid ~= nil and areaToAvoid or self.combineToUnload and self.combineToUnload:getCpDriveStrategy():getAreaToAvoid()
        if type(target) ~= 'number' then
            -- TODO: clarify this xOffset thing, it looks like the course interprets the xOffset differently (left < 0) than
            -- the Giants coordinate system and the waypoint uses the course's conventions. This is confusing, should use
            -- the same reference everywhere
            local goal = PathfinderUtil.getWaypointAsState3D(target, -xOffset or 0, zOffset or 0)
            self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToGoal(
                    self.vehicle, goal, allowReverse or false, fieldNum, vehiclesToIgnore, {},
                    maxFruitPercent, self.offFieldPenalty, areaToAvoid)
        else
            self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToNode(
                    self.vehicle, target, xOffset or 0, zOffset or 0, false,
                    fieldNum, vehiclesToIgnore, maxFruitPercent,
                    self.offFieldPenalty, areaToAvoid)
        end
        if done then
            return pathfindingCallbackFunc(self, path, goalNodeInvalid)
        else
            self:setPathfindingDoneCallback(self, pathfindingCallbackFunc)
            return true
        end
    else
        self:debug('Pathfinder already active')
    end
    return false
end

------------------------------------------------------------------------------------------------------------------------
-- Where are we related to the combine?
------------------------------------------------------------------------------------------------------------------------
---@return number, number, number distance between the tractor's front and the combine's back (always positive),
--- side offset (local x) of the combine's back in the tractor's front coordinate system (positive if the tractor is on
--- the right side of the combine)
--- back offset (local z) of the combine's back in the tractor's front coordinate system (positive if the tractor is behind
--- the combine)
function AIDriveStrategyUnloadCombine:getDistanceFromCombine(combine)
    local dx, _, dz = localToLocal(Markers.getBackMarkerNode(combine or self.combineToUnload),
            Markers.getFrontMarkerNode(self.vehicle), 0, 0, 0)
    return MathUtil.vector2Length(dx, dz), dx, dz
end

------------------------------------------------------------------------------------------------------------------------
-- Update combine status
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:updateCombineStatus()
    if not self.combineToUnload then
        return
    end
    -- add hysteresis to reversing info from combine, isReversing() may temporarily return false during reversing, make sure we need
    -- multiple update loops to change direction
    local combineToUnloadReversing = self.combineToUnloadReversing + (self.combineToUnload:getCpDriveStrategy():isReversing() and 0.1 or -0.1)
    if self.combineToUnloadReversing < 0 and combineToUnloadReversing >= 0 then
        -- direction changed
        self.combineToUnloadReversing = 1
    elseif self.combineToUnloadReversing > 0 and combineToUnloadReversing <= 0 then
        -- direction changed
        self.combineToUnloadReversing = -1
    else
        self.combineToUnloadReversing = MathUtil.clamp(combineToUnloadReversing, -1, 1)
    end
end

function AIDriveStrategyUnloadCombine:isMyCombineReversing()
    return self.combineToUnloadReversing > 0
end

------------------------------------------------------------------------------------------------------------------------
-- Check for full trailer when unloading a combine
---@return boolean true when changed to unload course
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:changeToUnloadWhenTrailerFull()
    --when trailer is full then go to unload
    if self:isDriveUnloadNowRequested() or self:getAllTrailersFull() then
        if self:isDriveUnloadNowRequested() then
            self:debug('drive now requested, changing to unload course.')
        else
            self:debug('trailer full, changing to unload course.')
        end
        if self.combineToUnload:getCpDriveStrategy():isTurning() or
                self.combineToUnload:getCpDriveStrategy():isAboutToTurn() then
            self:debug('... but we are too close to the end of the row, or combine is turning, moving back before changing to unload course')
        elseif self.combineToUnload and self.combineToUnload:getCpDriveStrategy():isAboutToReturnFromPocket() then
            self:debug('... letting the combine return from the pocket')
        else
            self:debug('... moving back a little in case AD wants to take over')
        end
        self:releaseCombine()
        self:startMovingBackFromCombine(self.states.MOVING_BACK_WITH_TRAILER_FULL, self.combineJustUnloaded)
        return true
    end
    return false
end

function AIDriveStrategyUnloadCombine:checkForCombineProximity()
    -- do not swerve for our combine towards the end of the course,
    -- otherwise we won't be able to align with it when coming from
    -- the wrong angle
    -- Increased distance from 20 to 75, so we don't swerve for our combine
    -- when we are coming from the front and drive to close to our combine
    if self.course:getDistanceToLastWaypoint(self.course:getCurrentWaypointIx()) < 75 then
        if not self.doNotSwerveForVehicle:get() then
            self:debug('Disable swerve for %s', CpUtil.getName(self.combineToUnload))
        end
        self.doNotSwerveForVehicle:set(self.combineToUnload, 2000)
    end

end

--- If the combine has a turn between its current position and the rendezvous waypoint,
--- we probably rather not approach the area around the turn so we are not in the way
--- of the combine while it is turning.
function AIDriveStrategyUnloadCombine:checkForCombineTurnArea()
    local turnAreaCenterWp, r = self.combineToUnload:getCpDriveStrategy():getTurnArea()
    if turnAreaCenterWp and turnAreaCenterWp:getDistanceFromVehicle(self.vehicle) <= r then
        self:debugSparse('Waiting for combine to pass the turn at %.1f, %.1f (r = %.1f) before the rendezvous waypoint',
                turnAreaCenterWp.x, turnAreaCenterWp.z, r)
        self:setMaxSpeed(0)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Drive to stopped combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:driveToCombine()

    self:checkForCombineProximity()

    self:setFieldSpeed()

    self.combineToUnload:getCpDriveStrategy():reconfirmRendezvous()

    if self:isOkToStartUnloadingCombine() then
        self:startUnloadingCombine()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Drive to moving combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:driveToMovingCombine()

    self:checkForCombineProximity()

    self:setFieldSpeed()

    self:checkForCombineTurnArea()

    -- stop when too close to a combine not ready to unload (wait until it is done with turning for example)
    if self:isWithinSafeManeuveringDistance(self.combineToUnload) and self.combineToUnload:getCpDriveStrategy():isManeuvering() then
        self:startWaitingForManeuveringCombine()
    elseif self:isOkToStartUnloadingCombine() then
        self:startUnloadingCombine()
    end

    if self.combineToUnload:getCpDriveStrategy():isWaitingForUnload() then
        self:debug('combine is now stopped and waiting for unload, wait for it to call again')
        self:startWaitingForSomethingToDo()
        return
    end

    if self.course:isCloseToLastWaypoint(AIDriveStrategyUnloadCombine.driveToCombineCourseExtensionLength / 2) and
            self.combineToUnload:getCpDriveStrategy():hasRendezvousWith(self.vehicle) then
        self:debugSparse('Combine is late, waiting ...')
        self:setMaxSpeed(0)
        -- stop confirming the rendezvous, allow the combine to time out if it can't get here on time
    else
        -- yes honey, I'm on my way!
        self.combineToUnload:getCpDriveStrategy():reconfirmRendezvous()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Waiting for maneuvering combine
-----------------------------------------------`-------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startWaitingForManeuveringCombine()
    self:debug('Too close to maneuvering combine, stop.')
    -- remember where the combine was when we started waiting
    self.lastCombinePos = {}
    self.lastCombinePos.x, self.lastCombinePos.y, self.lastCombinePos.z = getWorldTranslation(self.combineToUnload.rootNode)
    _, self.lastCombinePos.yRotation, _ = getWorldRotation(self.combineToUnload.rootNode)
    self.stateAfterWaitingForManeuveringCombine = self.state
    self:setNewState(self.states.WAITING_FOR_MANEUVERING_COMBINE)
end

function AIDriveStrategyUnloadCombine:waitForManeuveringCombine()
    if self:isWithinSafeManeuveringDistance(self.combineToUnload) and self.combineToUnload:getCpDriveStrategy():isManeuvering() then
        self:setMaxSpeed(0)
    else
        self:debug('Combine stopped maneuvering')
        --check whether the combine moved significantly while we were waiting
        local _, yRotation, _ = getWorldRotation(self.combineToUnload.rootNode)
        local dx, _, dz = worldToLocal(self.combineToUnload.rootNode, self.lastCombinePos.x, self.lastCombinePos.y, self.lastCombinePos.z)
        local distanceCombineMoved = MathUtil.vector2Length(dx, dz)
        if math.abs(yRotation - self.lastCombinePos.yRotation) > math.pi / 6 or distanceCombineMoved > 30 then
            self:debug('Combine moved (%d) or turned significantly while I was waiting, re-evaluate situation', distanceCombineMoved)
            self:startWaitingForSomethingToDo()
        else
            self:setNewState(self.stateAfterWaitingForManeuveringCombine)
        end
    end
end


------------------------------------------------------------------------------------------------------------------------
-- Unload combine (stopped)
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:unloadStoppedCombine()
    if self:changeToUnloadWhenTrailerFull() then
        return
    end
    local combineDriver = self.combineToUnload:getCpDriveStrategy()
    if combineDriver:isUnloadFinished() then
        if combineDriver:isWaitingForUnloadAfterCourseEnded() then
            if combineDriver:getFillLevelPercentage() < 0.1 then
                self:debug('Finished unloading combine at end of fieldwork, changing to unload course')
                self.ppc:setNormalLookaheadDistance()
                self:releaseCombine()
                self:startMovingBackFromCombine(self.states.MOVING_BACK_WITH_TRAILER_FULL, self.combineJustUnloaded)
            else
                self:driveBesideCombine()
            end
        else
            self:debug('finished unloading stopped combine, move back a bit to make room for it to continue')
            self:startMovingBackFromCombine(self.states.MOVING_BACK, self.combineToUnload)
            self.ppc:setNormalLookaheadDistance()
        end
    else
        self:driveBesideCombine()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Unload combine (moving)
-- We are driving on a copy of the combine's course with an offset
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:unloadMovingCombine()

    -- ignore combine for the proximity sensor
    -- self:ignoreVehicleProximity(self.combineToUnload, 3000)
    -- make sure the combine won't slow down when seeing us
    -- self.combineToUnload:getCpDriveStrategy():ignoreVehicleProximity(self.vehicle, 3000)

    -- allow on the fly offset changes
    self.combineOffset = self:getPipeOffset(self.combineToUnload)
    self.followCourse:setOffset(-self.combineOffset, 0)

    if self:changeToUnloadWhenTrailerFull() then
        return
    end

    self:driveBesideCombine()

    --when the combine is empty, stop and wait for next combine
    if self.combineToUnload:getCpDriveStrategy():getFillLevelPercentage() <= 0.1 then
        --when the combine is in a pocket, make room to get back to course
        if self.combineToUnload:getCpDriveStrategy():isWaitingInPocket() then
            self:debug('combine empty and in pocket, drive back')
            self:startMovingBackFromCombine(self.states.MOVING_BACK, self.combineToUnload)
            return
        elseif self.combineToUnload:getCpDriveStrategy():isTurning() or
                self.combineToUnload:getCpDriveStrategy():isAboutToTurn() then
            self:debug('combine empty and moving forward but we are too close to the end of the row or combine is turning, moving back')
            self:startMovingBackFromCombine(self.states.MOVING_BACK, self.combineToUnload)
            return
        elseif self:getAllTrailersFull(self.settings.fullThreshold:getValue()) then
            -- make some room for the pathfinder, as the trailer may not be full but has reached the threshold,
            -- which case is not caught in changeToUnloadWhenTrailerFull() as we want to keep unloading as long as
            -- we can
            self:debug('combine empty and moving forward but we want to leave, so move back a bit')
            self:startMovingBackFromCombine(self.states.MOVING_BACK_WITH_TRAILER_FULL, self.combineToUnload)
            return
        else
            self:debug('combine empty and moving forward')
            self:releaseCombine()
            self:startWaitingForSomethingToDo()
            return
        end
    end

    -- combine stopped in the meanwhile, like for example end of course
    if self.combineToUnload:getCpDriveStrategy():willWaitForUnloadToFinish() then
        self:debug('change to unload stopped combine')
        self:setNewState(self.states.UNLOADING_STOPPED_COMBINE)
        return
    end

    -- when the combine is turning just don't move
    if self.combineToUnload:getCpDriveStrategy():isManeuvering() then
        self:setMaxSpeed(0)
    elseif not self:isBehindAndAlignedToCombine() and not self:isInFrontAndAlignedToMovingCombine() then
        -- call these again just to log the reason
        self:isBehindAndAlignedToCombine(true)
        self:isInFrontAndAlignedToMovingCombine(true)
        self:info('not in a good position to unload, cancelling rendezvous, trying to recover')
        -- for some reason (like combine turned) we are not in a good position anymore then set us up again
        self:startWaitingForSomethingToDo()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Start moving back from empty combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startMovingBackFromCombine(newState, combine)
    if self.unloadTargetType == self.UNLOAD_TYPES.SILO_LOADER then
        --- Finished unloading of silo unloader. Moving back is not needed.
        self:setNewState(self.states.IDLE)
        return
    end

    local reverseCourse = Course.createStraightReverseCourse(self.vehicle, 15)
    self:startCourse(reverseCourse, 1)
    self:setNewState(newState)
    self.state.properties.vehicle = combine
    return
end

------------------------------------------------------------------------------------------------------------------------
-- We missed a rendezvous with the combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:onMissedRendezvous(combine)
    self:debug('missed the rendezvous with %s', CpUtil.getName(combine))
    if self.state == self.states.DRIVING_TO_MOVING_COMBINE and
            self.combineToUnload == combine then
        if self.course:getDistanceToLastWaypoint(self.course:getCurrentWaypointIx()) > 100 then
            self:debug('over 100 m from the combine to rendezvous, re-planning')
            self:startWaitingForSomethingToDo()
        end
    else
        self:debug('ignore missed rendezvous')
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Set up a course to move out of the way of a blocking vehicle
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:createMoveAwayCourse(blockingVehicle)
    local trailer = AIUtil.getImplementOrVehicleWithSpecialization(self.vehicle, Trailer)
    -- if we look straight left or right out of the window, is blockingVehicle in front of us or behind us?
    -- if in front, move back, if behind, move forward
    -- but since we have a trailer, don't use the tractor's direction node directly, instead, a point behind it
    -- about the half length of the rig.
    local _, frontMarkerOffset = Markers.getFrontMarkerNode(self.vehicle)
    local _, backMarkerOffset = Markers.getBackMarkerNode(self.vehicle)
    local _, _, dz = localToLocal(blockingVehicle.rootNode, self.vehicle:getAIDirectionNode(), 0, 0, 0)
    if dz > (frontMarkerOffset + backMarkerOffset) / 2 then
        self:debug('%s is in front, moving back (dz %.1f, front %.1f, back %.1f)', CpUtil.getName(blockingVehicle),
                dz, frontMarkerOffset, backMarkerOffset)
        -- blocking vehicle in front of us, move back, calculate course from the trailer's root node
        return Course.createFromNode(self.vehicle, trailer.rootNode, 0, -2, -27, -5, true)
    else
        -- blocking vehicle behind, move forward
        self:debug('%s is behind us, moving forward (dz: %.1f, front %.1f, back %.1f)', CpUtil.getName(blockingVehicle),
                dz, frontMarkerOffset, backMarkerOffset)
        return Course.createFromNode(self.vehicle, self.vehicle:getAIDirectionNode(), 0,
                frontMarkerOffset, frontMarkerOffset + self.maxDistanceWhenMovingOutOfWay, 5, false)
    end
end


------------------------------------------------------------------------------------------------------------------------
-- Is there another vehicle blocking us?
------------------------------------------------------------------------------------------------------------------------
--- If the other vehicle is a combine driven by CP, we will try get out of its way. Otherwise, if we are not being
--- held already, we tell the other vehicle to hold, and will attempt to get out of its way.
--- This is to make sure that only one of the two vehicles yields to the other one
--- If the other vehicle is an unloader in the idle state, we'll ask it to move as we are busy and it has
--- nothing to do anyway. Such a situation can arise when the first unloader just finished overloading to a waiting
--- trailer and pulled ahead a bit, waiting for a combine to call, when a second unloader arrives to the trailer
--- to overload, but can't get close enough because it is blocked by the first, idle one.
function AIDriveStrategyUnloadCombine:onBlockingVehicle(blockingVehicle, isBack)
    if not self.vehicle:getIsCpActive() or isBack then
        self:debug('%s has been blocking us for a while, ignoring as either not active or in the back', CpUtil.getName(blockingVehicle))
        return
    end
    if self.state ~= self.states.MOVING_AWAY_FROM_OTHER_VEHICLE and
            self.state ~= self.states.BACKING_UP_FOR_REVERSING_COMBINE and
            not self:isBeingHeld() then
        self:debug('%s has been blocking us for a while, move a bit', CpUtil.getName(blockingVehicle))
        local course
        if AIDriveStrategyCombineCourse.isActiveCpCombine(blockingVehicle) then
            -- except we are blocking our buddy, so set up a course parallel to the combine's direction,
            -- with an offset from the combine that makes sure we are clear. Use the trailer's root node (and not
            -- the tractor's) as when we reversing, it is easier when the trailer remains on the same side of the combine
            local trailer = AIUtil.getImplementOrVehicleWithSpecialization(self.vehicle, Trailer)
            local dx, _, _ = localToLocal(trailer.rootNode, blockingVehicle:getAIDirectionNode(), 0, 0, 0)
            local xOffset = self.vehicle.size.width / 2 + blockingVehicle:getCpDriveStrategy():getWorkWidth() / 2 + 2
            xOffset = dx > 0 and xOffset or -xOffset
            self:setNewState(self.states.MOVING_AWAY_FROM_OTHER_VEHICLE)
            self.state.properties.vehicle = blockingVehicle
            self.state.properties.dx = nil
            if CpMathUtil.isOppositeDirection(self.vehicle:getAIDirectionNode(), blockingVehicle:getAIDirectionNode(), 30) then
                -- we are head on with the combine, so reverse
                -- we will generate a straight reverse course relative to the blocking vehicle, but we want the course start
                -- approximately where our back marker is, as we will be reversing
                local _, _, from = localToLocal(Markers.getBackMarkerNode(self.vehicle), blockingVehicle:getAIDirectionNode(), 0, 0, 0)
                self:debug('%s is a CP combine, head on, so generate a course from %.1f m, xOffset %.1f',
                        CpUtil.getName(blockingVehicle), from, xOffset)
                course = Course.createFromNode(self.vehicle, blockingVehicle:getAIDirectionNode(), xOffset, from,
                        from + self.maxDistanceWhenMovingOutOfWay, 5, true)
                -- we will stop reversing when we are far enough from the combine's path
                self.state.properties.dx = xOffset
            elseif CpMathUtil.isSameDirection(self.vehicle:getAIDirectionNode(), blockingVehicle:getAIDirectionNode(), 30) then
                -- we are in front of the combine, same direction
                -- we will generate a straight forward course relative to the blocking vehicle, but we want the course start
                -- approximately where our front marker is
                local _, _, from = localToLocal(Markers.getFrontMarkerNode(self.vehicle), blockingVehicle:getAIDirectionNode(), 0, 0, 0)
                self:debug('%s is a CP combine, same direction, generate a course from %.1f with xOffset %.1f',
                        CpUtil.getName(blockingVehicle), from, xOffset)
                course = Course.createFromNode(self.vehicle, blockingVehicle:getAIDirectionNode(), xOffset, from,
                        from + self.maxDistanceWhenMovingOutOfWay, 5, false)
                -- drive the entire course, making sure the trailer is also out of way
                self.state.properties.dx = xOffset
            else
                self:debug('%s is a CP combine, not head on, not same direction', CpUtil.getName(blockingVehicle))
                self.state.properties.dx = nil
                course = self:createMoveAwayCourse(blockingVehicle)
            end
        elseif (AIDriveStrategyUnloadCombine.isActiveCpCombineUnloader(blockingVehicle) or
                AIDriveStrategyUnloadCombine.isActiveCpSiloLoader(blockingVehicle)) and
                blockingVehicle:getCpDriveStrategy():isIdle() then
            self:debug('%s is an idle CP combine unloader, request it to move.', CpUtil.getName(blockingVehicle))
            blockingVehicle:getCpDriveStrategy():requestToMoveForward(self.vehicle)
            -- no state change, wait for the other unloader to move
            return
        else
            -- straight back or forward
            course = self:createMoveAwayCourse(blockingVehicle)
            self:setNewState(self.states.MOVING_AWAY_FROM_OTHER_VEHICLE)
            self.state.properties.vehicle = blockingVehicle
            self.state.properties.dx = nil
            if blockingVehicle.cpHold then
                -- ask the other vehicle for hold until we drive around
                blockingVehicle:cpHold(20000)
            end
        end
        self:startCourse(course, 1)
    end
end

function AIDriveStrategyUnloadCombine:requestToMoveOutOfWay(vehicle)
    self:onBlockingVehicle(vehicle)
end

function AIDriveStrategyUnloadCombine:requestToMoveForward(requestingVehicle)
    self:debug('%s requests us to move forward.', CpUtil.getName(requestingVehicle))
    local course = Course.createStraightForwardCourse(self.vehicle, self.maxDistanceWhenMovingOutOfWay, 0)
    self:setNewState(self.states.MOVING_AWAY_FROM_OTHER_VEHICLE)
    self.state.properties.vehicle = requestingVehicle
    self.state.properties.dx = nil
    self:startCourse(course, 1)
end

function AIDriveStrategyUnloadCombine:moveAwayFromOtherVehicle()
    self:setMaxSpeed(self.settings.reverseSpeed:getValue())
    local driveStrategy = self.state.properties.vehicle.getCpDriveStrategy and self.state.properties.vehicle:getCpDriveStrategy()
    -- Are we still close to the vehicle we are blocking?
    if driveStrategy and driveStrategy:isVehicleInProximity(self.vehicle) then
        -- keep driving
        self:debugSparse('Still in proximity of %s', CpUtil.getName(self.state.properties.vehicle))
        self.movingAwayDelay:set(true, 2000)
        return
    end

    -- keep driving for a while after we are out of the proximity of the vehicle we were blocking, to make
    -- sure we have enough clearance
    if self.movingAwayDelay:get() then
        return
    end

    if self.state.properties.dx then
        -- moving away from a CP combine head on with us, move until dx is big enough so it can continue straight
        for _, childVehicle in ipairs(self.vehicle:getChildVehicles()) do
            local dx, _, _ = localToLocal(childVehicle.rootNode, self.state.properties.vehicle:getAIDirectionNode(), 0, 0, 0)
            self:debugSparse('dx between %s and my %s is %.1f', CpUtil.getName(self.state.properties.vehicle), CpUtil.getName(childVehicle), dx)
            if math.abs(dx) < math.abs(self.state.properties.dx) - 1 then
                return
            end
        end
        -- none of my child vehicles are closer than dx to the combine
        self:debug('Moved away from blocking CP combine %s', CpUtil.getName(self.state.properties.vehicle))
        self:startWaitingForSomethingToDo()
    else
        -- moving away from some other vehicle, or our combine not head on, just move until we can
        -- recalculate a path
        local d = calcDistanceFrom(self.vehicle.rootNode, self.state.properties.vehicle.rootNode)
        self:debugSparse('d from %s is %.1f', CpUtil.getName(self.state.properties.vehicle), d)
        if d > 2 * self.turningRadius then
            self:debug('Moved away from blocking vehicle %s', CpUtil.getName(self.state.properties.vehicle))
            self:startWaitingForSomethingToDo()
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Combine is reversing and we are behind it
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:requestToBackupForReversingCombine(blockedVehicle)
    if not self.vehicle:getIsCpActive() then
        return
    end
    self:debug('%s wants me to move out of way', blockedVehicle:getName())
    if self.state ~= self.states.BACKING_UP_FOR_REVERSING_COMBINE and
            self.state ~= self.states.MOVING_BACK and
            self.state ~= self.states.MOVING_AWAY_FROM_OTHER_VEHICLE and
            self.state ~= self.states.MOVING_BACK_WITH_TRAILER_FULL
    then
        -- reverse back a bit, this usually solves the problem
        -- TODO: there may be better strategies depending on the situation
        self:rememberCourse(self.course, self.course:getCurrentWaypointIx())
        self.stateAfterMovedOutOfWay = self.state

        local reverseCourse = Course.createStraightReverseCourse(self.vehicle, self.maxDistanceWhenMovingOutOfWay)
        self:startCourse(reverseCourse, 1)
        self:debug('Moving out of the way for %s', blockedVehicle:getName())
        self:setNewState(self.states.BACKING_UP_FOR_REVERSING_COMBINE)
        self.state.properties.vehicle = blockedVehicle
        -- this state ends when we reach the end of the course or when the combine stops reversing
    else
        self:debug('Already busy moving out of the way')
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Moving out of the way of a combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:moveOutOfWay()
    -- check both distances and use the smaller one, proximity sensor may not see the combine or
    -- d may be big enough but parts of the combine still close
    local blockedVehicle = self.state.properties.vehicle
    local d = self:getDistanceFromCombine(blockedVehicle)
    local dProximity, vehicle = self.proximityController:checkBlockingVehicleFront()
    local combineSpeed = (blockedVehicle.lastSpeedReal * 3600)
    local speed = combineSpeed + MathUtil.clamp(self.minDistanceWhenMovingOutOfWay - math.min(d, dProximity),
            -combineSpeed, self.settings.reverseSpeed:getValue() * 1.2)

    self:setMaxSpeed(speed)

    if AIUtil.isReversing(blockedVehicle) then
        -- add a little delay as isReversing may return false for a brief period if the combine stops or very slow
        self.blockedVehicleReversing:set(true, 1000)
    end

    -- combine stopped reversing or stopped and waiting for unload, resume what we were doing before
    if not self.blockedVehicleReversing:get() or
            (self.vehicle.getCpDriveStrategy and self.vehicle:getCpDriveStrategy().willWaitForUnloadToFinish and
                    self.vehicle:getCpDriveStrategy():willWaitForUnloadToFinish()) then
        -- end reversing course prematurely, it'll resume previous course
        self:onLastWaypointPassed()
    end
end

function AIDriveStrategyUnloadCombine:findOtherUnloaderAroundCombine(combine, combineOffset)
    if not combine then
        return nil
    end
    if g_currentMission then
        for _, vehicle in pairs(g_currentMission.vehicles) do
            if vehicle ~= self.vehicle and vehicle.cp.driver and vehicle.cp.driver:is_a(AIDriveStrategyUnloadCombine) then
                local dx, _, dz = localToLocal(vehicle.rootNode, combine:getAIDirectionNode(), 0, 0, 0)
                if math.abs(dz) < 30 and math.abs(dx) <= (combineOffset + 3) then
                    -- this is another unloader not too far from my combine
                    -- which side it is?
                    self:debugSparse('There is an other unloader (%s) around my combine (%s), dx = %.1f',
                            CpUtil.getName(vehicle), CpUtil.getName(combine), dx)
                    return dx
                end
            end
        end
    end
end

--- Find a path to the start position marker, but in the opposite direction of the marker and an offset of 4.5 m to the side.
function AIDriveStrategyUnloadCombine:startPathfindingToInvertedGoalPositionMarker()
    self:setNewState(self.states.WAITING_FOR_PATHFINDER)
    self.pathfindingStartedAt = g_currentMission.time
    local fieldNum = CpFieldUtil.getFieldNumUnderVehicle(self.vehicle)
    self:startPathfinding(self.invertedStartPositionMarkerNode, self.invertedGoalPositionOffset,
            -1.5 * AIUtil.getLength(self.vehicle), fieldNum, nil,
            self.onPathfindingDoneToInvertedGoalPositionMarker)
end

--- Path to the start position was found.
---@param path table
---@param goalNodeInvalid boolean
function AIDriveStrategyUnloadCombine:onPathfindingDoneToInvertedGoalPositionMarker(path, goalNodeInvalid)
    if self:isPathFound(path, goalNodeInvalid, "Inverted start position", false) and self.state == self.states.WAITING_FOR_PATHFINDER then
        self:debug("Found a path to the inverted goal position marker. Appending the missing straight segment.")
        self:setNewState(self.states.DRIVING_BACK_TO_START_POSITION_WHEN_FULL)
        local course = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)

        --- Append a straight alignment segment
        local x, _, z = course:getWaypointPosition(course:getNumberOfWaypoints())
        local dx, _, dz = localToWorld(self.invertedStartPositionMarkerNode, self.invertedGoalPositionOffset, 0, 0)

        course:append(Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz,
                0, 0, 0, 3, false))
        self:startCourse(course, 1)
    else
        self:debug("Could not find a path to the start position marker, pass over to the job!")
        self.vehicle:getJob():onTrailerFull(self.vehicle, self)
    end
end

-----------------------------------------------------------------------------------------------------------------------
--- Self unload
-----------------------------------------------------------------------------------------------------------------------
---
function AIDriveStrategyUnloadCombine:getSelfUnloadTargetParameters()
    return SelfUnloadHelper:getTargetParameters(
            self.fieldPolygon,
            self.vehicle,
    -- TODO: this is just a shot in the dark there should be a better way to find out what we have in
    -- the trailer
            self.augerWagon:getFillUnitFirstSupportedFillType(1),
            self.pipeController)
end

--- Find a path to the best trailer to unload
---@param ignoreFruit boolean if true, do not attempt to avoid fruit
function AIDriveStrategyUnloadCombine:startSelfUnload(ignoreFruit)

    if not self.pathfinder or not self.pathfinder:isActive() then
        self.pathfindingStartedAt = g_currentMission.time
        local alignLength, offsetX, unloadTrailer
        self.selfUnloadTargetNode, alignLength, offsetX, unloadTrailer = self:getSelfUnloadTargetParameters()
        if not self.selfUnloadTargetNode then
            return false
        end

        self.unloadTrailer = unloadTrailer

        -- little straight section parallel to the trailer to align better
        self:debug('Align course relative to target node from %.1f to %.1f, pipe offset %.1f',
                -alignLength + 1, -self.pipeController:getPipeOffsetZ() - self.unloadTargetOffset,
                self.pipeController:getPipeOffsetZ())
        self.selfUnloadAlignCourse = Course.createFromNode(self.vehicle, self.selfUnloadTargetNode,
                offsetX, -alignLength + 1,
                -self.pipeController:getPipeOffsetZ() - self.unloadTargetOffset,
                1, false)

        self:setNewState(self.states.WAITING_FOR_PATHFINDER)
        local fieldNum = CpFieldUtil.getFieldNumUnderVehicle(self.vehicle)
        local done, path
        -- require full accuracy from pathfinder as we must exactly line up with the trailer
        self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToNode(
                self.vehicle, self.selfUnloadTargetNode, offsetX, -alignLength,
                self:getAllowReversePathfinding(),
        -- use a low field penalty to encourage the pathfinder to bridge that gap between the field and the trailer
                fieldNum, {}, ignoreFruit and math.huge or nil, 0.1, nil, true)
        if done then
            return self:onPathfindingDoneBeforeSelfUnload(path)
        else
            self:setPathfindingDoneCallback(self, self.onPathfindingDoneBeforeSelfUnload)
        end
    else
        self:debug('Pathfinder already active')
    end
    return true
end

function AIDriveStrategyUnloadCombine:onPathfindingDoneBeforeSelfUnload(path)
    if path and #path > 2 then
        self.retryingSelfUnloadPathfinding = false
        self:debug('Pathfinding to self unload finished with %d waypoints (%d ms)',
                #path, g_currentMission.time - (self.pathfindingStartedAt or 0))
        local selfUnloadCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        if self.selfUnloadAlignCourse then
            selfUnloadCourse:append(self.selfUnloadAlignCourse)
            self.selfUnloadAlignCourse = nil
        end
        self:setNewState(self.states.DRIVING_TO_SELF_UNLOAD)
        self:startCourse(selfUnloadCourse, 1)
        return true
    elseif not self.retryingSelfUnloadPathfinding then
        self.retryingSelfUnloadPathfinding = true
        self:info('No path found to self unload in %d ms, retrying once with fruit avoidance disabled',
                g_currentMission.time - (self.pathfindingStartedAt or 0))
        self:startSelfUnload(true)
    else
        self.retryingSelfUnloadPathfinding = false
        self:debug('No path found to self unload in %d ms', g_currentMission.time - (self.pathfindingStartedAt or 0))
        self.vehicle:stopCurrentAIJob(AIMessageCpErrorNoPathFound.new())
        return false
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Driving to a trailer to unload an auger wagon
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:driveToSelfUnload()
    if self.course:isCloseToLastWaypoint(25) then
        -- disable one side of the proximity sensors to avoid being blocked by the trailer or its tractor
        -- TODO: make it work with pipe on the right side
        if self.pipeController:isPipeOnTheLeftSide() then
            self.proximityController:disableLeftSide()
        else
            self.proximityController:disableRightSide()
        end
    end
    -- slow down towards the end of course
    if self.course:isCloseToLastWaypoint(5) then
        self:setMaxSpeed(5)
    elseif self.course:isCloseToLastWaypoint(15) then
        self:setMaxSpeed(self.settings.turnSpeed:getValue())
    else
        self:setFieldSpeed()
    end
end

function AIDriveStrategyUnloadCombine:onLastWaypointPassedWhenDrivingToSelfUnload()
    self.pipeController:openPipe()
    self:setNewState(self.states.WAITING_FOR_AUGER_PIPE_TO_OPEN)
end

------------------------------------------------------------------------------------------------------------------------
-- Once at the trailer, waiting for the auger wagon's pipe to open
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:waitForAugerPipeToOpen()
    self:setMaxSpeed(0)
    if not self.pipeController:isPipeMoving() or self.pipeController:isPipeOpen() then
        self:setNewState(self.states.UNLOADING_AUGER_WAGON)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Unload the auger wagon into the trailer
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:unloadAugerWagon()
    local currentDischargeNode = self.augerWagon:getCurrentDischargeNode()
    local _, _, dz = localToLocal(currentDischargeNode.node, self.selfUnloadTargetNode, 0, 0, 0)

    -- move forward or backward slowly until the pipe is within 20 cm of target
    self:setMaxSpeed((math.abs(dz) > 0.2) and 1 or 0)

    if not self.augerWagon:getCanDischargeToObject(currentDischargeNode) then
        local fillLevelPercentage = self:getFillLevelPercentage()
        self:debug('Unloading to trailer ended, my fill level is %.1f', fillLevelPercentage)
        if fillLevelPercentage < 10 then
            self:startMovingAwayFromUnloadTrailer()
        else
            local unloadTrailer
            self.selfUnloadTargetNode, _, _, unloadTrailer = self:getSelfUnloadTargetParameters()

            if self.selfUnloadTargetNode and unloadTrailer == self.unloadTrailer then
                self:debug('Auger wagon has fruit after unloading and the same trailer (%s) seems to have capacity',
                        CpUtil.getName(unloadTrailer))
                self:startMovingToNextFillNode(self.selfUnloadTargetNode)
            else
                -- done with this trailer, move away from it and wait for the
                self:debug('Auger wagon not empty after unloading but done with this trailer (%s) as it is full',
                        CpUtil.getName(self.unloadTrailer))
                self:startMovingAwayFromUnloadTrailer(true)
            end
        end
    end
    -- forward or backward
    return dz < 0
end

-- Start moving to the next fill node of the same trailer
function AIDriveStrategyUnloadCombine:startMovingToNextFillNode(newSelfUnloadTargetNode)
    local _, _, dz = localToLocal(newSelfUnloadTargetNode, self.vehicle:getAIDirectionNode(),
            0, 0, -self.pipeController:getPipeOffsetZ())
    local selfUnloadCourse
    if dz > 0 then
        -- next fill node is in front of us, move forward
        selfUnloadCourse = Course.createFromNode(self.vehicle, self.vehicle:getAIDirectionNode(),
                0, 0, dz + 2, 1, false)
    else
        -- next fill node behind us, need to reverse
        local reverserNode = AIUtil.getReverserNode(self.vehicle, self.augerWagon)
        selfUnloadCourse = Course.createFromNode(self.vehicle, reverserNode, 0, 0, dz - 2, 1, true)
    end
    self:debug('Course to next target node of the same trailer created, dz = %.1f', dz)
    self:setNewState(self.states.MOVING_TO_NEXT_FILL_NODE)
    self:startCourse(selfUnloadCourse, 1)
end

-- Move forward or backward until we can discharge again
function AIDriveStrategyUnloadCombine:moveToNextFillNode()
    local currentDischargeNode = self.augerWagon:getCurrentDischargeNode()
    local _, _, dz = localToLocal(currentDischargeNode.node, self.selfUnloadTargetNode, 0, 0, 0)

    -- move forward or backward slowly towards the target fill node
    self:setMaxSpeed((math.abs(dz) > 0.2) and 1 or 0)

    if self.augerWagon:getCanDischargeToObject(currentDischargeNode) then
        self:debug('Can discharge again, moving closer to the fill node')
        self:setNewState(self.states.UNLOADING_AUGER_WAGON)
    end

    return dz < 0
end

-- Move a bit forward and away from the trailer/tractor we just unloaded into so the
-- pathfinder won't have problems when search for a path to the combine
---@param attemptToUnloadAgainAfterMovedAway boolean after moved away, attempt to find a trailer to unload
--- again as the auger wagon isn't empty yet
function AIDriveStrategyUnloadCombine:startMovingAwayFromUnloadTrailer(attemptToUnloadAgainAfterMovedAway)
    self.selfUnloadTargetNode = nil
    self.attemptToUnloadAgainAfterMovedAway = attemptToUnloadAgainAfterMovedAway
    self.pipeController:closePipe(false)
    self.course = Course.createStraightForwardCourse(self.vehicle, self.maxDistanceWhenMovingOutOfWay,
            self.pipeController:isPipeOnTheLeftSide() and -2 or 2)
    self:setNewState(self.states.MOVING_AWAY_FROM_UNLOAD_TRAILER)
    self:startCourse(self.course, 1)
end

function AIDriveStrategyUnloadCombine:moveAwayFromUnloadTrailer()
    local _, _, dz = localToLocal(self.unloadTrailer.rootNode, Markers.getBackMarkerNode(self.vehicle), 0, 0, 0)
    -- (conveniently ignoring the length offset)
    -- move until our tractor's back marker does not overlap the trailer or it's tractor
    if dz < -math.max(self.unloadTrailer.size.length / 2, self.unloadTrailer.rootVehicle.size.length / 2) then
        self:onMovedAwayFromUnloadTrailer()
    else
        self:setMaxSpeed(5)
    end
end

function AIDriveStrategyUnloadCombine:onMovedAwayFromUnloadTrailer()
    self.proximityController:enableBothSides()
    if self.attemptToUnloadAgainAfterMovedAway then
        self:debug('Moved away from trailer so the pathfinder will work, look for another trailer')
        self:startUnloadingTrailers()
    else
        self:debug('Moved away from trailer so the pathfinder will work')
        self:startWaitingForSomethingToDo()
    end
end


------------------------------------------------------------------------------------------------------------------------
-- Unloading on the field
------------------------------------------------------------------------------------------------------------------------

--- Is the unloader unloading to a heap?
---@param ignoreDrivingToHeap boolean Ignore unloader, that are driving to the heap
---@return boolean
function AIDriveStrategyUnloadCombine:isUnloadingOnTheField(ignoreDrivingToHeap)
    if self.state == self.states.DRIVE_TO_FIELD_UNLOAD_POSITION and ignoreDrivingToHeap then
        return false
    end
    return CpUtil.isStateOneOf(self.state, self.fieldUnloadStates)
            or self.state == self.states.WAITING_FOR_PATHFINDER and CpUtil.isStateOneOf(self.lastState, self.fieldUnloadStates)
end

---@return CpHeapBunkerSilo|nil
function AIDriveStrategyUnloadCombine:getFieldUnloadHeap()
    return self.fieldUnloadData and self.fieldUnloadData.heapSilo
end

--- Starts the unloading on a field with an auger wagon or a trailer.
--- Drives to the heap/ field unload position: 
---     For reverse unloading an offset is applied only if an already existing heap was found.
---     For side unloading the x offset of the discharge node is applied. 
---@param controller ImplementController either a PipeController or TrailerController
---@param allowReverseUnloading boolean is unloading at the back allowed?
function AIDriveStrategyUnloadCombine:startUnloadingOnField(controller, allowReverseUnloading)
    --- Create unload course based on tip side setting(discharge node offset)
    local dischargeNodeIndex, dischargeNode, xOffset = controller:getDischargeNodeAndOffsetForTipSide(self.unloadTipSideID, true)
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
    local fieldNum = CpFieldUtil.getFieldNumUnderVehicle(self.vehicle)
    self:startPathfinding(self.fieldUnloadPositionNode, -self.fieldUnloadData.xOffset,
            -AIUtil.getLength(self.vehicle) * 1.3, fieldNum, nil,
            self.onPathfindingDoneBeforeUnloadingOnField)
end

--- Moves the field unload position to the center front of the heap.
function AIDriveStrategyUnloadCombine:updateFieldPositionByHeapSilo(heapSilo)
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

--- Path to the field unloading position was found.
---@param path table
---@param goalNodeInvalid boolean
function AIDriveStrategyUnloadCombine:onPathfindingDoneBeforeUnloadingOnField(path, goalNodeInvalid)
    if self:isPathFound(path, goalNodeInvalid, "Field unload position", false) and self.state == self.states.WAITING_FOR_PATHFINDER then
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
function AIDriveStrategyUnloadCombine:waitingUntilFieldUnloadIsAllowed()
    self:setMaxSpeed(0)
    for _, unloader in pairs(CpAICombineUnloader.activeUnloaders) do
        if unloader ~= self.vehicle then
            ---@type AIDriveStrategyUnloadCombine
            local strategy = unloader:getCpDriveStrategy()
            if strategy then
                if strategy:isUnloadingOnTheField(true) then
                    if self.fieldUnloadData.heapSilo and self.fieldUnloadData.heapSilo:isOverlappingWith(strategy:getFieldUnloadHeap()) then
                        self:debug("Is waiting for unloader: %s", CpUtil.getName(unloader))
                        return
                    end
                end
            end
        end
    end
    self:onFieldUnloadPositionReached()
end

--- Called when the driver reaches the field unloading position.
function AIDriveStrategyUnloadCombine:onFieldUnloadPositionReached()

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
function AIDriveStrategyUnloadCombine:onReverseFieldUnloadPositionReached()
    local course = Course.createFromNodeToNode(self.vehicle,
            self.vehicle:getAIDirectionNode(), self.fieldUnloadPositionNode,
            0, 0, 5, 3, true)
    self:setNewState(self.states.REVERSING_TO_THE_FIELD_UNLOAD_HEAP)
    self:startCourse(course, 1)
end

--- Reverse driving to the heap.
function AIDriveStrategyUnloadCombine:driveToReverseFieldUnloadHeap()
    --- Checks if the heap end was reached.
    local node = self.fieldUnloadData.dischargeNode.node
    if self.fieldUnloadData.heapSilo:isNodeInSilo(node) then
        self:onReverseFieldUnloadHeapReached()
    end
end

function AIDriveStrategyUnloadCombine:onReverseFieldUnloadHeapReached()
    self:setNewState(self.states.PREPARE_FOR_FIELD_UNLOAD)
    self:debug("Reverse field unload position reached and start preparing for unload.")
end

--- Prepares the auger wagon/trailer for unloading.
--- Waits for the pipe of the auger wagon to unfold.
--- After that unload and use a straight forward course.
function AIDriveStrategyUnloadCombine:prepareForFieldUnload()
    self:setMaxSpeed(0)
    if self.fieldUnloadData.controller:prepareForUnload(true) then
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
function AIDriveStrategyUnloadCombine:onFieldUnloadingFinished()
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
    local fieldNum = CpFieldUtil.getFieldNumUnderVehicle(self.vehicle)
    self:debug("Disabling off-field penalty for driving to the park position.")
    self.offFieldPenalty = 0
    self:startPathfinding(self.fieldUnloadTurnEndNode, -self.fieldUnloadData.xOffset * 1.5,
            -AIUtil.getLength(self.vehicle), fieldNum, nil,
            self.onPathfindingDoneBeforeDrivingToFieldUnloadParkPosition)
end

--- Course to the park position found.
function AIDriveStrategyUnloadCombine:onPathfindingDoneBeforeDrivingToFieldUnloadParkPosition(path, goalNodeInvalid)
    if self:isPathFound(path, goalNodeInvalid, "Field unload position park position", false) and self.state == self.states.WAITING_FOR_PATHFINDER then
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
        self:startWaitingForSomethingToDo()
        self.fieldUnloadData = nil
        return false
    end
end

function AIDriveStrategyUnloadCombine:onFieldUnloadParkPositionReached()
    self:debug("Field unload finished and park position reached.")
    self:startWaitingForSomethingToDo()
    self.fieldUnloadData = nil
end

------------------------------------------------------------------------------------------------------------------------
-- Debug
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:debug(...)
    local combineName = self.combineToUnload and (' -> ' .. CpUtil.getName(self.combineToUnload)) or '(unassigned)'
    CpUtil.debugVehicle(self.debugChannel, self.vehicle, combineName .. ' ' .. self:getStateAsString() .. ': ' .. string.format(...))
end

function AIDriveStrategyUnloadCombine:update(dt)
    AIDriveStrategyUnloadCombine:superClass().update(self)
    if CpUtil.isVehicleDebugActive(self.vehicle) and CpDebug:isChannelActive(self.debugChannel) then
        if self.course then
            self.course:draw()
        end
        if self.selfUnloadTargetNode then
            DebugUtil.drawDebugNode(self.selfUnloadTargetNode, 'Target')
        end
        if self.fieldUnloadData then
            --- Only draw the field unload data, when the field unload is active.
            if self.fieldUnloadPositionNode then
                CpUtil.drawDebugNode(self.fieldUnloadPositionNode, false, 3)
            end
            if self.fieldUnloadTurnEndNode then
                CpUtil.drawDebugNode(self.fieldUnloadTurnEndNode, false, 1)
            end
            if self.fieldUnloadTurnStartNode then
                CpUtil.drawDebugNode(self.fieldUnloadTurnStartNode, false, 1)
            end
            if self.fieldUnloadData.heapSilo then
                self.fieldUnloadData.heapSilo:drawDebug()
            end
        end
        if self.state == self.states.DRIVING_BACK_TO_START_POSITION_WHEN_FULL and self.invertedStartPositionMarkerNode then
            CpUtil.drawDebugNode(self.invertedStartPositionMarkerNode, true, 3);
        end
    end
    self:updateImplementControllers(dt)
end

function AIDriveStrategyUnloadCombine:renderText(x, y, ...)

    if not CpUtil.isVehicleDebugActive(self.vehicle) or not CpDebug:isChannelActive(self.debugChannel) then
        return
    end

    renderText(0.6 + x, 0.2 + y, 0.018, string.format(...))
end

--FillUnit.updateFillUnitAutoAimTarget = Utils.overwrittenFunction(FillUnit.updateFillUnitAutoAimTarget, AIDriveStrategyUnloadCombine.updateFillUnitAutoAimTarget)
