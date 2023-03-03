--- AI job for the silo driver.
---@class CpAIJobBunkerSilo : CpAIJobFieldWork
CpAIJobBunkerSilo = {
	name = "BUNKER_SILO_CP",
	jobName = "CP_job_bunkerSilo",
	fieldPositionParameterText = "CP_jobParameters_bunkerSiloPosition_title",
	targetPositionParameterText = "CP_jobParameters_parkPosition_title",
}
local CpAIJobBunkerSilo_mt = Class(CpAIJobBunkerSilo, CpAIJobFieldWork)

function CpAIJobBunkerSilo.new(isServer, customMt)
	local self = CpAIJobFieldWork.new(isServer, customMt or CpAIJobBunkerSilo_mt)
	
	self.hasValidPosition = nil 
	self.bunkerSilo = nil

	return self
end

function CpAIJobBunkerSilo:setupTasks(isServer)
	-- this will add a standard driveTo task to drive to the target position selected by the user
	CpAIJob.setupTasks(self, isServer)
	
	self.bunkerSiloTask = CpAITaskBunkerSilo.new(isServer, self)
	self:addTask(self.bunkerSiloTask)
end

function CpAIJobBunkerSilo:setupCpJobParameters()
	self.cpJobParameters = CpBunkerSiloJobParameters(self)
	CpSettingsUtil.generateAiJobGuiElementsFromSettingsTable(self.cpJobParameters.settingsBySubTitle,self,self.cpJobParameters)
	self.cpJobParameters:validateSettings()
end

--- Disables course generation.
function CpAIJobBunkerSilo:getCanGenerateFieldWorkCourse()
	return false
end

--- Disables course generation.
function CpAIJobBunkerSilo:isCourseGenerationAllowed()
	return false
end

function CpAIJobBunkerSilo:getIsAvailableForVehicle(vehicle)
	return vehicle.getCanStartCpBunkerSiloWorker and vehicle:getCanStartCpBunkerSiloWorker()
end

function CpAIJobBunkerSilo:getCanStartJob()
	return self.hasValidPosition
end

function CpAIJobBunkerSilo:applyCurrentState(vehicle, mission, farmId, isDirectStart)
	CpAIJob.applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	
	self:copyFrom(vehicle:getCpBunkerSiloWorkerJob())

	local x, z = self.cpJobParameters.siloPosition:getPosition()

	-- no field position from the previous job, use the vehicle's current position
	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
		self.cpJobParameters.siloPosition:setPosition(x, z)
	end

end

--- Checks the bunker silo position setting.
function CpAIJobBunkerSilo:validateBunkerSiloSetup(isValid, errorMessage)
	
	if not isValid then 
		return isValid, errorMessage
	end
	self.hasValidPosition = false 
	self.bunkerSilo = nil
	-- everything else is valid, now find the bunker silo.
	local tx, tz = self.cpJobParameters.siloPosition:getPosition()
	self.hasValidPosition, self.bunkerSilo =  g_bunkerSiloManager:getBunkerSiloAtPosition(tx, tz)
	--[[	
	if not self.hasValidPosition and self.isDirectStart then 
		local vehicle = self:getVehicle()
		if vehicle then
			local x, _, z
			x, _, z = getWorldTranslation(Markers.getFrontMarkerNode(vehicle))
			self.hasValidPosition, self.bunkerSilo =  g_bunkerSiloManager:getBunkerSiloAtPosition(x, z)
			if not self.hasValidPosition then 
				x, _, z = getWorldTranslation(Markers.getBackMarkerNode(vehicle))
				self.hasValidPosition, self.bunkerSilo =  g_bunkerSiloManager:getBunkerSiloAtPosition(x, z)
			end
		end
	end
	]]--
	self.bunkerSiloTask:setSilo(self.bunkerSilo)
	
	local x, z = self.cpJobParameters.startPosition:getPosition()
	local angle = self.cpJobParameters.startPosition:getAngle()
	local dirX, dirZ = self.cpJobParameters.startPosition:getDirection()
	self.bunkerSiloTask:setParkPosition(x, z, angle, dirX, dirZ)

	if not self.hasValidPosition or self.bunkerSilo == nil then 
		return false, g_i18n:getText("CP_error_no_bunkerSilo_found")
	end
	return true, ''
end

function CpAIJobBunkerSilo:setValues()
	CpAIJob.setValues(self)
	local vehicle = self.vehicleParameter:getVehicle()
	self.bunkerSiloTask:setVehicle(vehicle)
end

--- Called when parameters change, scan field
function CpAIJobBunkerSilo:validate(farmId)
	local isValid, errorMessage = CpAIJob.validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	local vehicle = self.vehicleParameter:getVehicle()
	if vehicle then 
		vehicle:applyCpBunkerSiloWorkerJobParameters(self)
	end
	isValid, errorMessage = self:validateBunkerSiloSetup(isValid, errorMessage)
	if not isValid then
		return isValid, errorMessage
	end
	return true, ''
end

function CpAIJobBunkerSilo:drawSilos(map)
	g_bunkerSiloManager:drawSilos(map, self.bunkerSilo)
end

function CpAIJobBunkerSilo:copyFrom(job)
	self.cpJobParameters:copyFrom(job.cpJobParameters)
end

function CpAIJobBunkerSilo:saveToXMLFile(xmlFile, key, usedModNames)
	CpAIJobBunkerSilo:superClass().saveToXMLFile(self, xmlFile, key)
	self.cpJobParameters:saveToXMLFile(xmlFile, key)
	return true
end

function CpAIJobBunkerSilo:loadFromXMLFile(xmlFile, key)
	CpAIJobBunkerSilo:superClass().loadFromXMLFile(self, xmlFile, key)
	self.cpJobParameters:loadFromXMLFile(xmlFile, key)
end

function CpAIJobBunkerSilo:readStream(streamId, connection)
	CpAIJobBunkerSilo:superClass().readStream(self, streamId, connection)
	
	local x, z = self.cpJobParameters.siloPosition:getPosition()
	self.hasValidPosition, self.bunkerSilo =  g_bunkerSiloManager:getBunkerSiloAtPosition(x, z)
	self.bunkerSiloTask:setSilo(self.bunkerSilo)

	local x, z = self.cpJobParameters.startPosition:getPosition()
	local angle = self.cpJobParameters.startPosition:getAngle()
	local dirX, dirZ = self.cpJobParameters.startPosition:getDirection()
	self.bunkerSiloTask:setParkPosition(x, z, angle, dirX, dirZ)
end
