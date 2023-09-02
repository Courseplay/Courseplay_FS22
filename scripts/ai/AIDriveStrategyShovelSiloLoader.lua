--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2022 

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

---@class AIDriveStrategyShovelSiloLoader : AIDriveStrategyCourse
---@field shovelController ShovelController
AIDriveStrategyShovelSiloLoader = {}
local AIDriveStrategyShovelSiloLoader_mt = Class(AIDriveStrategyShovelSiloLoader, AIDriveStrategyCourse)

----------------------------------------------------------------
--- State properties
----------------------------------------------------------------
--[[
    shovelPosition : number (1-4)
    shovelMovingSpeed : number|nil speed while the shovel/ front loader is moving
]]


----------------------------------------------------------------
--- States
----------------------------------------------------------------

AIDriveStrategyShovelSiloLoader.myStates = {
    DRIVING_ALIGNMENT_COURSE = {shovelPosition = ShovelController.POSITIONS.TRANSPORT},
    
    DRIVING_INTO_SILO = {shovelPosition = ShovelController.POSITIONS.LOADING, shovelMovingSpeed = 0},
    DRIVING_OUT_OF_SILO = {shovelPosition = ShovelController.POSITIONS.TRANSPORT},

    WAITING_FOR_TRAILER = {shovelPosition = ShovelController.POSITIONS.TRANSPORT},
    
    DRIVING_TO_UNLOAD_POSITION = {shovelPosition = ShovelController.POSITIONS.TRANSPORT},
    DRIVING_TO_UNLOAD_TRAILER = {shovelPosition = ShovelController.POSITIONS.TRANSPORT},
    DRIVING_TO_UNLOAD = {shovelPosition = ShovelController.POSITIONS.PRE_UNLOADING, shovelMovingSpeed = 0},
    UNLOADING = {shovelPosition = ShovelController.POSITIONS.UNLOADING, shovelMovingSpeed = 0},
    REVERSING_AWAY_FROM_UNLOAD = {shovelPosition = ShovelController.POSITIONS.PRE_UNLOADING, shovelMovingSpeed = 0},
}

AIDriveStrategyShovelSiloLoader.maxValidTrailerDistanceToSiloFront = 30
AIDriveStrategyShovelSiloLoader.searchForTrailerDelaySec = 30 
AIDriveStrategyShovelSiloLoader.distShovelTrailerPreUnload = 7
AIDriveStrategyShovelSiloLoader.distShovelUnloadStationPreUnload = 8

function AIDriveStrategyShovelSiloLoader.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyShovelSiloLoader_mt
    end
    local self = AIDriveStrategyCourse.new(customMt)
    AIDriveStrategyCourse.initStates(self, AIDriveStrategyShovelSiloLoader.myStates)
    self.state = self.states.INITIAL
    self.debugChannel = CpDebug.DBG_SILO
    return self
end

function AIDriveStrategyShovelSiloLoader:delete()
    AIDriveStrategyShovelSiloLoader:superClass().delete(self)
    if self.siloController then 
        self.siloController:delete()
        self.siloController = nil
    end
    CpUtil.destroyNode(self.heapNode)
    CpUtil.destroyNode(self.unloadPositionNode)
    CpUtil.destroyNode(self.siloFrontNode)
end

function AIDriveStrategyShovelSiloLoader:getGeneratedCourse(jobParameters)
    return nil
end

---@param bunkerSilo CpBunkerSilo
---@param heapSilo CpHeapBunkerSilo
function AIDriveStrategyShovelSiloLoader:setSiloAndHeap(bunkerSilo, heapSilo)
    self.bunkerSilo = bunkerSilo
    self.heapSilo = heapSilo
end

---@param unloadTrigger CpTrigger
function AIDriveStrategyShovelSiloLoader:setUnloadTrigger(unloadTrigger)
    self.unloadTrigger = unloadTrigger
end

