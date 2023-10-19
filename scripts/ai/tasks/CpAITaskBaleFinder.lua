
---@class CpAIJobBaleFinder : CpAITask
CpAITaskBaleFinder = CpObject(CpAITask)

function CpAITaskBaleFinder:reset()
	CpAITask.reset(self)
	self.fieldPolygon = nil
end

function CpAIJobBaleFinder:setFieldPolygon(polygon)
	self.fieldPolygon = polygon	
end

function CpAITaskBaleFinder:start()	
	if self.isServer then
		self:debug("CP bale finder task started.")
		local strategy = AIDriveStrategyFindBales(self, self.job)
		strategy:setFieldPolygon(self.job.fieldPolygon)
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
