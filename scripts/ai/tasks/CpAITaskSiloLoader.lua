--- Bunker silo task
---@class CpAITaskSiloLoader
CpAITaskSiloLoader = {}
local CpAITaskSiloLoader_mt = Class(CpAITaskSiloLoader, AITask)

function CpAITaskSiloLoader.new(isServer, job, customMt)
	local self = AITask.new(isServer, job, customMt or CpAITaskSiloLoader_mt)
	self.vehicle = nil
	self.silo = nil
	return self
end

function CpAITaskSiloLoader:reset()
	self.vehicle = nil
	self.silo = nil
	CpAITaskSiloLoader:superClass().reset(self)
end

function CpAITaskSiloLoader:update(dt)
end

function CpAITaskSiloLoader:setVehicle(vehicle)
	self.vehicle = vehicle
end

function CpAITaskSiloLoader:setSilo(silo)
	self.silo = silo	
end

function CpAITaskSiloLoader:start()
	if self.isServer then
		self.vehicle:startCpSiloLoaderWorker(self.silo, self.job:getCpJobParameters())
	end

	CpAITaskSiloLoader:superClass().start(self)
end

function CpAITaskSiloLoader:stop()
	CpAITaskSiloLoader:superClass().stop(self)

	if self.isServer then
		self.vehicle:stopCpSiloLoaderWorker()
	end
end
