--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

Chopper support added by Pops64

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


--[[
 
 AI Drive Strategy for Choppers

]]

---@class AIDriveStrategyChopperCourse : AIDriveStrategyCombineCourse

AIDriveStrategyChopperCourse = {}
local AIDriveStrategyChopperCourse_mt = Class(AIDriveStrategyChopperCourse, AIDriveStrategyCombineCourse)

-- The chopper may start outside of the field this setting permints expansion of the field boundary in this case
AIDriveStrategyChopperCourse.distanceOverFieldEdgeAllowed = 50

-- Developer hack: to check the class of an object one should use the is_a() defined in CpObject.lua.
-- However, when we reload classes on the fly during the development, the is_a() calls in other modules still
-- have the old class definition (for example CombineUnloadManager.lua) of this class and thus, is_a() fails.
-- Therefore, use this instead, this is safe after a reload.
AIDriveStrategyChopperCourse.isAAIDriveStrategyChopperCourse = true

function AIDriveStrategyChopperCourse.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyChopperCourse_mt
    end
    local self = AIDriveStrategyCombineCourse.new(customMt)
    --- Unloaders Object. Stores all data about who we are unloading 
    ---@type CpTemporaryObject
    self.unloaders = {
        unloaderA = CpTemporaryObject(nil),
        unloaderB = CpTemporaryObject(nil),
        nextUnloader = 'B',
        currentUnloader = 'A',
    }
    self.chaseMode = false
    return self
end

function AIDriveStrategyChopperCourse:setAllStaticParameters()
    --Old Code to add markers to Choppers which don't have AI markers
    self:checkMarkers()
    AIDriveStrategyChopperCourse.superClass().setAllStaticParameters(self)

    -- We need set this as a variable and update left/right side on turns in self:updatePipeOffset()
    self:setPipeOffsetX()
    self:setPipeOffsetZ()
    local total, pipeInFruit = self.vehicle:getFieldWorkCourse():setPipeInFruitMap(self.pipeOffsetX - 2, self:getWorkWidth())
    self:debug('Pipe in fruit map updated, there are %d non-headland waypoints, of which at %d the pipe will be in the fruit',
            total, pipeInFruit)
    self:debug('AIDriveStrategyChopperCourse set')
end

function AIDriveStrategyChopperCourse:initializeImplementControllers(vehicle)
    AIDriveStrategyChopperCourse:superClass().initializeImplementControllers(self, vehicle)
    local _
    _, self.pipeController = self:addImplementController(vehicle, PipeController, Pipe, {}, nil)
    self.combine, self.chopperController = self:addImplementController(vehicle, ChopperController, Combine, {}, nil)
end

-- function AIDriveStrategyChopperCourse:setJobParameterValues(jobParameters)
--     AIDriveStrategyChopperCourse:superClass().setJobParameterValues(jobParameters)
--     local x, z = jobParameters.fieldPosition:getPosition()
--     self.fieldPolygon = CpFieldUtil.getFieldPolygonAtWorldPosition(x, z)
-- end

function AIDriveStrategyChopperCourse:update(dt)
    AIDriveStrategyCombineCourse.update(self, dt)
    -- Old Code need to make Choppers work
    self:updateChopperFillType()
end

function AIDriveStrategyChopperCourse:getDriveData(dt, vX, vY, vZ)
    self:handlePipe()

    if self.temporaryHold:get() then
        self:setMaxSpeed(0)
    end
    if self.state == self.states.WORKING then
        -- Harvesting
        self:checkRendezvous()
        self:checkBlockingUnloader()

        if self:isChopperWaitingForUnloader() then
            self:debug('No trailer calling for an unloader')
            self:stopForUnload(self.states.WAITING_FOR_UNLOAD_ON_FIELD, true)
        end

    elseif self.state == self.states.TURNING then
        self:checkBlockingUnloader()
    elseif self.state == self.states.WAITING_FOR_LOWER then
        if self:isChopperWaitingForUnloader() then
            self:debug('No trailer calling for an unloader')
            self:stopForUnload(self.states.WAITING_FOR_UNLOAD_ON_FIELD, true)
        end
    elseif self.state == self.states.UNLOADING_ON_FIELD then
        -- Unloading
        self:driveUnloadOnField()
        self:callUnloaderWhenNeeded()

    end
    return AIDriveStrategyFieldWorkCourse.getDriveData(self, dt, vX, vY, vZ)
end

