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

AIDriveStrategyUnloadCombine.safetyDistanceFromChopper = 0.75
AIDriveStrategyUnloadCombine.targetDistanceBehindChopper = 1
AIDriveStrategyUnloadCombine.targetOffsetBehindChopper = 3 -- 3 m to the right
AIDriveStrategyUnloadCombine.targetDistanceBehindReversingChopper = 2
AIDriveStrategyUnloadCombine.minDistanceFromReversingChopper = 10
AIDriveStrategyUnloadCombine.minDistanceFromWideTurnChopper = 5
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
    DRIVE_TO_FIRST_UNLOADER = { checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true },
    DRIVE_TO_UNLOAD_COURSE = { checkForTrafficConflict = true, enableProximitySpeedControl = true, enableProximitySwerve = true },
    UNLOADING_MOVING_COMBINE = {},
    UNLOADING_STOPPED_COMBINE = {},
    FOLLOW_CHOPPER = { isUnloadingChopper = true, enableProximitySpeedControl = true },
    FOLLOW_FIRST_UNLOADER = { checkForTrafficConflict = true },
    MOVE_BACK_FROM_REVERSING_CHOPPER = { isUnloadingChopper = true },
    MOVE_BACK_FROM_EMPTY_COMBINE = {},
    MOVE_BACK_FULL = {},
    HANDLE_CHOPPER_HEADLAND_TURN = { isUnloadingChopper = true, isHandlingChopperTurn = true },
    HANDLE_CHOPPER_180_TURN = { isUnloadingChopper = true, isHandlingChopperTurn = true, enableProximitySpeedControl = true },
    FOLLOW_CHOPPER_THROUGH_TURN = { isUnloadingChopper = true, isHandlingChopperTurn = true, enableProximitySpeedControl = true },
    ALIGN_TO_CHOPPER_AFTER_TURN = { isUnloadingChopper = true, isHandlingChopperTurn = true, enableProximitySpeedControl = true },
    MOVING_OUT_OF_WAY = { isUnloadingChopper = true },
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

function AIDriveStrategyUnloadCombine:debug(...)
    local combineName = self.combineToUnload and (' -> ' .. CpUtil.getName(self.combineToUnload)) or '(unassigned)'
    CpUtil.debugVehicle(self.debugChannel, self.vehicle, combineName .. ' ' .. self:getStateAsString() .. ': ' .. string.format(...))
end

function AIDriveStrategyUnloadCombine:setAIVehicle(vehicle, jobParameters)
    AIDriveStrategyUnloadCombine:superClass().setAIVehicle(self, vehicle)
    self.reverser = AIReverseDriver(self.vehicle, self.ppc)
    self.proximityController = ProximityController(self.vehicle, self.ppc, self:getProximitySensorWidth())
    self.proximityController:registerIsSlowdownEnabledCallback(self, AIDriveStrategyUnloadCombine.isProximitySpeedControlEnabled)
    -- remove any course already loaded (for instance to not to interfere with the fieldworker proximity controller)
    vehicle:resetCpCourses()
    self:resetPathfinder()
end

function AIDriveStrategyUnloadCombine:dismiss()
    local x, _, z = getWorldTranslation(self:getDirectionNode())
    if self.combineToUnload then
        self.combineToUnload:getCpDriveStrategy():deregisterUnloader(self)
    end
    self:releaseUnloader()
    if courseplay:isField(x, z) then
        self:setNewState(self.states.ON_FIELD)
        self:startWaitingForCombine()
    end
    AIDriver.dismiss(self)
end

--enables unloading for AIDriveStrategyUnloadCombine with triggerHandler, but gets overwritten by OverloaderAIDriver, as it's not needed for it.
function AIDriveStrategyUnloadCombine:enableFillTypeUnloading()
    self.triggerHandler:enableFillTypeUnloading()
    self.triggerHandler:enableFillTypeUnloadingBunkerSilo()
end

function AIDriveStrategyUnloadCombine:driveUnloadCourse(dt)
    -- TODO: refactor that whole unload process, it was just copied from the legacy CP code
    self:searchForTipTriggers()
    local allowedToDrive, giveUpControl = self:onUnLoadCourse(true, dt)
    if not allowedToDrive then
        self:setMaxSpeed(0)
    end
    if not giveUpControl then
        AIDriver.drive(self, dt)
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
    return (self.state == self.states.ON_UNLOAD_COURSE and self.state.properties.enableProximitySpeedControl) or
            (self.state == self.states.ON_FIELD and self.state.properties.enableProximitySpeedControl)
end

function AIDriveStrategyUnloadCombine:isWaitingForAssignment()
    return self.state == self.states.ON_FIELD and self.state == self.states.WAITING_FOR_COMBINE_TO_CALL
end

function AIDriveStrategyUnloadCombine:startWaitingForCombine()
    self.course = Course.createStraightForwardCourse(self.vehicle, 25)
    self:setNewState(self.states.WAITING_FOR_COMBINE_TO_CALL)
end

-- we want to come to a hard stop while the base class pathfinder is running (starting a course with pathfinding),
-- because the way AIDriver works, it'll initialize the PPC to the new course/waypoint, which will turn the
-- vehicle's wheels in that direction, and since setting speed to 0 will just let the vehicle roll for a while
-- it may be running into something (like the combine)
function AIDriveStrategyUnloadCombine:stopForPathfinding()
    self:setMaxSpeed(0)
end

function AIDriveStrategyUnloadCombine:driveInDirection(dt, lx, lz, fwd, speed, allowedToDrive)
    --AIVehicleUtil.driveInDirection(self.vehicle, dt, self.vehicle.cp.steeringAngle, 1, 0.5, 10, allowedToDrive, fwd, lx, lz, speed, 1)
    -- TODO: use this directly everywhere, seems to work better than the vanilla AIVehicleUtil version
    self:driveVehicleInDirection(dt, allowedToDrive, fwd, lx, lz, speed)
