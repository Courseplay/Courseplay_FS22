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

function AIDriveStrategyFollowCourse:updateAIFieldWorkerDriveStrategies()
    local driveStrategyFollowCourse = AIDriveStrategyFollowCourse.new()
    CpUtil.debugVehicle(1, self, 'Adding FollowCourse drive strategy')
    driveStrategyFollowCourse:setAIVehicle(self)
    table.insert(self.spec_aiFieldWorker.driveStrategies, driveStrategyFollowCourse)
end

AIFieldWorker.updateAIFieldWorkerDriveStrategies = Utils.appendedFunction(AIFieldWorker.updateAIFieldWorkerDriveStrategies,
        AIDriveStrategyFollowCourse.updateAIFieldWorkerDriveStrategies)