-----------------------------------------------------------------------------------------------------------------------
--- Event listeners
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyChopperCourse:onWaypointPassed(ix, course)
    if self.state == self.states.UNLOADING_ON_FIELD and
            (self.unloadState == self.states.DRIVING_TO_SELF_UNLOAD or
                    self.unloadState == self.states.DRIVING_TO_SELF_UNLOAD_AFTER_FIELDWORK_ENDED or
                    self.unloadState == self.states.RETURNING_FROM_SELF_UNLOAD) then
        -- nothing to do while driving to unload and back
        return AIDriveStrategyFieldWorkCourse.onWaypointPassed(self, ix, course)
    end

    self:checkFruit()

    -- make sure we start making a pocket while we still have some fill capacity left as we'll be
    -- harvesting fruit while making the pocket unless we have self unload turned on
    if self:shouldMakePocket() and not self.settings.selfUnload:getValue() then
        self.fillLevelFullPercentage = self.pocketFillLevelFullPercentage
    end

    local isOnHeadland = self.course:isOnHeadland(ix)
    self.combineController:updateStrawSwath(isOnHeadland)

    if self.state == self.states.WORKING then
        self:estimateDistanceUntilFull(ix)
        self:callUnloaderWhenNeeded()
        self:checkNextUnloader()
    end

    if self.state == self.states.UNLOADING_ON_FIELD and
            self.unloadState == self.states.MAKING_POCKET and
            self.unloadInPocketIx and ix == self.unloadInPocketIx then
        -- we are making a pocket and reached the waypoint where we are going to stop and wait for unload
        self:debug('Waiting for unload in the pocket')
        self.unloadState = self.states.WAITING_FOR_UNLOAD_IN_POCKET
    end

    if self.returnedFromPocketIx and self.returnedFromPocketIx == ix then
        -- back to normal look ahead distance for PPC, no tight turns are needed anymore
        self:debug('Reset PPC to normal lookahead distance')
        self.ppc:setNormalLookaheadDistance()
    end
    AIDriveStrategyFieldWorkCourse.onWaypointPassed(self, ix, course)
end

function AIDriveStrategyChopperCourse:checkNextUnloader()
    if not self:getUnloader(self:getCurrentUnloaderIdent()) and self:getUnloader(self:getNextUnloader()) then
        self:debug('checkNextUnloader: I lost my current unloder and I have one that is arriving switch them')
        self:updateNextUnloader()
    elseif self:getUnloader(self:getNextUnloader()) and self:getUnloader(self:getNextUnloader()):readyToRecive() then
        self:debug('checkNextUnloader: Discharging to %s, s %s is ready to come along side', CpUtil.getName((self:getCurrentUnloaderIdent()).vehicle), CpUtil.getName((self:getNextUnloader()).vehicle))
        self:getUnloader(self:getCurrentUnloaderIdent()):requestDriveUnloadNow()
        self:updateNextUnloader()
    elseif self:getUnloader(self:getNextUnloader()) then
        self:debug('checkNextUnloader: Next Unloader is %s, is ready to come along side: %s', CpUtil.getName((self:getNextUnloader())), self:getUnloader(self:getNextUnloader()):readyToRecive())
    end
end
function AIDriveStrategyChopperCourse:checkRendezvous()
    if self.unloaderToRendezvous:get() then
        local lastPassedWaypointIx = self.ppc:getLastPassedWaypointIx() or self.ppc:getRelevantWaypointIx()
        if lastPassedWaypointIx > self.unloaderRendezvousWaypointIx then
            -- past the rendezvous waypoint
            self:debug('Unloader missed the rendezvous at %d', self.unloaderRendezvousWaypointIx)
            local unloaderWhoDidNotShowUp = self.unloaderToRendezvous:get()
            -- need to call this before onMissedRendezvous as the unloader will call back to set up a new rendezvous
            -- and we don't want to cancel that right away
            self:cancelRendezvous()
            unloaderWhoDidNotShowUp:getCpDriveStrategy():onMissedRendezvous(self.vehicle)
        end
        if self:getUnloader(self:getNextUnloader()) and self:getUnloader(self:getNextUnloader()):readyToRecive() then
            self:debug('Discharging to %s, cancelling unloader rendezvous %s is ready to come along side', CpUtil.getName((self:getCurrentUnloaderIdent()).vehicle), CpUtil.getName((self:getNextUnloader()).vehicle))
            self:cancelRendezvous()
        end
    end
end

