CpAITaskAttachHeader = {}
local AITaskDriveToCp_mt = Class(CpAITaskAttachHeader, AITaskDriveTo)

function CpAITaskAttachHeader.new(isServer, job, customMt)
    local self = AITask.new(isServer, job, customMt or AITaskDriveToCp_mt)
    return self
end

function CpAITaskAttachHeader:setVehicle(vehicle)
    self.vehicle = vehicle
end

function CpAITaskAttachHeader:start()
    if self.isServer then
        CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self.vehicle, 'CP Attach header task started')
        self.vehicle:startCpAttachHeader(self, self.job:getCpJobParameters())
    end
	AITask.start(self)
end

function CpAITaskAttachHeader:update()
end

function CpAITaskAttachHeader:stop()
    if self.isServer then
        CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self.vehicle, 'CP Attach header task stopped')
        self.vehicle:stopCpAttachHeader()
    end
    AITask.stop(self)
end
