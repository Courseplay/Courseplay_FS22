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


]]--

---@class AIDriveStrategyUnloadCombine : AIDriveStrategyCourse
AIDriveStrategyUnloadCombine = {}
local AIDriveStrategyUnloadCombine_mt = Class(AIDriveStrategyUnloadCombine, AIDriveStrategyCourse)

AIDriveStrategyUnloadCombine.minDistanceWhenMovingOutOfWay = 5
AIDriveStrategyUnloadCombine.safeManeuveringDistance = 30 -- distance to keep from a combine not ready to unload
AIDriveStrategyUnloadCombine.unloaderFollowingDistance = 30 -- distance to keep between two unloaders assigned to the same chopper
AIDriveStrategyUnloadCombine.pathfindingRange = 5 -- won't do pathfinding if target is closer than this
AIDriveStrategyUnloadCombine.proximitySensorRange = 15

-- Developer hack: to check the class of an object one should use the is_a() defined in CpObject.lua.
-- However, when we reload classes on the fly during the development, the is_a() calls in other modules still
-- have the old class definition (for example CombineUnloadManager.lua) of this class and thus, is_a() fails.
-- Therefore, use this instead, this is safe after a reload.
AIDriveStrategyUnloadCombine.isACombineUnloadAIDriver = true

AIDriveStrategyUnloadCombine.myStates = {
    ON_FIELD = {},
    ON_UNLOAD_COURSE = { checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true },
    WAITING_FOR_COMBINE_TO_CALL = {},
    WAITING_FOR_PATHFINDER = {},
    DRIVE_TO_COMBINE = { checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true },
    DRIVE_TO_MOVING_COMBINE = { checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true },
    UNLOADING_MOVING_COMBINE = {},
    UNLOADING_STOPPED_COMBINE = {},
    MOVING_BACK = {},
    MOVING_BACK_WITH_TRAILER_FULL = {},
    MOVING_OUT_OF_WAY = {},
    MOVING_AWAY_FROM_BLOCKING_VEHICLE = {},
    WAITING_FOR_MANEUVERING_COMBINE = {},
    ON_UNLOAD_WITH_AUTODRIVE = {},
}

function AIDriveStrategyUnloadCombine.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyUnloadCombine_mt
    end
    local self = AIDriveStrategyCourse.new(customMt)
    AIDriveStrategyCourse.initStates(self, AIDriveStrategyUnloadCombine.myStates)
    self.state = self.states.WAITING_FOR_COMBINE_TO_CALL
    self.debugChannel = CpDebug.DBG_UNLOAD_COMBINE
    ---@type ImplementController[]
    self.controllers = {}
    self.combineOffset = 0
    self.distanceToCombine = math.huge
    self.distanceToFront = 0
    self.combineToUnloadReversing = 0
    self.doNotSwerveForVehicle = CpTemporaryObject()
    self.justFinishedPathfindingForDistance = CpTemporaryObject()
    self.timeToCheckCombines = CpTemporaryObject(true)
    self:resetPathfinder()
    return self
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

function AIDriveStrategyUnloadCombine:setFieldPolygon(fieldPolygon)
    self.fieldPolygon = fieldPolygon
end

function AIDriveStrategyUnloadCombine:getGeneratedCourse(jobParameters)
    return nil
end

function AIDriveStrategyUnloadCombine:setJobParameterValues(jobParameters)
    self.fullThreshold = jobParameters.fullThreshold:getValue()
    self:debug("Will consider itself full over %d percent", self.fullThreshold)
end

function AIDriveStrategyUnloadCombine:setAIVehicle(vehicle, jobParameters)
    AIDriveStrategyUnloadCombine:superClass().setAIVehicle(self, vehicle)
    self.reverser = AIReverseDriver(self.vehicle, self.ppc)
    self.proximityController = ProximityController(self.vehicle, self.ppc, self:getProximitySensorWidth())
    self.proximityController:registerIsSlowdownEnabledCallback(self, AIDriveStrategyUnloadCombine.isProximitySpeedControlEnabled)
    -- remove any course already loaded (for instance to not to interfere with the fieldworker proximity controller)
    vehicle:resetCpCourses()
    self:resetPathfinder()

    self.augerWagon = AIUtil.getImplementOrVehicleWithSpecialization(self.vehicle, Pipe)
    if self.augerWagon then
        ImplementUtil.setPipeAttributes(self, self.augerWagon, self.augerWagon)
        self:debug('Found an auger wagon.')
    else
        self:debug('No auger wagon found.')
    end
end

