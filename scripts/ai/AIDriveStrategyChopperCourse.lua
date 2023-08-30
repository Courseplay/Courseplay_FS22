--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

Chopper support added by Pops64 2023

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

-- The chopper may start outside of the field this setting permits expansion of the field boundary in this case
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
        currentUnloader = CpTemporaryObject(nil),
        nextUnloader = CpTemporaryObject(nil)
    }

    -- Bool to set for special logic when unloader is need to be snugged up against the chopper so we don't drive in the fruit or off the field when unloading
    self.chaseMode = false
    return self
end

function AIDriveStrategyChopperCourse:setAllStaticParameters()
    --Old Code to add markers to Choppers which don't have AI markers
    self:checkMarkers()
    AIDriveStrategyChopperCourse.superClass().setAllStaticParameters(self)

    -- Check if we are a sugarcane harvester for special handling
    self.isSugarCaneHarvester = self:getSugarCaneHarvester()

    -- We need set this as a variable and update left/right side on turns in self:checkPipeOffsetXForFruit()
    self:setPipeOffsetX()
    -- This is used to increase offset z when being chased instead along side
    self:setPipeOffsetZ()

    self:debug('AIDriveStrategyChopperCourse set')

end

function AIDriveStrategyChopperCourse:initializeImplementControllers(vehicle)
    AIDriveStrategyChopperCourse:superClass().initializeImplementControllers(self, vehicle)
    -- Need access to chopper controller functions
    local _
    _, self.pipeController = self:addImplementController(vehicle, PipeController, Pipe, {}, nil)
    self.combine, self.chopperController = self:addImplementController(vehicle, ChopperController, Combine, {}, nil)
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Main Loop
---------------------------------------------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyChopperCourse:update(dt)
    AIDriveStrategyCombineCourse.update(self, dt)
    -- Old Code still needed to make Choppers work
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
        self:checkUnloaderState()

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

--- We need to check pipeoffsetX after a turn as fruit side may have changed
-- function AIDriveStrategyChopperCourse:resumeFieldworkAfterTurn(ix)
--     self:checkPipeOffsetXForFruit(ix)
--     AIDriveStrategyChopperCourse.superClass().resumeFieldworkAfterTurn(self, ix)
-- end

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

    -- Is this really need any more seeing how fruit check is handled by checkPipeOffsetXForFruit
    self:checkFruit()

    if self.state == self.states.WORKING then
        self:estimateDistanceUntilFull(ix)
        self:callUnloaderWhenNeeded()
        -- Alteration from parent function we need to check every once in a while to see if the next unloader incoming is ready to replace out current unloader
        
    end

    AIDriveStrategyFieldWorkCourse.onWaypointPassed(self, ix, course)
end

--- Called when the last waypoint of a course is passed, Non of the parent logic applies to us just call the fieldwork function
-- 
function AIDriveStrategyCombineCourse:onLastWaypointPassed()
    AIDriveStrategyFieldWorkCourse.onLastWaypointPassed(self)
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
        if self:getNextUnloader() and self:getNextUnloader():readyToReceive() then
            -- We only cancel the rendezvous if we try to switch the unloaders here there will be multiple calls to it causing logic breaks
            self:debug('Discharging to %s, cancelling unloader rendezvous %s is ready to come along side', CpUtil.getName(self:getCurrentUnloader().vehicle), CpUtil.getName(self:getNextUnloader().vehicle))
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

-- TODO: move this to the PipeController? Rename this is it doesn't check pipe in checks for trailer in range
function AIDriveStrategyChopperCourse:handlePipe()
    self.pipeController:handleChopperPipe()
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Pipe offset functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyChopperCourse:setPipeOffsetX()
    
    
    if self.isSugarCaneHarvester then
        -- Since the sugarcane harvester rotates we need to find total pipe length and use that as our offset. 
        -- This math is handled in pipe controller
        self.pipeOffsetX = self.pipeController:getPipeOffsetX()
    else
        -- Use the work width plus a little bit. But make sure we don't go further than 80% of the max discharge. 
        -- This may cause issues on very large modded choppers that didn't alter the discharge distance
        self.pipeOffsetX =  math.min(self.chopperController:getChopperDischargeDistance() * .8, self:getWorkWidth()/2 + 4)
    end
    self:debug('Pipe Offset X was set as: %.2f', self.pipeOffsetX)
