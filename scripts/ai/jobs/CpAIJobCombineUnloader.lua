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


---@param vehicle Vehicle
---@param mission Mission
---@param farmId number
---@param isDirectStart boolean disables the drive to by giants
---@param isStartPositionInvalid boolean resets the drive to target position by giants and the field position to the vehicle position.
function CpAIJobCombineUnloader:applyCurrentState(vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
	CpAIJobFieldWork:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)

	local x, z

	if vehicle.getLastJob ~= nil then
		local lastJob = vehicle:getLastJob()
		if lastJob ~= nil and lastJob.cpJobParameters then
			x, z = lastJob.fieldPositionParameter:getPosition()
		end
	end

	x, z = vehicle:getCpCombineUnloaderFieldPosition()

	-- no field position from the previous job, use the vehicle's current position
	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
	end

	self.fieldPositionParameter:setPosition(x, z)
end

function CpAIJobCombineUnloader:setValues()
	CpAIJob.setValues(self)
	local vehicle = self.vehicleParameter:getVehicle()
	self.combineUnloaderTask:setVehicle(vehicle)
end

--- Called when parameters change, scan field
function CpAIJobCombineUnloader:validate(farmId)
--[[
	if not self.fieldPolygon then
		-- after a savegame is loaded, we still have the job parameters (positions), but we do not save the
		-- field polygon, so just regenerate it here if we can
		self.fieldPolygon, _ = CpFieldUtil.getFieldPolygonAtWorldPosition(self.fieldPositionParameter.x, self.fieldPositionParameter.z)
		if self.fieldPolygon then
			self.hasValidPosition = true
		end
	end
	local isValid, errorMessage = CpAIJob.validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	if not self.fieldPolygon then 
		self.selectedFieldPlot:setVisible(false)
		return false, g_i18n:getText("CP_error_not_on_field")
	end
	self.selectedFieldPlot:setWaypoints(self.fieldPolygon)
	self.selectedFieldPlot:setVisible(true)
	self.selectedFieldPlot:setBrightColor(true)
	self.combineUnloaderTask:setFieldPolygon(self.fieldPolygon)
	return true
	]]--
	local isValid, errorMessage = CpAIJob.validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	local vehicle = self.vehicleParameter:getVehicle()
	if vehicle then 
		local x, z = self.fieldPositionParameter:getPosition()
		vehicle:setCpCombineUnloaderFieldPosition(x, z)
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