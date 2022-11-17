--- AI job for the silo driver.
---@class CpAIJobBunkerSilo : CpAIJobFieldWork
CpAIJobBunkerSilo = {
	name = "BUNKER_SILO_CP",
	translations = {
		jobName = "CP_job_bunkerSilo",
		fieldPositionParameter = "CP_jobParameters_bunkerSiloPosition_title"
	}
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

	local x, z = self.fieldPositionParameter:getPosition()

	-- no field position from the previous job, use the vehicle's current position
	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
	end

	self.fieldPositionParameter:setPosition(x, z)
end

--- Checks the bunker silo position setting.
function CpAIJobBunkerSilo:validateBunkerSiloSetup(isValid, errorMessage)
	
	if not isValid then 
		return isValid, errorMessage
	end
	self.hasValidPosition = false 
	self.bunkerSilo = nil
	-- everything else is valid, now find the bunker silo.
	local tx, tz = self.fieldPositionParameter:getPosition()
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
	
	local x, z = self.positionAngleParameter:getPosition()
	local angle = self.positionAngleParameter:getAngle()
	local dirX, dirZ = self.positionAngleParameter:getDirection()
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
	local x, z = job.fieldPositionParameter:getPosition()
	if x ~=nil then
		self.fieldPositionParameter:setValue(x, z)
	end
	local x, z = job.positionAngleParameter:getPosition()
	if x ~= nil then
		self.positionAngleParameter:setPosition(x, z)
	end
	local angle = job.positionAngleParameter:getAngle()
	if angle ~= nil then
		self.positionAngleParameter:setAngle(angle)
	end
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
	self.fieldPositionParameter:readStream(streamId, connection)
	local x, z = self.fieldPositionParameter:getPosition()
	self.hasValidPosition, self.bunkerSilo =  g_bunkerSiloManager:getBunkerSiloAtPosition(x, z)
	self.bunkerSiloTask:setSilo(self.bunkerSilo)
	local x, z = self.positionAngleParameter:getPosition()
	local angle = self.positionAngleParameter:getAngle()
	local dirX, dirZ = self.positionAngleParameter:getDirection()
	self.bunkerSiloTask:setParkPosition(x, z, angle, dirX, dirZ)
end

function CpAIJobBunkerSilo:writeStream(streamId, connection)
	CpAIJobBunkerSilo:superClass().writeStream(self, streamId, connection)
	self.fieldPositionParameter:writeStream(streamId, connection)
	self.positionAngleParameter:writeStream(streamId, connection)
end