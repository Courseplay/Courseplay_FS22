
---@class CpAITaskCombineUnloader : CpAITask
CpAITaskCombineUnloader = CpObject(CpAITask)

function CpAITaskCombineUnloader:reset()
	CpAITask.reset(self)
	self.fieldPolygon = nil
end

function CpAITaskCombineUnloader:setFieldPolygon(polygon)
	self.fieldPolygon = polygon	
end

function CpAITaskCombineUnloader:start()
	if self.isServer then
		self:debug("CP combine unloader task started.")
		local strategy = AIDriveStrategyUnloadCombine(self, self.job)
		strategy:setFieldPolygon(self.fieldPolygon)
		strategy:setAIVehicle(self.vehicle, self.job:getCpJobParameters())
		self.vehicle:startCpWithStrategy(strategy)
	end
	CpAITask.start(self)
end

function CpAITaskCombineUnloader:stop(wasJobStopped)
	if self.isServer then
		self:debug("CP combine unloader task stopped.")
		self.vehicle:stopCpDriver(wasJobStopped)
	end
	CpAITask.stop(self)
end
