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
	self.cpJobParameters = CpBaleFinderJobParameters(self)
	CpSettingsUtil.generateAiJobGuiElementsFromSettingsTable(self.cpJobParameters.settingsBySubTitle,self,self.cpJobParameters)
	self.cpJobParameters:validateSettings()
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


function CpAIJobBaleFinder:applyCurrentState(vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
	CpAIJobBaleFinder:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
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
	self.baleFinderTask:setFieldPolygon(self.fieldPolygon)
	return isValid, errorMessage
end

function CpAIJobBaleFinder:readStream(streamId, connection)
	if streamReadBool(streamId) then
		self.fieldPolygon = CustomField.readStreamVertices(streamId, connection)
		self.baleFinderTask:setFieldPolygon(self.fieldPolygon)
	end
	CpAIJobBaleFinder:superClass().readStream(self, streamId, connection)
end

function CpAIJobBaleFinder:writeStream(streamId, connection)
	if self.fieldPolygon then
		streamWriteBool(streamId, true)
		CustomField.writeStreamVertices(self.fieldPolygon, streamId, connection)
	else 
		streamWriteBool(streamId, false)
	end
	CpAIJobBaleFinder:superClass().writeStream(self, streamId, connection)
end