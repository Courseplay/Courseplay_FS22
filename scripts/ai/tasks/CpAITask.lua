
--- AI Job task based on giants AITask
---@class CpAITask
---@field taskIndex number
CpAITask = CpObject()

---@param isServer boolean
---@param job CpAIJob
function CpAITask:init(isServer, job)
	self.isServer = isServer
	self.job = job
	self.isFinished = false
	self.isRunning = false
	self.markAsFinished = false
	self.debugChannel = CpDebug.DBG_FIELDWORK
	self:reset()
end

function CpAITask:delete()
	--- override
end

function CpAITask:update(dt)
	--- override
end

function CpAITask:start()
	self.isFinished = false
	self.isRunning = true

	if self.markAsFinished then
		self.isFinished = true
		self.markAsFinished = false
	end
end

function CpAITask:skip()
	if self.isRunning then
		self.isFinished = true
	else
		self.markAsFinished = true
	end
end

function CpAITask:stop(wasJobStopped)
	self.isRunning = false
	self.markAsFinished = false
end

function CpAITask:reset()
	self.isFinished = false
	self.vehicle = nil
end

function CpAITask:validate(ignoreUnsetParameters)
	return true, nil
end

function CpAITask:getIsFinished()
	return self.isFinished
end

function CpAITask:setVehicle(vehicle)
	self.vehicle = vehicle	
end

function CpAITask:getVehicle()
	return self.vehicle
end

function CpAITask:debug(...)
	if self.vehicle then 
		CpUtil.debugVehicle(self.debugChannel, self.vehicle, ...)
	else 
		CpUtil.debugFormat(self.debugChannel, ...)
	end
end