function AIDriveStrategyShovelSiloLoader:startWithoutCourse(jobParameters)
 
    -- to always have a valid course (for the traffic conflict detector mainly)
    self.course = Course.createStraightForwardCourse(self.vehicle, 25)
    self:startCourse(self.course, 1)

    self.jobParameters = jobParameters
    self.unloadPositionNode = CpUtil.createNode("unloadPositionNode", 0, 0, 0) 

    --- Is the unload target a trailer?
    self.isUnloadingAtTrailerActive = jobParameters.unloadAt:getValue() == CpSiloLoaderJobParameters.UNLOAD_TRAILER
    if not self.isUnloadingAtTrailerActive then 
        self:debug("Starting shovel silo to unload into unload trigger.")
        --- Uses the exactFillRootNode from the trigger 
        --- and the direction of the unload position marker
        --- to place the unload position node slightly in front.
        local x, y, z = getWorldTranslation(self.unloadTrigger:getFillUnitExactFillRootNode())
        setTranslation(self.unloadPositionNode, x, y, z)
        local position = jobParameters.unloadPosition
        local dirX, dirZ = position:getDirection()
        setDirection(self.unloadPositionNode, dirX, 0, dirZ, 0, 0, 1)
        local dx, dy, dz = localToWorld(self.unloadPositionNode, 0, 0, -math.max(self.distShovelUnloadStationPreUnload, self.turningRadius))
        setTranslation(self.unloadPositionNode, dx, dy, dz)
    else 
        self:debug("Starting shovel silo to unload into trailer.")
    end
    if self.bunkerSilo ~= nil then 
        self:debug("Bunker silo was found.")
        self.silo = self.bunkerSilo
    else 
        self:debug("Heap was found.")
        self.silo = self.heapSilo
    end

    local cx, cz = self.silo:getFrontCenter()
    local dirX, dirZ = self.silo:getLengthDirection()
    local yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
    self.siloFrontNode = CpUtil.createNode("siloFrontNode", cx, cz, yRot)
    self.siloAreaToAvoid = PathfinderUtil.NodeArea(self.siloFrontNode, -self.silo:getWidth()/2 - 3, 
        -3, self.silo:getWidth() + 6, self.silo:getLength() + 6)

    self.siloController = CpBunkerSiloLoaderController(self.silo, self.vehicle, self)
end

-----------------------------------------------------------------------------------------------------------------------
--- Implement handling
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyShovelSiloLoader:initializeImplementControllers(vehicle)
    self:addImplementController(vehicle, MotorController, Motorized, {}, nil)
    self:addImplementController(vehicle, WearableController, Wearable, {}, nil)
    ---@type table, ShovelController
    self.shovelImplement, self.shovelController = self:addImplementController(vehicle, ShovelController, Shovel, {}, nil)

end

--- Fuel save only allowed when no trailer is there to unload into.
function AIDriveStrategyShovelSiloLoader:isFuelSaveAllowed()
    return self.state == self.states.WAITING_FOR_TRAILER
end

