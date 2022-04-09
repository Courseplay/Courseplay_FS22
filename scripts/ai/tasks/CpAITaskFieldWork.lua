CpAITaskFieldWork = {}
local AITaskFieldWorkCp_mt = Class(CpAITaskFieldWork, AITaskFieldWork)

function CpAITaskFieldWork.new(isServer, job, customMt)
	---@type CpAITaskFieldWork
	local self = AITaskFieldWork.new(isServer, job, customMt or AITaskFieldWorkCp_mt)
	self.startPosition = nil
	return self
end

--- Makes sure the cp fieldworker gets started.
function CpAITaskFieldWork:start()
	if self.isServer then
		self.vehicle:startCpFieldWorker(self.job:getCpJobParameters(), self.startPosition)
	end
	AITask.start(self)
	
end

function CpAITaskFieldWork:setStartPosition(startPosition)
	self.startPosition = startPosition
end