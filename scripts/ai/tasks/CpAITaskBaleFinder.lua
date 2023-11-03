
---@class CpAIJobBaleFinder : CpAITask
CpAITaskBaleFinder = CpObject(CpAITask)

function CpAITaskBaleFinder:start()	
	if self.isServer then
		self:debug("CP bale finder task started.")
		local strategy = AIDriveStrategyFindBales(self, self.job)
		strategy:setFieldPolygon(self.job:getFieldPolygon())
		strategy:setAIVehicle(self.vehicle, self.job:getCpJobParameters())
	end
	CpAITask.start(self)
end

function CpAITaskBaleFinder:stop(wasJobStopped)
	if self.isServer then
		self:debug("CP bale finder task stopped.")
		self.vehicle:stopCpDriver(wasJobStopped)
	end
	CpAITask.stop(self)
end