end

function AIDriveStrategyChopperCourse:setPipeOffsetZ(offset)
    -- If offset is supplied use that(Chase Mode) plus what is returned from pipe controller
    self.pipeOffsetZ = (offset or 0) + self.pipeController:getPipeOffsetZ()
end

-- Return our current pipe offset plus any user supplied offset
function AIDriveStrategyChopperCourse:getPipeOffset(additionalOffsetX, additionalOffsetZ)
    self:debugSparse('Chopper PipeOffsetX is %.2f', self.pipeOffsetX)
    return self.pipeOffsetX + additionalOffsetX, self.pipeOffsetZ + additionalOffsetZ
end

function AIDriveStrategyChopperCourse:checkPipeOffsetXForFruit(ix)
    -- We can't use self.fruitRight and self.fruitLeft as theses are only reliable during harvesting.
    -- Pipe in fruit map can't be used on headlands so always use hasFruit and isn't generated for Choppers correctly
    -- Instead use the has Pathfinder Utility hasFruit() which is accessed by the parent class functions
    -- If fruit is found using our current pipe offset update to the opposite side
   
    -- Reset the pipeoffset if we were being chased by a unloader driver.
    if self.pipeOffsetX == 0 then
        self:setPipeOffsetX()
        self:setPipeOffsetZ()
        self.chaseMode = false
        self.landRow = false
        self:debug('checkPipeOffsetXForFruit: reset chase mode')
    end
    

    -- We need a waypoint to check use a supplied one(When we are getting the next unloader) or if nothing is supplied just use our current one
    local fruitCheckWaypoint = ix or self.course:getCurrentWaypointIx()
    self:debug('checkPipeOffsetXForFruit: Fruitwaypoint was set to %d', fruitCheckWaypoint)

    -- Safety check to make sure we don't go beyond the last waypoint. With out some serious logic there is no good way to handle this situation
    -- Keep the offset the same and hope for the best
    if self.course:isBeyondLastWaypointIx(fruitCheckWaypoint + 11) then
        self:debug('checkPipeOffsetXForFruit: Fruitwaypoint %d will be beyond the last waypoint', fruitCheckWaypoint)
        return
    end

    if not self.course:isOnHeadland(fruitCheckWaypoint) then
        
        local lRow, rowStartIx = self.course:getRowLength(fruitCheckWaypoint)
        self:debug('checkPipeOffsetXForFruit: lRow = %d rowStartIx = %d', lRow or 0, rowStartIx or 0)
        -- We didn't get a row length back try again a little further ahead
        if lRow == 0 then
            lRow, rowStartIx = self.course:getRowLength(fruitCheckWaypoint+2)
        end
        if lRow > 0 and rowStartIx then -- Yeah! We got a row length lets use the middle of the row to determine where the fruit is
            fruitCheckWaypoint = self.course:getNextWaypointIxWithinDistance(rowStartIx, lRow / 2)
            self:debug('Fruitwaypoint was set to the middle of the row %d', fruitCheckWaypoint)
        else -- We still didn't get a row length just set it 10 ahead and hope for the best
            fruitCheckWaypoint = fruitCheckWaypoint + 10
            self:debug('Fruitwaypoint was set 10 ahead to couldn\'t determine row length %d', fruitCheckWaypoint)
        end
    end
    
    -- If we are on the first headland engage chase mode and the pipeoffset to zero disabled for sugarcane
    if self.course:isOnHeadland(fruitCheckWaypoint, 1 ) and not self.isSugarCaneHarvester then
        self:debug('I am on a headland engaging chase mode')
        self.pipeOffsetX = 0
        self:setPipeOffsetZ(-self.measuredBackDistance) 
        -- We need this so the unloader knows what turn manuevers to use
        self.chaseMode = true
    else
        -- Check to see if the waypoint that we are using would put the unloader in the fruit using out current pipe offset
        -- And if would use the opposite value of the pipe offset as the should be cleared because the should be our last row worked
        local hasFruit = self:isPipeInFruitAtWaypointNow(self.course, fruitCheckWaypoint, self.pipeOffsetX)
        self:debug('I found fruit %s at waypoint %d', tostring(hasFruit), fruitCheckWaypoint)
        if hasFruit then
            self:debug('I found fruit on my current side switch to the opposite side')
            self.pipeOffsetX = -self.pipeOffsetX
            -- Perform another check to see with out updated pipeoffset to make sure that was our last row worked and it is indeed clear of fruit
            -- If we find fruit again that means we no clear lane for the unloader drive and have it follow us down the row we are clearing
            hasFruit = self:isPipeInFruitAtWaypointNow(self.course, fruitCheckWaypoint, self.pipeOffsetX)
            if hasFruit and not self.isSugarCaneHarvester then
                self:debug('I found fruit again I must be on a land row switch to chase mode')
                self.pipeOffsetX = 0
                self:setPipeOffsetZ(-self.measuredBackDistance)
                -- We need this so the unloader knows what turn manuevers to use
                self.chaseMode = true
                self.landRow = true
                return
            end
        end
        
        -- Once final check to make sure the pipeoffset we are going to supply to the unloader is on the field.
        local x, _, z = localToWorld(self.storage.fruitCheckHelperWpNode.node, self.pipeOffsetX, 0, 0)
        local fieldId = CpFieldUtil.getFieldIdAtWorldPosition(x, z)

        if not CpFieldUtil.isNodeOnField(self.storage.fruitCheckHelperWpNode.node, fieldId) then
            -- The point we are using isn't on the field check the other side of the chopper to see if there is fruit and if there is no fruit use have the unloader follow us on that side
            -- Otherwise just have the unloader follow us
            if hasFruit and not self.isSugarCaneHarvester then 
                self.pipeOffsetX = 0
                self:setPipeOffsetZ(-self.measuredBackDistance - 2)
                -- We need this so the unloader knows what turn manuevers to use
                self.chaseMode = true
                self:debug('I found fruit and the opposite side isn\'t on the field I must be on an edge row engage chase mode')
            elseif not hasFruit then
                self:debug('I didn\'t find fruit and the opposite side ins\'t on the field stick to my original side')
                self.pipeOffsetX = -self.pipeOffsetX
            end
        else
            self:debug('No fruit found use the same side')
        end
    end
