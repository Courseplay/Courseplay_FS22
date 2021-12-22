--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

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

---@class AIDriveStrategyFieldWorkCourse : AIDriveStrategyCourse
AIDriveStrategyFieldWorkCourse = {}
local AIDriveStrategyFieldWorkCourse_mt = Class(AIDriveStrategyFieldWorkCourse, AIDriveStrategyCourse)

AIDriveStrategyFieldWorkCourse.myStates = {
    INITIAL = {},
    WORKING = {},
    ON_CONNECTING_TRACK = {},
    ON_ALIGNMENT_COURSE = {},
    WAITING_FOR_LOWER = {},
    WAITING_FOR_LOWER_DELAYED = {},
    WAITING_FOR_STOP = {},
    WAITING_FOR_WEATHER = {},
    TURNING = {},
    TEMPORARY = {},
}

AIDriveStrategyFieldWorkCourse.normalFillLevelFullPercentage = 99.5

function AIDriveStrategyFieldWorkCourse.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyFieldWorkCourse_mt
    end
    local self = AIDriveStrategyCourse.new(customMt)
    AIDriveStrategyCourse.initStates(self, AIDriveStrategyFieldWorkCourse.myStates)
    self.state = self.states.INITIAL
    -- cache for the nodes created by TurnContext
    self.turnNodes = {}
    -- course offsets dynamically set by the AI and added to all tool and other offsets
    self.aiOffsetX, self.aiOffsetZ = 0, 0

    return self
end

function AIDriveStrategyFieldWorkCourse:delete()
    AIDriveStrategyFieldWorkCourse:superClass().delete(self)
    self:raiseImplements()
    TurnContext.deleteNodes(self.turnNodes)
end

function AIDriveStrategyFieldWorkCourse:setAIVehicle(vehicle)
    AIDriveStrategyFieldWorkCourse:superClass().setAIVehicle(self, vehicle)
    self.ppc:registerListeners(self, 'onWaypointPassed', 'onWaypointChange')
    self:setAllStaticParameters()
end

function AIDriveStrategyFieldWorkCourse:update()
    AIDriveStrategyFieldWorkCourse:superClass().update(self)
    -- TODO_22 add debug flag
    if self.state == self.states.TURNING then
        if self.turnContext then
            self.turnContext:drawDebug()
        end
        if self.aiTurn then
            self.aiTurn:drawDebug()
        end
    end
    if self.course:isTemporary() then
       self.course:draw()
    end
end

--- This is the interface to the Giant's AIFieldWorker specialization, telling it the direction and speed
function AIDriveStrategyFieldWorkCourse:getDriveData(dt, vX, vY, vZ)

    self:updateFieldworkOffset()

    local moveForwards = not self.ppc:isReversing()
    local gx, gz, maxSpeed

    self:setMaxSpeed(self.vehicle:getCpSettingValue(CpVehicleSettings.fieldWorkSpeed))
    ----------------------------------------------------------------
    if not moveForwards then
        gx, gz, _, maxSpeed = self.reverser:getDriveData()
        if not gx then
            -- simple reverse (not towing anything), just use PPC
            gx, _, gz = self.ppc:getGoalPointPosition()
            maxSpeed = self.vehicle:getCpSettingValue(CpVehicleSettings.reverseSpeed)
        end
        self:setMaxSpeed(maxSpeed)
    else
        gx, _, gz = self.ppc:getGoalPointPosition()
    end
    ----------------------------------------------------------------
    if self.state == self.states.INITIAL then
        self:lowerImplements()
        self.state = self.states.WAITING_FOR_LOWER
    elseif self.state == self.states.WAITING_FOR_LOWER then
        if self.vehicle:getCanAIFieldWorkerContinueWork() then
            self:debug('all tools ready, start working')
            self.state = self.states.WORKING
        else
            self:debugSparse('waiting for all tools to lower')
            self:setMaxSpeed(0)
        end
    elseif self.state == self.states.WAITING_FOR_LOWER_DELAYED then
        -- getCanAIVehicleContinueWork() seems to return false when the implement being lowered/raised (moving) but
        -- true otherwise. Due to some timing issues it may return true just after we started lowering it, so this
        -- here delays the check for another cycle.
        self.state = self.states.WAITING_FOR_LOWER
        self:setMaxSpeed(0)
    elseif self.state == self.states.WORKING then
        self:setMaxSpeed(self.vehicle:getSpeedLimit(true))
    elseif self.state == self.states.TURNING then
        local turnGx, turnGz, turnMoveForwards, turnMaxSpeed = self.aiTurn:getDriveData(dt)
        self:setMaxSpeed(turnMaxSpeed)
        -- if turn tells us which way to go, use that, otherwise just do whatever PPC tells us
        gx, gz = turnGx or gx, turnGz or gz
        if turnMoveForwards ~= nil then moveForwards = turnMoveForwards end
    elseif self.state == self.states.ON_CONNECTING_TRACK then
        self:setMaxSpeed(self.vehicle:getCpSettingValue(CpVehicleSettings.fieldSpeed))
    elseif self.state == self.states.ON_ALIGNMENT_COURSE then
        self:setMaxSpeed(self.vehicle:getCpSettingValue(CpVehicleSettings.fieldWorkSpeed))
    end
    self:setAITarget()
    return gx, gz, moveForwards, self.maxSpeed, 100
