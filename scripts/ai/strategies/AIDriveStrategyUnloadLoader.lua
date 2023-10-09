--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2023 Courseplay Dev Team

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


---@class AIDriveStrategyUnloadLoader : AIDriveStrategyCourse
AIDriveStrategyUnloadLoader = CpObject(AIDriveStrategyCourse)

---------------------------------------------
--- State properties
---------------------------------------------
--[[
    fuelSaveAllowed : boolean              
    proximityControllerDisabled : boolean
]]

---------------------------------------------
--- Shared states
---------------------------------------------
AIDriveStrategyUnloadLoader.myStates = {
	DRIVING_TO_LOADER = {}, 
	DRIVING_BESIDE_LOADER = {},
	DRIVING_AWAY_FROM_LOADER = {}
}


function AIDriveStrategyUnloadLoader:init(...)
    AIDriveStrategyCourse.init(self, ...)

    self.states = CpUtil.initStates(self.states, AIDriveStrategyUnloadLoader.myStates)
    self.state = self.states.INITIAL
    self.debugChannel = CpDebug.DBG_UNLOAD_COMBINE
end

function AIDriveStrategyUnloadLoader:delete()
    AIDriveStrategyCourse.delete(self)
    AIDriveStrategyUnloadLoader.activeUnloaders[self] = nil
end


------------------------------------------------------------------------------------------------------------------------
-- Start and initialization
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadLoader:startWithoutCourse()
    -- to always have a valid course (for the traffic conflict detector mainly)
    self.course = Course.createStraightForwardCourse(self.vehicle, 25)

    self:startCourse(self.course, 1)
end

function AIDriveStrategyUnloadLoader:getGeneratedCourse(jobParameters)
    return nil
end

function AIDriveStrategyUnloadLoader:setAIVehicle(vehicle, jobParameters)
    AIDriveStrategyCourse.setAIVehicle(self, vehicle, jobParameters)
    self.reverser = AIReverseDriver(self.vehicle, self.ppc)
    self.proximityController = ProximityController(self.vehicle, self:getProximitySensorWidth())
end

--- Sets the unload target 
---@param targetStrategy AIDriveStrategySiloLoader
---@param targetVehicle table
---@param targetPoint Waypoint|number|nil
function AIDriveStrategyUnloadLoader:setTarget(targetVehicle, targetStrategy, targetPoint)
	self.unloadTargetVehicle = targetVehicle
	self.unloadTargetStrategy = targetStrategy
	--self.unloadTargetPoint = targetPoint
end

------------------------------------------------------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyUnloadLoader:getDriveData(dt, vX, vY, vZ)
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
        if not self.startTimer then
            --- Only create one instance of the timer and wait until it finishes.
            self.startTimer = Timer.createOneshot(50, function ()
                --- Pipe measurement seems to be buggy with a few over loaders, like bergman RRW 500,
                --- so a small delay of 50 ms is inserted here before unfolding starts.
                self.vehicle:raiseAIEvent("onAIFieldWorkerStart", "onAIImplementStart")
               	self:startPathfindingToLoader()
                self.startTimer = nil
            end)
        end
        self:setMaxSpeed(0)
    elseif self.state == self.states.WAITING_FOR_PATHFINDER then
        -- just wait for the pathfinder to finish
        self:setMaxSpeed(0)

	elseif self.state == self.states.DRIVING_TO_LOADER then
		self:setMaxSpeed(self.settings.fieldSpeed:getValue())
		
    elseif self.state == self.states.DRIVING_BESIDE_LOADER then
		--- 
    elseif self.state == self.states.DRIVING_AWAY_FROM_LOADER then
		self:setMaxSpeed(self.settings.fieldSpeed:getValue())
    end
    self:checkProximitySensors(moveForwards)
    return gx, gz, moveForwards, self.maxSpeed, 100
end

function AIDriveStrategyUnloadLoader:update(dt)
    AIDriveStrategyCourse.update(self, dt)
    self:updateImplementControllers(dt)
end