end

-- Function so the unloader can access chaseMode bool. Needed for handling special turn away logic
function AIDriveStrategyChopperCourse:getChaseMode()
    return self.chaseMode
end

-- Function so the unloader can access landRow bool. Needed for handling even more special turn away logic
function AIDriveStrategyChopperCourse:getLandRow()
    return self.landRow
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Unloader Handling Functions
--------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Register the unloader. We must always have a current unloader so if that is nil set who ever called registerUnloader set as our current
-- If we already have a current unloader and the unloader calling isn't our current set that as our nextUnloader
function AIDriveStrategyChopperCourse:registerUnloader(driver)
    if not self:getCurrentUnloader() then
        self.unloaders.currentUnloader:set(driver, 1000)
        -- Update our call percentage to use the user supplied setting on the unloader or if something breaks just go with 95
        self.callUnloaderAtFillLevelPercentage = driver:getFullThreshold() or 95
    elseif driver == self:getCurrentUnloader()  then
        self.unloaders.currentUnloader:set(driver, 1000)
        self.callUnloaderAtFillLevelPercentage = driver:getFullThreshold() or 95
    else
        self.unloaders.nextUnloader:set(driver, 1000)
    end
end

-- We must be told who to reset otherwise we could clear the wrong unloader out causing logic breaks
function AIDriveStrategyChopperCourse:resetUnloader(driver)
    if driver == self:getCurrentUnloader() then
        self.unloaders.currentUnloader:reset()
    elseif driver == self:getNextUnloader() == driver then
        self.unloaders.nextUnloader:reset()
    end
