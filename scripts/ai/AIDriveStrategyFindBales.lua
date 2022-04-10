--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
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
]]

--- Drive strategy to find bales on a field and collect or wrap them

---@class AIDriveStrategyFindBales : AIDriveStrategyCourse
AIDriveStrategyFindBales = {}
local AIDriveStrategyFindBales_mt = Class(AIDriveStrategyFindBales, AIDriveStrategyCourse)

AIDriveStrategyFindBales.myStates = {
    SEARCHING_FOR_NEXT_BALE = {},
    WAITING_FOR_PATHFINDER = {},
    DRIVING_TO_NEXT_BALE = {},
    APPROACHING_BALE = {},
    WORKING_ON_BALE = {},
    REVERSING_AFTER_PATHFINDER_FAILURE ={}
}

function AIDriveStrategyFindBales.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyFindBales_mt
    end
    local self = AIDriveStrategyCourse.new(customMt)
    AIDriveStrategyCourse.initStates(self, AIDriveStrategyFindBales.myStates)
    self.state = self.states.SEARCHING_FOR_NEXT_BALE
    -- cache for the nodes created by TurnContext
    self.turnNodes = {}
    -- course offsets dynamically set by the AI and added to all tool and other offsets
    self.aiOffsetX, self.aiOffsetZ = 0, 0
    self.debugChannel = CpDebug.DBG_FIELDWORK
    ---@type ImplementController[]
    self.controllers = {}
    self.bales = {}
    return self
end

function AIDriveStrategyFindBales:delete()
    AIDriveStrategyFindBales:superClass().delete(self)
    TurnContext.deleteNodes(self.turnNodes)
end

function AIDriveStrategyFindBales:startWithoutCourse()
    -- to always have a valid course (for the traffic conflict detector mainly)
    self.course = self:getStraightForwardCourse(25)
    self:startCourse(self.course, 1)

    self:info('Starting bale collect/wrap')

    for _, implement in pairs(self.vehicle:getAttachedImplements()) do
        self:info(' - %s', CpUtil.getName(implement.object))
    end

    self.bales = self:findBales()

    self:collectNextBale()
end

function AIDriveStrategyFindBales:collectNextBale()
    self.state = self.states.SEARCHING_FOR_NEXT_BALE
    if #self.bales > 0 then
        self:findPathToNextBale()
    else
        self:info('No bales found, scan the field once more before leaving for the unload course.')
        self.bales = self:findBales()
        if #self.bales > 0 then
            self:info('Found more bales, collecting them')
            self:findPathToNextBale()
            return
        end
        if self.baleLoader and self.baleLoaderController:hasBales() then 
            if self.baleLoaderController:canBeFolded() then
                --- Wait until the animations have finished and then make sure the bale loader can be send back with auto drive.
                self:info('There really are no more bales on the field')
                self.vehicle:stopCurrentAIJob(AIMessageErrorIsFull.new())
            end
        else
            self:info('There really are no more bales on the field')
            self.vehicle:stopCurrentAIJob(AIMessageSuccessFinishedJob.new())
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------
--- Implement handling
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyFindBales:initializeImplementControllers(vehicle)
    self.baleLoader = AIUtil.getImplementWithSpecialization(vehicle, BaleLoader)
    if self.baleLoader then
        self.baleLoaderController = BaleLoaderController(vehicle, self.baleLoader)
        self.baleLoaderController:setDriveStrategy(self)
        table.insert(self.controllers, self.baleLoaderController)
    end
    self.baleWrapper = AIUtil.getImplementWithSpecialization(vehicle, BaleWrapper)
    if self.baleWrapper then
        self.baleWrapperController = BaleWrapperController(vehicle, self.baleWrapper)
        self.baleWrapperController:setDriveStrategy(self)
        table.insert(self.controllers, self.baleWrapperController)
    end
    self:addImplementController(vehicle, MotorController, Motorized, {})
    self:addImplementController(vehicle, WearableController, Wearable, {})

end