-----------------------------------------------------------------------------------------------------------------------
--- Static parameters (won't change while driving)
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyShovelSiloLoader:setAllStaticParameters()
    self.reverser = AIReverseDriver(self.vehicle, self.ppc)
    self.proximityController = ProximityController(self.vehicle, self:getWorkWidth())
    self.proximityController:registerIgnoreObjectCallback(self, self.ignoreProximityObject)
    Markers.setMarkerNodes(self.vehicle)
    self.frontMarkerNode, self.backMarkerNode, self.frontMarkerDistance, self.backMarkerDistance = 
        Markers.getMarkerNodes(self.vehicle)
    self.siloEndProximitySensor = SingleForwardLookingProximitySensorPack(self.vehicle, self.shovelController:getShovelNode(), 5, 1)
    self.heapNode = CpUtil.createNode("heapNode", 0, 0, 0, nil)
    self.lastTrailerSearch = 0
end

-----------------------------------------------------------------------------------------------------------------------
--- Event listeners
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyShovelSiloLoader:onWaypointPassed(ix, course)
    if course:isLastWaypointIx(ix) then
        if self.state == self.states.DRIVING_ALIGNMENT_COURSE then 
            local course = self:getRememberedCourseAndIx()
            self:startCourse(course, 1)
            self:setNewState(self.states.DRIVING_INTO_SILO)
        elseif self.state == self.states.DRIVING_INTO_SILO then
            self:startDrivingOutOfSilo()
        elseif self.state == self.states.DRIVING_OUT_OF_SILO then
            if self.isUnloadingAtTrailerActive then
                self:setNewState(self.states.WAITING_FOR_TRAILER)
            else 
                self:startPathfindingToUnloadPosition()
            end
        elseif self.state == self.states.DRIVING_TO_UNLOAD_TRAILER then
            self:approachTrailerForUnloading()
        elseif self.state == self.states.DRIVING_TO_UNLOAD_POSITION then
           self:approachUnloadStationForUnloading()
        elseif self.state == self.states.DRIVING_TO_UNLOAD then
            self:setNewState(self.states.UNLOADING)
        elseif self.state == self.states.REVERSING_AWAY_FROM_UNLOAD then
            if self.shovelController:isEmpty() then
                self:startDrivingToSilo()
            else 
                self:setNewState(self.states.WAITING_FOR_TRAILER)
            end
        end
    end
end

--- this the part doing the actual work on the field after/before all
--- implements are started/lowered etc.
function AIDriveStrategyShovelSiloLoader:getDriveData(dt, vX, vY, vZ)
    self:updateLowFrequencyImplementControllers()
    local moveForwards = not self.ppc:isReversing()
    local gx, gz, _
    if not moveForwards then
        local maxSpeed
        gx, gz, maxSpeed = self:getReverseDriveData()
        self:setMaxSpeed(maxSpeed)
    else
        gx, _, gz = self.ppc:getGoalPointPosition()
    end
    if self.state == self.states.INITIAL then
        if self.silo:getTotalFillLevel() <=0 then 
            self:debug("Stopping the driver, as the silo is empty.")
            self.vehicle:stopCurrentAIJob(AIMessageSuccessFinishedJob.new())
            return
        end
        if self.shovelController:isFull() then
            if self.isUnloadingAtTrailerActive then 
                self:setNewState(self.states.WAITING_FOR_TRAILER)
            else 
                self:startPathfindingToUnloadPosition()
            end
        else
            self:startDrivingToSilo()
        end
        self:setMaxSpeed(0)
    elseif self.state == self.states.DRIVING_ALIGNMENT_COURSE then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    elseif self.state == self.states.WAITING_FOR_PATHFINDER then 
        self:setMaxSpeed(0)
    elseif self.state == self.states.DRIVING_INTO_SILO then 
        self:setMaxSpeed(self.settings.bunkerSiloSpeed:getValue())

        local _, _, closestObject = self.siloEndProximitySensor:getClosestObjectDistanceAndRootVehicle()
        local isEndReached, maxSpeed = self.siloController:isEndReached(self.shovelController:getShovelNode(), 0)
        if self.silo:isTheSameSilo(closestObject) or isEndReached then
            self:debug("End wall detected or bunker silo end is reached.")
            self:startDrivingOutOfSilo()
        end
        if self.shovelController:isFull() then 
            self:debug("Shovel is full, starting to drive out of the silo.")
            self:startDrivingOutOfSilo()
        end
    elseif self.state == self.states.DRIVING_OUT_OF_SILO then 
        self:setMaxSpeed(self.settings.bunkerSiloSpeed:getValue())
    elseif self.state == self.states.DRIVING_TO_UNLOAD_POSITION then     
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    elseif self.state == self.states.DRIVING_TO_UNLOAD_TRAILER then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    elseif self.state == self.states.WAITING_FOR_TRAILER then 
        self:setMaxSpeed(0)
        if (g_time - self.lastTrailerSearch) > self.searchForTrailerDelaySec * 1000 then
            self:searchForTrailerToUnloadInto()
            self.lastTrailerSearch = g_time
        end
        if CpDebug:isChannelActive(CpDebug.DBG_SILO, self.vehicle) then
            DebugUtil.drawDebugCircleAtNode(self.siloFrontNode, self.maxValidTrailerDistanceToSiloFront, 
                math.ceil(self.maxValidTrailerDistanceToSiloFront), nil, false, {0, 3, 0})
        end
    elseif self.state == self.states.DRIVING_TO_UNLOAD then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        local refNode
        if self.isUnloadingAtTrailerActive then 
            refNode = self.targetTrailer.exactFillRootNode
        else 
            refNode = self.unloadTrigger:getFillUnitExactFillRootNode()
        end
        if self.shovelController:isShovelOverTrailer(refNode) then 
            self:setNewState(self.states.UNLOADING)
            self:setMaxSpeed(0)
        end
        if not self.isUnloadingAtTrailerActive then 
            if self.shovelController:isShovelOverTrailer(refNode, 3) and self.shovelController:canDischarge(self.unloadTrigger) then 
                self:setNewState(self.states.UNLOADING)
                self:setMaxSpeed(0)
            end
        end
    elseif self.state == self.states.UNLOADING then 
        self:setMaxSpeed(0)
        if self:hasFinishedUnloading() then
            self:startReversingAwayFromUnloading()
        end
    elseif self.state == self.states.REVERSING_AWAY_FROM_UNLOAD then
        self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    end
    if self.state.properties.shovelPosition then 
        if not self.frozen and self.shovelController:moveShovelToPosition(self.state.properties.shovelPosition) then 
            if self.state.properties.shovelMovingSpeed ~= nil then 
                self:setMaxSpeed(self.state.properties.shovelMovingSpeed)
            end
        end
    end
    self:limitSpeed()
    return gx, gz, moveForwards, self.maxSpeed, 100
end

function AIDriveStrategyShovelSiloLoader:update(dt)
    AIDriveStrategyCourse.update(self)
    self:updateImplementControllers(dt)
    if CpDebug:isChannelActive(CpDebug.DBG_SILO, self.vehicle) then
        if self.course:isTemporary() then
            self.course:draw()
        elseif self.ppc:getCourse():isTemporary() then
            self.ppc:getCourse():draw()
        end
        if self.silo then 
            self.silo:drawDebug()
            self.siloAreaToAvoid:drawDebug()
        end
        self.siloController:draw()
        if self.heapSilo then 
            CpUtil.drawDebugNode(self.heapNode, false, 3)
        end
        if self.targetTrailer then 
            CpUtil.drawDebugNode(self.targetTrailer.exactFillRootNode, false, 3, "ExactFillRootNode")
        end
        CpUtil.drawDebugNode(self.unloadPositionNode, false, 3)
    end
end

--- Ignores the bunker silo for the proximity sensors.
function AIDriveStrategyShovelSiloLoader:ignoreProximityObject(object, vehicle)
    if self.silo:isTheSameSilo(object) then
        return true 
    end
    --- This ignores the terrain.
    if object == nil then
        return true
    end
end

function AIDriveStrategyShovelSiloLoader:getProximitySensorWidth()
    -- a bit less as size.width always has plenty of buffer
    return self.vehicle.size.width - 0.5
end

function AIDriveStrategyShovelSiloLoader:getWorkWidth()
    return self.settings.bunkerSiloWorkWidth:getValue()
end

function AIDriveStrategyShovelSiloLoader:setNewState(newState)
    self:debug("Changed State from %s to %s", self.state.name, newState.name)
    self.state = newState
end

--- Is the trailer valid or not?
---@param trailer table
---@param trailerToIgnore table|nil
---@return boolean
---@return table|nil
function AIDriveStrategyShovelSiloLoader:isValidTrailer(trailer, trailerToIgnore)
    local function debug(...)
        self:debug("%s attached to: %s => %s", CpUtil.getName(trailer), 
                trailer.rootVehicle and CpUtil.getName(trailer.rootVehicle) or "no root vehicle", string.format(...))
    end
    if not SpecializationUtil.hasSpecialization(Trailer, trailer.specializations) then 
        return false
    end
    if trailer.rootVehicle and not AIUtil.isStopped(trailer.rootVehicle) then 
        self:debug("is not stopped!", CpUtil.getName(trailer))
        return false
    end
    if trailerToIgnore and table.hasElement(trailerToIgnore, trailer) then 
        debug("will be ignored!", CpUtil.getName(trailer))
        return false
    end       
    local canLoad, fillUnitIndex, fillType, exactFillRootNode = 
        ImplementUtil.getCanLoadTo(trailer, self.shovelImplement, 
        nil, debug) 
    if not canLoad or exactFillRootNode == nil then 
        debug("can't be used!", CpUtil.getName(trailer))
        return false
    end
    return true, {  fillUnitIndex = fillUnitIndex,
                    fillType = fillType,
                    exactFillRootNode = exactFillRootNode,
                    trailer = trailer } 
end

--- Gets the closest trailer data with the distance
---@param trailerToIgnore table|nil optional trailers that will be ignored.
---@return table|nil
---@return number
function AIDriveStrategyShovelSiloLoader:getClosestTrailerAndDistance(trailerToIgnore)
    local closestDistance = math.huge
    local closestTrailerData = nil
    for i, vehicle in pairs(g_currentMission.vehicles) do 
        local dist = calcDistanceFrom(vehicle.rootNode, self.siloFrontNode)
        if dist < closestDistance then 
            local valid, trailerData = self:isValidTrailer(vehicle, trailerToIgnore) 
            if valid then
                closestDistance = dist
                closestTrailerData = trailerData
            end
        end
    end
    return closestTrailerData, closestDistance
end

--- Searches for trailer to unload into in a maximum radius relative to the silo front center.
function AIDriveStrategyShovelSiloLoader:searchForTrailerToUnloadInto()
    self:debug("Searching for an trailer nearby.")
    local trailerData, dist = self:getClosestTrailerAndDistance({})
    if not trailerData then 
        self:debug("No valid trailer found anywhere!")
        return
    end
    local trailer = trailerData.trailer
    if dist > self.maxValidTrailerDistanceToSiloFront then
        self:debug("Closest Trailer %s attached to %s with the distance %.2fm/%.2fm found is to far away!", 
            CpUtil.getName(trailer), trailer.rootVehicle and CpUtil.getName(trailer.rootVehicle) or "no root vehicle",
            dist, self.maxValidTrailerDistanceToSiloFront)
        return
    end
    --- Sets the unload position node in front of the closest side of the trailer.
    self:debug("Found a valid trailer %s within distance %.2f", CpUtil.getName(trailer), dist)
    self.targetTrailer = trailerData
    local _, _, distShovelDirectionNode = localToLocal(self.shovelController:getShovelNode(), self.vehicle:getAIDirectionNode(), 0, 0, 0)
    local dirX, _, dirZ = localDirectionToWorld(trailer.rootNode, 0, 0, 1)
    local yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
    local dx, _, dz = localToLocal(self.shovelController:getShovelNode(), trailer.rootNode, 0, 0, 0)
    if dx > 0 then 
        local x, y, z = localToWorld(trailer.rootNode, math.abs(distShovelDirectionNode) + self.distShovelTrailerPreUnload, 0, 0)
        setTranslation(self.unloadPositionNode, x, y, z)
        setRotation(self.unloadPositionNode, 0, MathUtil.getValidLimit(yRot - math.pi/2), 0)
    else 
        local x, y, z = localToWorld(trailer.rootNode, -math.abs(distShovelDirectionNode) - self.distShovelTrailerPreUnload, 0, 0)
        setTranslation(self.unloadPositionNode, x, y, z)
        setRotation(self.unloadPositionNode, 0,  MathUtil.getValidLimit(yRot + math.pi/2), 0)
    end
    self:startPathfindingToTrailer()
end

----------------------------------------------------------------
--- Pathfinding
----------------------------------------------------------------

--- Find an alignment path to the silo lane course.
---@param course table silo lane course
function AIDriveStrategyShovelSiloLoader:startPathfindingToStart(course)
    if not self.pathfinder or not self.pathfinder:isActive() then
        self:setNewState(self.states.WAITING_FOR_PATHFINDER)
        self:rememberCourse(course, 1)
        local done, path
        local fm = self:getFrontAndBackMarkers()
        self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToWaypoint(
            self.vehicle, course, 1, 0, -(fm + 4),
            true, nil, nil, 
            nil, 0, self.siloAreaToAvoid)
        if done then
            return self:onPathfindingDoneToStart(path)
        else
            self:setPathfindingDoneCallback(self, self.onPathfindingDoneToStart)
        end
    else
        self:debug('Pathfinder already active')
    end
    return true
end

function AIDriveStrategyShovelSiloLoader:onPathfindingDoneToStart(path)
    if path and #path > 2 then
        self:debug("Found alignment path to the course for the silo.")
        local alignmentCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        alignmentCourse:adjustForTowedImplements(2)
        self:startCourse(alignmentCourse, 1)
        self:setNewState(self.states.DRIVING_ALIGNMENT_COURSE)
    else 
        local course = self:getRememberedCourseAndIx()
        self:debug("No alignment path found, so driving directly to the course!")
        self:startCourse(course, 1)
        self:setNewState(self.states.DRIVING_INTO_SILO)
    end
end

--- Starts Pathfinding to the position node in front of a unload trigger.
function AIDriveStrategyShovelSiloLoader:startPathfindingToUnloadPosition()
    if not self.pathfinder or not self.pathfinder:isActive() then
        self:setNewState(self.states.WAITING_FOR_PATHFINDER)
        local done, path, goalNodeInvalid
        self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToNode(
            self.vehicle, self.unloadPositionNode,
            0, 0, true,
            nil, {}, nil,
            0, self.siloAreaToAvoid, false
        )
        if done then
            return self:onPathfindingDoneToUnloadPosition(path, goalNodeInvalid)
        else
            self:setPathfindingDoneCallback(self, self.onPathfindingDoneToUnloadPosition)
        end
    else
        self:debug('Pathfinder already active')
    end
    return true
end

function AIDriveStrategyShovelSiloLoader:onPathfindingDoneToUnloadPosition(path, goalNodeInvalid)
    if path and #path > 2 then
        self:debug("Found path to unloading station.")
        local course = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        course:adjustForTowedImplements(2)
        self:startCourse(course, 1)
        self:setNewState(self.states.DRIVING_TO_UNLOAD_POSITION)
    else 
        self:debug("Failed to drive close to unload position.")
      --  self.vehicle:stopCurrentAIJob(AIMessageCpErrorNoPathFound.new())
    end
end

--- Starts Pathfinding to the position node in front of the trailer side.  
function AIDriveStrategyShovelSiloLoader:startPathfindingToTrailer()
    if not self.pathfinder or not self.pathfinder:isActive() then
        self:setNewState(self.states.WAITING_FOR_PATHFINDER)
        local done, path, goalNodeInvalid
        self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToNode(
            self.vehicle, self.unloadPositionNode,
            0, 0, true,
            nil, {}, nil,
            0, self.siloAreaToAvoid, false
        )
        if done then
            return self:onPathfindingDoneToTrailer(path, goalNodeInvalid)
        else
            self:setPathfindingDoneCallback(self, self.onPathfindingDoneToTrailer)
        end
    else
        self:debug('Pathfinder already active')
    end
    return true
end

function AIDriveStrategyShovelSiloLoader:onPathfindingDoneToTrailer(path, goalNodeInvalid)
    if path and #path > 2 then
        self:debug("Found path to trailer %s.", CpUtil.getName(self.targetTrailer.trailer))
        local course = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        self:startCourse(course, 1)
        self:setNewState(self.states.DRIVING_TO_UNLOAD_TRAILER)
    else 
        self:debug("Failed to find path to trailer!")
        self:setNewState(self.states.WAITING_FOR_TRAILER)
    end
end
----------------------------------------------------------------
--- Silo work
----------------------------------------------------------------

--- Starts driving into the silo lane
function AIDriveStrategyShovelSiloLoader:startDrivingToSilo()
    --- Creates a straight course in the silo.
    local startPos, endPos = self.siloController:getTarget(self:getWorkWidth())
    local x, z = unpack(startPos)
    local dx, dz = unpack(endPos)
    local siloCourse = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 
        0, 0, 3, 3, false)
    local distance = siloCourse:getDistanceBetweenVehicleAndWaypoint(self.vehicle, 1)
    if distance > self.turningRadius then
        self:debug("Start driving to silo with pathfinder.")
        self:startPathfindingToStart(siloCourse)
    else
        self:debug("Start driving into the silo directly.")
        self:startCourse(siloCourse, 1)
        self:setNewState(self.states.DRIVING_INTO_SILO)
    end