end

-- This is called when ever the unloader loses the combine or it departs for the unload course
function AIDriveStrategyChopperCourse:deregisterUnloader(driver, noEventSend)
    if self.unloaderToRendezvous:get() then
        if self:getUnloader(driver) and self:getUnloader(driver).vehicle == self.unloaderToRendezvous:get() then
            self:cancelRendezvous()
        end
    end
    self:changeUnloader()
    --self:resetUnloader(driver)
end

-- Not sure when this is called TODO make a global reset but only if this is called when everything is shutting down otherwise we will cause logic breaks
function AIDriveStrategyChopperCourse:clearAllUnloaderInformation()
    self:debug('All Unloader Info has been cleared')
    self:cancelRendezvous()
    self.unloader:reset()
end

-- This is needed for the deregisterUnloader function we don't want to cancel the rendezvous if we are not the one we currently are set to rendezvous with(logic breaks)
function AIDriveStrategyChopperCourse:getUnloader(driver)
    if driver == self:getCurrentUnloader() then
        return self:getCurrentUnloader()
    elseif driver == self:getNextUnloader() then
        return self:getNextUnloader()
    end
end

-- This is called any time our NextUnloader is ready to replace out current.(Within a certain distance and aligned) It checks to make sure we have a current and if we do we clear it out
-- (The current unloader isn't always johnny on the spot telling the chopper to clear itself out)
-- Then we register as the current and reset the nextUnloader
function AIDriveStrategyChopperCourse:changeUnloader()
    if self:getCurrentUnloader() then
        self:resetUnloader(self:getCurrentUnloader())
    end
    if self:getNextUnloader() then
        self:registerUnloader(self:getNextUnloader())
        self.unloaders.nextUnloader:reset()
    end
end

-- Returns our current unloader. So we don't have to access the unloaders object directly
function AIDriveStrategyChopperCourse:getCurrentUnloader()
    return self.unloaders.currentUnloader:get()
end

-- Returns our next unloader. So we don't have to access the unloaders object directly
function AIDriveStrategyChopperCourse:getNextUnloader()
    return self.unloaders.nextUnloader:get()
end

-- Another safety check to make sure we always have a current unloader
-- This is ran every waypointpassed() call. It asks if our next unloader is behind and aligned and within 25 meters of last waypoint of its driveToCombine Course
function AIDriveStrategyChopperCourse:checkUnloaderState()
    if not self:getCurrentUnloader() and self:getNextUnloader() then
        self:debug('checkUnloaderState: I lost my current unloader and I have one that is arriving switch them')
        self:changeUnloader()
    elseif self:getNextUnloader() and self:getNextUnloader():readyToReceive() then
        self:debug('checkUnloaderState: Discharging to %s, and %s is ready to come along side', CpUtil.getName(self:getCurrentUnloader().vehicle), CpUtil.getName(self:getNextUnloader().vehicle))
        --TODO This is the user method to request drive now. It resets after 3 secs which may cause and already full unloader to return if there is a reason for it go to idle state from drive to unload
        self:getCurrentUnloader():requestDriveUnloadNow()
    end
end


-- Copied from parent. Altered to handle a current and next unloader
function AIDriveStrategyChopperCourse:callUnloaderWhenNeeded()

    if self:getCurrentUnloader() and self:getNextUnloader() then
        -- I have two unloaders already don't call any more. Otherwise we will have multiple unloaders try to show up
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
        -- Make sure we don't call more unloaders if we already have a current one and it is just not in range aka turns and a unloader on a driveToCombine Course
        if self:getCurrentUnloader() then
            self:debugSparse('callUnloaderWhenNeeded: stopped, no unloader needed my unloader is just out of range')
            return
        end
        bestUnloader, _ = self:findUnloader(self.vehicle, nil)
        self:debugSparse('callUnloaderWhenNeeded: stopped, need unloader here and I currently don\'t have any unloaders')
        if bestUnloader then
            self:checkPipeOffsetXForFruit()
            bestUnloader:getCpDriveStrategy():call(self.vehicle, nil)
        end
        return
    elseif not self.chaseMode then -- We do not want to deal with multiple unloaders when we are snugged up against the chopper
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

-- Copied from parent altered to check for active chopper unloaders
function AIDriveStrategyChopperCourse:findUnloader(combine, waypoint)
    local bestScore = -math.huge
    local bestUnloader, bestEte
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if AIDriveStrategyUnloadChopper.isActiveCpChopperUnloader(vehicle) then -- Alteration from parent
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

-- Copied from parent removed pocket logic and other things that were causes logic issues
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

function AIDriveStrategyChopperCourse:isChopperOnConnectingTrack()
    -- Connecting Tracks can be followed with an alignment turn which isn't a turn state but Driving to work Start
    -- The unloader driver relies on this so pathfinder isn't called before we are in our correct location
    return self.state == self.states.ON_CONNECTING_TRACK or self.state == self.states.DRIVING_TO_WORK_START_WAYPOINT
end


-- Copied from parent altered to remove pipe in fruit map logic. We don't have a pipeInFruit map for choppers
--- We calculated a waypoint to meet the unloader (either because it asked for it or we think we'll need
--- to unload. Now make sure that this location is not around a turn 
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


-- Copied from parent altered to use the trailer fill level instead of the chopper
function AIDriveStrategyChopperCourse:estimateDistanceUntilFull(ix)
    -- calculate fill rate so the combine driver knows if it can make the next row without unloading
    local fillLevel = 1
    local capacity = 1

    -- Choppers don't have fill levels get the trailer we currently are discharging too fill levels so we know when the unloader is about to depart
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

---------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utilities
-----------------------------------------------------------------------------------------------------------------------------------------------------

-- Check for sugarcane harvester certain logic needs to be disabled when we are unloading them
function AIDriveStrategyChopperCourse:getSugarCaneHarvester()
    for i, fillUnit in ipairs(self.vehicle:getFillUnits()) do
        if self.vehicle:getFillUnitSupportsFillType(i, FillType.SUGARCANE) then
            self:debug('This is a Sugarcane harvester')
            return true
        end
    end
    return false
end


-- Not what this does
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

-- Function to allow us to receive the nearest trailer objects
function AIDriveStrategyChopperCourse:nearestChopperTrailer()
    local trailer = self.pipeController:getClosestObject()
    local targetObject = self.pipeController:getDischargeObject()
    return trailer, targetObject
end

-- Return true for no headlands so we can reduce off field penalty for our unloader driver
function AIDriveStrategyChopperCourse:hasNoHeadlands()
    return self.course:getNumberOfHeadlands() == 0
end

function AIDriveStrategyChopperCourse:isFuelSaveAllowed()
    local isFuelSaveAllowed = AIDriveStrategyCombineCourse.isFuelSaveAllowed(self)
    return isFuelSaveAllowed or self:isChopperWaitingForUnloader() or (self:getCurrentUnloader() and not self:getCurrentUnloader():isUnloaderTurning())
end

-- Not being used?
function AIDriveStrategyChopperCourse:shouldHoldInTurnManeuver()
    --- Do not hold durning discharge
    return false
end


-- Get the trailer we are unloading to fill levels
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


-- This is current broken and any trailer nearby will cause it to be true. Maybe it is not .vehicle but a get implements to return the trailer object instead?
function AIDriveStrategyChopperCourse:isChopperWaitingForUnloader()
    local trailer, targetObject = self:nearestChopperTrailer()
    local dischargeNode = self.pipeController:getDischargeNode()
    self:debugSparse('%s %s', dischargeNode, self:isAnyWorkAreaProcessing())
    if not (targetObject == nil or trailer == nil) then 
        if targetObject and targetObject.rootVehicle.getIsCpActive and targetObject.rootVehicle:getIsCpActive() then
            local strategy = targetObject.rootVehicle:getCpDriveStrategy()
            if strategy.isAChopperUnloadAIDriver
                and self:getCurrentUnloader()
                and self:getCurrentUnloader().vehicle == targetObject.rootVehicle 
                and self:getCurrentUnloader():readyToReceive() then
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
