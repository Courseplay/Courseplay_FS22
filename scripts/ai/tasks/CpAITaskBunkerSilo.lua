
---@class CpAITaskBunkerSilo : CpAITask
CpAITaskBunkerSilo = CpObject(CpAITask)

function CpAITaskBunkerSilo:reset()
	self.silo = nil
	CpAITask.reset(self)
end

function CpAITaskBunkerSilo:setSilo(silo)
	self.silo = silo	
end

function CpAITaskBunkerSilo:start()
	if self.isServer then
		self:debug("CP bunker silo task started.")
		self.vehicle:resetCpCoursesFromGui()
		local strategy = AIDriveStrategyFindBales(self, self.job)
		strategy:setAIVehicle(self.vehicle, self.job:getCpJobParameters())
		strategy:setSilo(self.silo)
	end
	CpAITask.start(self)
end

function CpAITaskBunkerSilo:stop(wasJobStopped)
	if self.isServer then
		self:debug("CP bunker silo task stopped.")
		self.vehicle:stopCpDriver(wasJobStopped)
	end
	CpAITask.stop(self)
end
