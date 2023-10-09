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

--- Unloader waits until a valid harvester or loader request happens.
--- Can be skipped with drive now button.
--- TODO: Add possibility to avoid traffic conflicts and so on ...
---@class AIDriveStrategyWaitingForHarvesterOrLoader : AIDriveStrategyCourse
---@field currentTask CpAITaskWaitingForHarvesterOrLoader
AIDriveStrategyWaitingForHarvesterOrLoader = CpObject(AIDriveStrategyCourse)

---@type table<AIDriveStrategyWaitingForHarvesterOrLoader,table|nil>
AIDriveStrategyWaitingForHarvesterOrLoader.waitingUnloaders = {}


AIDriveStrategyWaitingForHarvesterOrLoader.myStates = {
	IDLE = { fuelSaveAllowed = true },
}

function AIDriveStrategyWaitingForHarvesterOrLoader:init(...)
    AIDriveStrategyCourse.init(self, ...)

    self.states = CpUtil.initStates(self.states, AIDriveStrategyWaitingForHarvesterOrLoader.myStates)
    self.state = self.states.IDLE
    self.debugChannel = CpDebug.DBG_UNLOAD_COMBINE

    self.driveUnloadNowRequested = CpTemporaryObject(false)
end

function AIDriveStrategyWaitingForHarvesterOrLoader:delete()
    AIDriveStrategyCourse.delete(self)
    AIDriveStrategyWaitingForHarvesterOrLoader.waitingUnloaders[self] = nil
end


function AIDriveStrategyWaitingForHarvesterOrLoader:startWithoutCourse()
    -- to always have a valid course (for the traffic conflict detector mainly)
    self.course = Course.createStraightForwardCourse(self.vehicle, 25)

    self:startCourse(self.course, 1)
end

function AIDriveStrategyWaitingForHarvesterOrLoader:getGeneratedCourse(jobParameters)
    return nil
end

function AIDriveStrategyWaitingForHarvesterOrLoader:setJobParameterValues(jobParameters)
    self.jobParameters = jobParameters
    local x, z = jobParameters.fieldPosition:getPosition()
    self.fieldPolygon = CpFieldUtil.getFieldPolygonAtWorldPosition(x, z)
end

function AIDriveStrategyWaitingForHarvesterOrLoader:setAIVehicle(vehicle, jobParameters)
    AIDriveStrategyCourse.setAIVehicle(self, vehicle, jobParameters)
    self.reverser = AIReverseDriver(self.vehicle, self.ppc)
    self.collisionAvoidanceController = CollisionAvoidanceController(self.vehicle, self)
    self.proximityController = ProximityController(self.vehicle, self:getProximitySensorWidth())
	AIDriveStrategyWaitingForHarvesterOrLoader.waitingUnloaders[self] = vehicle

    -- self.proximityController:registerIsSlowdownEnabledCallback(self, AIDriveStrategyUnloadCombine.isProximitySpeedControlEnabled)
    -- self.proximityController:registerBlockingVehicleListener(self, AIDriveStrategyUnloadCombine.onBlockingVehicle)
    -- self.proximityController:registerIgnoreObjectCallback(self, AIDriveStrategyUnloadCombine.ignoreProximityObject)
end

function AIDriveStrategyWaitingForHarvesterOrLoader:initializeImplementControllers(vehicle)
    local augerWagon, trailer
    augerWagon, self.pipeController = self:addImplementController(vehicle, 
        PipeController, Pipe)
    self:debug('Found a auger wagon: %s', CpUtil.getName(augerWagon))
    trailer, self.trailerController = self:addImplementController(vehicle, 
        TrailerController, Trailer)
    self.trailer = augerWagon or trailer
    local sugarCaneTrailer = SugarCaneTrailerController.getValidTrailer(vehicle)
    if sugarCaneTrailer then
        self:debug("Found a sugar can trailer: %s", CpUtil.getName(sugarCaneTrailer))
        self.trailer = sugarCaneTrailer
        self.sugarCaneTrailerController = SugarCaneTrailerController(vehicle, sugarCaneTrailer)
        self:appendImplementController(self.sugarCaneTrailerController)
    end
    self:addImplementController(vehicle, MotorController, Motorized)
    self:addImplementController(vehicle, WearableController, Wearable)
    self:addImplementController(vehicle, CoverController, Cover)
    self:addImplementController(vehicle, FoldableController, Foldable)
end