function AIDriveStrategyUnloadCombine:resetPathfinder()
    self.maxFruitPercent = 10
    -- prefer driving on field, don't do this too aggressively until we take into account the field owner
    -- otherwise we'll be driving through others' fields
    self.offFieldPenalty = PathfinderUtil.defaultOffFieldPenalty
    self.pathfinderFailureCount = 0
end

function AIDriveStrategyUnloadCombine:isTrafficConflictDetectionEnabled()
    return self.trafficConflictDetectionEnabled and
            (self.state == self.states.ON_UNLOAD_COURSE and self.state.properties.checkForTrafficConflict) or
            (self.state == self.states.ON_FIELD and self.state.properties.checkForTrafficConflict)
end

function AIDriveStrategyUnloadCombine:isProximitySwerveEnabled(vehicle)
    if vehicle == self.doNotSwerveForVehicle:get() then
        return false
    end
    return (self.state == self.states.ON_UNLOAD_COURSE and self.state.properties.enableProximitySwerve) or
            (self.state == self.states.ON_FIELD and self.state.properties.enableProximitySwerve)
end

function AIDriveStrategyUnloadCombine:isProximitySpeedControlEnabled()
    return true
end

function AIDriveStrategyUnloadCombine:isWaitingForAssignment()
    return self.state == self.states.ON_FIELD and self.state == self.states.WAITING_FOR_COMBINE_TO_CALL
end

------------------------------------------------------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:getDriveData(dt, vX, vY, vZ)
    self:updateLowFrequencyImplementControllers()
    -- make sure if we have a combine we stay registered
    if self.combineToUnload then
        self.combineToUnload:getCpDriveStrategy():registerUnloader(self)
    end

    -- safety check: combine has active AI driver
    if self.combineToUnload and not self.combineToUnload:getIsCpFieldWorkActive() then
        self:setMaxSpeed(0)
    elseif self.state == self.states.WAITING_FOR_COMBINE_TO_CALL then
        self:setMaxSpeed(0)

        if self:getDriveUnloadNow() or self:getAllTrailersFull() then
            self:startUnloadingTrailers()
            return
        end

        -- every few seconds, check for a combine which needs an unloader
        if self.timeToCheckCombines:get() then
            self:debug('Check if there\'s a combine to unload')
            self.combineToUnload, _ = self:findCombine()
            if self.combineToUnload then
                self:startWorking()
            else
                -- check back in a few seconds
                self.timeToCheckCombines:set(false, 5000)
            end
        end
    elseif self.state == self.states.WAITING_FOR_PATHFINDER then
        -- just wait for the pathfinder to finish
        self:setMaxSpeed(0)

    elseif self.state == self.states.DRIVE_TO_COMBINE then

        self:driveToCombine()

    elseif self.state == self.states.DRIVE_TO_MOVING_COMBINE then

        self:driveToMovingCombine()

    elseif self.state == self.states.UNLOADING_STOPPED_COMBINE then

        self:unloadStoppedCombine()

    elseif self.state == self.states.WAITING_FOR_MANEUVERING_COMBINE then

        self:waitForManeuveringCombine()

    elseif self.state == self.states.MOVING_OUT_OF_WAY then

        self:moveOutOfWay()

    elseif self.state == self.states.UNLOADING_MOVING_COMBINE then

        self:unloadMovingCombine(dt)

    elseif self.state == self.states.MOVING_AWAY_FROM_BLOCKING_VEHICLE then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        local d = calcDistanceFrom(self.vehicle.rootNode, self.blockingVehicle.rootNode)
        if d > 2 * self.turningRadius then
            self:debug('Moved away from blocking vehicle')
            self:startWaitingForCombine()
        end

    elseif self.state == self.states.MOVING_BACK_WITH_TRAILER_FULL then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        local _, dx, dz = self:getDistanceFromCombine(self.combineJustUnloaded)
        -- drive back way further if we are behind a chopper to have room
        local dDriveBack = math.abs(dx) < 3 and 1.5 * self.turningRadius or -10
        if dz > dDriveBack then
            self:startUnloadingTrailers()
        end

    elseif self.state == self.states.MOVING_BACK then

        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        -- drive back until the combine is in front of us
        local _, _, dz = self:getDistanceFromCombine(self.combineJustUnloaded)
        if dz > 0 then
            self:startWaitingForCombine()
        end

    end
    self:checkProximitySensors()
    self:checkBlockingVehicle()
    return AIDriveStrategyUnloadCombine.superClass().getDriveData(self, dt, vX, vY, vZ)
end

