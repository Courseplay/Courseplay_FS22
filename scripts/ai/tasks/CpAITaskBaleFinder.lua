CpAITaskBaleFinder = {}
local AITaskBaleFinderCp_mt = Class(CpAITaskBaleFinder, AITask)

function CpAITaskBaleFinder.new(isServer, job, customMt)
	local self = AITask.new(isServer, job, customMt or AITaskBaleFinderCp_mt)
	self.vehicle = nil
	return self
end

function CpAITaskBaleFinder:reset()
	self.vehicle = nil

	CpAITaskBaleFinder:superClass().reset(self)
end

function CpAITaskBaleFinder:update(dt)
end

function CpAITaskBaleFinder:setVehicle(vehicle)
	self.vehicle = vehicle
end

function CpAITaskBaleFinder:start()
	if self.isServer then
		self.vehicle:startCpBaleFinder()
	end

	CpAITaskBaleFinder:superClass().start(self)
end

function CpAITaskBaleFinder:stop()
	CpAITaskBaleFinder:superClass().stop(self)

	if self.isServer then
		self.vehicle:stopFieldWorker()
	end
end