function AIDriveStrategyChopperCourse:driveUnloadOnField()
    if self.unloadState == self.states.STOPPING_FOR_UNLOAD then
        self:setMaxSpeed(0)
        -- wait until we stopped before raising the implements
        if AIUtil.isStopped(self.vehicle) then
            if self.raiseHeaderAfterStopped then
                self:debug('Stopped, now raise implements and switch to next unload state')
                self:raiseImplements()
            end
            self.unloadState = self.newUnloadStateAfterStopped
        end
    elseif self.unloadState == self.states.WAITING_FOR_UNLOAD_ON_FIELD then
        if g_updateLoopIndex % 5 == 0 then
            --small delay, to make sure no more fillLevel change is happening
            if not self:isChopperWaitingForUnloader() then
                self:debug('I have a trailer, can continue working')
                self:changeToFieldWork()
            end
        end
        self:setMaxSpeed(0)
    end
end

function AIDriveStrategyChopperCourse:estimateDistanceUntilFull(ix)
    -- calculate fill rate so the combine driver knows if it can make the next row without unloading
    local fillLevel = 1
    local capacity = 1

    -- Choppers don't have fill levels get the trailer we currently are discharging too fill levels. This is for when we have multiple tippers
    fillLevel, capacity = self:getTrailerFillLevel()

    if ix > 1 then
        local dToNext = self.course:getDistanceToNextWaypoint(ix - 1)
        if self.fillLevelAtLastWaypoint and self.fillLevelAtLastWaypoint > 0 and self.fillLevelAtLastWaypoint <= fillLevel then
            local litersPerMeter = (fillLevel - self.fillLevelAtLastWaypoint) / dToNext
            -- make sure it won't end up being inf
            local litersPerSecond = math.min(1000, (fillLevel - self.fillLevelAtLastWaypoint) /
                    ((g_currentMission.time - (self.fillLevelLastCheckedTime or g_currentMission.time)) / 1000))
            -- smooth everything a bit, also ignore 0
            self.litersPerMeter = litersPerMeter > 0 and ((self.litersPerMeter + litersPerMeter) / 2) or self.litersPerMeter
            self.litersPerSecond = litersPerSecond > 0 and ((self.litersPerSecond + litersPerSecond) / 2) or self.litersPerSecond
        else
            -- no history yet, so make sure we don't end up with some unrealistic numbers
            self.waypointIxWhenFull = nil
            self.litersPerMeter = 0
            self.litersPerSecond = 0
        end
        self:debug('Fill rate is %.1f l/m, %.1f l/s (fill level %.1f, last %.1f, dToNext = %.1f)',
                self.litersPerMeter, self.litersPerSecond, fillLevel, self.fillLevelAtLastWaypoint, dToNext)
        self.fillLevelLastCheckedTime = g_currentMission.time
        self.fillLevelAtLastWaypoint = fillLevel
    end
    local litersUntilFull = capacity - fillLevel
    local dUntilFull = litersUntilFull / self.litersPerMeter
    local litersUntilCallUnloader = capacity * self.callUnloaderAtFillLevelPercentage / 100 - fillLevel
    local dUntilCallUnloader = litersUntilCallUnloader / self.litersPerMeter
    self.waypointIxWhenFull = self.course:getNextWaypointIxWithinDistance(ix, dUntilFull) or self.course:getNumberOfWaypoints()
    local wpDistance
    self.waypointIxWhenCallUnloader, wpDistance = self.course:getNextWaypointIxWithinDistance(ix, dUntilCallUnloader)
    self:debug('Will be full at waypoint %d, fill level %d at waypoint %d (current waypoint %d), %.1f m and %.1f l until call (currently %.1f l), wp distance %.1f',
            self.waypointIxWhenFull or -1, self.callUnloaderAtFillLevelPercentage, self.waypointIxWhenCallUnloader or -1,
            self.course:getCurrentWaypointIx(), dUntilCallUnloader, litersUntilCallUnloader, fillLevel, wpDistance)
end