------------------------------------------------------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyWaitingForHarvesterOrLoader:getDriveData(dt, vX, vY, vZ)
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

    if self.state == self.states.IDLE then
        self:setMaxSpeed(0)
        if self:isDriveUnloadNowRequested() then
            self:debug('Drive unload now requested')
            self.currentTask:skip()
        end
    elseif self.state == self.states.WAITING_FOR_PATHFINDER then
        -- just wait for the pathfinder to finish
        self:setMaxSpeed(0)
    end
    self:checkProximitySensors(moveForwards)
    return gx, gz, moveForwards, self.maxSpeed, 100
end

function AIDriveStrategyWaitingForHarvesterOrLoader:update(dt)
    AIDriveStrategyCourse.update(self, dt)
    self:updateImplementControllers(dt)
end

function AIDriveStrategyWaitingForHarvesterOrLoader:draw()
	if CpUtil.isVehicleDebugActive(self.vehicle) and CpDebug:isChannelActive(self.debugChannel) then
       
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Implement controller handling.
------------------------------------------------------------------------------------------------------------------------

function AIDriveStrategyWaitingForHarvesterOrLoader:isFuelSaveAllowed()
    return self.state.properties.fuelSaveAllowed
end

--------------------------------------------
--- Harvester/Loader interface functions
--------------------------------------------

--- Interface function for a combine to call the unloader.
---@param targetStrategy AIDriveStrategyCourse the strategy of the calling vehicle
---@param targetVehicle table the combine vehicle calling
---@param waypoint Waypoint|nil if given, the combine wants to meet the unloader at this waypoint, otherwise wants the
--- unloader to come to the combine.
---@return boolean true if the unloader has accepted the request
function AIDriveStrategyWaitingForHarvesterOrLoader:call(targetStrategy, targetVehicle, waypoint)
	self.currentTask:setTarget(targetStrategy, 
		targetVehicle, waypoint)
	self.currentTask:skip()
	return true
end

function AIDriveStrategyWaitingForHarvesterOrLoader:isServingPosition(x, z, outwardsOffset)
    local closestDistance = CpMathUtil.getClosestDistanceToPolygonEdge(self.fieldPolygon, x, z)
    return closestDistance < outwardsOffset or CpMathUtil.isPointInPolygon(self.fieldPolygon, x, z)
end

--- Fill level in %.
function AIDriveStrategyWaitingForHarvesterOrLoader:getFillLevelPercentage()
    return FillLevelManager.getTotalTrailerFillLevelPercentage(self.vehicle)
end

--- Get the Dubins path length and the estimated seconds en-route to gaol
---@param goal State3D
function AIDriveStrategyWaitingForHarvesterOrLoader:getDistanceAndEte(goal)
    local start = PathfinderUtil.getVehiclePositionAsState3D(self.vehicle)
    local solution = PathfinderUtil.dubinsSolver:solve(start, goal, self.turningRadius)
    local dubinsPathLength = solution:getLength(self.turningRadius)
    local estimatedSecondsEnroute = dubinsPathLength / (self.settings.fieldSpeed:getValue() / 3.6) + 3 -- add a few seconds to allow for starting the engine/accelerating
    return dubinsPathLength, estimatedSecondsEnroute
end

--- Get the Dubins path length and the estimated seconds en-route to vehicle
---@param vehicle table the other vehicle
function AIDriveStrategyWaitingForHarvesterOrLoader:getDistanceAndEteToVehicle(vehicle)
    local goal = PathfinderUtil.getVehiclePositionAsState3D(vehicle)
    return self:getDistanceAndEte(goal)
end

--- Get the Dubins path length and the estimated seconds en-route to a waypoint
---@param waypoint Waypoint
function AIDriveStrategyWaitingForHarvesterOrLoader:getDistanceAndEteToWaypoint(waypoint)
    local goal = PathfinderUtil.getWaypointAsState3D(waypoint, 0, 0)
    return self:getDistanceAndEte(goal)
end


function AIDriveStrategyWaitingForHarvesterOrLoader:isDriveUnloadNowRequested()
    if self.driveUnloadNowRequested:get() then
        self.driveUnloadNowRequested:reset()
        self:debug('User requested drive unload now')
        return true
    end
    return false
end

--- Request to start unloading the trailer at our earliest convenience. We won't directly start it from
--- here, just set this flag, as we may be in the middle of something, or may want to back up before
--- starting on the (self)unload course.
function AIDriveStrategyWaitingForHarvesterOrLoader:requestDriveUnloadNow()
    -- will reset automatically after a second so we don't have to worry about it getting stuck :)
    self.driveUnloadNowRequested:set(true, 1000)
end