end

-- Seems like the Giants AIDriveStrategyCollision needs these variables on the vehicle to be set
-- to calculate an accurate path prediction
function AIDriveStrategyFieldWorkCourse:setAITarget()
    --local dx, _, dz = localDirectionToWorld(self.vehicle:getAIDirectionNode(), 0, 0, 1)
    local wp = self.ppc:getCurrentWaypoint()
    local dx, dz = wp.dx, wp.dz
    local length = MathUtil.vector2Length(dx, dz)
    dx = dx / length
    dz = dz / length
    self.vehicle.aiDriveDirection = { dx, dz }
    local x, _, z = getWorldTranslation(self.vehicle:getAIDirectionNode())
    self.vehicle.aiDriveTarget = { x, z }
end

-- remember a course to start
function AIDriveStrategyFieldWorkCourse:rememberCourse(course, ix)
    self.rememberedCourse = course
    self.rememberedCourseStartIx = ix
end

-- start a remembered course
function AIDriveStrategyFieldWorkCourse:startRememberedCourse()
    self:startCourse(self.rememberedCourse, self.rememberedCourseStartIx)
end

function AIDriveStrategyFieldWorkCourse:getRememberedCourseAndIx()
    return self.rememberedCourse, self.rememberedCourseStartIx
end
-----------------------------------------------------------------------------------------------------------------------
--- Implement handling
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyFieldWorkCourse:lowerImplements()
    for _, implement in pairs(self.vehicle:getAttachedAIImplements()) do
        implement.object:aiImplementStartLine()
    end
    self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_START_LINE)

    if AIUtil.hasAIImplementWithSpecialization(self.vehicle, SowingMachine) or self.ppc:isReversing() then
        -- sowing machines want to stop while the implement is being lowered
        -- also, when reversing, we assume that we'll switch to forward, so stop while lowering, then start forward
        -- TODO_22
        --self.state = self.states.WAITING_FOR_LOWER_DELAYED
    end
end

function AIDriveStrategyFieldWorkCourse:raiseImplements()
    for _, implement in pairs(self.vehicle:getAttachedAIImplements()) do
        implement.object:aiImplementEndLine()
    end
    self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
end


function AIDriveStrategyFieldWorkCourse:shouldRaiseImplements(turnStartNode)
    -- see if the vehicle has AI markers -> has work areas (built-in implements like a mower or cotton harvester)
    local doRaise = self:shouldRaiseThisImplement(self.vehicle, turnStartNode)
    -- and then check all implements
    for _, implement in pairs(AIUtil.getAllAIImplements(self.vehicle)) do
        -- only when _all_ implements can be raised will we raise them all, hence the 'and'
        doRaise = doRaise and self:shouldRaiseThisImplement(implement.object, turnStartNode)
    end
    return doRaise