function AIDriveStrategyChopperCourse:findUnloader(combine, waypoint)
    local bestScore = -math.huge
    local bestUnloader, bestEte
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if AIDriveStrategyUnloadChopper.isActiveCpChopperUnloader(vehicle) then
            local x, _, z = getWorldTranslation(self.vehicle.rootNode)
            ---@type AIDriveStrategyChopperCourse
            local driveStrategy = vehicle:getCpDriveStrategy()
            if driveStrategy:isServingPosition(x, z, self.distanceOverFieldEdgeAllowed) then
                local unloaderFillLevelPercentage = driveStrategy:getFillLevelPercentage()
                if driveStrategy:isIdle() and unloaderFillLevelPercentage < 99 then
                    local unloaderDistance, unloaderEte
                    if combine then
                        -- if already stopped, we want the unloader to come to us
                        unloaderDistance, unloaderEte = driveStrategy:getDistanceAndEteToVehicle(combine)
                    elseif self.waypointIxWhenCallUnloader then
                        -- if still going, we want the unloader to meet us at the waypoint
                        unloaderDistance, unloaderEte = driveStrategy:getDistanceAndEteToWaypoint(waypoint)
                    end
                    local score = unloaderFillLevelPercentage - 0.1 * unloaderDistance
                    self:debug('findUnloader: %s idle on my field, fill level %.1f, distance %.1f, ETE %.1f, score %.1f)',
                            CpUtil.getName(vehicle), unloaderFillLevelPercentage, unloaderDistance, unloaderEte, score)
                    if score > bestScore then
                        bestUnloader = vehicle
                        bestScore = score
                        bestEte = unloaderEte
                    end
                else
                    self:debug('findUnloader: %s serving my field but already busy', CpUtil.getName(vehicle))
                end
            else
                self:debug('findUnloader: %s is not serving my field', CpUtil.getName(vehicle))
            end
        end
    end
    if bestUnloader then
        self:debug('findUnloader: best unloader is %s (score %.1f, ETE %.1f)',
                CpUtil.getName(bestUnloader), bestScore, bestEte)
        return bestUnloader, bestEte
    else
        self:debugSparse('findUnloader: no idle unloader found')
    end
end

function AIDriveStrategyChopperCourse:getTrailerFillLevel()
    local fillLevel = 0
    local capacity = 1
    local trailer, targetObject = self:nearestChopperTrailer() 
    if targetObject then
        fillLevel, capacity = FillLevelManager.getAllTrailerFillLevels(targetObject)
        self:debug('Chopper Trailer fill level is %.1f and can hold %.1f',
            fillLevel, capacity)
    end
    return fillLevel, capacity
end

--- Not exactly sure what this does, but without this the chopper just won't move.
--- Copied from AIDriveStrategyCombine:update()
function AIDriveStrategyChopperCourse:updateChopperFillType()
    self.chopperController:updateChopperFillType()
end

-----------------------------------------------------------------------------------------------------------------------
--- Pipe handling
-----------------------------------------------------------------------------------------------------------------------

-- This part of an ugly workaround to make the chopper pickups work
function AIDriveStrategyChopperCourse:checkMarkers()
    for _, implement in pairs(AIUtil.getAllAIImplements(self.vehicle)) do
        local aiLeftMarker, aiRightMarker, aiBackMarker = implement.object:getAIMarkers()
        if not aiLeftMarker or not aiRightMarker or not aiBackMarker then
            self.notAllImplementsHaveAiMarkers = true
            return
        end
    end
end

function AIDriveStrategyChopperCourse:isFuelSaveAllowed()
    local isFuelSaveAllowed = AIDriveStrategyCombineCourse.isFuelSaveAllowed(self)
    return isFuelSaveAllowed or self:isChopperWaitingForUnloader()
end

-- Not being used
function AIDriveStrategyChopperCourse:shouldHoldInTurnManeuver()
    --- Do not hold durning discharge
    return false
end

-- TODO: move this to the PipeController? Rename this is it doesnt check pipe in checks for trailer in range
function AIDriveStrategyChopperCourse:handlePipe()
    self.pipeController:handleChopperPipe()
end

function AIDriveStrategyChopperCourse:isChopperWaitingForUnloader()
    local trailer, targetObject = self:nearestChopperTrailer()
    local dischargeNode = self.pipeController:getDischargeNode()
    self:debugSparse('%s %s', dischargeNode, self:isAnyWorkAreaProcessing())
    if not (targetObject == nil or trailer == nil) then 
        if targetObject and targetObject.getIsCpActive and targetObject:getIsCpActive() then
            local strategy = targetObject:getCpDriveStrategy()
            if strategy.isAChopperUnloadAIDriver
                and self:getUnloader(self:getCurrentUnloaderIdent()) 
                and self:getUnloader(self:getCurrentUnloaderIdent()).vehicle == targetObject 
                and self:getUnloader(self:getCurrentUnloaderIdent()):readyToRecive() then
                    self:debugSparse('Chopper has a CP Driven trailer now, continue')
                    return false
            end
        else
            self:debugSparse('Chopper has a non CP Driven trailer now, continue')
            return false
        end
    end
    self:debugSparse('Chopper waiting for trailer, discharge node %s, target object %s, trailer %s',
                tostring(dischargeNode), tostring(targetObject), tostring(trailer))
    return true
