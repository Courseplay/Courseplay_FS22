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

AIDriveStrategyShovelSiloLoader.safeSpaceToTrailer = 5
AIDriveStrategyShovelSiloLoader.maxValidTrailerDistanceToSiloFront = 30
AIDriveStrategyShovelSiloLoader.searchForTrailerDelaySec = 15 
AIDriveStrategyShovelSiloLoader.distShovelTrailerPreUnload = 7
AIDriveStrategyShovelSiloLoader.distShovelUnloadStationPreUnload = 7

function AIDriveStrategyShovelSiloLoader.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyShovelSiloLoader_mt
    end
    local self = AIDriveStrategyCourse.new(customMt)
    AIDriveStrategyCourse.initStates(self, AIDriveStrategyShovelSiloLoader.myStates)
    self.state = self.states.INITIAL
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
---@param unloadStation table
function AIDriveStrategyShovelSiloLoader:setUnloadTriggerAndStation(unloadTrigger, unloadStation)
    self.unloadTrigger = unloadTrigger
    self.unloadStation = unloadStation
end

function AIDriveStrategyShovelSiloLoader:startWithoutCourse(jobParameters)
 
    -- to always have a valid course (for the traffic conflict detector mainly)
    self.course = Course.createStraightForwardCourse(self.vehicle, 25)
    self:startCourse(self.course, 1)

    self.jobParameters = jobParameters
    self.unloadPositionNode = CpUtil.createNode("unloadPositionNode", 0, 0, 0) 

    self.isUnloadingAtTrailerActive = jobParameters.unloadAt:getValue() == CpSiloLoaderJobParameters.UNLOAD_TRAILER
    if not self.isUnloadingAtTrailerActive then 
        self:debug("Starting shovel silo to unload into unload trigger.")
        local x, y, z = getWorldTranslation(self.unloadTrigger:getTrigger():getFillUnitExactFillRootNode())
        setTranslation(self.unloadPositionNode, x, y, z)
        local position = jobParameters.unloadPosition
        local dirX, dirZ = position:getDirection()
        setDirection(self.unloadPositionNode, dirX, 0, dirZ, 0, 0, 1)
        local dx, dy, dz = localToWorld(self.unloadPositionNode, 0, 0, -self.distShovelUnloadStationPreUnload)
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
    self.siloFrontNode = CpUtil.createNode("siloFrontNode", cx, cz, 0)

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
    self:setFrontAndBackMarkers()

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
            --self.vehicle:stopCurrentAIJob(AIMessageSuccessFinishedJob.new())
        end
    end
end

--- this the part doing the actual work on the field after/before all
--- implements are started/lowered etc.
function AIDriveStrategyShovelSiloLoader:getDriveData(dt, vX, vY, vZ)
    self:updateLowFrequencyImplementControllers()

    local moveForwards = not self.ppc:isReversing()
    local gx, gz, _

    ----------------------------------------------------------------
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
            self:startPathfindingToUnloadPosition()
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
    elseif self.state == self.states.WAITING_FOR_TRAILER then 
        self:setMaxSpeed(0)
        if (g_time - self.lastTrailerSearch) > self.searchForTrailerDelaySec * 1000 then
            self:searchForTrailerToUnloadInto()
            self.lastTrailerSearch = g_time
        end
    elseif self.state == self.states.DRIVING_TO_UNLOAD then
        self:setMaxSpeed(self.settings.reverseSpeed:getValue())
        local refNode
        if self.isUnloadingAtTrailerActive then 
            refNode = self.targetTrailer.exactFillRootNode
        else 
            refNode = self.unloadTrigger:getTrigger():getFillUnitExactFillRootNode()
        end
        if self.shovelController:isShovelOverTrailer(refNode) then 
            self:setNewState(self.states.UNLOADING)
            self:setMaxSpeed(0)
        end
    elseif self.state == self.states.UNLOADING then 
        self:setMaxSpeed(0)
        if self:hasFinishedUnloading() then
            if self.isUnloadingAtTrailerActive then 
                self:startReversingAwayFromUnloading()
            else 
                self:startDrivingToSilo()
            end
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
        end
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

function AIDriveStrategyShovelSiloLoader:setNewState(newState)
    self:debug("Changed State from %s to %s", self.state.name, newState.name)
    self.state = newState
end

