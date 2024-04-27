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
--- TODO: Separate bale wrapper and bale loaders.
---       Might be a good idea to have the bale loader strategy derive from the find bales(only wrapper) strategy.

---@class AIDriveStrategyFindBales : AIDriveStrategyCourse
AIDriveStrategyFindBales = CpObject(AIDriveStrategyCourse)

AIDriveStrategyFindBales.myStates = {
    SEARCHING_FOR_NEXT_BALE = {},
    WAITING_FOR_PATHFINDER = {},
    DRIVING_TO_NEXT_BALE = {},
    APPROACHING_BALE = {},
    WORKING_ON_BALE = {},
    REVERSING_AFTER_PATHFINDER_FAILURE = {},
    REVERSING_DUE_TO_OBSTACLE_AHEAD = {}
}

function AIDriveStrategyFindBales:init(task, job)
    AIDriveStrategyCourse.init(self, task, job)
    AIDriveStrategyCourse.initStates(self, AIDriveStrategyFindBales.myStates)
    self.state = self.states.INITIAL
    self.debugChannel = CpDebug.DBG_FIND_BALES
    self.bales = {}
end

function AIDriveStrategyFindBales:delete()
    AIDriveStrategyCourse.delete(self)
    g_baleToCollectManager:unlockBalesByDriver(self)
end

function AIDriveStrategyFindBales:getGeneratedCourse(jobParameters)
    return nil
end

function AIDriveStrategyFindBales:startWithoutCourse()
    -- to always have a valid course (for the traffic conflict detector mainly)
    self.course = Course.createStraightForwardCourse(self.vehicle, 25)
    self:startCourse(self.course, 1)

    self:info('Starting bale collect/wrap')

    for _, implement in pairs(self.vehicle:getAttachedImplements()) do
        self:info(' - %s', CpUtil.getName(implement.object))
    end
    self.vehicle:raiseAIEvent("onAIFieldWorkerStart", "onAIImplementStart")
    self:lowerImplements()
end

function AIDriveStrategyFindBales:collectNextBale()
    self.state = self.states.SEARCHING_FOR_NEXT_BALE
    if #self.bales > 0 then
        self:findPathToNextBale()
    else
        self:debug('No bales found, scan the field once more before leaving for the unload course.')
        local wrongWrapType
        self.bales, wrongWrapType = self:findBales()
        if #self.bales > 0 then
            self:debug('Found more bales, collecting them')
            self:findPathToNextBale()
            return
        end
        if self.baleLoader and self:hasBalesLoaded() and not (self.baleLoaderController and self.baleLoaderController:isChangingBaleSize()) then
            if self:isReadyToFoldImplements() then
                --- Wait until the animations have finished and then make sure the bale loader can be send back with auto drive.
                self:debug('There really are no more bales on the field')
                self.vehicle:stopCurrentAIJob(AIMessageErrorIsFull.new())
            end
        elseif self.baleLoader and wrongWrapType then 
            self:debug('Only bales with a wrong wrap type left.')
            self.vehicle:stopCurrentAIJob(AIMessageErrorWrongBaleWrapType.new())
        else
            self:debug('There really are no more bales on the field')
            self.vehicle:stopCurrentAIJob(AIMessageSuccessFinishedJob.new())
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------
--- Implement handling
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyFindBales:initializeImplementControllers(vehicle)
    --- The bale loader/wrapper variable is used to check if a bale loader or wrapper was found.
    self.baleWrapper, self.baleWrapperController = self:addImplementController(vehicle, BaleWrapperController, BaleWrapper, {}, nil)
    self.baleLoader, self.baleLoaderController = self:addImplementController(vehicle, BaleLoaderController, BaleLoader, {}, nil)
    self.baleLoader = self.baleLoader or self:addImplementController(vehicle, APalletAutoLoaderController, nil, {}, "spec_aPalletAutoLoader")
    self.baleLoader = self.baleLoader or self:addImplementController(vehicle, UniversalAutoloadController, nil, {}, "spec_universalAutoload")
    self:addImplementController(vehicle, MotorController, Motorized, {}, nil)
    self:addImplementController(vehicle, WearableController, Wearable, {}, nil)
    self:addImplementController(vehicle, FoldableController, Foldable, {})
end

--- Wait for the giants bale loader to finish grabbing the bale.
function AIDriveStrategyFindBales:isReadyToLoadNextBale()
    local isGrabbingBale = false
    for i, controller in pairs(self.controllers) do 
        if controller.isGrabbingBale then 
            isGrabbingBale = isGrabbingBale or controller:isGrabbingBale()
        end
    end
    return not isGrabbingBale
end

function AIDriveStrategyFindBales:isGrabbingBale()
    return not self:isReadyToLoadNextBale()
end