end

function AIDriveStrategyChopperCourse:nearestChopperTrailer()
    local trailer = self.pipeController:getClosestObject()
    local targetObject = self.pipeController:getDischargeObject()
    return trailer, targetObject
end

function AIDriveStrategyChopperCourse:checkFruit()
    -- getValidityOfTurnDirections() wants to have the vehicle.aiDriveDirection, so get that here.
    local dx, _, dz = localDirectionToWorld(self.vehicle:getAIDirectionNode(), 0, 0, 1)
    local length = MathUtil.vector2Length(dx, dz)
    dx = dx / length
    dz = dz / length
    self.vehicle.aiDriveDirection = { dx, dz }
    -- getValidityOfTurnDirections works only if all AI Implements have aiMarkers. Since
    -- we make all Cutters AI implements, even the ones which do not have AI markers (such as the
    -- chopper pickups which do not work with the Giants helper) we have to make sure we don't call
    -- getValidityOfTurnDirections for those
    if self.notAllImplementsHaveAiMarkers then
        self.fruitLeft, self.fruitRight = 0, 0
    else
        self.fruitLeft, self.fruitRight = AIVehicleUtil.getValidityOfTurnDirections(self.vehicle)
    end
    local workWidth = self:getWorkWidth()
    local x, _, z = localToWorld(self.vehicle:getAIDirectionNode(), workWidth, 0, 0)
    self.fieldOnLeft = CpFieldUtil.isOnField(x, z)
    x, _, z = localToWorld(self.vehicle:getAIDirectionNode(), -workWidth, 0, 0)
    self.fieldOnRight = CpFieldUtil.isOnField(x, z)
    self:debug('Fruit left: %.2f right %.2f, field on left %s, right %s',
            self.fruitLeft, self.fruitRight, tostring(self.fieldOnLeft), tostring(self.fieldOnRight))
end

-- Return true for no headlands so we can reduce off field pently for our unloader driver
function AIDriveStrategyChopperCourse:hasNoHeadlands()
    return self.course:getNumberOfHeadlands() == 0
end

--- We need to update pipeoffset after turn as fruit side may have changed
function AIDriveStrategyChopperCourse:resumeFieldworkAfterTurn(ix)
    self:updatePipeOffset(ix)
    AIDriveStrategyChopperCourse.superClass().resumeFieldworkAfterTurn(self, ix)
end

function AIDriveStrategyChopperCourse:setPipeOffsetX()
    -- Get the max discharge distance of the chopper and use 40% of that as our pipe offset
    self.pipeOffsetX = math.min(self.chopperController:getChopperDischargeDistance() * .4, self:getWorkWidth()/2 + 4)
end

function AIDriveStrategyChopperCourse:setPipeOffsetZ(offset)
    self.pipeOffsetZ = offset or -3
end
-- Currently works need to improve fruit side check
function AIDriveStrategyChopperCourse:getPipeOffset(additionalOffsetX, additionalOffsetZ)
    self:debugSparse('Chopper PipeOffsetX is %.2f', self.pipeOffsetX)
    return self.pipeOffsetX + additionalOffsetX, self.pipeOffsetZ + additionalOffsetZ
end

