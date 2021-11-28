AIDriveStrategyCourse = {}
local AIDriveStrategyCourse_mt = Class(AIDriveStrategyCourse, AIDriveStrategy)

AIDriveStrategyCourse.myStates = {
    DEFAULT = {},
}

function AIDriveStrategyCourse.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyCourse_mt
    end
    local self = AIDriveStrategy.new(customMt)
    self:initStates(AIDriveStrategyCourse.myStates)
    return self
end

--- Aggregation of states from this and all descendant classes
function AIDriveStrategyCourse:initStates(states)
    self.states = {}
    for key, state in pairs(states) do
        self.states[key] = {name = tostring(key), properties = state}
    end
end

function AIDriveStrategyCourse:debug(...)
    CpUtil.debugVehicle(self.debugChannel, self.vehicle, self.state.name .. ': ' .. string.format(...))
end

function AIDriveStrategyCourse:debugSparse(...)
    if g_updateLoopIndex % 100 == 0 then
        self:debug(...)
    end
end

function AIDriveStrategyCourse:info(...)
    CpUtil.infoVehicle(self.vehicle, self.state.name .. ': ' .. string.format(...))
end

function AIDriveStrategyCourse:error(...)
    CpUtil.infoVehicle(self.vehicle, self.state.name .. ': ' .. string.format(...))
end

function AIDriveStrategyCourse:setAIVehicle(vehicle)
    AIDriveStrategyStraight:superClass().setAIVehicle(self, vehicle)
    self.ppc = PurePursuitController(vehicle)
    self.ppc:setCourse(vehicle:getFieldWorkCourse())
    -- TODO: should probably be the closest waypoint to the target?
    self.ppc:initialize(1)
end

function AIDriveStrategyCourse:update()
    self.ppc:update()
end

function AIDriveStrategyCourse:getDriveData(dt, vX, vY, vZ)
    local moveForwards = not self.ppc:isReversing()
    local gx, _, gz = self.ppc:getGoalPointPosition()
    local maxSpeed = self.vehicle:getSpeedLimit(true)
    return gx, gz, moveForwards, maxSpeed, 100
end