--- Have any bales been loaded?
function AIDriveStrategyFindBales:hasBalesLoaded()
    local hasBales = false
    for i, controller in pairs(self.controllers) do 
        if controller.hasBales then 
            hasBales = hasBales or controller:hasBales()
        end
    end
    return hasBales
end

--- Can all bale loaders be folded?
function AIDriveStrategyFindBales:isReadyToFoldImplements()
    local canBeFolded = true
    for i, controller in pairs(self.controllers) do 
        if controller.canBeFolded then 
            canBeFolded = canBeFolded and controller:canBeFolded()
        end
    end
    return canBeFolded
end

function AIDriveStrategyFindBales:areBaleLoadersFull()
    local allBaleLoadersFilled = self.baleLoader ~= nil
    for i, controller in pairs(self.controllers) do 
        if controller.isFull then 
            allBaleLoadersFilled = allBaleLoadersFilled and controller:isFull()
        end
    end
    return allBaleLoadersFilled
end

function AIDriveStrategyFindBales:getBalesToIgnore()
    local objectsToIgnore = {}
    if self.lastBale then
        return { self.lastBale }
    elseif self.baleLoaderController then 
        return self.baleLoaderController:getBalesToIgnore()
    else
        for i, controller in pairs(self.controllers) do 
            if controller.getBalesToIgnore then 
                for i, bale in pairs(controller:getBalesToIgnore()) do 
                    table.insert(objectsToIgnore, bale)
                end
               
            end
        end
    end
    return objectsToIgnore
end