-- Currently works need to improve fruit side check
function AIDriveStrategyChopperCourse:updatePipeOffset(ix)
    -- We can't use self.fruitRight and self.fruitLeft as theses are only reliable during haversting.
    -- Instead use the has Pathfinder Utiliy hasFruit() the same function used in generating a pipe in fruit map
    -- Pipe in fruit map can't be used on headlands so always use hasFruit
    -- If fruit is found using our current pipe offset update to the opposite side
    
    local fruitCheckWaypoint = ix or self.course:getCurrentWaypointIx()
    self:debug('Fruitwaypoint was set to %d', fruitCheckWaypoint)

    if not self.course:isOnHeadland(fruitCheckWaypoint) then
        local lRow, rowStartIx = self.course:getRowLength(fruitCheckWaypoint)
        if ixAtRowStart then
            fruitCheckWaypoint = self.course:getNextWaypointIxWithinDistance(startIx,lRow / 2)
            self:debug('Fruitwaypoint was set to the middle of the row %d', fruitCheckWaypoint)
        else
            fruitCheckWaypoint = fruitCheckWaypoint + 20
            self:debug('Fruitwaypoint was set 20 ahead to couldn\'t determine row length %d', fruitCheckWaypoint)
        end
    end

    -- Reset the pipeoffset if we where being chased by a unloader driver
    if self.pipeOffsetX == 0 then
        self:setPipeOffsetX()
        self.chaseMode = false
        self:setPipeOffsetZ()
        self:debug('reset chase mode')
    end

    local hasFruit = self:isPipeInFruitAtWaypointNow(self.course, fruitCheckWaypoint, self.pipeOffsetX)
    self:debug('I found fruit %s at waypoint %d', tostring(hasFruit), fruitCheckWaypoint)
    if hasFruit then
        self:debug('I found fruit use the opposite side')
        self.pipeOffsetX = -self.pipeOffsetX
        hasFruit = self:isPipeInFruitAtWaypointNow(self.course, fruitCheckWaypoint, self.pipeOffsetX)
        if hasFruit then
            self:debug('I must be on a land row switch to chase mode')
            self.pipeOffsetX = 0
            self:setPipeOffsetZ(-self.measuredBackDistance - 2)
            self.chaseMode = true
            return
        end
    end
    local x, _, z = localToWorld(self.storage.fruitCheckHelperWpNode.node, self.pipeOffsetX, 0, 0)
    local fieldPolygon = self.course:getFieldPolygon()
    if not CpMathUtil.isPointInPolygon(fieldPolygon, x, z) and not self.course:isOnHeadland(fruitCheckWaypoint, 1) then
        self:debug('No fruit found use but no field found use the oppisote side')
        self.pipeOffsetX = -self.pipeOffsetX
    elseif self.course:isOnHeadland(fruitCheckWaypoint, 1) then
            self:debug('I am on a headland enganing chase mode')
            self.pipeOffsetX = 0
            self:setPipeOffsetZ(-self.measuredBackDistance - 2)
        self.chaseMode = true
    end
    self:debug('No fruit found use the same side')
end

function AIDriveStrategyChopperCourse:getChaseMode()
    return self.chaseMode
end

function AIDriveStrategyChopperCourse:registerUnloader(driver, whichUnloader)
    if whichUnloader == 'A' then
        self:debugSparse('registerUnloader: %s is registed as driver A', CpUtil.getName(driver.vehicle))
        self.unloaders.unloaderA:set(driver, 1000)
    elseif whichUnloader == 'B' then
        self:debugSparse('registerUnloader: %s is registed as driver B', CpUtil.getName(driver.vehicle))
        self.unloaders.unloaderB:set(driver, 1000)
    else
        self:debugSparse('registerUnloader: %s tried to register but didn\'t pass me A/B Unloader', CpUtil.getName(driver.vehicle))
    end
end

function AIDriveStrategyChopperCourse:resetUnloader(whichUnloader)
    if whichUnloader == 'A' then
        self:debug('resetUnloader: driver A was reset')
        self.unloaders.unloaderA:reset()
    elseif whichUnloader == 'B' then
        self:debug('resetUnloader: driver B was reset')
        self.unloaders.unloaderB:reset()
    else
        self:debug('resetUnloader: Someone tried to unregister but tell me who')
    end
end
function AIDriveStrategyChopperCourse:deregisterUnloader(driver, whichUnloader, noEventSend)
    if self.unloaderToRendezvous:get() then
        if self:getUnloader(whichUnloader) and self:getUnloader(whichUnloader).vehicle == self.unloaderToRendezvous:get() then
            self:cancelRendezvous()
        end
    end
    self:resetUnloader(whichUnloader)
end

function AIDriveStrategyChopperCourse:clearAllUnloaderInformation()
    self:debug('All Unloader Info has been cleared')
    self:cancelRendezvous()
    self.unloader:reset()
end

function AIDriveStrategyChopperCourse:getUnloader(whichUnloader)
    if whichUnloader == 'A' then
        return self.unloaders.unloaderA:get()
    elseif whichUnloader == 'B' then
        return self.unloaders.unloaderB:get()
    end
end

function AIDriveStrategyChopperCourse:updateNextUnloader()
    self:debug('I updated the unloaders')
    if self.unloaders.currentUnloader == 'A' then
        self.unloaders.nextUnloader = 'A'
        self.unloaders.currentUnloader = 'B'
    else
        self.unloaders.nextUnloader = 'B'
        self.unloaders.currentUnloader = 'A'
    end
end

function AIDriveStrategyChopperCourse:getNextUnloader()
    return self.unloaders.nextUnloader