end

---@param turnStartNode number at the last waypoint of the row, pointing in the direction of travel. This is where
--- the implement should be raised when beginning a turn
function AIDriveStrategyFieldWorkCourse:shouldRaiseThisImplement(object, turnStartNode)
    local aiFrontMarker, _, aiBackMarker = WorkWidthUtil.getAIMarkers(object, nil, true)
    -- if something (like a combine) does not have an AI marker it should not prevent from raising other implements
    -- like the header, which does have markers), therefore, return true here
    if not aiBackMarker or not aiFrontMarker then return true end
    -- TODO_22
    --local marker = self.vehicle.cp.settings.implementRaiseTime:is(ImplementRaiseLowerTimeSetting.EARLY) and aiFrontMarker or aiBackMarker
    local marker = aiFrontMarker
    -- turn start node in the back marker node's coordinate system
    local _, _, dz = localToLocal(marker, turnStartNode, 0, 0, 0)
    self:debugSparse('%s: shouldRaiseImplements: dz = %.1f', CpUtil.getName(object), dz)
    -- marker is just in front of the turn start node
    return dz > 0
end


--- When finishing a turn, is it time to lower all implements here?
-- TODO: remove the reversing parameter and use ppc to find out once not called from turn.lua
function AIDriveStrategyFieldWorkCourse:shouldLowerImplements(turnEndNode, reversing)
    -- see if the vehicle has AI markers -> has work areas (built-in implements like a mower or cotton harvester)
    local doLower, vehicleHasMarkers = self:shouldLowerThisImplement(self.vehicle, turnEndNode, reversing)
    if not vehicleHasMarkers and reversing then
        -- making sure the 'and' below will work if reversing and the vehicle has no markers
        doLower = true
    end
    -- and then check all implements
    for _, implement in ipairs(AIUtil.getAllAIImplements(self.vehicle)) do
        if reversing then
            -- when driving backward, all implements must reach the turn end node before lowering, hence the 'and'
            doLower = doLower and self:shouldLowerThisImplement(implement.object, turnEndNode, reversing)
        else
            -- when driving forward, if it is time to lower any implement, we'll lower all, hence the 'or'
            doLower = doLower or self:shouldLowerThisImplement(implement.object, turnEndNode, reversing)
        end
    end
    return doLower
end

---@param object table is a vehicle or implement object with AI markers (marking the working area of the implement)
---@param turnEndNode number node at the first waypoint of the row, pointing in the direction of travel. This is where
--- the implement should be in the working position after a turn
---@param reversing boolean are we reversing? When reversing towards the turn end point, we must lower the implements
--- when we are _behind_ the turn end node (dz < 0), otherwise once we reach it (dz > 0)
---@return boolean, boolean the second one is true when the first is valid
function AIDriveStrategyFieldWorkCourse:shouldLowerThisImplement(object, turnEndNode, reversing)
    local aiLeftMarker, aiRightMarker, aiBackMarker = WorkWidthUtil.getAIMarkers(object, nil, true)
    if not aiLeftMarker then return false, false end
    local _, _, dzLeft = localToLocal(aiLeftMarker, turnEndNode, 0, 0, 0)
    local _, _, dzRight = localToLocal(aiRightMarker, turnEndNode, 0, 0, 0)
    local _, _, dzBack = localToLocal(aiBackMarker, turnEndNode, 0, 0, 0)
    local loweringDistance
    if AIUtil.hasAIImplementWithSpecialization(self.vehicle, SowingMachine) then
        -- sowing machines are stopped while lowering, but leave a little reserve to allow for stopping
        -- TODO: rather slow down while approaching the lowering point
        loweringDistance = 0.5
    else
        -- others can be lowered without stopping so need to start lowering before we get to the turn end to be
        -- in the working position by the time we get to the first waypoint of the next row
        loweringDistance = self.vehicle.lastSpeed * self.loweringDurationMs + 0.5 -- vehicle.lastSpeed is in meters per millisecond
    end
    local dzFront = (dzLeft + dzRight) / 2
    self:debug('%s: dzLeft = %.1f, dzRight = %.1f, dzFront = %.1f, dzBack = %.1f, loweringDistance = %.1f, reversing %s',
            CpUtil.getName(object), dzLeft, dzRight, dzFront, dzBack, loweringDistance, tostring(reversing))
    -- TODO_22
    --local dz = self.vehicle.cp.settings.implementLowerTime:is(ImplementRaiseLowerTimeSetting.EARLY) and dzFront or dzBack
    local dz = dzFront
    if reversing then
        return dz < 0 , true
    else
        -- dz will be negative as we are behind the target node
        return dz > - loweringDistance, true
    end
