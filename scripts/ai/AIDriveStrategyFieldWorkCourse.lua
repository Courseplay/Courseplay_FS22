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
    UNLOAD_OR_REFILL_ON_FIELD = {},
    WAITING_FOR_UNLOAD_OR_REFILL ={}, -- while on the field
    ON_CONNECTING_TRACK = {},
    WAITING_FOR_LOWER = {},
    WAITING_FOR_LOWER_DELAYED = {},
    WAITING_FOR_STOP = {},
    WAITING_FOR_WEATHER = {},
    TURNING = {},
    TEMPORARY = {},
}

function AIDriveStrategyFieldWorkCourse.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyFieldWorkCourse_mt
    end
    local self = AIDriveStrategyCourse.new(customMt)
    AIDriveStrategyCourse.initStates(self, AIDriveStrategyFieldWorkCourse.myStates)
    self.state = self.states.INITIAL
    -- cache for the nodes created by TurnContext
    self.turnNodes = {}
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
    if self.state == self.states.TURNING and self.turnContext then
        self.turnContext:drawDebug()
    end
end

--- This is the interface to the Giant's AIFieldWorker specialization, telling it the direction and speed
function AIDriveStrategyFieldWorkCourse:getDriveData(dt, vX, vY, vZ)
    local moveForwards = not self.ppc:isReversing()
    local gx, _, gz = self.ppc:getGoalPointPosition()
    local maxSpeed = self.vehicle:getSpeedLimit(true)

    if self.state == self.states.INITIAL then
        self:lowerImplements()
        self.state = self.states.WAITING_FOR_LOWER
    elseif self.state == self.states.WAITING_FOR_LOWER then
        if self.vehicle:getCanAIFieldWorkerContinueWork() then
            self:debug('all tools ready, start working')
            self.state = self.states.WORKING
        else
            self:debugSparse('waiting for all tools to lower')
            maxSpeed = 0
        end
    elseif self.state == self.states.WAITING_FOR_LOWER_DELAYED then
        -- getCanAIVehicleContinueWork() seems to return false when the implement being lowered/raised (moving) but
        -- true otherwise. Due to some timing issues it may return true just after we started lowering it, so this
        -- here delays the check for another cycle.
        self.state = self.states.WAITING_FOR_LOWER
        maxSpeed = 0
    elseif self.state == self.states.WORKING then
        maxSpeed = self.vehicle:getSpeedLimit(true)
    elseif self.state == self.states.TURNING then
        maxSpeed = self.aiTurn:getDriveData()
    end
    self:setAITarget()
    self:debugSparse('%.1f/%.1f', gx, gz)
    return gx, gz, moveForwards, maxSpeed, 100
end

-- Seems like the Giants AIDriveStrategyCollision needs these variables on the vehicle to be set
-- to calculate an accurate path prediction
function AIDriveStrategyFieldWorkCourse:setAITarget()
    local dx, _, dz = localDirectionToWorld(self.vehicle:getAIDirectionNode(), 0, 0, 1)
    local length = MathUtil.vector2Length(dx, dz)
    dx = dx / length
    dz = dz / length
    self.vehicle.aiDriveDirection = { dx, dz }
    local x, _, z = getWorldTranslation(self.vehicle:getAIDirectionNode())
    self.vehicle.aiDriveTarget = { x, z }
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
        self.state = self.states.WAITING_FOR_LOWER_DELAYED
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
function AIDriveStrategyFieldWorkCourse:onWaypointChange(ix)
    if self.state ~= self.states.TURNING and self.course:isTurnStartAtIx(ix) then
        self:startTurn(ix)
    end
end

function AIDriveStrategyFieldWorkCourse:onWaypointPassed(ix)

end

-----------------------------------------------------------------------------------------------------------------------
--- Turn
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyFieldWorkCourse:startTurn(ix)
    local fm, bm = self:getFrontAndBackMarkers()
    self.ppc:setShortLookaheadDistance()
    self.turnContext = TurnContext(self.course, ix, self.turnNodes, self:getWorkWidth(), fm, bm,
            self:getTurnEndSideOffset(), self:getTurnEndForwardOffset())
    self.aiTurn = CourseTurn(self.vehicle, self, self.ppc, self.turnContext, self.course, self.workWidth)
    self.state = self.states.TURNING
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
end

--- Find the foremost and rearmost AI marker
function AIDriveStrategyFieldWorkCourse:setFrontAndBackMarkers()
    local markers= {}
    local addMarkers = function(object, referenceNode)
        self:debug('Finding AI markers of %s', CpUtil.getName(object))
        local aiLeftMarker, aiRightMarker, aiBackMarker = WorkWidthUtil.getAIMarkers(object)
        if aiLeftMarker and aiBackMarker and aiRightMarker then
            local _, _, leftMarkerDistance = localToLocal(aiLeftMarker, referenceNode, 0, 0, 0)
            local _, _, rightMarkerDistance = localToLocal(aiRightMarker, referenceNode, 0, 0, 0)
            local _, _, backMarkerDistance = localToLocal(aiBackMarker, referenceNode, 0, 0, 0)
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

-----------------------------------------------------------------------------------------------------------------------
--- Install into the stock helper
-----------------------------------------------------------------------------------------------------------------------
-- We replace the Giants AIDriveStrategyStraight with our AIDriveStrategyFieldWorkCourse  to take care of
-- field work.
function AIDriveStrategyFieldWorkCourse:updateAIFieldWorkerDriveStrategies()
    local driveStrategyFollowFieldWorkCourse = AIDriveStrategyFieldWorkCourse.new()
    driveStrategyFollowFieldWorkCourse:setAIVehicle(self)
    -- TODO: messing around with AIFieldWorker spec internals is not the best idea, should rather implement
    -- our own specialization
    for i, strategy in ipairs(self.spec_aiFieldWorker.driveStrategies) do
        if strategy.getDriveStraightData then
            CpUtil.debugVehicle(CpDebug.DBG_MODE_4, self, 'Replacing fieldwork helper drive strategy with Courseplay drive strategy')
            self.spec_aiFieldWorker.driveStrategies[i]:delete()
            self.spec_aiFieldWorker.driveStrategies[i] = driveStrategyFollowFieldWorkCourse
            return
        end
    end
end

AIFieldWorker.updateAIFieldWorkerDriveStrategies = Utils.appendedFunction(AIFieldWorker.updateAIFieldWorkerDriveStrategies,
        AIDriveStrategyFieldWorkCourse.updateAIFieldWorkerDriveStrategies)