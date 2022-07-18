--- Combine unloader job.
---@class CpAIJobCombineUnloader : CpAIJobFieldWork
CpAIJobCombineUnloader = {
	name = "COMBINE_UNLOADER_CP",
	translations = {
		jobName = "CP_job_unloadCombine"
	}
}
local AIJobCombineUnloaderCp_mt = Class(CpAIJobCombineUnloader, CpAIJobFieldWork)


function CpAIJobCombineUnloader.new(isServer, customMt)
	local self = CpAIJobFieldWork.new(isServer, customMt or AIJobCombineUnloaderCp_mt)
	
	return self
end

function CpAIJobCombineUnloader:setupTasks(isServer)
	CpAIJob.setupTasks(self, isServer)
	self.combineUnloaderTask = CpAITaskCombineUnloader.new(isServer, self)
	self:addTask(self.combineUnloaderTask)
end

function CpAIJobCombineUnloader:setupCpJobParameters()
	self.cpJobParameters = CpCombineUnloaderJobParameters(self)
	CpSettingsUtil.generateAiJobGuiElementsFromSettingsTable(self.cpJobParameters.settingsBySubTitle, self, self.cpJobParameters)
	self.cpJobParameters:validateSettings()
end

--- Disables course generation.
function CpAIJobCombineUnloader:getCanGenerateFieldWorkCourse()
	return false
end

--- Disables course generation.
function CpAIJobCombineUnloader:isCourseGenerationAllowed()
	return false
end

function CpAIJobCombineUnloader:getIsAvailableForVehicle(vehicle)
	return vehicle.getCanStartCpCombineUnloader and vehicle:getCanStartCpCombineUnloader()
end

function CpAIJobCombineUnloader:getCanStartJob()
	return self.hasValidPosition
end


function CpAIJobCombineUnloader:applyCurrentState(vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
	CpAIJobCombineUnloader:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
end

function CpAIJobCombineUnloader:setValues()
	CpAIJob.setValues(self)
	local vehicle = self.vehicleParameter:getVehicle()
	self.combineUnloaderTask:setVehicle(vehicle)
end

--- Called when parameters change, scan field
function CpAIJobCombineUnloader:validate(farmId)
	local isValid, errorMessage = CpAIJob.validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	isValid, errorMessage = self:validateFieldSetup(isValid, errorMessage)	
	self.combineUnloaderTask:setFieldPolygon(self.fieldPolygon)
	return isValid, errorMessage
end

function CpAIJobCombineUnloader:readStream(streamId, connection)
	if streamReadBool(streamId) then
		self.fieldPolygon = CustomField.readStreamVertices(streamId, connection)
		self.combineUnloaderTask:setFieldPolygon(self.fieldPolygon)
	end
	CpAIJobCombineUnloader:superClass().readStream(self, streamId, connection)
end

function CpAIJobCombineUnloader:writeStream(streamId, connection)
	if self.fieldPolygon then
		streamWriteBool(streamId, true)
		CustomField.writeStreamVertices(self.fieldPolygon, streamId, connection)
	else 
		streamWriteBool(streamId, false)
	end
	CpAIJobCombineUnloader:superClass().writeStream(self, streamId, connection)
end