----------------------------------------------------------------
--- Pathfinding
----------------------------------------------------------------

--- Find an alignment path to the heap course.
---@param course table heap course
function AIDriveStrategyShovelSiloLoader:startPathfindingToStart(course)
    if not self.pathfinder or not self.pathfinder:isActive() then
        self:setNewState(self.states.WAITING_FOR_PATHFINDER)
        self:rememberCourse(course, 1)
        local done, path
        local fm = self:getFrontAndBackMarkers()
        self.pathfinder, done, path = PathfinderUtil.startPathfindingFromVehicleToWaypoint(
            self.vehicle, course, 1, 0, -(fm + 4),
            true, nil)
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
        self:debug("Found alignment path to the course for the heap.")
        local alignmentCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
        self:startCourse(alignmentCourse, 1)
        self:setNewState(self.states.DRIVING_ALIGNMENT_COURSE)
    else 
        local course = self:getRememberedCourseAndIx()
        self:debug("No alignment path found!")
        self:startCourse(course, 1)
        self:setNewState(self.states.DRIVING_INTO_SILO)
    end
end


function AIDriveStrategyShovelSiloLoader:searchForTrailerToUnloadInto()
    self:debug("Searching for an trailer nearby.")
    local function getClosestTrailerAndDistance()
        local closestDistance = math.huge
        local closestTrailer = nil
        for i, vehicle in pairs(g_currentMission.vehicles) do 
            if SpecializationUtil.hasSpecialization(Trailer, vehicle.specializations) and AIUtil.isStopped(vehicle.rootVehicle) then 
                local dist = calcDistanceFrom(vehicle.rootNode, self.siloFrontNode)
                if dist < closestDistance then 
                    closestDistance = dist
                    closestTrailer = vehicle
                end
            end
        end
        return closestTrailer, closestDistance
    end
    local trailer, dist = getClosestTrailerAndDistance()
    if not trailer then 
        self:debug("No valid trailer found anywhere!")
        return
    end
    if dist > self.maxValidTrailerDistanceToSiloFront then
        self:debug("No Trailer with the max distance found, closest: %.2f", dist)
        return
    end
    self:debug("Found a trailer %s within distance %.2f", CpUtil.getName(trailer), dist)
    local canLoad, fillUnitIndex, fillType, exactFillRootNode = 
                    ImplementUtil.getCanLoadTo(trailer, self.shovelImplement) 
    if canLoad and exactFillRootNode ~= nil then 
        self.targetTrailer = {
            fillUnitIndex = fillUnitIndex,
            fillType = fillType,
            exactFillRootNode = exactFillRootNode,
            trailer = trailer
        }
        
        local _, _, distShovelDirectionNode = localToLocal(self.shovelController:getShovelNode(), self.vehicle:getAIDirectionNode(), 0, 0, 0)
        --self.distShovelTrailerPreUnload
        local dirX, _, dirZ = localDirectionToWorld(trailer.rootNode, 0, 0, 1)
        local yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
        local dx, _, dz = localToLocal(self.shovelController:getShovelNode(), trailer.rootNode, 0, 0, 0)
        if dx > 0 then 
            local x, y, z = localToWorld(trailer.rootNode, dx + distShovelDirectionNode + self.distShovelTrailerPreUnload, 0, 0)
            setTranslation(self.unloadPositionNode, x, y, z)
            setRotation(self.unloadPositionNode, 0, MathUtil.getValidLimit(yRot + math.pi/2), 0)

        else 
            local x, y, z = localToWorld(trailer.rootNode, dx - distShovelDirectionNode -self.distShovelTrailerPreUnload, 0, 0)
            setTranslation(self.unloadPositionNode, x, y, z)
            setRotation(self.unloadPositionNode, 0,  MathUtil.getValidLimit(yRot - math.pi/2), 0)
        end
        self:startPathfindingToTrailer()

    end
end

