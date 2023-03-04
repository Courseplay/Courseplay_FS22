CpAITaskCombineUnloader = {}
local AITaskCombineUnloaderCp_mt = Class(CpAITaskCombineUnloader, AITask)

function CpAITaskCombineUnloader.new(isServer, job, customMt)
	local self = AITask.new(isServer, job, customMt or AITaskCombineUnloaderCp_mt)
	self.vehicle = nil
	self.fieldPolygon = nil
	self.fieldUnloadPosition = nil
	self.unloadTipSideID = nil
	return self
end

function CpAITaskCombineUnloader:reset()
	self.vehicle = nil
	self.fieldPolygon = nil
	self.fieldUnloadPosition = nil
	self.unloadTipSideID = nil
	CpAITaskCombineUnloader:superClass().reset(self)
end

function CpAITaskCombineUnloader:update(dt)
end

function CpAITaskCombineUnloader:setVehicle(vehicle)
	self.vehicle = vehicle
end

function CpAITaskCombineUnloader:setFieldPolygon(fieldPolygon)
	self.fieldPolygon = fieldPolygon
end

function CpAITaskCombineUnloader:setFieldUnloadPositionAndTipSide(position, tipSideID)
	self.fieldUnloadPosition = position
	self.unloadTipSideID = tipSideID
end

function CpAITaskCombineUnloader:start()
	if self.isServer then
		self.vehicle:startCpCombineUnloader(self.fieldPolygon, self.job:getCpJobParameters(), self.fieldUnloadPosition, self.unloadTipSideID)
	end

	CpAITaskCombineUnloader:superClass().start(self)
end

function CpAITaskCombineUnloader:stop()
	CpAITaskCombineUnloader:superClass().stop(self)

	if self.isServer then
		self.vehicle:stopFieldWorker()
	end
end
