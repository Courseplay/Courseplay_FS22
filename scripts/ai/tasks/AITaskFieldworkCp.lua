AITaskFieldworkCp = {}
local AITaskFieldworkCp_mt = Class(AITaskFieldworkCp, AITaskFieldWork)

function AITaskFieldworkCp.new(isServer, job, customMt)
	local self = AITaskFieldWork.new(isServer, job, customMt or AITaskFieldworkCp_mt)

	return self
end

--- Makes sure Cp driver gets started.
function AITaskFieldworkCp:start()
	if self.isServer then
		self.vehicle:cpStartFieldworker()
	end
	AITask.start(self)
end
