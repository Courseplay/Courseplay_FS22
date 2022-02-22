--- Bale finder job.
---@class CpAIJobBaleFinder : CpAIJobFieldWork
CpAIJobBaleFinder = {
	name = "BALE_FINDER_CP",
	translations = {
		jobName = "CP_job_baleCollect"
	}
}
local AIJobBaleFinderCp_mt = Class(CpAIJobBaleFinder, CpAIJobFieldWork)


function CpAIJobBaleFinder.new(isServer, customMt)
	local self = CpAIJobFieldWork.new(isServer, customMt or AIJobBaleFinderCp_mt)
	
	return self
end

function CpAIJobBaleFinder:setupTasks(isServer)
	CpAIJob.setupTasks(self, isServer)
	self.baleFinderTask = CpAITaskBaleFinder.new(isServer, self)
	self:addTask(self.baleFinderTask)
end

function CpAIJobBaleFinder:setupCpJobParameters()
	--- No cp job parameters needed for now.
end

--- Disables course generation.
function CpAIJobBaleFinder:getCanGenerateFieldWorkCourse()
	return false
end

--- Disables course generation.
function CpAIJobBaleFinder:isCourseGenerationAllowed()
	return false
end

function CpAIJobBaleFinder:getIsAvailableForVehicle(vehicle)
	return vehicle.getCanStartCpBaleFinder and vehicle:getCanStartCpBaleFinder()
end

function CpAIJobBaleFinder:getCanStartJob()
	return self.hasValidPosition
end


function CpAIJobBaleFinder:applyCurrentState(vehicle, mission, farmId, isDirectStart)
	CpAIJobBaleFinder:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
end

function CpAIJobBaleFinder:setValues()
	CpAIJob.setValues(self)
	local vehicle = self.vehicleParameter:getVehicle()
	self.baleFinderTask:setVehicle(vehicle)
end

--- Called when parameters change, scan field
function CpAIJobBaleFinder:validate(farmId)
	local isValid, errorMessage = CpAIJob.validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	isValid, errorMessage = self:validateFieldSetup(isValid, errorMessage)
	return isValid, errorMessage
end