-----------------------------------------------------------------------------------------------------------------------
--- Static parameters (won't change while driving)
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyFindBales:setAllStaticParameters()
    -- make sure we have a good turning radius set
    self.turningRadius = AIUtil.getTurningRadius(self.vehicle, true)
    -- Set the offset to 0, we'll take care of getting the grabber to the right place
    self.settings.toolOffsetX:setFloatValue(0)
    self.reverser = AIReverseDriver(self.vehicle, self.ppc)
    -- list of bales we tried (or in the process of trying) to find path for
    self.balesTried = {}
    -- when everything fails, reverse and try again. This is reset only when a pathfinding succeeds to avoid
    -- backing up forever
    self.numBalesLeftOver = 0
end

function AIDriveStrategyFindBales:setFieldPolygon(fieldPolygon)
    self.fieldPolygon = fieldPolygon
end

--- Bale wrap type for the bale loader. 
function AIDriveStrategyFindBales:setAIVehicle(vehicle, jobParameters)
    AIDriveStrategyCourse.setAIVehicle(self, vehicle, jobParameters)
    self.baleWrapType = jobParameters.baleWrapType:getValue()
    self:debug("Bale type selected: %s", tostring(self.baleWrapType))
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
    local balesFound, baleWithWrongWrapType = {}, false
    for _, object in pairs(g_baleToCollectManager:getBales()) do
        local isValid, wrongWrapType = BaleToCollect.isValidBale(object, 
                self.baleWrapper, self.baleLoader, self.baleWrapType)
        if isValid and g_baleToCollectManager:isValidBale(object) then
            local bale = BaleToCollect(object)
            -- if the bale has a mountObject it is already on the loader so ignore it
            if not object.mountObject and object:getOwnerFarmId() == self.vehicle:getOwnerFarmId() and
                    self:isBaleOnField(bale) then
                -- bales may .have multiple nodes, using the object.id deduplicates the list
                balesFound[object.id] = bale
            end
        end
        baleWithWrongWrapType = baleWithWrongWrapType or wrongWrapType
    end
    local bales = {}
    for _, bale in pairs(balesFound) do
        table.insert(bales, bale)
    end
    self:debug('Found %d bales.', #bales)
    --- Saves the number of bales found for the cp status.
    self.numBalesLeftOver = #bales
    return bales, baleWithWrongWrapType
end

---@param bales table[]
---@param balesToIgnore BaleToCollect[]|nil exclude bales on this list from the results
---@return BaleToCollect|nil closest bale
---@return number|nil distance to the closest bale
---@return number|nil index of the bale
function AIDriveStrategyFindBales:findClosestBale(bales, balesToIgnore)
    if not bales then 
        return
    end
    local closestBale, minDistance, ix = nil, math.huge, 1
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
                if not table.hasElement(balesToIgnore or {}, bale) then
                    -- bale is not on the list of bales to ignore
                    closestBale = bale
                    minDistance = d
                    ix = i
                else
                    self:debug('    IGNORED')
                end
            end
        else
            --- When a bale gets wrapped it changes its identity and the node becomes invalid. This can happen
            --- when we pick up (and wrap) a bale other than the target bale, for example because there's another bale
            --- in the grabber's way. That is now wrapped but our bale list does not know about it so let's rescan the field
            self:debug('%d. bale (%d, %s) INVALID', i, bale:getId(), bale:getBaleObject())
            invalidBales = invalidBales + 1
            self:debug('Found invalid bale(s), rescanning field', invalidBales)
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
    if self.bumpedIntoAnotherBale then
        self.bumpedIntoAnotherBale = false
        self:debug("Bumped into a bale other than the target on the way, rescanning.")
        self:findBales()
    end
    local bale, d, ix = self:findClosestBale(self.bales)
    if bale then
        if bale:isLoaded() then
            self:debug('Bale %d is already loaded, skipping', bale:getId())
            table.remove(self.bales, ix)
        else
            self:startPathfindingToBale(bale)
            -- remove bale from list
            table.remove(self.bales, ix)
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

--- Pathfinding has finished
---@param controller PathfinderController
---@param success boolean
---@param course Course|nil
---@param goalNodeInvalid boolean|nil
function AIDriveStrategyFindBales:onPathfindingFinished(controller, 
    success, course, goalNodeInvalid)
    if self.state == self.states.DRIVING_TO_NEXT_BALE then
        if success then
            self.balesTried = {}
            self:startCourse(course, 1)
        else
            g_baleToCollectManager:unlockBalesByDriver(self)
            if #self.balesTried < 5 and #self.bales > #self.balesTried then
                if goalNodeInvalid then
                    -- there may be another bale too close to the previous one
                    self:debug('Finding path to next bale failed, goal node invalid.')
                    self:retryPathfindingWithAnotherBale()
                elseif self:isNearFieldEdge() then
                    self.balesTried = {}
                    self:debug('Finding path to next bale failed, we are close to the field edge, back up a bit and then try again')
                    self:startReversing(self.states.REVERSING_AFTER_PATHFINDER_FAILURE)
                else
                    self:debug('Finding path to next bale failed, but we are not too close to the field edge')
                    self:retryPathfindingWithAnotherBale()
                end
            else
                self.balesTried = {}
                self:info('Pathfinding failed five times, giving up')
                self.vehicle:stopCurrentAIJob(AIMessageCpErrorNoPathFound.new())
            end
        end
    end
end

--- After pathfinding failed, retry with another bale
function AIDriveStrategyFindBales:retryPathfindingWithAnotherBale()
    self:debug("Retrying with another bale.")
    local bale, d, ix = self:findClosestBale(self.bales, self.balesTried)
    if bale then
        self:startPathfindingToBale(bale)
    else
        self.balesTried = {}
        self:debug("No valid bale found on retry!")
        self.vehicle:stopCurrentAIJob(AIMessageCpErrorNoPathFound.new())
    end
end

function AIDriveStrategyFindBales:getPathfinderBaleTargetAsGoalNode(bale)
    local safeDistanceFromBale = bale:getSafeDistance()
    local halfVehicleWidth = AIUtil.getWidth(self.vehicle) / 2
    local goal = self:getBaleTarget(bale)
    local configuredOffset = self:getConfiguredOffset()
    local offset = Vector(0, safeDistanceFromBale + configuredOffset)
    goal:add(offset:rotate(goal.t))
    self:debug('Start pathfinding to next bale (%d), safe distance from bale %.1f, half vehicle width %.1f, configured offset %s',
        bale:getId(), safeDistanceFromBale, halfVehicleWidth,
        configuredOffset and string.format('%.1f', configuredOffset) or 'n/a')
    return goal
end

---@param bale BaleToCollect
function AIDriveStrategyFindBales:startPathfindingToBale(bale)
    self.state = self.states.DRIVING_TO_NEXT_BALE
    g_baleToCollectManager:lockBale(bale:getBaleObject(), self)
    local context = PathfinderContext(self.vehicle):objectsToIgnore(self:getBalesToIgnore())
    context:allowReverse(false):maxFruitPercent(self.settings.avoidFruit:getValue() and 10 or math.huge)
    table.insert(self.balesTried, bale)
    self.pathfinderController:registerListeners(self, self.onPathfindingFinished, nil,
            self.onPathfindingObstacleAtStart)
    self.pathfinderController:findPathToGoal(context, self:getPathfinderBaleTargetAsGoalNode(bale))
end

function AIDriveStrategyFindBales:onPathfindingObstacleAtStart(controller, lastContext, maxDistance, trailerCollisionsOnly)
    g_baleToCollectManager:unlockBalesByDriver(self)
    self.balesTried = {}
    self:debug('Pathfinding detected obstacle at start, back up and retry')
    self:startReversing(self.states.REVERSING_DUE_TO_OBSTACLE_AHEAD)
end

function AIDriveStrategyFindBales:startReversing(state)
    self.state = state
    self:startCourse(Course.createStraightReverseCourse(self.vehicle, 10), 1)
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
        elseif self.state == self.states.REVERSING_DUE_TO_OBSTACLE_AHEAD then
            self:debug('backed due to obstacle, trying again')
            self.state = self.states.SEARCHING_FOR_NEXT_BALE
        end
    end
end

function AIDriveStrategyFindBales:startApproachingBale()
    self:debug('Approaching bale...')
    self:startCourse(Course.createStraightForwardCourse(self.vehicle, 20), 1)
    self.state = self.states.APPROACHING_BALE
end

--- this the part doing the actual work on the field after/before all
--- implements are started/lowered etc.
function AIDriveStrategyFindBales:getDriveData(dt, vX, vY, vZ)
    self:updateLowFrequencyImplementControllers()
    self:updateLowFrequencyPathfinder()
    if self.state == self.states.INITIAL then
        if self:getCanContinueWork() then 
            self.state = self.states.SEARCHING_FOR_NEXT_BALE
        else
            --- Waiting until the unfolding has finished.
            if self.bales == nil then 
                --- Makes sure the hud bale counter already gets updated
                self.bales = self:findBales() 
            end
            self:setMaxSpeed(0)
        end
    elseif self.state == self.states.SEARCHING_FOR_NEXT_BALE then
        self:setMaxSpeed(0)
        self:debug('work: searching for next bale')
        self:collectNextBale()
    elseif self.state == self.states.WAITING_FOR_PATHFINDER then
        self:setMaxSpeed(0)
    elseif self.state == self.states.DRIVING_TO_NEXT_BALE then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
        if not self.bumpedIntoAnotherBale and self:isGrabbingBale() then
            -- we are not at the bale yet but grabbing something, likely bumped into another bale
            self.bumpedIntoAnotherBale = true
        end
    elseif self.state == self.states.APPROACHING_BALE then
        self:setMaxSpeed(self.settings.fieldWorkSpeed:getValue() / 2)
        self:approachBale()
    elseif self.state == self.states.WORKING_ON_BALE then
        self:workOnBale()
        self:setMaxSpeed(0)
    elseif self.state == self.states.REVERSING_AFTER_PATHFINDER_FAILURE then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
    elseif self.state == self.states.REVERSING_DUE_TO_OBSTACLE_AHEAD then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
    end

    local moveForwards = not self.ppc:isReversing()
    local gx, gz
    if not moveForwards then
        local maxSpeed
        gx, gz, maxSpeed = self:getReverseDriveData()
        self:setMaxSpeed(maxSpeed)
    else
        gx, _, gz = self.ppc:getGoalPointPosition()
    end

    return gx, gz, moveForwards, self.maxSpeed, 100
end

function AIDriveStrategyFindBales:approachBale()
    if self.baleLoader then
        if not self:isReadyToLoadNextBale() then
            self:debug('Start picking up bale')
            self.state = self.states.WORKING_ON_BALE
            self.numBalesLeftOver = math.max(self.numBalesLeftOver-1, 0)
        end
    end
    if self.baleWrapper then
        self.baleWrapperController:handleBaleWrapper()
        if self.baleWrapperController:isWorking() then
            self:debug('Start wrapping bale')
            self.state = self.states.WORKING_ON_BALE
            self.numBalesLeftOver = math.max(self.numBalesLeftOver-1, 0)
        end
    end
end

function AIDriveStrategyFindBales:workOnBale()
    if self.baleLoader then
        if self:isReadyToLoadNextBale() then
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
    return self.settings.baleCollectorOffset:getValue()
end

function AIDriveStrategyFindBales:isAutoContinueAtWaitPointEnabled()
    return true
end

function AIDriveStrategyFindBales:isStoppingAtWaitPointAllowed()
    return true
end

function AIDriveStrategyFindBales:update(dt)
    AIDriveStrategyCourse.update(self, dt)
    self:updateImplementControllers(dt)

    if CpDebug:isChannelActive(self.debugChannel, self.vehicle) then
        if self.course then
            self.course:draw()
        elseif self.ppc:getCourse() then
            self.ppc:getCourse():draw()
        end
    end

    if self:areBaleLoadersFull() and self:isReadyToFoldImplements() then
        self:debug('Bale loader is full, stopping job.')
        self.vehicle:stopCurrentAIJob(AIMessageErrorIsFull.new())
    end

    --- Ignores the loaded auto loader bales.
    --- TODO: Maybe add a delay here?
    local loadedBales = self:getBalesToIgnore()
    for _, bale in pairs(loadedBales) do 
        --- Makes sure these loaded bales from an autoload trailer,
        --- can't be selected as a target by another bale loader.
        g_baleToCollectManager:temporarilyLeaseBale(bale)
    end
end

---@param status CpStatus
function AIDriveStrategyFindBales:updateCpStatus(status)
    status:setBaleData(self.numBalesLeftOver)
end