function AIDriveStrategyUnloadCombine:startWaitingForCombine()
    self:releaseCombine()
    self.timeToCheckCombines:set(false, 5000)
    self.course = Course.createStraightForwardCourse(self.vehicle, 25)
    self:setNewState(self.states.WAITING_FOR_COMBINE_TO_CALL)
end

function AIDriveStrategyUnloadCombine:driveBesideCombine()
    -- we don't want a moving target
    self:fixAutoAimNode()
    local targetNode = self:getTrailersTargetNode()
    local _, offsetZ = self:getPipeOffset(self.combineToUnload)
    -- TODO: this - 1 is a workaround the fact that we use a simple P controller instead of a PI
    local _, _, dz = localToLocal(targetNode, self:getCombineRootNode(), 0, 0, -offsetZ - 1)
    -- use a factor to make sure we reach the pipe fast, but be more gentle while discharging
    local factor = self.combineToUnload:getCpDriveStrategy():isDischarging() and 0.5 or 2
    local speed = self.combineToUnload.lastSpeedReal * 3600 + MathUtil.clamp(-dz * factor, -10, 15)

    -- slow down while the pipe is unfolding to avoid crashing onto it
    if self.combineToUnload:getCpDriveStrategy():isPipeMoving() then
        speed = (math.min(speed, self.combineToUnload:getLastSpeed() + 2))
    end

    self:renderText(0, 0.02, "%s: driveBesideCombine: dz = %.1f, speed = %.1f, factor = %.1f",
            CpUtil.getName(self.vehicle), dz, speed, factor)
    if not CpUtil.isVehicleDebugActive(self.vehicle) or not CpDebug:isChannelActive(self.debugChannel) then
        DebugUtil.drawDebugNode(targetNode, 'target')
    end
    self:setMaxSpeed(math.max(0, speed))
end

function AIDriveStrategyUnloadCombine:onEndCourse()
    if self.state == self.states.ON_UNLOAD_COURSE or self.state == self.states.ON_UNLOAD_WITH_AUTODRIVE then
        self:setNewState(self.states.ON_FIELD)
        self:startWaitingForCombine()
        self:setDriveUnloadNow(false)
        self:openCovers(self.vehicle)
        self:disableCollisionDetection()
    end
end

function AIDriveStrategyUnloadCombine:onWaypointPassed(ix, course)
    if course:isLastWaypointIx(ix) then
        self:onLastWaypointPassed()
    end
end

function AIDriveStrategyUnloadCombine:onLastWaypointPassed()
    if self.state == self.states.DRIVE_TO_COMBINE or
            self.state == self.states.DRIVE_TO_MOVING_COMBINE then
        self:startWorking()
    elseif self.state == self.states.MOVING_OUT_OF_WAY then
        self:setNewState(self.stateAfterMovedOutOfWay)
    end
end

-- if closer than this to the last waypoint, start slowing down
function AIDriveStrategyUnloadCombine:getSlowDownDistanceBeforeLastWaypoint()
    local d = AIDriver.defaultSlowDownDistanceBeforeLastWaypoint
    -- in some states there's no need to slow down before reaching the last waypoints
    if self.state == self.states.ON_FIELD then
        if self.state == self.states.DRIVE_TO_FIRST_UNLOADER then
            d = 0
        else
            -- in general, be more bold than the standard AI Driver to not waste time for rendezvous
            d = AIDriver.defaultSlowDownDistanceBeforeLastWaypoint / 3
        end
    end
    return d
end

function AIDriveStrategyUnloadCombine:setFieldSpeed()
    if self.course then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    end
end

function AIDriveStrategyUnloadCombine:setNewState(newState)
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
    --return combine:getCpDriveStrategy():getPipeOffset(-self.settings.combineOffsetX:get(), self.settings.combineOffsetZ:get())
    return combine:getCpDriveStrategy():getPipeOffset(0, 0)
end

function AIDriveStrategyUnloadCombine:getCombinesMeasuredBackDistance()
    return self.combineToUnload:getCpDriveStrategy():getMeasuredBackDistance()
end

function AIDriveStrategyUnloadCombine:getCanShowDriveOnButton()
    return self.state == self.states.ON_FIELD or AIDriver.getCanShowDriveOnButton(self)
end

function AIDriveStrategyUnloadCombine:getAllTrailersFull()
    local fillLevelInfo = {}
    self.fillLevelManager:getAllFillLevels(self.vehicle, fillLevelInfo)
    for fillType, info in pairs(fillLevelInfo) do
        if self.fillLevelManager:isValidFillType(self.vehicle, fillType) and info.fillLevel < info.capacity then
            -- not fuel and not full, so not all full...
            -- TODO: this assumes that other than diesel, air, etc. the only fill type we have is the one the
            -- combine is harvesting. Could consider the combine's fill type but that sometimes is UNKNOWN
            return false
        end
    end
    return true