-----------------------------------------------------------------------------------------------------------------------
--- Static parameters (won't change while driving)
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyFindBales:setAllStaticParameters()
    -- make sure we have a good turning radius set
    self.turningRadius = AIUtil.getTurningRadius(self.vehicle)
    -- Set the offset to 0, we'll take care of getting the grabber to the right place
    self.settings.toolOffsetX:setFloatValue(0)
    self.pathfinderFailureCount = 0
end

function AIDriveStrategyFindBales:setFieldPolygon(fieldPolygon)
    self.fieldPolygon = fieldPolygon
end

-----------------------------------------------------------------------------------------------------------------------
--- Bale finding
-----------------------------------------------------------------------------------------------------------------------
---@param bale BaleToCollect
function AIDriveStrategyFindBales:isBaleOnField(bale)
    local x, _, z = bale:getPosition()
    return CpMathUtil.isPointInPolygon(self.fieldPolygon, x, z) 
end

--- Find bales on field
---@return BaleToCollect[] list of bales found
function AIDriveStrategyFindBales:findBales()
    local balesFound = {}
    for _, object in pairs(g_currentMission.nodeToObject) do
        if BaleToCollect.isValidBale(object, self.baleWrapper, self.baleLoader) then
            local bale = BaleToCollect(object)
            -- if the bale has a mountObject it is already on the loader so ignore it
            if not object.mountObject and object:getOwnerFarmId() == self.vehicle:getOwnerFarmId() and
                    self:isBaleOnField(bale) then
                -- bales may have multiple nodes, using the object.id deduplicates the list
                balesFound[object.id] = bale
            end
        end
    end
    -- convert it to a normal array so lua can give us the number of entries
    local bales = {}
    for _, bale in pairs(balesFound) do
        table.insert(bales, bale)
    end
    self:debug('Found %d bales', #bales)
    return bales
end

---@return BaleToCollect, number closest bale and its distance
function AIDriveStrategyFindBales:findClosestBale(bales)
    local closestBale, minDistance, ix = nil, math.huge
    local invalidBales = 0
    for i, bale in ipairs(bales) do
        if bale:isStillValid() then
            local _, _, _, d = bale:getPositionInfoFromNode(self.vehicle:getAIDirectionNode())
            self:debug('%d. bale (%d, %s) in %.1f m', i, bale:getId(), bale:getBaleObject(), d)
            if d < self.turningRadius * 4 then
                -- if it is really close, check the length of the Dubins path
                -- as we may need to drive a loop first to get to it
                d = self:getDubinsPathLengthToBale(bale)
                self:debug('    Dubins length is %.1f m', d)
            end
            if d < minDistance then
                closestBale = bale
                minDistance = d
                ix = i
            end
        else
            --- When a bale gets wrapped it changes its identity and the node becomes invalid. This can happen
            --- when we pick up (and wrap) a bale other than the target bale, for example because there's another bale
            --- in the grabber's way. That is now wrapped but our bale list does not know about it so let's rescan the field
            self:debug('%d. bale (%d, %s) INVALID', i, bale:getId(), bale:getBaleObject())
            invalidBales = invalidBales + 1
            self:debug('Found an invalid bales, rescanning field', invalidBales)
            self.bales = self:findBales()
            -- return empty, next time this is called everything should be ok
            return
        end
    end
    return closestBale, minDistance, ix
end

function AIDriveStrategyFindBales:getDubinsPathLengthToBale(bale)
    local start = PathfinderUtil.getVehiclePositionAsState3D(self.vehicle)
    local goal = self:getBaleTarget(bale)
    local solution = PathfinderUtil.dubinsSolver:solve(start, goal, self.turningRadius)
    return solution:getLength(self.turningRadius)
end

function AIDriveStrategyFindBales:findPathToNextBale()
    if not self.bales then return end
    local bale, d, ix = self:findClosestBale(self.bales)
    if ix then
        if bale:isLoaded() then
            self:debug('Bale %d is already loaded, skipping', bale:getId())
            table.remove(self.bales, ix)
        elseif not self:isObstacleAhead() then
            self:startPathfindingToBale(bale)
            -- remove bale from list
            table.remove(self.bales, ix)
        else
            self:debug('There is an obstacle ahead, backing up a bit and retry')
            self:startReversing()
        end
    end
end

--- The trick here is to get a target direction at the bale
function AIDriveStrategyFindBales:getBaleTarget(bale)
    -- first figure out the direction at the goal, as the pathfinder needs that.
    -- for now, just use the direction from our location towards the bale
    local xb, zb, yRot, d = bale:getPositionInfoFromNode(self.vehicle:getAIDirectionNode())
    return State3D(xb, -zb, CourseGenerator.fromCpAngle(yRot))
end

-----------------------------------------------------------------------------------------------------------------------
--- Pathfinding
-----------------------------------------------------------------------------------------------------------------------
---@param bale BaleToCollect
function AIDriveStrategyFindBales:startPathfindingToBale(bale)
    if not self.pathfinder or not self.pathfinder:isActive() then
        self.pathfindingStartedAt = g_currentMission.time
        local safeDistanceFromBale = bale:getSafeDistance()
        local halfVehicleWidth = AIUtil.getWidth(self.vehicle) / 2
        local goal = self:getBaleTarget(bale)
        local configuredOffset = self:getConfiguredOffset()
        local offset = Vector(0, safeDistanceFromBale +
                (configuredOffset and configuredOffset or (halfVehicleWidth + 0.2)))
        goal:add(offset:rotate(goal.t))
        self:debug('Start pathfinding to next bale (%d), safe distance from bale %.1f, half vehicle width %.1f, configured offset %s',
                bale:getId(), safeDistanceFromBale, halfVehicleWidth,
                configuredOffset and string.format('%.1f', configuredOffset) or 'n/a')
        local done, path, goalNodeInvalid
        -- use no off-field penalty if we are on a custom field
        self.pathfinder, done, path, goalNodeInvalid =
        PathfinderUtil.startPathfindingFromVehicleToGoal(self.vehicle, goal, false, nil,
                {}, self.lastBale and {self.lastBale} or {}, nil, nil)
        if done then
            return self:onPathfindingDoneToNextBale(path, goalNodeInvalid)
        else
            self.state = self.states.WAITING_FOR_PATHFINDER
            self:setPathfindingDoneCallback(self, self.onPathfindingDoneToNextBale)
            return true
        end
    else
        self:debug('Pathfinder already active')
    end
end

function AIDriveStrategyFindBales:onPathfindingDoneToNextBale(path, goalNodeInvalid)
    if path and #path > 2 then
        self.pathfinderFailureCount = 0
        self:debug('Found path (%d waypoints, %d ms)', #path, g_currentMission.time - (self.pathfindingStartedAt or 0))
        self.fieldIdworkCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        self:startCourse(self.fieldIdworkCourse, 1)
        self:debug('Driving to next bale')
        self.state = self.states.DRIVING_TO_NEXT_BALE
        return true
    else
        self.pathfinderFailureCount = self.pathfinderFailureCount + 1
        if self.pathfinderFailureCount == 1 then
            self:debug('Finding path to next bale failed, trying next bale')
            self.state = self.states.SEARCHING_FOR_NEXT_BALE
        elseif self.pathfinderFailureCount == 2 then
            if self:isNearFieldEdge() then
                self.pathfinderFailureCount = 0
                self:debug('Finding path to next bale failed twice, we are close to the field edge, back up a bit and then try again')
                self:startReversing()
            else
                self:debug('Finding path to next bale failed twice, but we are not too close to the field edge, trying another bale')
                self.state = self.states.SEARCHING_FOR_NEXT_BALE
            end
        else
            self:info('Pathfinding failed three times, giving up')
            self.pathfinderFailureCount = 0
            self.vehicle:stopCurrentAIJob(AIMessageErrorUnknown.new())
        end
        return false
    end
end

function AIDriveStrategyFindBales:startReversing()
    self:startCourse(self:getStraightReverseCourse(10), 1)
    self.state = self.states.REVERSING_AFTER_PATHFINDER_FAILURE
end

function AIDriveStrategyFindBales:isObstacleAhead()
    -- TODO_22 check the proximity sensor first
    if self.forwardLookingProximitySensorPack then
        local d, vehicle, _, deg, dAvg = self.forwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
        if d < 1.2 * self.turningRadius then
            self:debug('Obstacle ahead at %.1f m', d)
            return true
        end
    end
    -- then a more thorough check, we want to ignore the last bale we worked on as that may lay around too close
    -- to the baler. This happens for example to the Andersen bale wrapper.
    self:debug('Check obstacles ahead, ignoring bale object %s', self.lastBale and self.lastBale or 'nil')
    local leftOk, rightOk, straightOk =
    PathfinderUtil.checkForObstaclesAhead(self.vehicle, self.turningRadius, self.lastBale and{self.lastBale})
    -- if at least one is ok, we are good to go.
    return not (leftOk or rightOk or straightOk)
end

function AIDriveStrategyFindBales:isNearFieldEdge()
    local x, _, z = localToWorld(self.vehicle:getAIDirectionNode(), 0, 0, 0)
    local vehicleIsOnField = CpFieldUtil.isOnField(x, z)
    x, _, z = localToWorld(self.vehicle:getAIDirectionNode(), 0, 0, 1.2 * self.turningRadius)
    local isFieldInFrontOfVehicle = CpFieldUtil.isOnFieldArea(x, z)
    self:debug('vehicle is on field: %s, field in front of vehicle: %s',
            tostring(vehicleIsOnField), tostring(isFieldInFrontOfVehicle))
    return vehicleIsOnField and not isFieldInFrontOfVehicle
end

-----------------------------------------------------------------------------------------------------------------------
--- Event listeners
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyFindBales:onWaypointPassed(ix, course)
    if course:isLastWaypointIx(ix) then
        if self.state == self.states.DRIVING_TO_NEXT_BALE then
            self:debug('last waypoint while driving to next bale reached')
            self:startApproachingBale()
        elseif self.state == self.states.WORKING_ON_BALE then
            self:debug('last waypoint on bale pickup reached, start collecting bales again')
            self:collectNextBale()
        elseif self.state == self.states.APPROACHING_BALE then
            self:debug('looks like somehow we missed a bale, rescanning field')
            self.bales = self:findBales()
            self:collectNextBale()
        elseif self.state == self.states.REVERSING_AFTER_PATHFINDER_FAILURE then
            self:debug('backed up after pathfinder failed, trying again')
            self.state = self.states.SEARCHING_FOR_NEXT_BALE
        end
    end
end

function AIDriveStrategyFindBales:startApproachingBale()
    self:debug('Approaching bale...')
    self:startCourse(self:getStraightForwardCourse(20), 1)
    self.state = self.states.APPROACHING_BALE
end

--- this the part doing the actual work on the field after/before all
--- implements are started/lowered etc.
function AIDriveStrategyFindBales:getDriveData(dt, vX, vY, vZ)
    self:updateLowFrequencyImplementControllers()
    if self.state == self.states.SEARCHING_FOR_NEXT_BALE then
        self:setMaxSpeed(0)
        self:debug('work: searching for next bale')
        self:collectNextBale()
    elseif self.state == self.states.WAITING_FOR_PATHFINDER then
        self:setMaxSpeed(0)
    elseif self.state == self.states.DRIVING_TO_NEXT_BALE then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    elseif self.state == self.states.APPROACHING_BALE then
        self:setMaxSpeed(self.settings.fieldWorkSpeed:getValue() / 2)
        self:approachBale()
    elseif self.state == self.states.WORKING_ON_BALE then
        self:workOnBale()
        self:setMaxSpeed(0)
    elseif self.state == self.states.REVERSING_AFTER_PATHFINDER_FAILURE then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
    end
    return AIDriveStrategyFindBales.superClass().getDriveData(self, dt, vX, vY, vZ)
end

function AIDriveStrategyFindBales:approachBale()
    if self.baleLoader then
        if self.baleLoaderController:isGrabbingBale() then
            self:debug('Start picking up bale')
            self.state = self.states.WORKING_ON_BALE
        end
    end
    if self.baleWrapper then
        self.baleWrapperController:handleBaleWrapper()
        if self.baleWrapperController:isWorking() then
            self:debug('Start wrapping bale')
            self.state = self.states.WORKING_ON_BALE
        end
    end
end

function AIDriveStrategyFindBales:workOnBale()
    if self.baleLoader then
        if not self.baleLoaderController:isGrabbingBale() then
            self:debug('Bale picked up, moving on to the next')
            self:collectNextBale()
        end
    end
    if self.baleWrapper then
        self.baleWrapperController:handleBaleWrapper()
        if not self.baleWrapperController:isWorking() then
            self.lastBale = self.baleWrapperController:getLastDroppedBale()
            self:debug('Bale wrapped, moving on to the next, last dropped bale %s', self.lastBale)
            self:collectNextBale()
        end
    end
end

function AIDriveStrategyFindBales:calculateTightTurnOffset()
    self.tightTurnOffset = 0
end

function AIDriveStrategyFindBales:getConfiguredOffset()
    if self.baleLoader then
        return g_vehicleConfigurations:get(self.baleLoader, 'baleCollectorOffset')
    elseif self.baleWrapper then
        return g_vehicleConfigurations:get(self.baleWrapper, 'baleCollectorOffset')
    end
end

function AIDriveStrategyFindBales:isAutoContinueAtWaitPointEnabled()
    return true
end

function AIDriveStrategyFindBales:isStoppingAtWaitPointAllowed()
    return true
end

--- Helper functions to generate a straight course
function AIDriveStrategyFindBales:getStraightForwardCourse(length)
    local l = length or 100
    return Course.createFromNode(self.vehicle, self.vehicle.rootNode, 0, 0, l, 5, false)
end

function AIDriveStrategyFindBales:getStraightReverseCourse(length)
    local lastTrailer = AIUtil.getLastAttachedImplement(self.vehicle)
    local l = length or 100
    return Course.createFromNode(self.vehicle, lastTrailer.rootNode or self.vehicle.rootNode, 0, 0, -l, -5, true)
end

function AIDriveStrategyFindBales:update()
    AIDriveStrategyFindBales:superClass().update(self)
    self:updateImplementControllers()
end