function AIDriveStrategyShovelSiloLoader:startPathfindingToUnloadPosition()
    if not self.pathfinder or not self.pathfinder:isActive() then
        self:setNewState(self.states.WAITING_FOR_PATHFINDER)
        local done, path, goalNodeInvalid
        self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToNode(
            self.vehicle, self.unloadPositionNode,
            0, 0, true,
            nil, {}, nil,
            0, nil, false
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
        self:startCourse(course, 1)
        self:setNewState(self.states.DRIVING_TO_UNLOAD_POSITION)
    else 
        self:debug("Failed to drive close to unload position.")
        --self.vehicle:stopCurrentAIJob(AIMessageCpErrorNoPathFound.new())
    end
end

function AIDriveStrategyShovelSiloLoader:startPathfindingToTrailer()
    if not self.pathfinder or not self.pathfinder:isActive() then
        self:setNewState(self.states.WAITING_FOR_PATHFINDER)
        local done, path, goalNodeInvalid
        self.pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToNode(
            self.vehicle, self.unloadPositionNode,
            0, 0, true,
            nil, {}, nil,
            0, nil, false
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
        self:debug("Found path to unloading station.")
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

function AIDriveStrategyShovelSiloLoader:startDrivingToSilo()
    local startPos, endPos = self.siloController:getTarget(self:getWorkWidth())
    local x, z = unpack(startPos)
    local dx, dz = unpack(endPos)

    local siloCourse = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 
        0, 0, 3, 3, false)


    local distance = siloCourse:getDistanceBetweenVehicleAndWaypoint(self.vehicle, 1)

    if distance > 1.5 * self.turningRadius then
        self:debug("Start driving to silo with pathfinder.")
        self:startPathfindingToStart(siloCourse)
    else
        self:debug("Start driving into the silo.")
        self:startCourse(siloCourse, 1)
        self:setNewState(self.states.DRIVING_INTO_SILO)
    end
end

function AIDriveStrategyShovelSiloLoader:startDrivingOutOfSilo()
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

function AIDriveStrategyShovelSiloLoader:approachTrailerForUnloading()
    local dx, _, dz = getWorldTranslation(self.targetTrailer.exactFillRootNode)
    local x, _, z = getWorldTranslation(self.vehicle:getAIDirectionNode())
    local course = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 
        0, -3, 0, 3, false)
    local firstWpIx = course:getNearestWaypoints(self.vehicle:getAIDirectionNode())
    self:startCourse(course, firstWpIx)
    self:setNewState(self.states.DRIVING_TO_UNLOAD)
end

function AIDriveStrategyShovelSiloLoader:approachUnloadStationForUnloading()
    local dx, _, dz = getWorldTranslation(self.unloadTrigger:getTrigger():getFillUnitExactFillRootNode())
    local x, _, z = getWorldTranslation(self.vehicle:getAIDirectionNode())
    local course = Course.createFromTwoWorldPositions(self.vehicle, x, z, dx, dz, 
        0, -3, 0, 3, false)
    local firstWpIx = course:getNearestWaypoints(self.vehicle:getAIDirectionNode())
    self:startCourse(course, firstWpIx)
    self:setNewState(self.states.DRIVING_TO_UNLOAD)
end

function AIDriveStrategyShovelSiloLoader:getWorkWidth()
    return self.settings.bunkerSiloWorkWidth:getValue()
end

----------------------------------------------------------------
--- Unloading
----------------------------------------------------------------
function AIDriveStrategyShovelSiloLoader:hasFinishedUnloading()
    if self.isUnloadingAtTrailerActive then 
        if self.targetTrailer.trailer:getFillUnitFreeCapacity(self.targetTrailer.fillUnitIndex) <= 0 then 
            self:debug("Trailer is full, abort unloading into trailer %s.", CpUtil.getName(self.targetTrailer.trailer))
            return true
        end
    else 
        if self.unloadTrigger:getTrigger():getFillUnitFreeCapacity(1, self.shovelController:getDischargeFillType(), self.vehicle:getOwnerFarmId()) then 
            self:debug("Unload Trigger is full.")
            return true
        end
    end
    if self.shovelController:isEmpty() then 
        self:debug("Finished unloading, as the shovel is empty.")
        return true
    end

    return false
end

function AIDriveStrategyShovelSiloLoader:startReversingAwayFromUnloading()
    local _, _, spaceToTrailer = localToLocal(self.shovelController:getShovelNode(), self.vehicle:getAIDirectionNode(), 0, 0, 0)
    local course = Course.createStraightReverseCourse(self.vehicle, 2*spaceToTrailer, 0 )
    self:startCourse(course, 1)
    self:setNewState(self.states.REVERSING_AWAY_FROM_UNLOAD)
end