end

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
        -- check for an available combine but not in every loop, not needed
        if self.timeToCheckCombines:get() then
            self:debug('Check if there\'s a combine to unload')
            self.combineToUnload, _ = self:findCombine()
            if self.combineToUnload then
                self:startWorking()
            else
                -- check back in a few seconds
                self.timeToCheckCombines:set(false, 10000)
            end
        end
    elseif self.state == self.states.WAITING_FOR_PATHFINDER then
        -- just wait for the pathfinder to finish
        self:setMaxSpeed(0)

    elseif self.state == self.states.DRIVE_TO_FIRST_UNLOADER then

        -- previous first unloader not unloading anymore
        if self:iAmFirstUnloader() then
            -- switch to drive to chopper or following chopper
            self:startWorking()
        end

        self:setFieldSpeed()

        if self:isOkToStartFollowingFirstUnloader() then
            self:startFollowingFirstUnloader()
        end

    elseif self.state == self.states.WAITING_FOR_FIRST_UNLOADER then
        -- wait to become first unloader or until first unloader can be followed
        if self:iAmFirstUnloader() then
            -- switch to drive to chopper or following chopper
            self:startWorking()
        end

        self:setMaxSpeed(0)

        if self:isOkToStartFollowingFirstUnloader() then
            self:startFollowingFirstUnloader()
        end

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

    elseif self.state == self.states.FOLLOW_CHOPPER then

        self:followChopper()

    elseif self.state == self.states.FOLLOW_FIRST_UNLOADER then

        self:followFirstUnloader()

    elseif self.state == self.states.HANDLE_CHOPPER_HEADLAND_TURN then

        self:handleChopperHeadlandTurn()

    elseif self.state == self.states.HANDLE_CHOPPER_180_TURN then

        self:handleChopper180Turn()

    elseif self.state == self.states.ALIGN_TO_CHOPPER_AFTER_TURN then

        self:alignToChopperAfterTurn()

    elseif self.state == self.states.FOLLOW_CHOPPER_THROUGH_TURN then

        self:followChopperThroughTurn()

    elseif self.state == self.states.DRIVE_TO_UNLOAD_COURSE then

        self:setFieldSpeed()

        -- try not crashing into our combine on the way to the unload course
        if self.combineJustUnloaded and
                not self.combineJustUnloaded.cp.driver:isChopper() and
                self:isWithinSafeManeuveringDistance(self.combineJustUnloaded) and
                self.combineJustUnloaded.cp.driver:isManeuvering() then
            self:debugSparse('holding for maneuvering combine %s on the unload course', self.combineJustUnloaded:getName())
            --self.combineJustUnloaded.cp.driver:hold()
        end

    elseif self.state == self.states.MOVE_BACK_FULL then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        local _, dx, dz = self:getDistanceFromCombine(self.combineJustUnloaded)
        -- drive back way further if we are behind a chopper to have room
        local dDriveBack = math.abs(dx) < 3 and 0.75 * self.settings.turnDiameter:get() or -10
        if dz > dDriveBack then
            self:startUnloadCourse()
        end

    elseif self.state == self.states.MOVE_BACK_FROM_EMPTY_COMBINE then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        -- drive back until the combine is in front of us
        local _, _, dz = self:getDistanceFromCombine(self.combineJustUnloaded)
        if dz > 0 then
            self:startWaitingForCombine()
        end

    elseif self.state == self.states.MOVE_BACK_FROM_REVERSING_CHOPPER then
        self:renderText(0, 0, "drive straight reverse :offset local :%s saved:%s", tostring(self.combineOffset), tostring(self.settings.combineOffsetX:get()))

        local d = self:getDistanceFromCombine()
        local combineSpeed = (self.combineToUnload.lastSpeedReal * 3600)
        local speed = combineSpeed + MathUtil.clamp(self.minDistanceFromReversingChopper - d, -combineSpeed, self.vehicle.cp.speeds.reverse * 1.5)

        self:renderText(0, 0.7, 'd = %.1f, distance diff = %.1f speed = %.1f', d, self.minDistanceFromReversingChopper - d, speed)
        -- keep 15 m distance from chopper
        self:setMaxSpeed(speed)
        if not self:isMyCombineReversing() then
            -- resume forward course
            self:startCourse(self.followCourse, self.followCourse:getCurrentWaypointIx())
            self:setNewState(self.states.HANDLE_CHOPPER_HEADLAND_TURN)
        end
    end
    return AIDriveStrategyUnloadCombine.superClass().getDriveData(self, dt, vX, vY, vZ)
end

function AIDriveStrategyUnloadCombine:setCombineToUnloadClient(combineToUnload)
    self.combineToUnload = combineToUnload
    self.combineToUnload:getCpDriveStrategy():registerUnloader(self.vehicle)
end

function AIDriveStrategyUnloadCombine:getTractorsFillLevelPercent()
    return self.tractorToFollow.cp.totalFillLevelPercent
end

function AIDriveStrategyUnloadCombine:getFillLevelPercent()
    return self.vehicle.cp.totalFillLevelPercent
end

function AIDriveStrategyUnloadCombine:getNominalSpeed()
    if self.state == self.states.ON_UNLOAD_COURSE then
        return self:getRecordedSpeed()
    else
        return self.settings.fieldSpeed:getValue()
    end
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

function AIDriveStrategyUnloadCombine:driveBesideChopper()
    local targetNode = self:getTrailersTargetNode()
    self:renderText(0, 0.02, "%s: driveBesideChopper:offset local :%s saved:%s", CpUtil.getName(self.vehicle), tostring(self.combineOffset), tostring(self.settings.combineOffsetX:get()))
    self:releaseAutoAimNode()
    local _, _, dz = localToLocal(targetNode, self:getCombineRootNode(), 0, 0, 5)
    self:setMaxSpeed(math.max(0, (self.combineToUnload.lastSpeedReal * 3600) + (MathUtil.clamp(-dz, -10, 15))))
end

function AIDriveStrategyUnloadCombine:driveBehindChopper()
    self:renderText(0, 0.05, "%s: driveBehindChopper offset local :%s saved:%s", CpUtil.getName(self.vehicle), tostring(self.combineOffset), tostring(self.settings.combineOffsetX:get()))
    self:fixAutoAimNode()
    --get required Speed
    self:setMaxSpeed(self:getSpeedBehindChopper())
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
    if self.state == self.states.ON_FIELD then
        if self.state == self.states.DRIVE_TO_UNLOAD_COURSE then
            self:setNewState(self.states.ON_UNLOAD_COURSE)
            --AIDriver.onLastWaypoint(self)
            return
        elseif self.state == self.states.DRIVE_TO_FIRST_UNLOADER then
            self:startDrivingToChopper()
        elseif self.state == self.states.DRIVE_TO_COMBINE or
                self.state == self.states.DRIVE_TO_MOVING_COMBINE then
            self:startWorking()
        elseif self.state == self.states.MOVING_OUT_OF_WAY then
            self:setNewState(self.stateAfterMovedOutOfWay)
        end
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

