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
		local tx, tz = self.job:getCpJobParameters().fieldPosition:getPosition()
		local fieldPolygon = CpFieldUtil.getFieldPolygonAtWorldPosition(tx, tz)
		self.vehicle:startCpBaleFinder(fieldPolygon, self.job:getCpJobParameters())
	end

	CpAITaskBaleFinder:superClass().start(self)
end

function CpAITaskBaleFinder:stop()
	CpAITaskBaleFinder:superClass().stop(self)

	if self.isServer then
		self.vehicle:stopCpBaleFinder()
	end
end
