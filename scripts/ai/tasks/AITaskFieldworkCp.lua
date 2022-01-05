AITaskFieldworkCp = {}
local AITaskFieldworkCp_mt = Class(AITaskFieldworkCp, AITaskFieldwork)

function AITaskFieldworkCp.new(isServer, job, customMt)
	local self = AITaskFieldwork.new(isServer, job, customMt or AITaskFieldworkCp_mt)

	return self
end

--- Makes sure Cp driver gets started.
function AITaskFieldworkCp:start()
	if self.isServer then
		self.vehicle:startStopDriver()
	end

	AITaskFieldworkCp:superClass().start(self)
end
