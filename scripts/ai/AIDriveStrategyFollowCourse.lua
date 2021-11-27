AIDriveStrategyFollowCourse = {}
local AIDriveStrategyFollowCourse_mt = Class(AIDriveStrategyFollowCourse, AIDriveStrategy)

function AIDriveStrategyFollowCourse.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyFollowCourse_mt
    end
    local self = AIDriveStrategy.new(customMt)
    return self
end

function AIDriveStrategyFollowCourse:setAIVehicle(vehicle)
    AIDriveStrategyStraight:superClass().setAIVehicle(self, vehicle)
    self.ppc = PurePursuitController(vehicle)
    self.ppc:setCourse(vehicle:getFieldWorkCourse())
    -- TODO: should probably be the closest waypoint to the target?
    self.ppc:initialize(1)
end

function AIDriveStrategyFollowCourse:update()
    self.ppc:update()
end

function AIDriveStrategyFollowCourse:getDriveData(dt, vX, vY, vZ)
    local moveForwards = not self.ppc:isReversing()
    local gx, _, gz = self.ppc:getGoalPointPosition()
    local maxSpeed = self.vehicle:getSpeedLimit(true)
    return gx, gz, moveForwards, maxSpeed, 100
end

function AIDriveStrategyFollowCourse:updateAIFieldWorkerDriveStrategies()
    local driveStrategyFollowCourse = AIDriveStrategyFollowCourse.new()
    driveStrategyFollowCourse:setAIVehicle(self)
    -- TODO: messing around with AIFieldWorker spec internals is not the best idea, should rather implement
    -- our own specialization
    for i, strategy in ipairs(self.spec_aiFieldWorker.driveStrategies) do
        if strategy.getDriveStraightData then
            CpUtil.debugVehicle(1, self, 'Replacing fieldwork helper drive strategy with Courseplay drive strategy')
            self.spec_aiFieldWorker.driveStrategies[i]:delete()
            self.spec_aiFieldWorker.driveStrategies[i] = driveStrategyFollowCourse
        end
    end
end

AIFieldWorker.updateAIFieldWorkerDriveStrategies = Utils.appendedFunction(AIFieldWorker.updateAIFieldWorkerDriveStrategies,
        AIDriveStrategyFollowCourse.updateAIFieldWorkerDriveStrategies)