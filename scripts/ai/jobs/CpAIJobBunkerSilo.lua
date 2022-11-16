--- AI job for the silo driver.
---@class CpAIJobBunkerSilo : CpAIJob
CpAIJobBunkerSilo = {
	name = "BUNKER_SILO_CP",
	translations = {
		jobName = "CP_job_bunkerSilo",
	}
}
local AIJobFieldWorkCp_mt = Class(CpAIJobBunkerSilo, CpAIJob)

function CpAIJobBunkerSilo.new(isServer, customMt)
	local self = CpAIJob.new(isServer, customMt or AIJobFieldWorkCp_mt)
	
	self.hasValidPosition = nil 
	self.bunkerSilo = nil

	return self
end

function CpAIJobBunkerSilo:setupTasks(isServer)
	-- this will add a standard driveTo task to drive to the target position selected by the user
	CpAIJobBunkerSilo:superClass().setupTasks(self, isServer)
	
	self.bunkerSiloTask = CpAITaskBunkerSilo.new(isServer, self)
	self:addTask(self.bunkerSiloTask)
end

function CpAIJobBunkerSilo:setupJobParameters()
	CpAIJobBunkerSilo:superClass().setupJobParameters(self)

	-- Adds bunker silo position parameter
	self.bunkerSiloPositionParameter = AIParameterPosition.new()
	self.bunkerSiloPositionParameter.setValue = function (self, x, z)
		self:setPosition(x, z)		
	end
	self.bunkerSiloPositionParameter.isCpFieldPositionTarget = true

	self:addNamedParameter("bunkerSiloPosition", self.bunkerSiloPositionParameter )
	local positionGroup = AIParameterGroup.new(g_i18n:getText("CP_jobParameters_bunkerSiloPosition_title"))
	positionGroup:addParameter(self.bunkerSiloPositionParameter )
	table.insert(self.groupedParameters, positionGroup)

	self.cpJobParameters = CpBunkerSiloJobParameters(self)
	CpSettingsUtil.generateAiJobGuiElementsFromSettingsTable(self.cpJobParameters.settingsBySubTitle,self,self.cpJobParameters)
	self.cpJobParameters:validateSettings()
end

function CpAIJobBunkerSilo:applyCurrentState(vehicle, mission, farmId, isDirectStart)
	CpAIJobBunkerSilo:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	
	self:copyFrom(vehicle:getCpBunkerSiloWorkerJob())

	local x, z = self.bunkerSiloPositionParameter:getPosition()

	-- no field position from the previous job, use the vehicle's current position
	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
	end

	self.bunkerSiloPositionParameter:setPosition(x, z)
end

--- Checks the bunker silo position setting.
function CpAIJobBunkerSilo:validateBunkerSiloSetup(isValid, errorMessage)
	
	if not isValid then 
		return isValid, errorMessage
	end
	self.hasValidPosition = false 
	self.bunkerSilo = nil
	-- everything else is valid, now find the bunker silo.
	local tx, tz = self.bunkerSiloPositionParameter:getPosition()
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
	CpAIJobBunkerSilo:superClass().setValues(self)
	local vehicle = self.vehicleParameter:getVehicle()
	self.bunkerSiloTask:setVehicle(vehicle)
end

--- Called when parameters change, scan field
function CpAIJobBunkerSilo:validate(farmId)
	local isValid, errorMessage = CpAIJobBunkerSilo:superClass().validate(self, farmId)
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

function CpAIJobBunkerSilo:getFieldPositionTarget()
	return self.bunkerSiloPositionParameter:getPosition()
end

function CpAIJobBunkerSilo:getCanStartJob()
	return self.hasValidPosition
end

function CpAIJobBunkerSilo:getIsAvailableForVehicle(vehicle)
	return vehicle.getCanStartCpBunkerSiloWorker and vehicle:getCanStartCpBunkerSiloWorker()
end

function CpAIJobBunkerSilo:copyFrom(job)
	self.cpJobParameters:copyFrom(job.cpJobParameters)
	local x, z = job.bunkerSiloPositionParameter:getPosition()
	if x ~=nil then
		self.bunkerSiloPositionParameter:setValue(x, z)
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