end

--- Fill level in %. Assumes all trailers have the same fill type
function AIDriveStrategyUnloadCombine:getFillLevelPercentage()
    local fillLevelInfo = {}
    local totalFillLevel, totalCapacity = 0, 0
    self.fillLevelManager:getAllFillLevels(self.vehicle, fillLevelInfo)
    for fillType, info in pairs(fillLevelInfo) do
        if self.fillLevelManager:isValidFillType(self.vehicle, fillType) then
            totalFillLevel = info.fillLevel
            totalCapacity = info.capacity
        end
    end
    return totalFillLevel / totalCapacity * 100
end

function AIDriveStrategyUnloadCombine:shouldDriveOn()
    return self:getFillLevelPercentage() > self:getDriveOnThreshold()
end

function AIDriveStrategyUnloadCombine:getDriveUnloadNow()
    --return self.settings.driveUnloadNow:get()
    return false
end

function AIDriveStrategyUnloadCombine:setDriveUnloadNow(driveUnloadNow)
    --self.settings.driveUnloadNow:set(driveUnloadNow)
    --self:refreshHUD()
end

function AIDriveStrategyUnloadCombine:getDriveOnThreshold()
    -- TODO
    return 100
end

function AIDriveStrategyUnloadCombine:releaseCombine()
    if self.combineToUnload then
        self.combineToUnload:getCpDriveStrategy():deregisterUnloader(self)
    end
    self.combineJustUnloaded = self.combineToUnload
    self.combineToUnload = nil
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

function AIDriveStrategyUnloadCombine:isBehindAndAlignedToCombine(debugEnabled)
    local dx, _, dz = localToLocal(self.vehicle.rootNode, self.combineToUnload:getAIDirectionNode(), 0, 0, 0)
    local pipeOffset = self:getPipeOffset(self.combineToUnload)
    if dz > 0 then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: dz > 0')
        return false
    end
    if math.abs(dx) > math.abs(1.5 * pipeOffset) then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: dx > 1.5 pipe offset (%.1f > 1.5 * %.1f)', dx, pipeOffset)
        return false
    end
    local d = MathUtil.vector2Length(dx, dz)
    if d > 30 then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: too far from combine (%.1f > 30)', d)
        return false
    end
    if not CpMathUtil.isSameDirection(self.vehicle:getAIDirectionNode(), self.combineToUnload:getAIDirectionNode(), 45) then
        self:debugIf(debugEnabled, 'isBehindAndAlignedToCombine: direction difference is > 45)')
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
    if math.abs(dx) > math.abs(1.5 * pipeOffset) and math.abs(dx) < math.abs(pipeOffset) * 0.5 then
        self:debugIf(debugEnabled,
                'isInFrontAndAlignedToMovingCombine: dx (%.1f) not between 0.5 and 1.5 pipe offset (%.1f)', dx, pipeOffset)
        return false
    end
    if not CpMathUtil.isSameDirection(self.vehicle:getAIDirectionNode(), self.combineToUnload:getAIDirectionNode(), 30) then
        self:debugIf(debugEnabled, 'isInFrontAndAlignedToMovingCombine: direction difference is > 30)')
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
-- Start the real work now!
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startWorking()
    if self:isOkToStartUnloadingCombine() then
        -- Right behind the combine, aligned, go for the pipe
        self:startUnloadingCombine()
    else
        self:startDrivingToCombine()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Start the course to unload the trailers
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startUnloadingTrailers()
    self:setMaxSpeed(0)
    if self.augerWagon then
        self:debug('Have auger wagon, looking for a trailer.')
    else
        self:debug('Have no auger wagon, stop, so eventually AD can take over.')
        self.vehicle:stopCurrentAIJob(AIMessageErrorIsFull.new())
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
    -- try to find the waypoint closest to the vehicle, as startIx we got is right beside the combine
    -- which may be far away and if that's our target, PPC will be slow to bring us back on the course
    -- and we may end up between the end of the pipe and the combine
    local startSearchAt = startIx - 5
    local nextFwdIx, found = self.followCourse:getNextFwdWaypointIxFromVehiclePosition(startSearchAt > 0 and startSearchAt or 1,
            self.vehicle:getAIDirectionNode(), self.combineToUnload:getCpDriveStrategy():getWorkWidth())
    if found then
        startIx = nextFwdIx
    end
    self.combineOffset = self:getPipeOffset(self.combineToUnload)
    self.followCourse:setOffset(-self.combineOffset, 0)
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

