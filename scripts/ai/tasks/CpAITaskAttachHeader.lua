
---@class CpAITaskAttachHeader : CpAITask
CpAITaskAttachHeader = CpObject(CpAITask)

function CpAITaskAttachHeader:start()
    if self.isServer then
        self:debug('CP Attach header task started')
        local strategy = AIDriveStrategyAttachHeader(self, self.job)
        strategy:setAIVehicle(self.vehicle, self.job:getCpJobParameters())
        self.vehicle:startCpWithStrategy(strategy)
    end
	CpAITask.start(self)
end

function CpAITaskAttachHeader:stop(wasJobStopped)
    if self.isServer then
        self:debug('CP Attach header task stopped')
        self.vehicle:stopCpDriver(wasJobStopped)
    end
    CpAITask.stop(self)
end