function AIDriveStrategyUnloadCombine:getSpeedBesideChopper(targetNode)
    local allowedToDrive = true
    local baseNode = self:getPipesBaseNode(self.combineToUnload)
    --Discharge Node to AutoAimNode
    local wx, wy, wz = getWorldTranslation(targetNode)
    --cpDebug:drawLine(dnX,dnY,dnZ, 100, 100, 100, wx,wy,wz)
    -- pipe's local position in the trailer's coordinate system
    local dx, _, dz = worldToLocal(baseNode, wx, wy, wz)
    --am I too far in front but beside the chopper ?
    if dz < 3 and math.abs(dx) < math.abs(self:getSavedCombineOffset()) + 1 then
        allowedToDrive = false
    end
    -- negative speeds are invalid
    return math.max(0, (self.combineToUnload.lastSpeedReal * 3600) + (MathUtil.clamp(-dz, -10, 15))), allowedToDrive
end

function AIDriveStrategyUnloadCombine:getSpeedBesideCombine(targetNode)
end

function AIDriveStrategyUnloadCombine:getSpeedBehindChopper()
    local distanceToChoppersBack, _, dz = self:getDistanceFromCombine()
    local fwdDistance = self.chopperProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
    if dz < 0 then
        -- I'm way too forward, stop here as I'm most likely beside the chopper, let it pass before
        -- moving to the middle
        self:setMaxSpeed(0)
    end
    local errorSafety = self.safetyDistanceFromChopper - fwdDistance
    local errorTarget = self.targetDistanceBehindChopper - dz
    local error = math.abs(errorSafety) < math.abs(errorTarget) and errorSafety or errorTarget
    local deltaV = MathUtil.clamp(-error * 2, -10, 15)
    local speed = (self.combineToUnload.lastSpeedReal * 3600) + deltaV
    self:renderText(0, 0.7, 'd = %.1f, dz = %.1f, speed = %.1f, errSafety = %.1f, errTarget = %.1f',
            distanceToChoppersBack, dz, speed, errorSafety, errorTarget)
    return speed
end