function AIDriveStrategyUnloadCombine:getCombineRootNode()
    -- for attached harvesters this gets the root node of the harvester as that is our reference point to the
    -- pipe offsets
    return self.combineToUnload:getCpDriveStrategy():getCombine().rootNode
end

------------------------------------------------------------------------------------------------------------------------
--Start driving to combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startDrivingToCombine()
    if self.combineToUnload:getCpDriveStrategy():isWaitingForUnload() then
        self:debug('Combine is waiting for unload, start finding path to combine')
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
    else
        -- combine is moving, agree on a rendezvous, for that, we need to know the driving distance to the
        -- combine first, so find a simple A* path (no hybrid A* needed here as all we need is an approximate distance
        -- avoiding fruit)
        self:debug('Combine is moving, find path to determine driving distance first')
        if self.combineToUnload:getCpDriveStrategy():isWillingToRendezvous() then
            self:startPathfindingForDistance()
        else
            self:debug('Combine is not willing to rendezvous, wait a bit')
            self:startWaitingForCombine()
        end
    end
end

function AIDriveStrategyUnloadCombine:onPathfindingDoneToMovingCombine(path, goalNodeInvalid)
    if self:isPathFound(path, goalNodeInvalid, CpUtil.getName(self.combineToUnload)) and self.state == self.states.WAITING_FOR_PATHFINDER then
        local driveToCombineCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        self:startCourse(driveToCombineCourse, 1)
        self:setNewState(self.states.DRIVE_TO_MOVING_COMBINE)
        return true
    else
        self:startWaitingForCombine()
        return false
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Start a simple A* pathfinding to the combine to find out the driving distance while avoiding fruit
-- (which may be considerably longer than a direct path between the unloader and the combine)
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startPathfindingForDistance()
    -- ignore node direction as all we want to know here is the distance
    if self:isPathfindingNeeded(self.vehicle, self:getCombineRootNode(), 0, -15, nil, 360) then
        if self.justFinishedPathfindingForDistance:get() then
            self:debug('just finished another pathfinding for distance, wait a bit before starting another')
            self:startWaitingForCombine()
            return
        end
        self:setNewState(self.states.WAITING_FOR_PATHFINDER)
        local done, path, goalNodeInvalid
        self.pathfindingStartedAt = g_time

        self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startAStarPathfindingFromVehicleToNode(
                self.vehicle, self.combineToUnload:getAIDirectionNode(), 0, -15,
                CpFieldUtil.getFieldNumUnderVehicle(self.combineToUnload), { self.combineToUnload },
                self:getOffFieldPenalty(self.combineToUnload))
        if done then
            self:onPathfindingDoneForDistance(path, goalNodeInvalid)
            return
        else
            self:setPathfindingDoneCallback(self, self.onPathfindingDoneForDistance)
            return
        end
    else
        local d = self:getDistanceFromCombine()
        self:arrangeRendezvousWithCombine(d)
        return
    end
end

function AIDriveStrategyUnloadCombine:onPathfindingDoneForDistance(path, goalNodeInvalid)
    local pauseMs = math.min(g_time - (self.pathfindingStartedAt or 0), 15000)
    self:debug('No pathfinding for distance for %d milliseconds', pauseMs)
    self.justFinishedPathfindingForDistance:set(true, pauseMs)
    if self.state == self.states.WAITING_FOR_PATHFINDER then
        local aStarLength = 0
        if path and #path > 2 then
            local driveToCombineCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
            aStarLength = driveToCombineCourse:getLength()
        else
            self:debug('pathfinding to find distance to combine did not work out, use direct distance.')
        end
        -- to better estimate the driving distance, generate a Dubins path. This will include all turns we have to make
        -- (which may be a considerable distance and thus time). We then take the difference between the Dubins path and
        -- the straight distance and add it to the A* distance. This still isn't accurate but much closer to reality
        local start = PathfinderUtil.getVehiclePositionAsState3D(self.vehicle)
        local goal = PathfinderUtil.getVehiclePositionAsState3D(self.combineToUnload)
        local solution = PathfinderUtil.dubinsSolver:solve(start, goal, self.turningRadius)
        local dubinsPathLength = solution:getLength(self.turningRadius)
        local directPathLength = calcDistanceFrom(self.vehicle.rootNode, self.combineToUnload.rootNode)
        self:debug('Distance: %d m, Dubins: %d m, A*: %d m', directPathLength, aStarLength, dubinsPathLength)
        self:arrangeRendezvousWithCombine(aStarLength + dubinsPathLength - directPathLength)
        return true
    else
        self:debug('pathfinding to find distance to combine done but not waiting for pathfinder, no rendezvous.')
        self:startWaitingForCombine()
        return true
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
        self:startWaitingForCombine()
    end
