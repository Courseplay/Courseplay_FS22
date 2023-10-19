
---@class CpAITaskDriveTo : CpAITask
CpAITaskDriveTo = CpObject(CpAITask)

function CpAITaskDriveTo:start()
    if self.isServer then
        self:debug('CP drive to task started')
        local strategy = AIDriveStrategyDriveToFieldWorkStart(self, self.job)
        strategy:setAIVehicle(self.vehicle, self.job:getCpJobParameters())
        self.vehicle:startCpWithStrategy(strategy)
        self.vehicle:startCpDriveTo(self, self.job:getCpJobParameters())
    end
    CpAITask.start(self)
end

function CpAITaskDriveTo:stop(wasJobStopped)
    if self.isServer then
        self:debug('CP drive to task stopped')
        self.vehicle:stopCpDriver(wasJobStopped)
    end
    CpAITask.stop(self)
end
