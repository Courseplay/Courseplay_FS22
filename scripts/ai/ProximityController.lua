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
-- stop limit we use for self unload to approach the trailer
ProximityController.stopThresholdNormal = 1.5
-- stop limit we use for self unload to approach the trailer
ProximityController.stopThresholdSelfUnload = 0.1
-- an obstacle is considered ahead of us if the reported angle is less then this
-- (and we won't stop or reverse if the angle is higher than this, thus obstacles to the left or right)
ProximityController.angleAheadDeg = 75

function ProximityController:init(vehicle, ppc, width)
    self.vehicle = vehicle
    self.ppc = ppc
    -- if anything closer than this, we stop
    self.stopThreshold = CpTemporaryObject(self.stopThresholdNormal)
    self:setState(self.states.NO_OBSTACLE, 'proximity controller initialized')
    self.forwardLookingProximitySensorPack = WideForwardLookingProximitySensorPack(
            self.vehicle, Markers.getFrontMarkerNode(self.vehicle), self.sensorRange, 1, width)
    self.backwardLookingProximitySensorPack = BackwardLookingProximitySensorPack(
            self.vehicle, Markers.getBackMarkerNode(self.vehicle), self.sensorRange, 1)
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

---@param maxSpeed number current maximum allowed speed for vehicle
---@return number gx world x coordinate to drive to or nil
---@return number gz world z coordinate to drive to or nil
---@return boolean direction is forwards if true or nil
---@return number maximum speed adjusted to slow down (or 0 to stop) when obstacles are ahead, otherwise maxSpeed
function ProximityController:getDriveData(maxSpeed)
    local d, vehicle, range, deg, dAvg = math.huge, nil, 10, 0
    local pack = self.ppc:isReversing() and self.backwardLookingProximitySensorPack or self.forwardLookingProximitySensorPack
    if pack then
        d, vehicle, _, deg, dAvg = pack:getClosestObjectDistanceAndRootVehicle()
        range = pack:getRange()
    end
    local normalizedD = d / (range - self.stopThreshold:get())
    local obstacleAhead = math.abs(deg) < self.angleAheadDeg
    if d < self.stopThreshold:get() and obstacleAhead then
        -- too close, stop
        self:setState(self.states.STOP,
                string.format('Obstacle ahead, d = %.1f, deg = %.1f, too close, stop.', d, deg))
        maxSpeed = 0
    elseif normalizedD < 1 and self:isSlowdownEnabled(vehicle) then
        -- something in range, reduce speed proportionally when enabled
        local deltaV = maxSpeed - self.minLimitedSpeed
        maxSpeed = self.minLimitedSpeed + normalizedD * deltaV
        self:setState(self.states.SLOW_DOWN,
                string.format('Obstacle ahead, d = %.1f, deg = %.1f, slowing down to %.1f', d, deg, maxSpeed))
    else
        self:setState(self.states.NO_OBSTACLE, 'No obstacle')
    end
    return nil, nil, nil, maxSpeed
end