end

function AIDriveStrategyUnloadCombine:onPathfindingDoneToCombine(path, goalNodeInvalid)
    if self:isPathFound(path, goalNodeInvalid, CpUtil.getName(self.combineToUnload)) and self.state == self.states.WAITING_FOR_PATHFINDER then
        local driveToCombineCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        self:startCourse(driveToCombineCourse, 1)
        self:setNewState(self.states.DRIVE_TO_COMBINE)
        return true
    else
        self:startWaitingForCombine()
        return false
    end
end

------------------------------------------------------------------------------------------------------------------------
-- With the driving distance known, arrange an unload rendezvous with the combine
------------------------------------------------------------------------------------------------------------------------
---@param d number distance in meters to drive to the combine, preferably the pathfinder route around the crop
function AIDriveStrategyUnloadCombine:arrangeRendezvousWithCombine(d)
    if self.combineToUnload:getCpDriveStrategy():hasRendezvousWith(self) then
        self:debug('Have a pending rendezvous, wait a bit')
        self:startWaitingForCombine()
        return
    end
    local estimatedSecondsEnroute = d / (self.settings.fieldSpeed:getValue() / 3.6) + 3 -- add a few seconds to allow for starting the engine/accelerating
    local rendezvousWaypoint, rendezvousWaypointIx = self.combineToUnload:getCpDriveStrategy():getUnloaderRendezvousWaypoint(estimatedSecondsEnroute, self,
            not self.settings.avoidFruit:getValue())
    if rendezvousWaypoint then
        local xOffset, zOffset = self:getPipeOffset(self.combineToUnload)
        if self:isPathfindingNeeded(self.vehicle, rendezvousWaypoint, xOffset, zOffset, 25) then
            self:setNewState(self.states.WAITING_FOR_PATHFINDER)
            -- just in case, as the combine may give us a rendezvous waypoint
            -- where it is full, make sure we are behind the combine
            zOffset = -self:getCombinesMeasuredBackDistance() - 5
            self:debug('Start pathfinding to moving combine, %d m, ETE: %d s, meet combine at waypoint %d, xOffset = %.1f, zOffset = %.1f',
                    d, estimatedSecondsEnroute, rendezvousWaypointIx, xOffset, zOffset)
            self:startPathfinding(rendezvousWaypoint, xOffset, zOffset,
                    CpFieldUtil.getFieldNumUnderVehicle(self.combineToUnload),
                    { self.combineToUnload }, self.onPathfindingDoneToMovingCombine)
        else
            self:debug('Rendezvous waypoint %d to moving combine too close, wait a bit', rendezvousWaypointIx)
            self:startWaitingForCombine()
            return
        end
    else
        self:debug('can\'t find rendezvous waypoint to combine, waiting')
        self:startWaitingForCombine()
        return
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
        pathfindingCallbackFunc)
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

        if type(target) ~= 'number' then
            -- TODO: clarify this xOffset thing, it looks like the course interprets the xOffset differently (left < 0) than
            -- the Giants coordinate system and the waypoint uses the course's conventions. This is confusing, should use
            -- the same reference everywhere
            local goal = PathfinderUtil.getWaypointAsState3D(target, -xOffset or 0, zOffset or 0)
            self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToGoal(
                    self.vehicle, goal, false, fieldNum, vehiclesToIgnore, {},
                    maxFruitPercent, self.offFieldPenalty, self.combineToUnload:getCpDriveStrategy():getAreaToAvoid())
        else
            self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToNode(
                    self.vehicle, target, xOffset or 0, zOffset or 0, false,
                    fieldNum, vehiclesToIgnore, maxFruitPercent,
                    self.offFieldPenalty, self.combineToUnload:getCpDriveStrategy():getAreaToAvoid())
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
    if self:getDriveUnloadNow() or self:getAllTrailersFull() then
        if self:getDriveUnloadNow() then
            self:debug('drive now requested, changing to unload course.')
        else
            self:debug('trailer full, changing to unload course.')
        end
        if self.followCourse and self.followCourse:isCloseToNextTurn(10) and not self.followCourse:isCloseToLastTurn(20) then
            self:debug('... but we are too close to the end of the row, moving back before changing to unload course')
        elseif self.combineToUnload and self.combineToUnload:getCpDriveStrategy():isAboutToReturnFromPocket() then
            self:debug('... letting the combine return from the pocket')
        else
            self:debug('... moving back a little in case AD wants to take over')
        end
        self:releaseCombine()
        self:startMovingBackFromCombine(self.states.MOVING_BACK_WITH_TRAILER_FULL)
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

