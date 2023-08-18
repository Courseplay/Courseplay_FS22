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
    return self
end

function AIDriveStrategyChopperCourse:setAllStaticParameters()
    --Old Code to add markers to Choppers which don't have AI markers
    self:checkMarkers()
    AIDriveStrategyChopperCourse.superClass().setAllStaticParameters(self)

    -- We need set this as a variable and update left/right side on turns in self:updatePipeOffset()
    self:setPipeOffset()
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

function AIDriveStrategyChopperCourse:start(course, startIx, jobParameters)
    AIDriveStrategyChopperCourse.superClass().start(self, course, startIx, jobParameters)
    -- Update the pipeOffset side when we start work  
    self:updatePipeOffset(startIx)
end

function AIDriveStrategyCombineCourse:checkRendezvous()
    if self.unloaderToRendezvous:get() then
        local lastPassedWaypointIx = self.ppc:getLastPassedWaypointIx() or self.ppc:getRelevantWaypointIx()
        local d = self.course:getDistanceBetweenWaypoints(lastPassedWaypointIx, self.unloaderRendezvousWaypointIx)
        if d < 10 then
            self:debugSparse('Slow down around the unloader rendezvous waypoint %d to let the unloader catch up',
                    self.unloaderRendezvousWaypointIx)
            self:setMaxSpeed(self.settings.fieldWorkSpeed:getValue() / 2)
        elseif lastPassedWaypointIx > self.unloaderRendezvousWaypointIx then
            -- past the rendezvous waypoint
            self:debug('Unloader missed the rendezvous at %d', self.unloaderRendezvousWaypointIx)
            local unloaderWhoDidNotShowUp = self.unloaderToRendezvous:get()
            -- need to call this before onMissedRendezvous as the unloader will call back to set up a new rendezvous
            -- and we don't want to cancel that right away
            self:cancelRendezvous()
            unloaderWhoDidNotShowUp:getCpDriveStrategy():onMissedRendezvous(self.vehicle)
        end
        if self:isDischarging() then
            self:debug('Discharging, cancelling unloader rendezvous')
            self:cancelRendezvous()
        end
    end
end

function AIDriveStrategyCombineCourse:driveUnloadOnField()
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
        self:debug('findUnloader: no idle unloader found')
    end
end

function AIDriveStrategyChopperCourse:getTrailerFillLevel()
    local fillLevel = 0
    local capacity = 1
    if not self:isChopperWaitingForUnloader() then
        local trailer, targetObject = self:nearestChopperTrailer() 
        fillLevel, capacity = FillLevelManager.getAllTrailerFillLevels(targetObject)
        self:debug('Chopper Trailer fill level is %.1f and can hold %.1f',
            fillLevel, capacity)
    end
    return fillLevel, capacity
end

function AIDriveStrategyChopperCourse:isChopperWaitingForUnloader()
    return self.waitingForTrailer
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
    local trailer, targetObject = self:nearestChopperTrailer()
    local dischargeNode = self.pipeController:getDischargeNode()
    self:debugSparse('%s %s', dischargeNode, self:isAnyWorkAreaProcessing())
    if targetObject == nil or trailer == nil then
        self:debugSparse('Chopper waiting for trailer, discharge node %s, target object %s, trailer %s',
                tostring(dischargeNode), tostring(targetObject), tostring(trailer))
        self.waitingForTrailer = true
    end
    if self.waitingForTrailer then
        if not (targetObject == nil or trailer == nil) then
            self:debugSparse('Chopper has trailer now, continue')
            self.waitingForTrailer = false
        end
    end
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

function AIDriveStrategyChopperCourse:setPipeOffset()
    -- Get the max discharge distance of the chopper and use 40% of that as our pipe offset
    self.pipeOffsetX = math.abs(self.chopperController:getChopperDischargeDistance() * .4)
end
-- Currently works need to improve fruit side check
function AIDriveStrategyChopperCourse:getPipeOffset(additionalOffsetX, additionalOffsetZ)
    self:debugSparse('Chopper PipeOffsetX is %.2f', self.pipeOffsetX)
    return self.pipeOffsetX + additionalOffsetX, -3 + additionalOffsetZ
end

-- Currently works need to improve fruit side check
function AIDriveStrategyChopperCourse:updatePipeOffset(ix)
    -- We can't use self.fruitRight and self.fruitLeft as theses are only reliable during haversting.
    -- Instead use the pipe in fruit map to see if the next 25 waypoints will have the pipe in fruit
    -- If so switch the offset so the unloader will not drive in the fruit. Also if we encounter a turn start escape 
    -- This should be more reliable as fruit side shouldn't change when not turning
    -- Reset pipeOffsetx to the right side and check to see if needs to be changed to the left
    self.pipeOffsetX = math.abs(self.pipeOffsetX)
    --Check for a turn in the next 5 waypoints if we find one use our current waypoint for fruit check. With this we can assume we ar at the end of a row.
    -- This avoids unreliable pipeinfruit map data at turn points
    while ix <= ix + 10 do
        if self.course:isTurnStartAtIx(ix) then
            self:debug('There is a turn soon check fruit at my current location')
            if self.course:isPipeInFruitAt(ix) then
                self.pipeOffsetX = -self.pipeOffsetX
                self:debug('I have updated pipeoffset to the left side')
                return
            else
                self:debug('I have left the pipeoffset on the right side')
                return
            end
        else
            ix = ix + 1
        end
    end
    self:debug('I have found no turn soon check the next 10 waypoints for fruit')
    -- We didn't find the a turn so check the 5 waypoints ahead in pipeinfruit map to see for fruit. This should also avoid any bad fruit data
    if self.course:isPipeInFruitAt(ix) then
        self.pipeOffsetX = -self.pipeOffsetX
        self:debug('I have updated pipeoffset to left side')
        return
    end
    --TODO Add a check to see if we are on the last row and if we are set the it to field side
    self:debug('I have left the pipeoffset on the right side')
end