end

--- Are all implements now aligned with the node? Can be used to find out if we are for instance aligned with the
--- turn end node direction in a question mark turn and can start reversing.
function AIDriveStrategyFieldWorkCourse:areAllImplementsAligned(node)
    -- see if the vehicle has AI markers -> has work areas (built-in implements like a mower or cotton harvester)
    local allAligned = self:isThisImplementAligned(self.vehicle, node)
    -- and then check all implements
    for _, implement in ipairs(AIUtil.getAllAIImplements(self.vehicle)) do
        -- _all_ implements must be aligned, hence the 'and'
        allAligned = allAligned and self:isThisImplementAligned(implement.object, node)
    end
    return allAligned
end

function AIDriveStrategyFieldWorkCourse:isThisImplementAligned(object, node)
    local aiFrontMarker, _, _ = WorkWidthUtil.getAIMarkers(object, nil, true)
    if not aiFrontMarker then return true end
    return TurnContext.isSameDirection(aiFrontMarker, node, 2)
end

-----------------------------------------------------------------------------------------------------------------------
--- Event listeners
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyFieldWorkCourse:onWaypointChange(ix, course)
    if self.state ~= self.states.TURNING and self.state ~= self.states.ON_CONNECTING_TRACK
            and self.course:isTurnStartAtIx(ix) then
        self:startTurn(ix)
    elseif self.state == self.states.ON_CONNECTING_TRACK then
        if not self.course:isOnConnectingTrack(ix) then
            -- reached the end of the connecting track, back to work
            self:debug('connecting track ended, back to work, first lowering implements.')
            self.state = self.states.WORKING
            self:lowerImplements()
        end
    elseif self.state == self.states.ON_ALIGNMENT_COURSE then
        if course:getDistanceToLastWaypoint(ix) < 5 then
            self:debug('alignment after connecting track ended, back to work, first lowering implements.')
            self.state = self.states.WORKING
            self:lowerImplements()
            self.ppc:setNormalLookaheadDistance()
            self:startRememberedCourse()
        end
    end
end

function AIDriveStrategyFieldWorkCourse:onWaypointPassed(ix, course)
    if self.state == self.states.WORKING then
        -- check for transition to connecting track, make sure we've been on it for a few waypoints already
        -- to avoid raising the implements too soon, this can be a problem with long implements not yet reached
        -- the end of the headland track while the tractor is already on the connecting track
        if self.course:isOnConnectingTrack(self.course:getCurrentWaypointIx()) and self.course:isOnConnectingTrack(ix) and self.course:isOnConnectingTrack(ix - 2) then
            -- reached a connecting track (done with the headland, move to the up/down row or vice versa),
            -- raise all implements while moving
            self:debug('on a connecting track now, raising implements.')
            self:raiseImplements()
            self.state = self.states.ON_CONNECTING_TRACK
        end
        if self.course:isOnConnectingTrack(ix) then
            -- passed a connecting track waypoint
            -- check transition from connecting track to the up/down rows
            -- we are close to the end of the connecting track, transition back to the up/down rows with
            -- an alignment course
            local d, firstUpDownWpIx = self.course:getDistanceToFirstUpDownRowWaypoint(ix)
            self:debug('up/down rows start in %d meters.', d or -1)
            -- (no alignment if there is a turn generated here)
            if d < 5 * self.turningRadius and firstUpDownWpIx and not self.course:isTurnEndAtIx(firstUpDownWpIx) then
                self:debug('End connecting track, start working on up/down rows (waypoint %d) with alignment course if needed.', firstUpDownWpIx)
                self:rememberCourse(course, firstUpDownWpIx)
                self.ppc:setShortLookaheadDistance()
                self:startCourse(AlignmentCourse(self.vehicle, self.vehicle:getAIDirectionNode(), self.turningRadius,
                        course, firstUpDownWpIx, math.min(self.frontMarkerDistance, 0)):getCourse(), 1)
                self.state = self.states.ON_ALIGNMENT_COURSE
            end
        end
    end
    if course:isLastWaypointIx(ix) then
        self:onLastWaypointPassed()
    end