function AIDriveStrategyUnloadLoader:draw()
	if CpUtil.isVehicleDebugActive(self.vehicle) and CpDebug:isChannelActive(self.debugChannel) then
        if self.course then
            self.course:draw()
        end
        if self.fieldUnloadPositionNode then
            CpUtil.drawDebugNode(self.fieldUnloadPositionNode, 
                false, 3, "Unload position node")
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Event listeners
------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyUnloadLoader:onWaypointPassed(ix, course)
    if course:isLastWaypointIx(ix) then
        self:onLastWaypointPassed()
    end
end

function AIDriveStrategyUnloadLoader:onLastWaypointPassed()
    self:debug('Last waypoint passed')
   	if self.state == self.states.DRIVING_TO_LOADER then
        self:setNewState(self.states.DRIVING_BESIDE_LOADER)
    elseif self.state == self.states.DRIVING_BESIDE_LOADER then
        self:setNewState(self.states.DRIVING_AWAY_FROM_LOADER)
    elseif self.state == self.states.DRIVING_AWAY_FROM_LOADER then
		--- Finished strategy
		self:finishTask()
    end
end

----------------------------------------------------------
-- Implement controller handling.
------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyUnloadLoader:initializeImplementControllers(vehicle)
    local augerWagon, trailer
    augerWagon, self.pipeController = self:addImplementController(vehicle, 
        PipeController, Pipe, {}, nil)
    self:debug('Auger wagon was found: %s', CpUtil.getName(augerWagon))
    trailer, self.trailerController = self:addImplementController(vehicle, 
        TrailerController, Trailer, {}, nil)
    local sugarCaneTrailer = SugarCaneTrailerController.getValidTrailer(vehicle)
    self.trailer = augerWagon or trailer
    if sugarCaneTrailer then 
        self:debug("Found a sugar cane trailer: %s", CpUtil.getName(sugarCaneTrailer))
        self.trailer = sugarCaneTrailer
        self.sugarCaneTrailerController = SugarCaneTrailerController(vehicle, sugarCaneTrailer)
        self:appendImplementController(self.sugarCaneTrailerController)
    end
    self:addImplementController(vehicle, MotorController, Motorized, {})
    self:addImplementController(vehicle, WearableController, Wearable, {})
    self:addImplementController(vehicle, FoldableController, Foldable, {})
end

--------------------------------------------
--- Pathfinding
--------------------------------------------

function AIDriveStrategyUnloadLoader:startPathfindingToLoader()
	self:setNewState(self.states.WAITING_FOR_PATHFINDER)
	local context = PathfinderControllerContext(self.vehicle, 1)
	context:set(true, self:getAllowReversePathfinding(),
        nil, 0.1,
        true, nil, 
        nil, nil)
	self.pathfinderController:setCallbacks(self, self.onPathfindingDoneToLoader, self.onPathfindingFailedToLoader)
	local backDistance = self.unloadTargetStrategy:getMeasuredBackDistance()
	self.unloadOffsetX, self.unloadOffsetZ = self.unloadTargetStrategy:getPipeOffset(
		0, math.max(backDistance, self.turningRadius * 1.5)) 
	self.pathfinderController:findPathToNode(context, AIUtil.getDirectionNode(self.unloadTargetVehicle), 
		self.unloadOffsetX, self.unloadOffsetZ)
end


function AIDriveStrategyUnloadLoader:onPathfindingDoneToLoader(controller, success, path, goalNodeInvalid)
	if success then 
		local course = self.pathfinderController:getTemporaryCourseFromPath(path)
		self:startCourse(course, 1)
		self:setNewState(self.states.DRIVING_TO_LOADER)
	else 
		self:debug("Failed to find a path to the loader: %s", CpUtil.getName(self.unloadTargetVehicle))
		self.vehicle:stopCurrentAIJob(AIMessageCpErrorNoPathFound.new())
	end
end


function AIDriveStrategyUnloadLoader:onPathfindingFailedToLoader(controller, wasLastRetry, numberOfFails)
	self:debug("Pathfinding to the loader %s failed, so we try again without fruit penalty.", 
		CpUtil.getName(self.unloadTargetVehicle))
	local context = self.pathfinderController:getLastContext()
	context:ignoreFruit()
	self.pathfinderController:findPathToNode(context, AIUtil.getDirectionNode(self.unloadTargetVehicle), 
		self.unloadOffsetX, self.unloadOffsetZ)
end