end

function AIDriveStrategyShovelSiloLoader:startDrivingOutOfSilo()
    --- Creates the straight reverse course.
    local startPos, endPos = self.siloController:getLastTarget()
    local x, z = unpack(endPos)
    local dx, dz = unpack(startPos)
    local reverseCourse = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 
        0, 0, 6, 3, true)
    local ix = reverseCourse:getNextRevWaypointIxFromVehiclePosition(1, self.vehicle:getAIDirectionNode(), 10)   
    if ix == 1 then 
        ix = reverseCourse:getNumberOfWaypoints()
    end
    self:startCourse(reverseCourse, ix)
    self:setNewState(self.states.DRIVING_OUT_OF_SILO)
end

--- Drives from the position node in front of the trailer to the trailer, so the unloading can begin after that.
function AIDriveStrategyShovelSiloLoader:approachTrailerForUnloading()
    local dx, _, dz = getWorldTranslation(self.targetTrailer.exactFillRootNode)
    local x, _, z = getWorldTranslation(self.vehicle:getAIDirectionNode())
    local course = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 
        0, -3, 0, 3, false)
    local firstWpIx = course:getNearestWaypoints(self.vehicle:getAIDirectionNode())
    self:startCourse(course, firstWpIx)
    self:setNewState(self.states.DRIVING_TO_UNLOAD)
    self.shovelController:calculateMinimalUnloadingHeight(self.targetTrailer.exactFillRootNode)