end

--- Called when the last waypoint of a course is passed
function AIDriveStrategyFieldWorkCourse:onLastWaypointPassed()
    self:debug('Last waypoint of the course reached.')
    -- by default, stop the job
    self:finishFieldWork()
end

-----------------------------------------------------------------------------------------------------------------------
--- Turn
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyFieldWorkCourse:startTurn(ix)
    local fm, bm = self:getFrontAndBackMarkers()
    self.ppc:setShortLookaheadDistance()
    self.turnContext = TurnContext(self.course, ix, self.turnNodes, self:getWorkWidth(), fm, bm,
            self:getTurnEndSideOffset(), self:getTurnEndForwardOffset())
    if AITurn.canMakeKTurn(self.vehicle, self.turnContext, self.workWidth) then
        self.aiTurn = KTurn(self.vehicle, self, self.ppc, self.turnContext, self.workWidth)
    else
        self.aiTurn = CourseTurn(self.vehicle, self, self.ppc, self.turnContext, self.course, self.workWidth)
    end
    self.state = self.states.TURNING
end

-----------------------------------------------------------------------------------------------------------------------
--- State changes
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyFieldWorkCourse:finishFieldWork()
    self:debug('Course ended, stopping job.')
    self.vehicle:stopCurrentAIJob(AIMessageSuccessFinishedJob.new())
end

function AIDriveStrategyFieldWorkCourse:changeToFieldWork()
    self:debug('change to fieldwork')
    self.state = self.states.WAITING_FOR_LOWER_DELAYED
    self:lowerImplements(self.vehicle)
end

function AIDriveStrategyFieldWorkCourse:stopAndChangeToUnload()
    -- TODO_22 run unload/refill with the vanilla helper?
    if false and self.unloadRefillCourse and not self.heldForUnloadRefill then
        self:rememberWaypointToContinueFieldwork()
        self:debug('at least one tool is empty/full, aborting work at waypoint %d.', self.storage.continueFieldworkAtWaypoint or -1)
        self:changeToUnloadOrRefill()
        self:startCourseWithPathfinding(self.unloadRefillCourse, 1)
    else
        if self.vehicle.spec_autodrive and self.vehicle.cp.settings.autoDriveMode:useForUnloadOrRefill() then
            -- Switch to AutoDrive when enabled
            self:rememberWaypointToContinueFieldwork()
            self:stopWork()
            self:foldImplements()
            self.state = self.states.ON_UNLOAD_OR_REFILL_WITH_AUTODRIVE
            self:debug('passing the control to AutoDrive to run the unload/refill course.')
            --- Make sure trigger handler is disabled, while autodrive is driving.
            self.triggerHandler:disableFillTypeLoading()
            self.triggerHandler:disableFuelLoading()
            self.vehicle.spec_autodrive:StartDrivingWithPathFinder(self.vehicle, self.vehicle.ad.mapMarkerSelected, self.vehicle.ad.mapMarkerSelected_Unload, self, FieldworkAIDriver.onEndCourse, nil);
        else
            -- otherwise we'll
            self:changeToFieldworkUnloadOrRefill()
        end;
    end
end