end

function AIDriveStrategyChopperCourse:getCurrentUnloaderIdent()
    return self.unloaders.currentUnloader
end

function AIDriveStrategyChopperCourse:getCurrentUnloader()
    return self:getUnloader(self:getCurrentUnloaderIdent())
end
function AIDriveStrategyChopperCourse:callUnloaderWhenNeeded()

    if self:getUnloader(self:getCurrentUnloaderIdent()) and self:getUnloader(self:getNextUnloader()) then
        -- I have two unloaders already don't call any more
        self:debug('callUnloaderWhenNeeded: I have two unloaders no need for more')
        return
    end

    if not self.timeToCallUnloader:get() then
        return
    end

    -- check back again in a few seconds
    self.timeToCallUnloader:set(false, 3000)
    local bestUnloader, bestEte
    if self:isWaitingForUnload() then
        if self:getUnloader(self:getCurrentUnloaderIdent()) then
            self:debug('callUnloaderWhenNeeded: stopped, no unloader needed my unloader is just out of range')
            return
        end
        bestUnloader, _ = self:findUnloader(self.vehicle, nil)
        self:debug('callUnloaderWhenNeeded: stopped, need unloader here and I currently don\'t have any unloaders')
        if bestUnloader then
            self:updatePipeOffset()
            bestUnloader:getCpDriveStrategy():call(self.vehicle, nil, self:getCurrentUnloaderIdent())
        end
        return
    elseif not self.chaseMode then
        if not self.waypointIxWhenCallUnloader then
            self:debug('callUnloaderWhenNeeded: don\'t know yet where to meet the unloader')
            return
        end
        -- Find a good waypoint to unload, as the calculated one may have issues, like pipe would be in the fruit,
        -- or in a turn, etc.
        -- TODO: isPipeInFruitAllowed
        local tentativeRendezvousWaypointIx = self:findBestWaypointToUnload(self.waypointIxWhenCallUnloader, true)
        if not tentativeRendezvousWaypointIx then
            self:debug('callUnloaderWhenNeeded: can\'t find a good waypoint to meet the unloader')
            return
        end
        bestUnloader, bestEte = self:findUnloader(nil, self.course:getWaypoint(tentativeRendezvousWaypointIx))
        -- getSpeedLimit() may return math.huge (inf), when turning for example, not sure why, and that throws off
        -- our ETE calculation
        if bestUnloader and self.vehicle:getSpeedLimit(true) < 100 then
            local dToUnloadWaypoint = self.course:getDistanceBetweenWaypoints(tentativeRendezvousWaypointIx,
                    self.course:getCurrentWaypointIx())
            local myEte = dToUnloadWaypoint / (self.vehicle:getSpeedLimit(true) / 3.6)
            self:debug('callUnloaderWhenNeeded: best unloader ETE at waypoint %d %.1fs, my ETE %.1fs',
                    tentativeRendezvousWaypointIx, bestEte, myEte)
            if bestEte - 5 > myEte then
                -- I'll be at the rendezvous a lot earlier than the unloader which will almost certainly result in the
                -- cancellation of the rendezvous.
                -- So, set something up further away, with better chances,
                -- using the unloader's ETE, knowing that 1) that ETE is for the current rendezvous point, 2) there
                -- may be another unloader selected for that waypoint
                local dToTentativeRendezvousWaypoint = bestEte * (self.vehicle:getSpeedLimit(true) / 3.6)
                self:debug('callUnloaderWhenNeeded: too close to rendezvous waypoint, trying move it %.1fm',
                        dToTentativeRendezvousWaypoint)
                tentativeRendezvousWaypointIx = self.course:getNextWaypointIxWithinDistance(
                        self.course:getCurrentWaypointIx(), dToTentativeRendezvousWaypoint)
                if tentativeRendezvousWaypointIx then
                    bestUnloader, bestEte = self:findUnloader(nil, self.course:getWaypoint(tentativeRendezvousWaypointIx))
                    if bestUnloader then
                        self:callUnloader(bestUnloader, tentativeRendezvousWaypointIx, bestEte)
                    end
                else
                    self:debug('callUnloaderWhenNeeded: still can\'t find a good waypoint to meet the unloader')
                end
            elseif bestEte + 5 > myEte then
                -- do not call too early (like minutes before we get there), only when it needs at least as
                -- much time to get there as the combine (-5 seconds)
                self:callUnloader(bestUnloader, tentativeRendezvousWaypointIx, bestEte)
            end
        end
    end
