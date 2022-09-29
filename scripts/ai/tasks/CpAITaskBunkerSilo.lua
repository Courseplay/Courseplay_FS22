--- Bunker silo task
---@class CpAITaskBunkerSilo
CpAITaskBunkerSilo = {}
local AITaskBaleFinderCp_mt = Class(CpAITaskBunkerSilo, AITask)

function CpAITaskBunkerSilo.new(isServer, job, customMt)
	local self = AITask.new(isServer, job, customMt or AITaskBaleFinderCp_mt)
	self.vehicle = nil
	self.silo = nil
	return self
end

function CpAITaskBunkerSilo:reset()
	self.vehicle = nil
	self.silo = nil
	CpAITaskBunkerSilo:superClass().reset(self)
end

function CpAITaskBunkerSilo:update(dt)
end

function CpAITaskBunkerSilo:setVehicle(vehicle)
	self.vehicle = vehicle
end

function CpAITaskBunkerSilo:setSilo(silo)
	self.silo = silo	
end

function CpAITaskBunkerSilo:start()
	if self.isServer then
		self.vehicle:startCpBunkerSiloWorker(self.silo, self.job:getCpJobParameters())
	end

	CpAITaskBunkerSilo:superClass().start(self)
end

function CpAITaskBunkerSilo:stop()
	CpAITaskBunkerSilo:superClass().stop(self)

	if self.isServer then
		self.vehicle:stopCpBunkerSiloWorker()
	end
end