------------------------------------------------------------------------------------------------------------------------
-- Drive to stopped combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:driveToCombine()

    self:checkForCombineProximity()

    self:setInfoText(self.vehicle, "DRIVE_TO_COMBINE");

    self:setFieldSpeed()

    if self:isOkToStartUnloadingCombine() then
        self:startUnloadingCombine()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Drive to moving combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:driveToMovingCombine()

    self:checkForCombineProximity()

    self:setInfoText("DRIVE_TO_COMBINE");

    self:setFieldSpeed()

    -- stop when too close to a combine not ready to unload (wait until it is done with turning for example)
    if self:isWithinSafeManeuveringDistance(self.combineToUnload) and self.combineToUnload:getCpDriveStrategy():isManeuvering() then
        self:startWaitingForManeuveringCombine()
    elseif self:isOkToStartUnloadingCombine() then
        self:startUnloadingCombine()
    end

    if self.combineToUnload:getCpDriveStrategy():isWaitingForUnloadAfterPulledBack() then
        self:debug('combine is now waiting for unload after pulled back, recalculate path')
        self:startDrivingToCombine()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Waiting for maneuvering combine
------------------------------------------------------------------------------------------------------------------------
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
            self:startWorking()
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
                self:startMovingBackFromCombine(self.states.MOVING_BACK_WITH_TRAILER_FULL)
            else
                self:driveBesideCombine()
            end
        else
            self:debug('finished unloading stopped combine, move back a bit to make room for it to continue')
            self:startMovingBackFromCombine(self.states.MOVING_BACK)
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
            self:startMovingBackFromCombine(self.states.MOVING_BACK)
            return
        elseif self.followCourse:isCloseToNextTurn(10) and not self.followCourse:isCloseToLastTurn(20) then
            self:debug('combine empty and moving forward but we are too close to the end of the row, moving back')
            self:startMovingBackFromCombine(self.states.MOVING_BACK)
            return
        else
            self:debug('combine empty and moving forward')
            self:releaseCombine()
            self:startWaitingForCombine()
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
        self.combineToUnload:getCpDriveStrategy():cancelRendezvous()
        self:startDrivingToCombine()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Start moving back from empty combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startMovingBackFromCombine(newState)
    local reverseCourse = Course.createStraightReverseCourse(self.vehicle, 25)
    self:startCourse(reverseCourse, 1)
    self:setNewState(newState)
    return
end

------------------------------------------------------------------------------------------------------------------------
-- We missed a rendezvous with the combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:onMissedRendezvous(combineAIDriver)
    self:debug('missed the rendezvous with %s', CpUtil.getName(combineAIDriver.vehicle))
    if self.state == self.states.ON_FIELD and self.state == self.states.DRIVE_TO_MOVING_COMBINE and
            self.combineToUnload == combineAIDriver.vehicle then
        if self.course:getDistanceToLastWaypoint(self.course:getCurrentWaypointIx()) > 100 then
            self:debug('over 100 m from the combine to rendezvous, re-planning')
            self:startWorking()
        end
    else
        self:debug('ignore missed rendezvous, state %s, fieldwork state %s', self.state.name, self.state.name)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Is there another vehicle blocking us?
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:checkBlockingVehicle()
    local d, blockingVehicle = self.proximityController:checkBlockingVehicleFront()
    if blockingVehicle then
        -- someone in front of us
        if blockingVehicle == self.blockingVehicle and self.blockedByAnotherVehicleTime - 10000 > g_time then
            -- have been blocked by this guy long enough, try to recover
            self:debug('%s has been blocking us for a while, move back a bit', CpUtil.getName(blockingVehicle))
            local reverseCourse = Course.createStraightReverseCourse(self.vehicle, 25)
            self:startCourse(reverseCourse, 1)
            self:setNewState(self.states.MOVING_AWAY_FROM_BLOCKING_VEHICLE)
        end
        if self.blockingVehicle == nil then
            -- first time we are being blocked, remember the time
            self:debug('%s is blocking us', CpUtil.getName(blockingVehicle))
            self.blockedByAnotherVehicleTime = g_time
        end
        self.blockingVehicle = blockingVehicle
    else
        -- no one in front of us
        self.blockingVehicle = nil
    end
