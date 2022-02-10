CpAITaskFieldWork = {}
local AITaskFieldWorkCp_mt = Class(CpAITaskFieldWork, AITaskFieldWork)

function CpAITaskFieldWork.new(isServer, job, customMt)
	local self = AITaskFieldWork.new(isServer, job, customMt or AITaskFieldWorkCp_mt)

	return self
end

--- Makes sure the cp fieldworker gets started.
function CpAITaskFieldWork:start()
	if self.isServer then
		self.vehicle:cpStartFieldWorker(self.job:getCpJobParameters())
	end
	AITask.start(self)
	
end