end

--- Drives from the position node in front of the trigger to the unload trigger, so the unloading can begin after that.
function AIDriveStrategyShovelSiloLoader:approachUnloadStationForUnloading()
    local dx, _, dz = getWorldTranslation(self.unloadTrigger:getFillUnitExactFillRootNode())
    local x, _, z = getWorldTranslation(self.vehicle:getAIDirectionNode())
    local course = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 
        0, -3, 3, 2, false)
    local firstWpIx = course:getNearestWaypoints(self.vehicle:getAIDirectionNode())
    self:startCourse(course, firstWpIx)
    self:setNewState(self.states.DRIVING_TO_UNLOAD)
    self.shovelController:calculateMinimalUnloadingHeight(self.unloadTrigger:getFillUnitExactFillRootNode())
end

----------------------------------------------------------------
--- Unloading
----------------------------------------------------------------

--- Is the unloading finished?
---@return boolean
function AIDriveStrategyShovelSiloLoader:hasFinishedUnloading()
    if self.shovelController:isEmpty() then 
        self:debug("Finished unloading, as the shovel is empty.")
        return true
    end
    if self.isUnloadingAtTrailerActive then 
        if self.targetTrailer.trailer:getFillUnitFreeCapacity(self.targetTrailer.fillUnitIndex) <= 0 then 
            self:debug("Trailer is full, abort unloading into trailer %s.", CpUtil.getName(self.targetTrailer.trailer))
            self.targetTrailer = nil
            return true
        end
    else 
        if self.unloadTrigger:getFillUnitFreeCapacity(1, self.shovelController:getDischargeFillType(), self.vehicle:getOwnerFarmId()) <= 0 then 
            self:debugSparse("Unload Trigger is full.")
        end
    end
    return false
end

--- Starts reverse straight to make some space to the trailer or unload trigger.
function AIDriveStrategyShovelSiloLoader:startReversingAwayFromUnloading()
    local _, _, spaceToTrailer = localToLocal(self.shovelController:getShovelNode(), self.vehicle:getAIDirectionNode(), 0, 0, 0)
    local course = Course.createStraightReverseCourse(self.vehicle, 2*spaceToTrailer, 
        0, self.vehicle:getAIDirectionNode() )
    self:startCourse(course, 1)
    self:setNewState(self.states.REVERSING_AWAY_FROM_UNLOAD)
end