end

------------------------------------------------------------------------------------------------------------------------
-- We are blocking another vehicle who wants us to move out of way
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:onBlockingOtherVehicle(blockedVehicle)
    if not self:isActive() then
        return
    end
    self:debugSparse('%s wants me to move out of way', blockedVehicle:getName())
    if self.state ~= self.states.MOVING_OUT_OF_WAY and
            self.state ~= self.states.MOVING_BACK and
            self.state ~= self.states.MOVING_BACK_WITH_TRAILER_FULL
    then
        -- reverse back a bit, this usually solves the problem
        -- TODO: there may be better strategies depending on the situation
        local reverseCourse = Course.createStraightReverseCourse(self.vehicle, 25)
        self:startCourse(reverseCourse, 1, self.course, self.course:getCurrentWaypointIx())
        self.stateAfterMovedOutOfWay = self.state
        self:debug('Moving out of the way for %s', blockedVehicle:getName())
        self.blockedVehicle = blockedVehicle
        self:setNewState(self.states.MOVING_OUT_OF_WAY)
        -- this state ends when we reach the end of the course or when the combine stops reversing
    else
        self:debugSparse('Already busy moving out of the way')
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Moving out of the way of a combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:moveOutOfWay()
    -- check both distances and use the smaller one, proximity sensor may not see the combine or
    -- d may be big enough but parts of the combine still close
    local d = self:getDistanceFromCombine(self.blockedVehicle)
    local dProximity, vehicle = self.proximityController:checkBlockingVehicleFront()
    local combineSpeed = (vehicle.lastSpeedReal * 3600)
    local speed = combineSpeed + MathUtil.clamp(self.minDistanceWhenMovingOutOfWay - math.min(d, dProximity),
            -combineSpeed, self.settings.reverseSpeed:getValue() * 1.2)

    self:setMaxSpeed(speed)

    -- combine stopped reversing or stopped and waiting for unload, resume what we were doing before
    if not AIUtil.isReversing(vehicle) or
            (self.vehicle.getCpDriveStrategy and self.vehicle.getCpDriveStrategy.willWaitForUnloadToFinish and
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

function AIDriveStrategyUnloadCombine:isAutoDriveDriving()
    return self.state == self.states.ON_UNLOAD_WITH_AUTODRIVE
end

------------------------------------------------------------------------------------------------------------------------
-- Combine management
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:findCombine()
    for _, vehicle in pairs(g_currentMission.vehicles) do
        local driveStrategy = vehicle.getCpDriveStrategy and vehicle:getCpDriveStrategy()
        if driveStrategy and driveStrategy.needUnloader then
            local x, _, z = getWorldTranslation(vehicle.rootNode)
            if CpMathUtil.isPointInPolygon(self.fieldPolygon, x, z) then
                if driveStrategy:needUnloader(self.fullThreshold) then
                    self:debug('Found combine %s on my field, fill level over %d in need of an unloader',
                            CpUtil.getName(vehicle), self.fullThreshold)
                    return vehicle, driveStrategy
                else
                    self:debug('Found combine %s on my field but it does not need an unloader', CpUtil.getName(vehicle))
                end
            else
                self:debug('Combine %s is not on my field', CpUtil.getName(vehicle))
            end
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Debug
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:debug(...)
    local combineName = self.combineToUnload and (' -> ' .. CpUtil.getName(self.combineToUnload)) or '(unassigned)'
    CpUtil.debugVehicle(self.debugChannel, self.vehicle, combineName .. ' ' .. self:getStateAsString() .. ': ' .. string.format(...))
end

function AIDriveStrategyUnloadCombine:update()
    AIDriveStrategyUnloadCombine:superClass().update(self)
    if CpUtil.isVehicleDebugActive(self.vehicle) and CpDebug:isChannelActive(self.debugChannel) then
        if self.course then
            self.course:draw()
        end
    end
end

function AIDriveStrategyUnloadCombine:renderText(x, y, ...)

    if not CpUtil.isVehicleDebugActive(self.vehicle) or not CpDebug:isChannelActive(self.debugChannel) then
        return
    end

    renderText(0.6 + x, 0.2 + y, 0.018, string.format(...))
end

--FillUnit.updateFillUnitAutoAimTarget = Utils.overwrittenFunction(FillUnit.updateFillUnitAutoAimTarget, AIDriveStrategyUnloadCombine.updateFillUnitAutoAimTarget)