-- switch back to fieldwork after the turn ended.
---@param ix number waypoint to resume fieldwork after
---@param forceIx boolean if true, fieldwork will resume exactly at ix. If false, we'll look for the next waypoint
--- in front of us.
function AIDriveStrategyFieldWorkCourse:resumeFieldworkAfterTurn(ix, forceIx)
    self.ppc:setNormalLookaheadDistance()
    self.state = self.states.WORKING
    self:lowerImplements()
    -- restore our own listeners for waypoint changes
    self.ppc:registerListeners(self, 'onWaypointPassed', 'onWaypointChange')
    local startIx = forceIx and ix or self.course:getNextFwdWaypointIxFromVehiclePosition(ix, self.vehicle:getAIDirectionNode(), 0)
    self:startCourse(self.course, startIx)
end

-----------------------------------------------------------------------------------------------------------------------
--- Static parameters (won't change while driving)
----------------------------------------------------------------------``-------------------------------------------------
function AIDriveStrategyFieldWorkCourse:setAllStaticParameters()
    self:setFrontAndBackMarkers()
    self.workWidth = WorkWidthUtil.getAutomaticWorkWidth(self.vehicle)
    self.turningRadius = AIUtil.getTurningRadius(self.vehicle)
    self.loweringDurationMs = AIUtil.findLoweringDurationMs(self.vehicle)
    self.reverser = AIReverseDriver(self.vehicle, self.ppc, self.course)
    if self.frontMarkerDistance < 0 then
        self:debug('extend course by %.1f m to make sure we do not miss anything when the course ends',
                -self.frontMarkerDistance)
        self.course:extend(-self.frontMarkerDistance)
    end
end

--- Find the foremost and rearmost AI marker
function AIDriveStrategyFieldWorkCourse:setFrontAndBackMarkers()
    local markers= {}
    local addMarkers = function(object, referenceNode)
        self:debug('Finding AI markers of %s', CpUtil.getName(object))
        local aiLeftMarker, aiRightMarker, aiBackMarker = WorkWidthUtil.getAIMarkers(object)
        if aiLeftMarker and aiBackMarker and aiRightMarker then
            local leftMarkerDistance = ImplementUtil.getDistanceToImplementNode(referenceNode, object, aiLeftMarker)
            local rightMarkerDistance = ImplementUtil.getDistanceToImplementNode(referenceNode, object, aiRightMarker)
            local backMarkerDistance = ImplementUtil.getDistanceToImplementNode(referenceNode, object, aiBackMarker)
            table.insert(markers, leftMarkerDistance)
            table.insert(markers, rightMarkerDistance)
            table.insert(markers, backMarkerDistance)
            self:debug('%s: left = %.1f, right = %.1f, back = %.1f', CpUtil.getName(object), leftMarkerDistance, rightMarkerDistance, backMarkerDistance)
        end
    end

    local referenceNode = self.vehicle:getAIDirectionNode()
    -- now go ahead and try to find the real markers
    -- work areas of the vehicle itself
    addMarkers(self.vehicle, referenceNode)
    -- and then the work areas of all the implements
    for _, implement in pairs( AIUtil.getAllAIImplements(self.vehicle)) do
        addMarkers(implement.object, referenceNode)
    end

    if #markers == 0 then
        -- make sure we always have a default front/back marker, placed on the direction node if nothing else found
        table.insert(markers, 0)
        table.insert(markers, 3)
    end
    -- now that we have all, find the foremost and the last
    self.frontMarkerDistance, self.backMarkerDistance = 0, 0
    local frontMarkerDistance, backMarkerDistance = -math.huge, math.huge
    for _, d in pairs(markers) do
        if d > frontMarkerDistance then
            frontMarkerDistance = d
        end
        if d < backMarkerDistance then
            backMarkerDistance = d
        end
    end
    self.frontMarkerDistance = frontMarkerDistance
    self.backMarkerDistance = backMarkerDistance
    self:debug('front marker: %.1f, back marker: %.1f', frontMarkerDistance, backMarkerDistance)
end

function AIDriveStrategyFieldWorkCourse:getFrontAndBackMarkers()
    if not self.frontMarkerDistance then
        self:setFrontAndBackMarkers()
    end
    return self.frontMarkerDistance, self.backMarkerDistance
end

function AIDriveStrategyFieldWorkCourse:getWorkWidth()
    return self.workWidth
end

-----------------------------------------------------------------------------------------------------------------------
--- Dynamic parameters (may change while driving)
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyFieldWorkCourse:getTurnEndSideOffset()
    return 0
end

function AIDriveStrategyFieldWorkCourse:getTurnEndForwardOffset()
    return 0
end

function AIDriveStrategyFieldWorkCourse:rememberWaypointToContinueFieldwork()
    self.storage.continueFieldworkAtWaypoint = self:getBestWaypointToContinueFieldwork()
end

function AIDriveStrategyFieldWorkCourse:getBestWaypointToContinueFieldwork()
    local bestKnownCurrentWpIx = self.ppc:getLastPassedWaypointIx() or self.ppc:getCurrentWaypointIx()
    -- after we return from a refill/unload, continue a bit before the point where we left to
    -- make sure not leaving any unworked patches
    local bestWpIx = self.course:getPreviousWaypointIxWithinDistance(bestKnownCurrentWpIx, 10)
    if bestWpIx then
        -- anything other than a turn start wp will work fine
        if self.course:isTurnStartAtIx(bestWpIx) then
            bestWpIx = bestWpIx - 1
        end
    else
        bestWpIx = bestKnownCurrentWpIx
    end
    self:debug('Best return to fieldwork waypoint is %d', bestWpIx)
    return bestWpIx
end

--- We already set the offsets on the course at start, this is to update those values
-- if the user changed them during the run or the AI driver wants to add an offset
function AIDriveStrategyFieldWorkCourse:updateFieldworkOffset()
    self.course:setOffset(
            self.vehicle:getCpSettingValue(CpVehicleSettings.toolOffsetX) + self.aiOffsetX + (self.tightTurnOffset or 0),
            self.vehicle:getCpSettingValue(CpVehicleSettings.toolOffsetZ) + self.aiOffsetZ)
end

-----------------------------------------------------------------------------------------------------------------------
--- Install into the stock helper
-----------------------------------------------------------------------------------------------------------------------
-- We replace the Giants AIDriveStrategyStraight with our AIDriveStrategyFieldWorkCourse  to take care of
-- field work.
function AIDriveStrategyFieldWorkCourse:updateAIFieldWorkerDriveStrategies()
    if not self:getFieldWorkCourse() then
        CpUtil.debugVehicle(CpDebug.DBG_MODE_4, self, 'has no CP field work course, run the built-in helper...')
        return
    end
    -- TODO: messing around with AIFieldWorker spec internals is not the best idea, should rather implement
    -- our own specialization
    for i, strategy in ipairs(self.spec_aiFieldWorker.driveStrategies) do
        if strategy.getDriveStraightData then
            self.spec_aiFieldWorker.driveStrategies[i]:delete()
            local cpDriveStrategy
            if AIUtil.getImplementOrVehicleWithSpecialization(self, Combine) then
                cpDriveStrategy = AIDriveStrategyCombineCourse.new()
                CpUtil.debugVehicle(CpDebug.DBG_MODE_4, self, 'Replacing fieldwork helper drive strategy with AIDriveStrategyCombineCourse')
            else
                cpDriveStrategy = AIDriveStrategyFieldWorkCourse.new()
                CpUtil.debugVehicle(CpDebug.DBG_MODE_4, self, 'Replacing fieldwork helper drive strategy with AIDriveStrategyFieldWorkCourse')
            end
            cpDriveStrategy:setAIVehicle(self)
            self.spec_aiFieldWorker.driveStrategies[i] = cpDriveStrategy
            return
        end
    end
end

AIFieldWorker.updateAIFieldWorkerDriveStrategies = Utils.appendedFunction(AIFieldWorker.updateAIFieldWorkerDriveStrategies,
        AIDriveStrategyFieldWorkCourse.updateAIFieldWorkerDriveStrategies)