function AIDriveStrategyUnloadCombine:getOffsetBehindChopper()
    local distanceToChoppersBack, dx, dz = self:getDistanceFromCombine()

    local rightDistance = self.chopperProximitySensorPack:getClosestObjectDistanceAndRootVehicle(-90)
    local fwdRightDistance = self.chopperProximitySensorPack:getClosestObjectDistanceAndRootVehicle(-45)
    local minDistance = math.min(rightDistance, fwdRightDistance / 1.4)

    local currentOffsetX, _ = self.followCourse:getOffset()
    -- TODO: course offset seems to be inverted
    currentOffsetX = -currentOffsetX
    local error
    if dz < 0 and minDistance < 1000 then
        -- proximity sensor in range, use that to adjust our target offset
        -- TODO: use actual vehicle width instead of magic constant (we need to consider vehicle width
        -- as the proximity sensor is in the middle
        error = (self.safetyDistanceFromChopper + 1) - minDistance
        self.targetOffsetBehindChopper = MathUtil.clamp(self.targetOffsetBehindChopper + 0.02 * error, -20, 20)
        self:debug('err %.1f target %.1f', error, self.targetOffsetBehindChopper)
    end
    error = self.targetOffsetBehindChopper - currentOffsetX
    local newOffset = currentOffsetX + error * 0.2
    self:renderText(0, 0.68, 'right = %.1f, fwdRight = %.1f, current = %.1f, err = %1.f',
            rightDistance, fwdRightDistance, currentOffsetX, error)
    self:debug('right = %.1f, fwdRight = %.1f, current = %.1f, err = %1.f',
            rightDistance, fwdRightDistance, currentOffsetX, error)
    return MathUtil.clamp(-newOffset, -50, 50)
end

function AIDriveStrategyUnloadCombine:getSpeedBehindTractor(tractorToFollow)
    local targetDistance = 35
    local diff = calcDistanceFrom(self.vehicle.rootNode, tractorToFollow.rootNode) - targetDistance
    return math.min(self.settings.fieldSpeed:getValue(), (tractorToFollow.lastSpeedReal * 3600) + (MathUtil.clamp(diff, -10, 25)))
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

function AIDriveStrategyUnloadCombine:getChopperOffset(combine)
    local pipeOffset = g_combineUnloadManager:getCombinesPipeOffset(combine)
    local leftOk, rightOk = g_combineUnloadManager:getPossibleSidesToDrive(combine)
    local currentOffset = self.combineOffset
    local newOffset = currentOffset

    -- fruit on both sides, stay behind the chopper
    if not leftOk and not rightOk then
        newOffset = 0
    elseif leftOk and not rightOk then
        -- no fruit to the left
        if currentOffset >= 0 then
            -- we are already on the left or middle, go to left
            newOffset = pipeOffset
        else
            -- we are on the right, move to the middle
            newOffset = 0
        end
    elseif not leftOk and rightOk then
        -- no fruit to the right
        if currentOffset <= 0 then
            -- we are already on the right or in the middle, move to the right
            newOffset = -pipeOffset
        else
            -- we are on the left, move to the middle
            newOffset = 0
        end
    end
    if newOffset ~= currentOffset then
        self:debug('Change combine offset: %.1f -> %.1f (pipe %.1f), leftOk: %s rightOk: %s',
                currentOffset, newOffset, pipeOffset, tostring(leftOk), tostring(rightOk))
    end
    return newOffset
end

function AIDriveStrategyUnloadCombine:setSavedCombineOffset(newOffset)
    if self.settings.combineOffsetX:get() == 0 then
        self.settings.combineOffsetX:set(newOffset)
        self:refreshHUD()
        return newOffset
    else
        --TODO Handle manual offsets
    end
end

function AIDriveStrategyUnloadCombine:getSavedCombineOffset()
    if self.settings.combineOffsetX:get() then
        return self.settings.combineOffsetX:get()
    end
    -- else???? this does not make any sense, this is still just a nil ...
end

function AIDriveStrategyUnloadCombine:getCombinesMeasuredBackDistance()
    return self.combineToUnload:getCpDriveStrategy():getMeasuredBackDistance()
end

function AIDriveStrategyUnloadCombine:getCanShowDriveOnButton()
    return self.state == self.states.ON_FIELD or AIDriver.getCanShowDriveOnButton(self)
end

function AIDriveStrategyUnloadCombine:setDriveNow()
    if self.state == self.states.ON_FIELD then
        self:debug('drive now requested, changing to unload course.')
        self:releaseUnloader()
        self:startUnloadCourse()
    else
        AIDriver.setDriveNow(self)
    end
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

function AIDriveStrategyUnloadCombine:shouldDriveOn()
    return self:getFillLevelPercent() > self:getDriveOnThreshold()
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
    return self.vehicle.cp.settings.driveOnAtFillLevel:get()
end

function AIDriveStrategyUnloadCombine:onUserUnassignedActiveCombine()
    self:debug('User unassigned active combine.')
    self:releaseUnloader()
    self:setNewState(self.states.WAITING_FOR_COMBINE_TO_CALL)
end

function AIDriveStrategyUnloadCombine:releaseUnloader()
    self.combineJustUnloaded = self.combineToUnload
    self.combineToUnload = nil
end

function AIDriveStrategyUnloadCombine:combineIsMakingPocket()
    local combineDriver = self.combineToUnload:getCpDriveStrategy()
    if combineDriver ~= nil then
        return combineDriver.fieldworkUnloadOrRefillState == combineDriver.states.MAKING_POCKET
    end
end

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

function AIDriveStrategyUnloadCombine:isWithinSafeManeuveringDistance(vehicle)
    local d = calcDistanceFrom(self.vehicle.rootNode, vehicle:getAIDirectionNode())
    return d < self.safeManeuveringDistance
end

function AIDriveStrategyUnloadCombine:isBehindAndAlignedToChopper(maxDirectionDifferenceDeg)
    local dx, _, dz = localToLocal(self.vehicle.rootNode, self.combineToUnload:getAIDirectionNode(), 0, 0, 0)

    -- close enough and approximately same direction and behind and not too far to the left or right
    return dz < 0 and MathUtil.vector2Length(dx, dz) < 30 and
            CpMathUtil.isSameDirection(self.vehicle:getAIDirectionNode(), self.combineToUnload:getAIDirectionNode(),
                    maxDirectionDifferenceDeg or 45)

end

function AIDriveStrategyUnloadCombine:isBehindAndAlignedToCombine(maxDirectionDifferenceDeg)
    local dx, _, dz = localToLocal(self.vehicle.rootNode, self.combineToUnload:getAIDirectionNode(), 0, 0, 0)
    local pipeOffset = self:getPipeOffset(self.combineToUnload)

    -- close enough and approximately same direction and behind and not too far to the left or right
    return dz < 0 and math.abs(dx) < math.abs(1.5 * pipeOffset) and MathUtil.vector2Length(dx, dz) < 30 and
            CpMathUtil.isSameDirection(self.vehicle:getAIDirectionNode(), self.combineToUnload:getAIDirectionNode(),
                    maxDirectionDifferenceDeg or 45)

end

--- In front of the combine, right distance from pipe to start unloading and the combine is moving
function AIDriveStrategyUnloadCombine:isInFrontAndAlignedToMovingCombine(maxDirectionDifferenceDeg)
    local dx, _, dz = localToLocal(self.vehicle.rootNode, self.combineToUnload:getAIDirectionNode(), 0, 0, 0)
    local pipeOffset = self:getPipeOffset(self.combineToUnload)

    -- in front of the combine, close enough and approximately same direction, about pipe offset side distance
    -- and is not waiting (stopped) for the unloader
    if dz >= 0 and math.abs(dx) < math.abs(pipeOffset) * 1.5 and math.abs(dx) > math.abs(pipeOffset) * 0.5 and
            MathUtil.vector2Length(dx, dz) < 30 and
            CpMathUtil.isSameDirection(self.vehicle:getAIDirectionNode(), self.combineToUnload:getAIDirectionNode(),
                    maxDirectionDifferenceDeg or 30) and
            not self.combineToUnload:getCpDriveStrategy():willWaitForUnloadToFinish() then
        return true
    else
        return false
    end
end

function AIDriveStrategyUnloadCombine:isOkToStartFollowingChopper()
    return self.combineToUnload:getCpDriveStrategy():isChopper() and self:isBehindAndAlignedToChopper() and self:iAmFirstUnloader()
end

function AIDriveStrategyUnloadCombine:isFollowingChopper()
    return self.state == self.states.ON_FIELD and
            self.state == self.states.FOLLOW_CHOPPER
end

function AIDriveStrategyUnloadCombine:isHandlingChopperTurn()
    return self.state == self.states.ON_FIELD and self.state.properties.isHandlingChopperTurn
end

function AIDriveStrategyUnloadCombine:isOkToStartFollowingFirstUnloader()
    if self.firstUnloader and self.firstUnloader.cp.driver:isFollowingChopper() then
        local unloaderDirectionNode = self.firstUnloader:getAIDirectionNode()
        local _, _, dz = localToLocal(self.vehicle.rootNode, unloaderDirectionNode, 0, 0, 0)
        local d = calcDistanceFrom(self.vehicle.rootNode, unloaderDirectionNode)
        -- close enough and either in the same direction or behind
        if d < 1.5 * self.unloaderFollowingDistance and
                (CpMathUtil.isSameDirection(self.vehicle:getAIDirectionNode(), unloaderDirectionNode, 45) or
                        dz < -(self.safeManeuveringDistance / 2)) then
            self:debug('At %d meters (%.1f behind) from first unloader %s, start following it',
                    d, dz, CpUtil.getName(self.firstUnloader))
            return true
        end
    end
    return false
end

function AIDriveStrategyUnloadCombine:isOkToStartUnloadingCombine()
    if self.combineToUnload:getCpDriveStrategy():isReadyToUnload(true) then
        return self:isBehindAndAlignedToCombine() or self:isInFrontAndAlignedToMovingCombine()
    else
        self:debugSparse('combine not ready to unload, waiting')
        return false
    end
end

function AIDriveStrategyUnloadCombine:iAmFirstUnloader()
    return self.vehicle == g_combineUnloadManager:getUnloaderByNumber(1, self.combineToUnload)
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
function AIDriveStrategyUnloadCombine:startUnloadCourse()
    self:debug('Changing to unload course.')
    if self.vehicle.spec_autodrive and self.vehicle.cp.settings.autoDriveMode:useForUnloadOrRefill() then
        -- directly hand over to AD as in other modes
        self.state = self.states.ON_UNLOAD_WITH_AUTODRIVE
        self:debug('passing the control to AutoDrive to run the unload course.')
        self.vehicle.spec_autodrive:StartDrivingWithPathFinder(self.vehicle, self.vehicle.ad.mapMarkerSelected, self.vehicle.ad.mapMarkerSelected_Unload, self, AIDriveStrategyUnloadCombine.onEndCourse, nil);
    else
        self:startCourseWithPathfinding(self.unloadCourse, 1, 0, 0, true)
        self:setNewState(self.states.DRIVE_TO_UNLOAD_COURSE)
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

------------------------------------------------------------------------------------------------------------------------
-- Start to follow a chopper
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startFollowingChopper()
    self.followCourse, self.followCourseIx = self:setupFollowCourse()

    -- don't start at a turn start WP, unless the chopper is still finishing the row before the turn
    -- and waiting for us now. We don't want to start following the chopper at a turn start waypoint if the chopper
    -- isn't turning anymore
    if self.combineCourse:isTurnStartAtIx(self.followCourseIx) then
        self:debug('start following at turn start waypoint %d', self.followCourseIx)
        if not self.combineToUnload:getCpDriveStrategy():isFinishingRow() then
            self:debug('chopper already started turn so moving to the next (turn end) waypoint')
            -- if the chopper is started the turn already or in the process of ending the turn, skip to the turn end waypoint
            self.followCourseIx = self.followCourseIx + 1
        end
    end

    self.followCourse:setOffset(0, 0)
    self:startCourse(self.followCourse, self.followCourseIx)
    self:setNewState(self.states.FOLLOW_CHOPPER)
end

------------------------------------------------------------------------------------------------------------------------
-- Start to follow the first unloader (currently unloading a chopper)
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startFollowingFirstUnloader()

    if self.firstUnloader and not self.firstUnloader.cp.driver:iAmFirstUnloader() then
        self:debug('%s is not the first unloader anymore.', CpUtil.getName(self.firstUnloader))
        self:startWorking()
        return
    end

    if self.firstUnloader.cp.driver.state == self.states.ON_FIELD and
            not self.firstUnloader.cp.driver.onFieldState.properties.isUnloadingChopper then
        self:debug('%s is the first unloader but not following the chopper, has state %s', CpUtil.getName(self.firstUnloader),
                self.firstUnloader.cp.driver.onFieldState.name)
        self:startWorking()
        return
    end

    self.followCourse, _ = self:setupFollowCourse()

    self.followCourseIx = self:getWaypointIxBehindFirstUnloader(self.followCourse)

    if not self.followCourseIx then
        self:debug('Can\'t find waypoint behind %s, the first unloader', CpUtil.getName(self.firstUnloader))
        self:startWorking()
        return
    end

    self:startCourse(self.followCourse, self.followCourseIx)
    self:setNewState(self.states.FOLLOW_FIRST_UNLOADER)
end

function AIDriveStrategyUnloadCombine:getWaypointIxBehindFirstUnloader(course)
    local firstUnloaderWpIx = self.firstUnloader.cp.driver and self.firstUnloader.cp.driver:getRelevantWaypointIx()
    return course:getPreviousWaypointIxWithinDistance(firstUnloaderWpIx, self.unloaderFollowingDistance)
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
    self.followCourse, self.followCourseIx = self:setupFollowCourse()
    self.combineOffset = self:getPipeOffset(self.combineToUnload)
    self.followCourse:setOffset(-self.combineOffset, 0)
    self:debug('Will follow combine\'s course at waypoint %d, side offset %.1f',
            self.followCourseIx, self.followCourse.offsetX)
    self:startCourse(self.followCourse, self.followCourseIx)
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
--Start driving to chopper
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startDrivingToChopper()
    if self:iAmFirstUnloader() then
        self:debug('First unloader, start pathfinding to chopper')
        self:startPathfindingToCombine(self.onPathfindingDoneToCombine, nil, -15)
    else
        self.firstUnloader = g_combineUnloadManager:getUnloaderByNumber(1, self.combineToUnload)
        self:debug('Second unloader, start pathfinding to first unloader')
        if self:isOkToStartFollowingFirstUnloader() then
            self:startFollowingFirstUnloader()
        else
            self:startPathfindingToFirstUnloader(self.onPathfindingDoneToFirstUnloader)
        end
    end
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
    if self.justFinishedPathfindingForDistance:get() then
        self:debug('just finished another pathfinding for distance, wait a bit before starting another')
        self:startWaitingForCombine()
        return
    end
    -- ignore node direction as all we want to know here is the distance
    if self:isPathfindingNeeded(self.vehicle, self:getCombineRootNode(), 0, -15, nil, 360) then
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
-- Pathfinding to first unloader of a chopper. This is how the second unloader gets to the chopper.
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startPathfindingToFirstUnloader(onPathfindingDoneFunc)
    self:debug('Finding path to unloader %s', CpUtil.getName(self.firstUnloader))
    -- TODO: here we may have to pass in the combine to ignore once we start driving to a moving combine, at least
    -- when it is on the headland.
    if self:isPathfindingNeeded(self.vehicle, self.firstUnloader:getAIDirectionNode(), 0, 0) then
        self:setNewState(self.states.WAITING_FOR_PATHFINDER)
        -- ignore everyone as by the time we get there they'll have moved anyway
        self:startPathfinding(self.combineToUnload.rootNode, 0, -5,
                CpFieldUtil.getFieldNumUnderVehicle(self.combineToUnload),
                { self.combineToUnload, self.firstUnloader }, onPathfindingDoneFunc)
    else
        self:debug('Won\'t start pathfinding to first unloader, too close?')
        if self:isOkToStartFollowingFirstUnloader() then
            self:startFollowingFirstUnloader()
        else
            self:setNewState(self.states.WAITING_FOR_FIRST_UNLOADER)
            self:debug('First unloader is not ready to be followed, waiting.')
        end
    end
end

function AIDriveStrategyUnloadCombine:onPathfindingDoneToFirstUnloader(path, goalNodeInvalid)
    if self:isPathFound(path, goalNodeInvalid, CpUtil.getName(self.firstUnloader)) and self.state == self.states.WAITING_FOR_PATHFINDER then
        local driveToFirstUnloaderCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        self:startCourse(driveToFirstUnloaderCourse, 1)
        self:setNewState(self.states.DRIVE_TO_FIRST_UNLOADER)
        return true
    else
        self:startWaitingForCombine()
        return false
    end
end

------------------------------------------------------------------------------------------------------------------------
--Pathfinding for wide turns
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startPathfindingToTurnEnd(xOffset, zOffset)
    self:setNewState(self.states.WAITING_FOR_PATHFINDER)

    if not self.pathfinder or not self.pathfinder:isActive() then
        local done, path, goalNodeInvalid
        self.pathfindingStartedAt = g_time
        local turnEndNode, startOffset, goalOffset = self.turnContext:getTurnEndNodeAndOffsets(self.vehicle)
        -- ignore combine for pathfinding, it is moving anyway and our turn functions make sure we won't hit it
        self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.findPathForTurn(self.vehicle, startOffset, turnEndNode, goalOffset,
                self.settings.turnDiameter:get() / 2, self:getAllowReversePathfinding(), self.followCourse, { self.combineToUnload })
        if done then
            return self:onPathfindingDoneToTurnEnd(path, goalNodeInvalid)
        else
            self:setPathfindingDoneCallback(self, self.onPathfindingDoneToTurnEnd)
            return true
        end
    else
        self:debug('Pathfinder already active')
    end
    return false
end

function AIDriveStrategyUnloadCombine:onPathfindingDoneToTurnEnd(path, goalNodeInvalid)
    if self:isPathFound(path, goalNodeInvalid, 'turn end', true) then
        local driveToCombineCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        self:startCourse(driveToCombineCourse, 1)
        self:setNewState(self.states.FOLLOW_CHOPPER_THROUGH_TURN)
    else
        self:setNewState(self.states.HANDLE_CHOPPER_180_TURN)
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
-- Check for full trailer/drive on setting when following a chopper
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:changeToUnloadWhenDriveOnLevelReached()
    --if the fillLevel is reached while turning go to Unload course
    if self:shouldDriveOn() then
        self:debug('Drive on level reached, changing to unload course')
        self:startMovingBackFromCombine(self.states.MOVE_BACK_FULL)
        return true
    end
    return false
end

------------------------------------------------------------------------------------------------------------------------
-- Check for full trailer when unloading a combine
---@return boolean true when changed to unload course
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:changeToUnloadWhenFull()
    --when trailer is full then go to unload
    if self:getDriveUnloadNow() or self:getAllTrailersFull() then
        if self:getDriveUnloadNow() then
            self:debug('drive now requested, changing to unload course.')
        else
            self:debug('trailer full, changing to unload course.')
        end
        if self.followCourse and self.followCourse:isCloseToNextTurn(10) and not self.followCourse:isCloseToLastTurn(20) then
            self:debug('... but we are too close to the end of the row, moving back before changing to unload course')
            self:startMovingBackFromCombine(self.states.MOVE_BACK_FROM_EMPTY_COMBINE)
        elseif self.combineToUnload:getCpDriveStrategy():isAboutToReturnFromPocket() then
            self:debug('... letting the combine return from the pocket')
            self:startMovingBackFromCombine(self.states.MOVE_BACK_FROM_EMPTY_COMBINE)
        else
            self:releaseUnloader()
            self:setMaxSpeed(0)
            self.vehicle:stopCurrentAIJob(AIMessageErrorIsFull.new())
        end
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
    elseif self:isOkToStartFollowingChopper() then
        self:startFollowingChopper()
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
    if self:changeToUnloadWhenFull() then
        return
    end
    local combineDriver = self.combineToUnload:getCpDriveStrategy()
    if combineDriver:isUnloadFinished() then
        if combineDriver:isWaitingForUnloadAfterCourseEnded() then
            if combineDriver:getFillLevelPercentage() < 0.1 then
                self:debug('Finished unloading combine at end of fieldwork, changing to unload course')
                self.ppc:setNormalLookaheadDistance()
                self:startMovingBackFromCombine(self.states.MOVE_BACK_FULL)
            else
                self:driveBesideCombine()
            end
        else
            self:debug('finished unloading stopped combine, move back a bit to make room for it to continue')
            self:startMovingBackFromCombine(self.states.MOVE_BACK_FROM_EMPTY_COMBINE)
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

    if self:changeToUnloadWhenFull() then
        return
    end

    self:driveBesideCombine()

    --when the combine is empty, stop and wait for next combine
    if self.combineToUnload:getCpDriveStrategy():getFillLevelPercentage() <= 0.1 then
        --when the combine is in a pocket, make room to get back to course
        if self.combineToUnload:getCpDriveStrategy():isWaitingInPocket() then
            self:debug('combine empty and in pocket, drive back')
            self:startMovingBackFromCombine(self.states.MOVE_BACK_FROM_EMPTY_COMBINE)
            return
        elseif self.followCourse:isCloseToNextTurn(10) and not self.followCourse:isCloseToLastTurn(20) then
            self:debug('combine empty and moving forward but we are too close to the end of the row, moving back')
            self:startMovingBackFromCombine(self.states.MOVE_BACK_FROM_EMPTY_COMBINE)
            return
        else
            self:debug('combine empty and moving forward')
            self:releaseUnloader()
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
        local dx, _, dz = localToLocal(self.vehicle.rootNode, self.combineToUnload:getAIDirectionNode(), 0, 0, 0)
        local pipeOffset = self:getPipeOffset(self.combineToUnload)
        local sameDirection = CpMathUtil.isSameDirection(self.vehicle:getAIDirectionNode(),
                self.combineToUnload:getAIDirectionNode(), 15)
        local willWait = self.combineToUnload:getCpDriveStrategy():willWaitForUnloadToFinish()
        self:info('not in a good position to unload, trying to recover')
        self:info('dx = %.2f, dz = %.2f, offset = %.2f, sameDir = %s', dx, dz, pipeOffset, tostring(sameDirection))
        -- switch to driving only when not holding for maneuvering combine
        -- for some reason (like combine turned) we are not in a good position anymore then set us up again
        self:startDrivingToCombine()
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Start moving back from empty combine
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startMovingBackFromCombine(newState)
    self:releaseUnloader()
    local reverseCourse = Course.createStraightReverseCourse(self.vehicle, 25)
    self:startCourse(reverseCourse, 1)
    self:setNewState(newState)
    return
end

------------------------------------------------------------------------------------------------------------------------
-- Chopper turns
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:startChopperTurn(ix)
    if self.combineToUnload:getCpDriveStrategy():isTurningOnHeadland() then
        self:startCourse(self.followCourse, ix)
        self:setNewState(self.states.HANDLE_CHOPPER_HEADLAND_TURN)
    else
        self.turnContext = TurnContext(self.followCourse, ix, self.aiDriverData,
                self.combineToUnload:getCpDriveStrategy():getWorkWidth(), self.frontMarkerDistance, self.backMarkerDistance, 0, 0)
        local finishingRowCourse = self.turnContext:createFinishingRowCourse(self.vehicle)
        self:startCourse(finishingRowCourse, 1)
        self:setNewState(self.states.HANDLE_CHOPPER_180_TURN)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Chopper turn on headland
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:handleChopperHeadlandTurn()

    local d, _, dz = self:getDistanceFromCombine()
    local minD = math.min(d, dz)
    local speed = (self.combineToUnload.lastSpeedReal * 3600) +
            (MathUtil.clamp(minD - self.targetDistanceBehindChopper, -self.vehicle.cp.speeds.turn, self.vehicle.cp.speeds.turn))
    self:renderText(0, 0.7, 'd = %.1f, dz = %.1f, minD = %.1f, speed = %.1f', d, dz, minD, speed)
    self:setMaxSpeed(speed)

    --if the chopper is reversing, drive backwards
    if self:isMyCombineReversing() then
        self:debug('Detected reversing chopper.')
        local reverseCourse = Course.createStraightReverseCourse(self.vehicle, 50)
        self:startCourse(reverseCourse, 1)
        self:setNewState(self.states.MOVE_BACK_FROM_REVERSING_CHOPPER)
    end

    if self:changeToUnloadWhenDriveOnLevelReached() then
        return
    end

    --when the turn is finished, return to follow chopper
    if not self:getCombineIsTurning() then
        self:debug('Combine stopped turning, resuming follow course')
        -- resume course beside combine
        -- skip over the turn start waypoint as it will throw the PPC off course
        self:startCourse(self.followCourse, self.combineCourse:skipOverTurnStart(self.combineCourse:getCurrentWaypointIx()))
        self:setNewState(self.states.ALIGN_TO_CHOPPER_AFTER_TURN)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Follow chopper
-- In this mode we drive the same course as the chopper but with an offset. The course may be started with
-- a temporary (pathfinder generated) course to align to the waypoint we start at.
-- After that we drive behind or beside the chopper, following the choppers fieldwork course but controlling
-- our speed to stay in the range of the pipe.
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:followChopper()

    --when trailer is full then go to unload
    if self:getDriveUnloadNow() or self:getAllTrailersFull() then
        self:startMovingBackFromCombine(self.states.MOVE_BACK_FULL)
        return
    end

    if self.course:isTemporary() and self.course:getDistanceToLastWaypoint(self.course:getCurrentWaypointIx()) > 5 then
        -- have not started on the combine's fieldwork course yet (still on the temporary alignment course)
        -- just drive the course
    else
        -- The dedicated chopper proximity sensor takes care of controlling our speed, the normal one
        -- should therefore ignore the chopper (but not others)
        -- self:ignoreVehicleProximity(self.combineToUnload, 3000)
        -- make sure the chopper won't slow down when seeing us
        -- self.combineToUnload:getCpDriveStrategy():ignoreVehicleProximity(self.vehicle, 3000)
        -- when on the fieldwork course, drive behind or beside the chopper, staying in the range of the pipe
        self.combineOffset = self:getChopperOffset(self.combineToUnload)

        local dx = self:findOtherUnloaderAroundCombine(self.combineToUnload, self.combineOffset)
        if dx then
            -- there's another unloader around the combine, on either side
            if math.abs(dx) > 1 then
                -- stay behind the chopper
                self.followCourse:setOffset(0, 0)
                self.combineOffset = 0
            end
        else
            self.followCourse:setOffset(-self.combineOffset, 0)
        end

        if self.combineOffset ~= 0 then
            self:driveBesideChopper()
        else
            self:driveBehindChopper()
        end
    end

    if self.combineToUnload:getCpDriveStrategy():isTurningButNotEndingTurn() then
        local combineTurnStartWpIx = self.combineToUnload:getCpDriveStrategy():getTurnStartWpIx()
        if combineTurnStartWpIx then
            self:debug('chopper reached a turn waypoint, start chopper turn')
            self:startChopperTurn(combineTurnStartWpIx)
        else
            self:error('Combine is turning but does not have a turn start waypoint index.')
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Chopper turn 180
-- The default strategy here is to stop before reaching the end of the row and then wait for the combine
-- to finish the 180 turn. After it finished the turn, we drive forward a bit to make sure we are behind the
-- chopper and then continue on the chopper's fieldwork course with the appropriate offset without pathfinding.
--
-- If the combine says that it won't reverse during the turn (for example performs a wide turn because the
-- next row to work on is not adjacent the current row), we switch to 'follow chopper through the turn' mode
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:handleChopper180Turn()

    if self:changeToUnloadWhenDriveOnLevelReached() then
        return
    end

    if self.combineToUnload:getCpDriveStrategy():isTurningButNotEndingTurn() then
        -- move forward until we reach the turn start waypoint
        local _, _, d = self.turnContext:getLocalPositionFromWorkEnd(Markers.getFrontMarkerNode(self.vehicle))
        self:debugSparse('Waiting for the chopper to turn, distance from row end %.1f', d)
        -- stop a bit before the end of the row to let the tractor slow down.
        if d > -3 then
            self:setMaxSpeed(0)
        elseif d > 0 then
            self:setMaxSpeed(0)
        else
            self:setMaxSpeed(self.vehicle.cp.speeds.turn)
        end
        if self.combineToUnload:getCpDriveStrategy():isTurnForwardOnly() then
            ---@type Course
            local turnCourse = self.combineToUnload:getCpDriveStrategy():getTurnCourse()
            if turnCourse then
                self:debug('Follow chopper through the turn')
                self:startCourse(turnCourse:copy(self.vehicle), 1)
                self:setNewState(self.states.FOLLOW_CHOPPER_THROUGH_TURN)
            else
                self:debugSparse('Chopper said turn is forward only but has no turn course')
            end
        end
    else
        local _, _, dz = self:getDistanceFromCombine()
        self:setMaxSpeed(self.vehicle.cp.speeds.turn)
        -- start the chopper course (and thus, turning towards it) only after we are behind it
        if dz < -3 then
            self:debug('now behind chopper, continue on chopper\'s course.')
            -- reset offset, as we don't know which side is going to work after the turn.
            self.followCourse:setOffset(0, 0)
            -- skip over the turn start waypoint as it will throw the PPC off course
            self:startCourse(self.followCourse, self.combineCourse:skipOverTurnStart(self.combineCourse:getCurrentWaypointIx()))
            -- TODO: shouldn't we be using lambdas instead?
            self:setNewState(self.states.ALIGN_TO_CHOPPER_AFTER_TURN)
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Follow chopper through turn
-- here we drive the chopper's turn course carefully keeping our distance from the combine.
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:followChopperThroughTurn()

    if self:changeToUnloadWhenDriveOnLevelReached() then
        return
    end

    local d = self:getDistanceFromCombine()
    if self.combineToUnload:getCpDriveStrategy():isTurning() then
        -- making sure we are never ahead of the chopper on the course (we both drive the same course), this
        -- prevents the unloader cutting in front of the chopper when for example the unloader is on the
        -- right side of the chopper and the chopper reaches a right turn.
        if self.course:getCurrentWaypointIx() > self.combineToUnload:getCpDriveStrategy().course:getCurrentWaypointIx() then
            self:setMaxSpeed(0)
        end
        -- follow course, make sure we are keeping distance from the chopper
        -- TODO: or just rely on the proximity sensor here?
        local combineSpeed = (self.combineToUnload.lastSpeedReal * 3600)
        local speed = math.max(self.vehicle.cp.speeds.turn, combineSpeed)
        self:setMaxSpeed(speed)
        self:renderText(0, 0.7, 'd = %.1f, speed = %.1f', d, speed)
    else
        self:debug('chopper is ending/ended turn, return to follow mode')
        self.followCourse:setOffset(0, 0)
        self:startCourse(self.followCourse, self.combineCourse:getCurrentWaypointIx())
        self:setNewState(self.states.ALIGN_TO_CHOPPER_AFTER_TURN)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Chopper ended a turn, we are now on the copper's course but still pointing
