--- Bunker silo task
---@class CpAITaskSiloLoader
---@field job table
CpAITaskSiloLoader = {}
local CpAITaskSiloLoader_mt = Class(CpAITaskSiloLoader, AITask)

function CpAITaskSiloLoader.new(isServer, job, customMt)
	local self = AITask.new(isServer, job, customMt or CpAITaskSiloLoader_mt)
	self.vehicle = nil
	self.silo = nil
	self.heap = nil
	return self
end

function CpAITaskSiloLoader:reset()
	self.vehicle = nil
	self.silo = nil
	self.heap = nil
	CpAITaskSiloLoader:superClass().reset(self)
end

function CpAITaskSiloLoader:update(dt)
end

function CpAITaskSiloLoader:setVehicle(vehicle)
	self.vehicle = vehicle
end

function CpAITaskSiloLoader:setSiloAndHeap(silo, heap)
	self.silo = silo
	self.heap = heap	
end

function CpAITaskSiloLoader:start()
	if self.isServer then
		local _, unloadTrigger, unloadStation = self.job:getUnloadTriggerAt(self.job:getCpJobParameters().unloadPosition)
		self.vehicle:startCpSiloLoaderWorker(self.job:getCpJobParameters(), self.silo, self.heap, unloadTrigger, unloadStation)
	end

	CpAITaskSiloLoader:superClass().start(self)
end

function CpAITaskSiloLoader:stop()
	CpAITaskSiloLoader:superClass().stop(self)

	if self.isServer then
		self.vehicle:stopCpSiloLoaderWorker()
	end
end
