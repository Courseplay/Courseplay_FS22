ProximityController = CpObject()

ProximityController.states = {
    NO_OBSTACLE = {},
    SLOW_DOWN = {},
    STOP = {}
}

-- Proximity sensor
-- how far the sensor can see
ProximityController.sensorRange = 10
-- the sensor will proportionally reduce speed when objects are in range down to this limit (won't set a speed lower than this)
ProximityController.minLimitedSpeed = 2
-- will stop under this threshold
ProximityController.stopThresholdNormal = 1.5

function ProximityController:init(vehicle, width)
    self.vehicle = vehicle
    -- if anything closer than this, we stop
    self.stopThreshold = CpTemporaryObject(self.stopThresholdNormal)
    self.blockingVehicle = CpTemporaryObject(nil)
    self:setState(self.states.NO_OBSTACLE, 'proximity controller initialized')
    self.forwardLookingProximitySensorPack = WideForwardLookingProximitySensorPack(
            self.vehicle, Markers.getFrontMarkerNode(self.vehicle), self.sensorRange, 1, width)
    self.backwardLookingProximitySensorPack = WideBackwardLookingProximitySensorPack(
            self.vehicle, Markers.getBackMarkerNode(self.vehicle), self.sensorRange, 1, self.vehicle.size.width)
end

function ProximityController:setState(state, debugString)
    if self.state ~= state then
        CpUtil.debugVehicle(CpDebug.DBG_TRAFFIC, self.vehicle, debugString)
        self.state = state
    end
end

function ProximityController:setTemporaryStopThreshold(value, ttlMs)
    self.stopThreshold:set(value, ttlMs)
end

function ProximityController:registerIsSlowdownEnabledCallback(object, callback)
    self.isSlowdownEnabledCallback = callback
    self.isSlowdownEnabledCallbackObject = object
end

function ProximityController:isSlowdownEnabled(vehicle)
    if self.isSlowdownEnabledCallbackObject then
        return self.isSlowdownEnabledCallback(self.isSlowdownEnabledCallbackObject, vehicle)
    else
        return true
    end
end

--- Register a function the controller calls when a vehicle has been blocking us for some time.
function ProximityController:registerBlockingVehicleListener(object, callback)
    self.onBlockingVehicleCallback = callback
    self.onBlockingVehicleObject = object
end

---@param vehicle table the vehicle blocking us
---@param isBack boolean true if it was detected behind us
function ProximityController:onBlockingVehicle(vehicle, isBack)
    if self.onBlockingVehicleObject then
        -- notify our listeners
        self.onBlockingVehicleCallback(self.onBlockingVehicleObject, vehicle, isBack)
    end
end

--- Registers a function to ignore a object or vehicle.
--- Currently used for ignoring the bunker silo walls in the bunker silo strategy.
--- TODO: Consider consolidating this with the other ignore logic for vehicles.
function ProximityController:registerIgnoreObjectCallback(object, callback)
    self.ignoreObjectCallback = callback
    self.ignoreObjectCallbackObject = object
end

function ProximityController:ignoreObject(object, vehicle)
    if self.ignoreObjectCallback then
        return self.ignoreObjectCallback(self.ignoreObjectCallbackObject, object, vehicle)
    else
        return false
    end
end

---@return number, table distance of vehicle and vehicle if there is one in range
function ProximityController:checkBlockingVehicleFront()
    return self.forwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
end

---@return number, table distance of vehicle and vehicle if there is one in range
function ProximityController:checkBlockingVehicleBack()
    return self.backwardLookingProximitySensorPack:getClosestObjectDistanceAndRootVehicle()
end

--- Is vehicle in range of the front or rear sensors?
---@param vehicle table
---@return boolean, number true if vehicle is in range, distance of vehicle
function ProximityController:isVehicleInRange(vehicle)
    for _, sensorPack in ipairs({self.forwardLookingProximitySensorPack, self.backwardLookingProximitySensorPack}) do
        local d, otherVehicle = sensorPack:getClosestObjectDistanceAndRootVehicle()
        if otherVehicle == vehicle then
            return true, d
        end
    end
end

function ProximityController:disableLeftSide()
    self.forwardLookingProximitySensorPack:disableLeftSide()
    self.backwardLookingProximitySensorPack:disableRightSide()
end

function ProximityController:disableRightSide()
    self.forwardLookingProximitySensorPack:disableRightSide()
    self.backwardLookingProximitySensorPack:disableLeftSide()
end

function ProximityController:enableBothSides()
    self.forwardLookingProximitySensorPack:enable()
    self.backwardLookingProximitySensorPack:enable()
end

---@param maxSpeed number current maximum allowed speed for vehicle
---@param moveForwards boolean are we moving forwards?
---@return number gx world x coordinate to drive to or nil
---@return number gz world z coordinate to drive to or nil
---@return boolean direction is forwards if true or nil
---@return number maximum speed adjusted to slow down (or 0 to stop) when obstacles are ahead, otherwise maxSpeed
function ProximityController:getDriveData(maxSpeed, moveForwards)

    --- Resets the traffic info text.
    self.vehicle:resetCpActiveInfoText(InfoTextManager.BLOCKED_BY_OBJECT)

    local d, vehicle, range, deg, dAvg = math.huge, nil, 10, 0
    local pack = moveForwards and self.forwardLookingProximitySensorPack or self.backwardLookingProximitySensorPack
    if pack then
        d, vehicle, object, deg, dAvg = pack:getClosestObjectDistanceAndRootVehicle()
        range = pack:getRange()
    end
    if self:ignoreObject(object, vehicle) then 
        self:setState(self.states.NO_OBSTACLE, 'No obstacle')
        return nil, nil, nil, maxSpeed
    end
    local normalizedD = d / (range - self.stopThreshold:get())
    if d < self.stopThreshold:get() then
        -- too close, stop
        self:setState(self.states.STOP,
                string.format('Obstacle ahead, d = %.1f, deg = %.1f, too close, stop.', d, deg))
        maxSpeed = 0
        self.vehicle:setCpInfoTextActive(InfoTextManager.BLOCKED_BY_OBJECT)
        if vehicle ~= nil and vehicle == self.blockingVehicle:get() then
            -- have been blocked by this guy long enough, try to recover
            CpUtil.debugVehicle(CpDebug.DBG_TRAFFIC, self.vehicle,
                    '%s has been blocking us for a while at %.1f m', CpUtil.getName(vehicle), d)
            self:onBlockingVehicle(vehicle, not moveForwards)
        end
        if not self.blockingVehicle:isPending() then
            -- first time we are being blocked, remember the time
            CpUtil.debugVehicle(CpDebug.DBG_TRAFFIC, self.vehicle, '%s is blocking us (%.1fm)', CpUtil.getName(vehicle), d)
            self.blockingVehicle:set(vehicle, nil, 7000)
        end

    elseif normalizedD < 1 and self:isSlowdownEnabled(vehicle) then
        -- something in range, reduce speed proportionally when enabled
        local deltaV = maxSpeed - self.minLimitedSpeed
        maxSpeed = self.minLimitedSpeed + normalizedD * deltaV
        self:setState(self.states.SLOW_DOWN,
                string.format('Obstacle ahead, d = %.1f, deg = %.1f, slowing down to %.1f', d, deg, maxSpeed))
    else
        self:setState(self.states.NO_OBSTACLE, string.format('No obstacle, d = %.1f, deg = %.1f.', d, deg))
        self.blockingVehicle:reset()
    end
    return nil, nil, nil, maxSpeed
end

function ProximityController:isStopped()
    return self.state == self.states.STOP   
end