-- in the wrong direction. Rely on PPC to turn us around and switch to normal follow mode when
-- about in the same direction
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:alignToChopperAfterTurn()

    self:setMaxSpeed(self.vehicle.cp.speeds.turn)

    if self:isBehindAndAlignedToChopper(45) then
        self:debug('Now aligned with chopper, continue on the side/behind')
        self:setNewState(self.states.FOLLOW_CHOPPER)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Follow first unloader who is still busy unloading a chopper. Be ready to take over if it is full
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:followFirstUnloader()
    self:setInfoText("FOLLOWING_TRACTOR");

    -- previous first unloader not unloading anymore
    if self:iAmFirstUnloader() then
        -- switch to drive to chopper or following chopper
        self:startWorking()
        return
    end

    local dFromFirstUnloader = self.followCourse:getDistanceBetweenWaypoints(self:getRelevantWaypointIx(),
            self.firstUnloader.cp.driver:getRelevantWaypointIx())

    if self.firstUnloader.cp.driver:isStopped() or self.firstUnloader.cp.driver:isReversing() then
        self:debugSparse('holding for stopped or reversing first unloader %s', CpUtil.getName(self.firstUnloader))
        self:setMaxSpeed(0)
    elseif self.firstUnloader.cp.driver:isHandlingChopperTurn() then
        self:debugSparse('holding for first unloader %s handing the chopper turn', CpUtil.getName(self.firstUnloader))
        self:setMaxSpeed(0)
    else
        -- adjust our speed if we are too close or too far
        local error = dFromFirstUnloader - self.unloaderFollowingDistance
        local deltaV = MathUtil.clamp(error, -2, 2)
        local speed = self.firstUnloader.lastSpeedReal * 3600 + deltaV
        self:setMaxSpeed(speed)
    end
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
-- We are blocking another vehicle who wants us to move out of way
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:onBlockingOtherVehicle(blockedVehicle)
    if not self:isActive() then
        return
    end
    self:debugSparse('%s wants me to move out of way', blockedVehicle:getName())
    if blockedVehicle.cp.driver:isChopper() then
        -- TODO: think about how to best handle choppers, since they always stop when no trailer
        -- is in range they always send these blocking events.
        --return
        self:debug('temporarily enable moving out of a chopper\'s way')
    end
    if self.state ~= self.states.MOVING_OUT_OF_WAY and
            self.state ~= self.states.MOVE_BACK_FROM_REVERSING_CHOPPER and
            self.state ~= self.states.MOVE_BACK_FROM_EMPTY_COMBINE and
            self.state ~= self.states.HANDLE_CHOPPER_HEADLAND_TURN and
            self.state ~= self.states.MOVE_BACK_FULL
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
-- Moving out of the way of a combine or chopper
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadCombine:moveOutOfWay()
    -- check both distances and use the smaller one, proximity sensor may not see the combine or
    -- d may be big enough but parts of the combine still close
    local d = self:getDistanceFromCombine(self.blockedVehicle)
    local dProximity = self.forwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
    local combineSpeed = (self.blockedVehicle.lastSpeedReal * 3600)
    local speed = combineSpeed +
            MathUtil.clamp(self.minDistanceWhenMovingOutOfWay - math.min(d, dProximity), -combineSpeed, self.vehicle.cp.speeds.reverse * 1.2)

    self:setMaxSpeed(speed)

    -- combine stopped reversing or stopped and waiting for unload, resume what we were doing before
    if not self:isMyCombineReversing() or
            (self.blockedVehicle.cp.driver.willWaitForUnloadToFinish and self.blockedVehicle.cp.driver:willWaitForUnloadToFinish()) then
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