end

function AIDriveStrategyChopperCourse:callUnloader(bestUnloader, tentativeRendezvousWaypointIx, bestEte)
    self:updatePipeOffset()
    if bestUnloader:getCpDriveStrategy():call(self.vehicle,
            self.course:getWaypoint(tentativeRendezvousWaypointIx), self:getNextUnloader()) then
        self.unloaderToRendezvous:set(bestUnloader, 1000 * (bestEte + 30))
        self.unloaderRendezvousWaypointIx = tentativeRendezvousWaypointIx
        self:debug('callUnloaderWhenNeeded: harvesting, unloader accepted rendezvous at waypoint %d', self.unloaderRendezvousWaypointIx)
    else
        self:debug('callUnloaderWhenNeeded: harvesting, unloader rejected rendezvous at waypoint %d', tentativeRendezvousWaypointIx)
    end
end

--- Are we ready for an unloader?
--- @param noUnloadWithPipeInFruit boolean pipe must not be in fruit for unload
function AIDriveStrategyChopperCourse:isReadyToUnload(noUnloadWithPipeInFruit)
    -- no unloading when not in a safe state (like turning)
    -- in these states we are always ready
    if self:willWaitForUnloadToFinish() then
        self:debugSparse('isReadyToUnload(): willWait')
        return true
    end

    -- but, if we are full and waiting for unload, we have no choice, we must be ready ...
    if self.state == self.states.UNLOADING_ON_FIELD and self.unloadState == self.states.WAITING_FOR_UNLOAD_ON_FIELD then
        self:debugSparse('isReadyToUnload(): state')
        return true
    end


    if not self.course then
        self:debugSparse('isReadyToUnload(): has no fieldwork course')
        return false
    end

    -- around a turn, for example already working on the next row but not done with the turn yet

    if self.course:isCloseToNextTurn(10) then
        self:debugSparse('isReadyToUnload(): too close to turn')
        return false
    end
    -- safe default, better than block unloading
    self:debugSparse('isReadyToUnload(): defaulting to ready to unload')
    return true
end

function AIDriveStrategyChopperCourse.isChopper(combine)
    local capacity = 0
    local dischargeNode = combine:getCurrentDischargeNode()
    if dischargeNode ~= nil then
        capacity = combine:getFillUnitCapacity(dischargeNode.fillUnitIndex)
    end
    return capacity == math.huge
end

function AIDriveStrategyChopperCourse:getConnectingTrack()
    return self.state == self.states.ON_CONNECTING_TRACK
end

--- We calculated a waypoint to meet the unloader (either because it asked for it or we think we'll need
--- to unload. Now make sure that this location is not around a turn or the pipe isn't in the fruit by
--- trying to move it up or down a bit. If that's not possible, just leave it and see what happens :)
function AIDriveStrategyChopperCourse:findBestWaypointToUnloadOnUpDownRows(ix, isPipeInFruitAllowed)
    local dToNextTurn = self.course:getDistanceToNextTurn(ix) or math.huge
    local lRow, ixAtRowStart = self.course:getRowLength(ix)
    local currentIx = self.course:getCurrentWaypointIx()
    local newWpIx = ix
    self:debug('Looking for a waypoint to unload around %d on up/down row, pipe in fruit %s, dToNextTurn: %d m, lRow = %d m',
            ix, tostring(pipeInFruit), dToNextTurn, lRow or 0)

    -- Waypoint would be on next row 
    if ixAtRowStart then
        -- so we'll have some distance for unloading
        if dToNextTurn < AIDriveStrategyCombineCourse.safeUnloadDistanceBeforeEndOfRow then
            local safeIx = self.course:getPreviousWaypointIxWithinDistance(ix,
                    AIDriveStrategyCombineCourse.safeUnloadDistanceBeforeEndOfRow)
            newWpIx = math.max(ixAtRowStart + 1, safeIx or -1, ix - 4, currentIx)
        end
        -- Waypoint would be on next row 
        if ixAtRowStart > currentIx then
            self:debug('Waypoint on next row, rejecting rendezvous')
            newWpIx = nil
        end
    end
    -- no better idea, just use the original estimated, making sure we avoid turn start waypoints
    if newWpIx and self.course:isTurnStartAtIx(newWpIx) then
        self:debug('Calculated rendezvous waypoint is at turn start, moving it up')
        -- make sure it is not on the turn start waypoint
        return math.max(newWpIx - 1, currentIx)
    else
        return newWpIx
    end
end